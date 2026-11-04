//! Mobile speech-to-text over cortiq-engine's Whisper path.
//!
//! A Whisper CMF (`arch_name` "whisper") has an encoder/decoder layout the
//! chat pipeline cannot build, so it gets a handle of its own:
//! `cortiq_stt_load` memory-maps the file and checks the architecture,
//! `cortiq_stt_transcribe` runs one WAV file through
//! `cortiq_engine::whisper::transcribe`, `cortiq_stt_free` releases it.
//! Never pass a speech handle to the chat functions or the other way round.
//!
//! One call at a time per handle. A transcription blocks for seconds to
//! minutes on a phone (the encoder dominates), so the app runs it on a
//! worker isolate, never the UI thread. Returned JSON is the thread-local
//! buffer every JSON getter of this library shares: copy it before the next
//! JSON call on the same thread.
use super::{set_error, set_last_json};
use cortiq_core::CmfModel;
use serde::Deserialize;
use std::{
    ffi::{CStr, c_char, c_void},
    panic::{AssertUnwindSafe, catch_unwind},
    path::Path,
    ptr::{null, null_mut},
    sync::{Arc, Mutex},
    time::Instant,
};

struct SttCtx {
    model: Arc<CmfModel>,
    /// Serializes transcriptions on one handle: the engine keeps a single
    /// worker pool, and the trim switch below is process-wide.
    busy: Mutex<()>,
}

/// `cortiq_stt_transcribe` options, all optional:
/// `{"language":"ru","task":"transcribe","max_tokens":200,"trim_encoder":true}`.
#[derive(Deserialize)]
#[serde(default)]
struct SttOptions {
    /// Whisper language code, the `<|xx|>` prompt token ("en", "ru", …).
    language: String,
    /// "transcribe" or "translate" (to English).
    task: String,
    /// Decoder budget per 30 s window, 1..=448.
    max_tokens: usize,
    /// Run the encoder over the audio prefix only instead of the full 30 s
    /// window. On a Xiaomi 12 Lite the full window costs about 80 s per
    /// clip whatever its length; trimmed, about one second per second of
    /// audio. Short clips (under ~8 s) then tend to loop, so the app pads a
    /// short recording with silence before it gets here.
    trim_encoder: bool,
}

impl Default for SttOptions {
    fn default() -> Self {
        Self {
            language: "en".to_string(),
            task: "transcribe".to_string(),
            max_tokens: 200,
            trim_encoder: true,
        }
    }
}

/// Open a Whisper CMF for transcription. NULL on error (`cortiq_last_error`);
/// a file of any other architecture is refused here, before the first clip.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_stt_load(path: *const c_char) -> *mut c_void {
    catch_unwind(|| {
        if path.is_null() {
            set_error("path is NULL");
            return null_mut();
        }
        let path = match unsafe { CStr::from_ptr(path) }.to_str() {
            Ok(p) => p,
            Err(_) => {
                set_error("path is not valid UTF-8");
                return null_mut();
            }
        };
        let model = match CmfModel::open_sharded(path) {
            Ok(m) => m,
            Err(e) => {
                set_error(&format!("open: {e}"));
                return null_mut();
            }
        };
        let arch = model.header.arch.arch_name.clone();
        if !arch.eq_ignore_ascii_case("whisper") {
            set_error(&format!("{path} is not a Whisper CMF (arch {arch})"));
            return null_mut();
        }
        Box::into_raw(Box::new(SttCtx {
            model: Arc::new(model),
            busy: Mutex::new(()),
        }))
        .cast()
    })
    .unwrap_or_else(|_| {
        set_error("panic during speech model load");
        null_mut()
    })
}

/// Release a speech handle. NULL is a no-op. Wait for a running
/// transcription first; the handle must not be freed under it.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_stt_free(handle: *mut c_void) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            drop(unsafe { Box::from_raw(handle.cast::<SttCtx>()) });
        }
    }));
}

/// Transcribe one WAV file (PCM 8/16/24/32-bit or IEEE float, any rate and
/// channel count; resampled to 16 kHz mono inside the engine). Returns JSON
/// `{"text":…,"elapsed_ms":…,"language":…,"trim_encoder":…}`, or NULL with
/// `cortiq_last_error` set. `options_json` may be NULL or empty.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_stt_transcribe(
    handle: *mut c_void,
    wav_path: *const c_char,
    options_json: *const c_char,
) -> *const c_char {
    catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() || wav_path.is_null() {
            set_error("handle or wav path is NULL");
            return null();
        }
        let ctx = unsafe { &*(handle as *const SttCtx) };
        let wav = match unsafe { CStr::from_ptr(wav_path) }.to_str() {
            Ok(p) => p,
            Err(_) => {
                set_error("wav path is not valid UTF-8");
                return null();
            }
        };
        let options = match parse_options(options_json) {
            Ok(o) => o,
            Err(e) => {
                set_error(&e);
                return null();
            }
        };
        let _busy = match ctx.busy.lock() {
            Ok(g) => g,
            Err(_) => {
                set_error("speech handle is poisoned");
                return null();
            }
        };
        // The engine reads this switch from the environment, so it is set
        // right before the call, under the handle lock.
        // SAFETY: the only readers are the engine's own `std::env::var`
        // calls inside `transcribe`, which run after this on the same
        // thread; no other thread of this library touches the environment.
        unsafe {
            std::env::set_var(
                "CMF_WHISPER_TRIM_ENCODER",
                if options.trim_encoder { "1" } else { "0" },
            );
        }
        let started = Instant::now();
        let max_tokens = options.max_tokens.clamp(1, 448);
        match cortiq_engine::whisper::transcribe(
            &ctx.model,
            Path::new(wav),
            &options.language,
            &options.task,
            max_tokens,
        ) {
            Ok(text) => {
                let out = serde_json::json!({
                    "text": text,
                    "elapsed_ms": started.elapsed().as_millis() as u64,
                    "language": options.language,
                    "task": options.task,
                    "trim_encoder": options.trim_encoder,
                });
                set_last_json(&out.to_string())
            }
            Err(e) => {
                set_error(&e);
                null()
            }
        }
    }))
    .unwrap_or_else(|_| {
        set_error("panic during transcription");
        null()
    })
}

fn parse_options(options_json: *const c_char) -> Result<SttOptions, String> {
    if options_json.is_null() {
        return Ok(SttOptions::default());
    }
    let s = unsafe { CStr::from_ptr(options_json) }
        .to_str()
        .map_err(|_| "options is not valid UTF-8".to_string())?;
    if s.trim().is_empty() {
        return Ok(SttOptions::default());
    }
    serde_json::from_str(s).map_err(|e| format!("options: {e}"))
}
