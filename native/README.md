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
cortiq_set_gpu(enable) / cortiq_gpu_available()        # GPU graph (0.5.30+)
cortiq_set_threads(n)                                  # pool size (0.5.30+)
cortiq_worker_tids(out, cap)                           # ADPF hints (0.5.30+)
cortiq_cancel(handle)                                  # stops a prefill too (0.5.32+)
cortiq_execution_info() -> json                        # simd/threads/gpu (0.5.33+)
```

Everything from `cortiq_set_gpu` down is looked up optionally, so an older
runtime still loads — the app then sizes the pool through `CMF_THREADS`,
skips the performance hints, can only cancel between tokens, and assembles
the About line itself.

The Dart side prefers `cortiq_chat_messages` (conversation as
`[{"role","content"},…]` through the file's own chat template) and pushes
temperature/top-p via `cortiq_set_options` before each generate; on
pre-0.3.10 libraries it falls back to a transcript through `cortiq_chat`.

The token callback fires synchronously on the calling thread, so the Dart
side (`lib/data/services/inference/native_engine.dart`) runs the blocking
call in a long-lived worker isolate — the engine pins that thread to the
big cores on its first call, so it is kept across generations. Cancelling
goes through `cortiq_cancel`, which the runtime also checks between prefill
chunks; the older path (returning `false` from the token callback) only ever
took effect once tokens were flowing, so Stop did nothing during a long
prompt's first minute.

Tuning knobs beyond the thread count still travel in the process
environment, which `lib/data/services/inference/engine_tuning.dart` writes
before `cortiq_load`. See [TUNING.md](TUNING.md) for the `CMF_*` variables
the shipped binary understands, the measurements taken on a real device, and
what is left open in the engine.

When the library is missing the app falls back to a clearly-labeled
**demo engine**.

## Android

All three ABIs are checked into `android/app/src/main/jniLibs/`
(arm64-v8a, armeabi-v7a, x86_64), taken from the cmf release
[v0.5.34](https://github.com/infosave2007/cmf/releases/tag/v0.5.34)
(`libcortiq-ffi-<target>.tar.gz`) — Vulkan compute on arm64-v8a and x86_64
(armeabi-v7a stays CPU-only by choice), the 0.5.30 ABI additions above, and
KV-cache reuse between turns. To update:

```bash
for t in aarch64-linux-android:arm64-v8a \
         armv7-linux-androideabi:armeabi-v7a \
         x86_64-linux-android:x86_64; do
  curl -L https://github.com/infosave2007/cmf/releases/download/v<VER>/libcortiq-ffi-${t%%:*}.tar.gz \
    | tar -xz -C android/app/src/main/jniLibs/${t##*:}/
done
```

Then check every library before committing it — a 4 KB-aligned `.so` will
not load on an Android 15 device with 16 KB pages, and the app falls back to
the demo engine:

```bash
llvm-readelf -lW android/app/src/main/jniLibs/*/libcortiq_ffi.so \
  | awk '$1=="LOAD"{print $NF}' | sort -u        # must be 0x4000 or larger
```

## iOS

`ios/Frameworks/libcortiq_ffi.a` (arm64, from the same release) is linked
via `ios/Flutter/Cortiq.xcconfig` — `-force_load` keeps the C ABI symbols
alive for `DynamicLibrary.process()` despite dead-code stripping. From
0.5.31 the same xcconfig also links Metal, QuartzCore, CoreGraphics and
IOSurface, which the runtime's wgpu backend needs; without them the link
fails on undefined Metal symbols. No Xcode project surgery required; drop in
a newer `.a` to update.

`libcortiq_ffi_sim.a` (simulator) has no release asset and is built locally,
so it lags the device slice — the simulator runs whatever ABI that older
build has, and the optional entry points simply stay absent there.

Apple's `nm` cannot read parts of these archives ("Unknown attribute kind",
a newer rustc LLVM than Xcode's reader). That is expected and not a broken
artifact: the linker uses the archive index, which `nm -g <archive>` still
lists. To check symbols, look there rather than at the members.

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
