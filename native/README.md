# Native cortiq runtime

CMF Mobile binds the cortiq inference engine through the C ABI of the
[`cortiq-ffi`](https://github.com/infosave2007/cmf/tree/master/crates/cortiq-ffi)
crate (header mirrored here as [`cortiq_ffi.h`](cortiq_ffi.h)):

```
cortiq_version / cortiq_last_error
cortiq_load(path) -> handle          # mmap, NULL on error
cortiq_free(handle)
cortiq_chat(handle, prompt, max_tokens, cb, user)      # file's chat template
cortiq_complete(handle, prompt, max_tokens, cb, user)  # raw prompt
```

The token callback fires synchronously on the calling thread, so the Dart
side (`lib/data/services/inference/native_engine.dart`) runs the blocking
call in a worker isolate and cancels by returning `false` from the
callback via a shared native flag.

When the library is missing the app falls back to a clearly-labeled
**demo engine**.

## Android

`android/app/src/main/jniLibs/arm64-v8a/libcortiq_ffi.so` is checked in,
taken from the cmf release
[v0.3.9](https://github.com/infosave2007/cmf/releases/tag/v0.3.9)
(`libcortiq-ffi-aarch64-linux-android.tar.gz`). To update:

```bash
curl -L -o /tmp/ffi.tar.gz \
  https://github.com/infosave2007/cmf/releases/download/v<VER>/libcortiq-ffi-aarch64-linux-android.tar.gz
tar -xzf /tmp/ffi.tar.gz -C android/app/src/main/jniLibs/arm64-v8a/
```

Or build from source: `cargo ndk -t arm64-v8a build --release -p cortiq-ffi`
in the cmf workspace.

## iOS

Build a static lib and link it into Runner (symbols resolve via
`DynamicLibrary.process()`):

```bash
cd cmf
cargo lipo --release -p cortiq-ffi --targets aarch64-apple-ios
```

Add `libcortiq_ffi.a` in Xcode (Runner → Build Phases → Link Binary With
Libraries) with `-force_load $(PROJECT_DIR)/libcortiq_ffi.a` in Other
Linker Flags so dead-code stripping keeps the symbols.

## Desktop smoke test

Real end-to-end inference through the same binding the app uses:

```bash
cargo build --release -p cortiq-ffi          # in the cmf workspace
CORTIQ_FFI_LIB=/path/to/libcortiq_ffi.dylib \
  dart run tool/ffi_smoke.dart /path/to/model.cmf "your prompt"
```

Verified 2026-07-18 with qwen3-5-4b.cmf (Q8_2F): mmap load 210 ms,
streaming at ~9 tok/s on an M-series Mac.

## Verify in the app

Settings → About shows `engine: cortiq-native <version>` instead of
`engine: demo`, and the demo banner disappears from the chat.
