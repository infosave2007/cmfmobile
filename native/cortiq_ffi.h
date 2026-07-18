/*
 * C ABI for the cortiq-engine runtime (cmfpublic), consumed by CMF Mobile
 * over dart:ffi (lib/data/services/inference/native_engine.dart).
 *
 * Build a `cortiq-ffi` cdylib crate in the cmfpublic workspace that wraps
 * CortiqRuntime and exports exactly these symbols. See README.md here.
 */
#ifndef CORTIQ_FFI_H
#define CORTIQ_FFI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque runtime context (CortiqRuntime + Pipeline). */
typedef void cortiq_ctx;

/*
 * Streamed generation events, one JSON object per callback invocation:
 *   {"delta":"tok"}                                — a new text fragment
 *   {"done":true,
 *    "usage":{"prompt_tokens":N,"completion_tokens":N},
 *    "tokens_per_second":F,
 *    "finish_reason":"stop|length|cancelled",
 *    "task_used":"general"}                        — final event
 */
typedef void (*cortiq_event_cb)(const char *event_json);

/* Opens and mmaps a .cmf model. Returns NULL on failure. */
cortiq_ctx *cortiq_load(const char *path, int32_t threads);

/* Frees the runtime and unmaps the model. */
void cortiq_free(cortiq_ctx *ctx);

/*
 * Runs one generation. request_json:
 *   {"messages":[{"role":"user","content":"..."}],
 *    "temperature":0.7,"top_p":0.95,"max_tokens":1024,
 *    "cortiq":{"task":"sql"}}          — optional task-mask routing
 * Returns 0 on success, non-zero on error (see cortiq_last_error).
 * The callback fires on an internal thread; the final event always fires.
 */
int32_t cortiq_generate(cortiq_ctx *ctx, const char *request_json,
                        cortiq_event_cb on_event);

/* Cooperatively stops the current generation (finish_reason=cancelled). */
void cortiq_cancel(cortiq_ctx *ctx);

/* Last error message for this thread; valid until the next FFI call. */
const char *cortiq_last_error(void);

#ifdef __cplusplus
}
#endif

#endif /* CORTIQ_FFI_H */
