/* Forces the linker to pull every cortiq_ffi archive member into Runner
 * so Dart's DynamicLibrary.process() resolves the C ABI at runtime.
 * Signatures mirror native/cortiq_ffi.h. */
#include <stdbool.h>
#include <stdint.h>

typedef bool (*cortiq_token_cb)(const char *token, void *user);

extern const char *cortiq_version(void);
extern const char *cortiq_last_error(void);
extern void *cortiq_load(const char *path);
extern void cortiq_free(void *handle);
extern int32_t cortiq_chat(void *handle, const char *prompt,
                           uint32_t max_tokens, cortiq_token_cb cb,
                           void *user);
extern int32_t cortiq_chat_messages(void *handle, const char *messages_json,
                                    uint32_t max_tokens, cortiq_token_cb cb,
                                    void *user);
extern int32_t cortiq_complete(void *handle, const char *prompt,
                               uint32_t max_tokens, cortiq_token_cb cb,
                               void *user);
extern int32_t cortiq_set_options(void *handle, const char *options_json);

__attribute__((used)) const void *cortiq_ffi_keep[] = {
    (const void *)cortiq_version,       (const void *)cortiq_last_error,
    (const void *)cortiq_load,          (const void *)cortiq_free,
    (const void *)cortiq_chat,          (const void *)cortiq_chat_messages,
    (const void *)cortiq_complete,      (const void *)cortiq_set_options,
};
