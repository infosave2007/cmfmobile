# Native cortiq runtime for CMF Mobile

CMF Mobile talks to the cortiq inference runtime (the Rust workspace in
[cmfpublic](https://github.com/infosave2007/cmf)) through the C ABI declared
in [`cortiq_ffi.h`](cortiq_ffi.h). When the library is not bundled, the app
falls back to a clearly-labeled **demo engine** so the full UX still works.

## 1. Create the FFI crate (once, in the cmfpublic workspace)

```toml
# crates/cortiq-ffi/Cargo.toml
[package]
name = "cortiq-ffi"
version = "0.1.0"
edition = "2021"

[lib]
name = "cortiq_ffi"
crate-type = ["cdylib", "staticlib"]

[dependencies]
cortiq-engine = { path = "../cortiq-engine" }
serde_json = "1"
```

Implement the five functions from `cortiq_ffi.h` on top of
`CortiqRuntime` (load → mmap; generate → pipeline with a per-token
callback; cancel → cooperative flag).

## 2. Android

```bash
cargo install cargo-ndk
cd cmfpublic
cargo ndk -t arm64-v8a -t armeabi-v7a -o /path/to/cmfmobile/android/app/src/main/jniLibs \
  build --release -p cortiq-ffi
```

The app loads `libcortiq_ffi.so` automatically at startup.

## 3. iOS

```bash
cargo install cargo-lipo
cd cmfpublic
cargo lipo --release -p cortiq-ffi --targets aarch64-apple-ios
```

Add `libcortiq_ffi.a` to the Xcode project (Runner → Build Phases →
Link Binary With Libraries) plus an "Other Linker Flags" entry
`-force_load $(PROJECT_DIR)/libcortiq_ffi.a` so the symbols survive
dead-code stripping. The app resolves symbols via
`DynamicLibrary.process()`.

## 4. Verify

Launch the app → Settings → About shows `engine: cortiq-native` instead of
`engine: demo`, and the demo banner disappears from the chat.
