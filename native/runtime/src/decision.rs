//! Mobile adapter over the unmodified cortiq-decision 0.8.0 service.
//! Opaque handles must not be freed while a call is in flight. All native
//! operations run on a Dart worker, never the platform UI thread.
use super::{set_error, set_last_json};
use cortiq_decision::{
    config::Config,
    container::{DecisionModel, Verify},
    protocol::ApiError,
    service::{DecisionService, LoadedModel, ModelHandle, Principal},
};
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    ffi::{CStr, c_char, c_void},
    panic::{AssertUnwindSafe, catch_unwind},
    sync::Arc,
};

#[unsafe(no_mangle)]
pub extern "C" fn cortiq_decision_load(path: *const c_char) -> *mut c_void {
    catch_unwind(|| {
        let result = (|| -> Result<DecisionService, Box<dyn std::error::Error>> {
            if path.is_null() {
                return Err("path is NULL".into());
            }
            let path = unsafe { CStr::from_ptr(path) }.to_str()?;
            let model = LoadedModel::new(DecisionModel::open(path, Verify::Full)?)?;
            let mut config = Config::default();
            // Mobile is offline by construction. HTTP authentication belongs
            // to CmfServer; this internal ABI is never exposed as a listener.
            config.auth.require = Some(false);
            config.oracle.enabled = false;
            config.learning.enabled = false;
            config.cache.enabled = false;
            Ok(
                DecisionService::open(Arc::new(ModelHandle::new(model)), config, None)?
                    .with_loopback(true)
                    .without_hint_log(),
            )
        })();
        match result {
            Ok(service) => Box::into_raw(Box::new(service)).cast(),
            Err(e) => {
                set_error(&e.to_string());
                std::ptr::null_mut()
            }
        }
    })
    .unwrap_or_else(|_| {
        set_error("panic during decision load");
        std::ptr::null_mut()
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn cortiq_decision_free(handle: *mut c_void) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            drop(unsafe { Box::from_raw(handle.cast::<DecisionService>()) });
        }
    }));
}

/// Borrowed JSON envelope {status, body}, copied by Dart before the next call.
/// A NULL C string is an invalid argument, never an empty request.
#[unsafe(no_mangle)]
pub extern "C" fn cortiq_decision_request(
    handle: *mut c_void,
    method: *const c_char,
    path: *const c_char,
    body: *const c_char,
) -> *const c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() || method.is_null() || path.is_null() || body.is_null() {
            return Err(ApiError::invalid("NULL decision argument"));
        }
        let string = |p| {
            unsafe { CStr::from_ptr(p) }
                .to_str()
                .map_err(|_| ApiError::invalid("invalid UTF-8"))
        };
        let service = unsafe { &*handle.cast::<DecisionService>() };
        dispatch(service, string(method)?, string(path)?, string(body)?)
    }))
    .unwrap_or_else(|_| Err(ApiError::internal("decision request failed")));
    let value = match result {
        Ok(body) => json!({"status":200,"body":body}),
        Err(e) => json!({"status":e.status,"body":e.body("mobile")}),
    };
    set_last_json(&value.to_string())
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct QuickRequest {
    text: String,
    skill: String,
    #[serde(default = "balanced")]
    profile: String,
}
fn balanced() -> String {
    "balanced".into()
}

