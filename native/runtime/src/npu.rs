//! The app's NPU switch: a C ABI over `cortiq_engine::npu` (Android only).
//!
//! The engine's NPU lane runs the FFN's `up` matvec on the Hexagon NPU
//! through Qualcomm's QNN HTP backend while the CPU computes `gate`, times
//! both ways on the first answer and keeps the NPU only where it wins. On
//! other platforms these entry points exist and report `supported: false`.

use std::ffi::c_char;

/// Ask for the NPU lane (or switch it off). Takes effect at the next load.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_set_npu(enable: bool) {
    #[cfg(target_os = "android")]
    cortiq_engine::npu::set_enabled(enable);
    #[cfg(not(target_os = "android"))]
    let _ = enable;
}

/// Directory holding `libcortiq_npu.so`, the QNN libraries and the Hexagon
/// skeletons: the app's native library directory. Call before enabling.
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
/// `{"supported":true,"requested":true,"available":true,"verdict":"cpu",
///   "npu_us":2080,"cpu_us":1490,"lanes":1,"weights_mb":15,"calls":24,
///   "fallbacks":0,"error":""}`. `verdict` is `untested`, `npu` or `cpu`.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_npu_status() -> *const c_char {
    #[cfg(target_os = "android")]
    let json = {
        let s = cortiq_engine::npu::status();
        serde_json::json!({
            "supported": true,
            "requested": s.requested,
            "available": s.available,
            "verdict": s.verdict,
            "npu_us": s.npu_us,
            "cpu_us": s.cpu_us,
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
