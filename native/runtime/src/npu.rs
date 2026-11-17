//! The app's NPU switch: a C ABI over `cortiq_engine::npu` (Android only).
//!
//! The engine's NPU lane gives the Hexagon DSP a share of the rows of a
//! prompt chunk's matrix products (our own integer-HVX module over FastRPC)
//! while the CPU computes the rest, times both ways and keeps the NPU only
//! where it wins. On other platforms these entry points exist and report
//! `supported: false`.

use std::ffi::c_char;

/// Ask for the NPU lane (or switch it off). Takes effect at the next load.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_set_npu(enable: bool) {
    #[cfg(target_os = "android")]
    cortiq_engine::npu::set_enabled(enable);
    #[cfg(not(target_os = "android"))]
    let _ = enable;
}

/// Directory holding `libcortiq_npu.so` and `libcortiq_hvx_skel.so`: the
/// app's native library directory. Call before enabling.
///
/// # Safety
/// `dir` is NULL or a NUL-terminated UTF-8 string valid for the call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cortiq_npu_set_lib_dir(dir: *const c_char) {
    if dir.is_null() {
        return;
    }
    #[cfg(target_os = "android")]
    if let Ok(d) = unsafe { std::ffi::CStr::from_ptr(dir) }.to_str() {
        cortiq_engine::npu::set_lib_dir(d);
    }
}

/// The lane's state as JSON, valid until the next call from this thread:
/// `{"supported":true,"requested":true,"available":true,
///   "prompt_verdict":"npu","prompt_npu":11233,"prompt_cpu":28085,
///   "decode_verdict":"untested","decode_npu":0,"decode_cpu":0,
///   "lanes":48,"weights_mb":420,"calls":96,"fallbacks":0,"error":""}`.
/// A verdict is `untested`, `npu` or `cpu`; the prompt numbers are
/// nanoseconds per activation vector per million weights, the decode ones
/// microseconds per fused gate+up.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_npu_status() -> *const c_char {
    #[cfg(target_os = "android")]
    let json = {
        let s = cortiq_engine::npu::status();
        serde_json::json!({
            "supported": true,
            "requested": s.requested,
            "available": s.available,
            "prompt_verdict": s.batch_verdict,
            "prompt_npu": s.batch_npu_us,
            "prompt_cpu": s.batch_cpu_us,
            "decode_verdict": s.verdict,
            "decode_npu": s.npu_us,
            "decode_cpu": s.cpu_us,
            "lanes": s.lanes,
            "weights_mb": s.weights_mb,
            "calls": s.calls,
            "fallbacks": s.fallbacks,
            "error": s.error,
        })
        .to_string()
    };
    #[cfg(not(target_os = "android"))]
    let json = r#"{"supported":false}"#.to_string();
    super::set_last_json(&json)
}