fn dispatch(
    service: &DecisionService,
    method: &str,
    path: &str,
    body: &str,
) -> Result<Value, ApiError> {
    if body.len() > 1_048_576 {
        let mut e = ApiError::invalid("request body exceeds 1 MiB");
        e.status = 413;
        return Err(e);
    }
    match (method, path) {
        ("GET", "/healthz") => Ok(service.healthz_json()),
        ("GET", "/v1/models") => Ok(service.models_json()),
        ("GET", "/v1/skills") => Ok(service.skills_json()),
        ("GET", path) if path.starts_with("/v1/skills/") => service.skill_json(&path[11..]),
        ("POST", "/v1/decisions" | "/api/alpha/decisions") => {
            let mut value: Value =
                serde_json::from_str(body).map_err(|_| ApiError::invalid("invalid JSON"))?;
            // No request can enable an external oracle on a mobile device.
            if !value.is_object() {
                return Err(ApiError::invalid("expected a JSON object"));
            }
            if value.get("cmf").is_none() {
                value["cmf"] = json!({});
            }
            if !value["cmf"].is_object() {
                return Err(ApiError::invalid("cmf must be an object"));
            }
            if value["cmf"].get("oracle").is_some_and(|v| v != false) {
                return Err(ApiError::invalid(
                    "mobile is offline; cmf.oracle must be false",
                ));
            }
            value["cmf"]["oracle"] = json!(false);
            Ok(service
                .decide_body(value.to_string().as_bytes(), &Principal::open())?
                .response)
        }
        ("POST", "/v1/decide") => {
            let request: QuickRequest =
                serde_json::from_str(body).map_err(|e| ApiError::invalid(e.to_string()))?;
            if request.text.trim().is_empty() || request.text.len() > 32768 {
                return Err(ApiError::invalid("text must contain 1–32768 UTF-8 bytes"));
            }
            let model = service.handle().current();
            let skill = model
                .skill(&request.skill)
                .ok_or_else(|| ApiError::not_found("unknown skill"))?;
            let contract = skill.rubric_question("intent").contract();
            let request = json!({"model":"cortiq/decision", "state":request.text,
                "questions":{"intent":contract},
                "cmf":{"skill":request.skill,"profile":request.profile,"oracle":false,"explain":true}});
            let decided =
                service.decide_body(request.to_string().as_bytes(), &Principal::open())?;
            let outcome = &decided.questions[0];
            let local = outcome
                .local
                .as_ref()
                .ok_or_else(|| ApiError::internal("no local decision"))?;
            Ok(json!({
                "id":decided.id,"skill":local.skill,
                "choice":if local.accepted { local.choice.clone() } else { None },
                "candidate":local.choice,"accepted":local.accepted,"confidence":local.confidence,
                "errors":local.ranked_errors(5).into_iter().map(|(label,error)|json!({"label":label,"error":error})).collect::<Vec<_>>(),
                "timings_us":decided.timings.to_json(),"oracle":false,
                "device":model.encoder().encoder().device_name(),"decision":decided.response
            }))
        }
        _ => Err(ApiError::not_found("unknown decision endpoint")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn null_is_safe() {
        assert!(cortiq_decision_load(std::ptr::null()).is_null());
        cortiq_decision_free(std::ptr::null_mut());
        let p = cortiq_decision_request(
            std::ptr::null_mut(),
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
        );
        let v: Value =
            serde_json::from_str(unsafe { CStr::from_ptr(p) }.to_str().unwrap()).unwrap();
        assert_eq!(v["status"], 400);
    }
    #[test]
    #[ignore = "requires CMF_TEST_MODEL pointing to the verified release file"]
    fn actual_model() {
        let path = std::env::var("CMF_TEST_MODEL").expect("CMF_TEST_MODEL required");
        let model = LoadedModel::new(DecisionModel::open(path, Verify::Full).unwrap()).unwrap();
        let mut cfg = Config::default();
        cfg.auth.require = Some(false);
        cfg.oracle.enabled = false;
        let service = DecisionService::open(Arc::new(ModelHandle::new(model)), cfg, None)
            .unwrap()
            .without_hint_log();
        let v = dispatch(
            &service,
            "POST",
            "/v1/decide",
            r#"{"text":"I still have not received my new card","skill":"banking77"}"#,
        )
        .unwrap();
        assert_eq!(v["choice"], "card_arrival");
        assert_eq!(v["accepted"], true);
        assert_eq!(v["oracle"], false);
        assert!(
            dispatch(
                &service,
                "POST",
                "/v1/decide",
                r#"{"text":"x","skill":"missing"}"#
            )
            .is_err()
        );
        assert!(
            dispatch(
                &service,
                "POST",
                "/v1/decisions",
                r#"{"cmf":{"oracle":true}}"#
            )
            .is_err()
        );
        assert_eq!(
            dispatch(&service, "GET", "/v1/skills", "{}").unwrap()["skills"]
                .as_array()
                .unwrap()
                .len(),
            3
        );
    }
}
