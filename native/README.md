# Native cortiq runtime

CMF Mobile binds the cortiq inference engine through the C ABI of the
[`cortiq-ffi`](https://github.com/infosave2007/cmf/tree/master/crates/cortiq-ffi)
crate (header mirrored here as [`cortiq_ffi.h`](cortiq_ffi.h)):

```
cortiq_version / cortiq_last_error
cortiq_load(path) -> handle          # mmap, NULL on error
cortiq_free(handle)
cortiq_chat(handle, prompt, max_tokens, cb, user)      # single user turn
cortiq_chat_messages(handle, messages_json, ...)       # multi-turn (0.3.10+)
cortiq_complete(handle, prompt, max_tokens, cb, user)  # raw prompt
cortiq_set_options(handle, options_json)               # sampler (0.3.10+)
```

The Dart side prefers `cortiq_chat_messages` (conversation as
`[{"role","content"},…]` through the file's own chat template) and pushes
temperature/top-p via `cortiq_set_options` before each generate; on
pre-0.3.10 libraries it falls back to a transcript through `cortiq_chat`.

The token callback fires synchronously on the calling thread, so the Dart
side (`lib/data/services/inference/native_engine.dart`) runs the blocking
call in a worker isolate and cancels by returning `false` from the
callback via a shared native flag.

When the library is missing the app falls back to a clearly-labeled
**demo engine**.

## Android

All three ABIs are checked into `android/app/src/main/jniLibs/`
(arm64-v8a, armeabi-v7a, x86_64), taken from the cmf release
[v0.5.9](https://github.com/infosave2007/cmf/releases/tag/v0.5.9)
(`libcortiq-ffi-<target>.tar.gz`) — adds q1t decode and the
`enable_thinking` sampler option. To update:

```bash
for t in aarch64-linux-android:arm64-v8a \
         armv7-linux-androideabi:armeabi-v7a \
         x86_64-linux-android:x86_64; do
  curl -L https://github.com/infosave2007/cmf/releases/download/v<VER>/libcortiq-ffi-${t%%:*}.tar.gz \
    | tar -xz -C android/app/src/main/jniLibs/${t##*:}/
done
```

## iOS

`ios/Frameworks/libcortiq_ffi.a` (arm64, from the same release) is linked
via `ios/Flutter/Cortiq.xcconfig` — `-force_load` keeps the C ABI symbols
alive for `DynamicLibrary.process()` despite dead-code stripping. No
Xcode project surgery required; drop in a newer `.a` to update.

## Desktop smoke test

Real end-to-end inference through the same binding the app uses:

```bash
cargo build --release -p cortiq-ffi          # in the cmf workspace
CORTIQ_FFI_LIB=/path/to/libcortiq_ffi.dylib \
  dart run tool/ffi_smoke.dart /path/to/model.cmf "your prompt"
```

Verified 2026-07-18 with qwen3-5-4b.cmf (Q8_2F), ffi 0.3.9 and 0.3.10
(multi-turn `cortiq_chat_messages` + `cortiq_set_options`): mmap load
~210 ms, streaming on an M-series Mac.

## Verify in the app

Settings → About shows `engine: cortiq-native <version>` instead of
`engine: demo`, and the demo banner disappears from the chat.
