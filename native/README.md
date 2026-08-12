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
cortiq_worker_start(config_json)                       # serve layer spans (0.5.70+)
cortiq_set_peer(config_json)                           # borrow a peer's (0.5.70+)
cortiq_peer_stats() -> json                            # what the peer costs (0.5.70+)
```

Everything from `cortiq_set_gpu` down is looked up optionally, so an older
runtime still loads — the app then sizes the pool through `CMF_THREADS`,
skips the performance hints, can only cancel between tokens, assembles the
About line itself, and offers no companion.

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
(arm64-v8a, armeabi-v7a, x86_64), built from the cmf release tag
[v0.5.70](https://github.com/infosave2007/cmf/releases/tag/v0.5.70).

**The build flags differ per ABI, and neither difference is optional.** The
64-bit ABIs carry Vulkan compute, which is behind a non-default cargo
feature — build them without `--features gpu` and you get a library that
loads, runs, reports the right version, and has quietly lost the GPU (the
`.so` drops from ~14 MB to ~6.8 MB, which is the fastest way to notice).
32-bit ARM stays CPU-only by choice, and it is the one that needs the page
size forced: NDK 28 aligns 64-bit output to 16 KB on its own but leaves
armeabi-v7a at 4 KB, and a 4 KB-aligned `.so` will not load on an Android 15
device with 16 KB pages — the app then falls back to the demo engine.

```bash
# from a worktree of the cmf repo at the release tag
cargo ndk -t arm64-v8a -t x86_64 --platform 26 \
  build --release -p cortiq-ffi --features gpu
RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384" \
  cargo ndk -t armeabi-v7a --platform 26 build --release -p cortiq-ffi
```

Copy each `target/<triple>/release/libcortiq_ffi.so` into
`jniLibs/<abi>/`, then check all three before committing — every line of
this is a bug that has actually shipped or nearly shipped:

```bash
llvm-readelf -lW android/app/src/main/jniLibs/*/libcortiq_ffi.so \
  | awk '$1=="LOAD"{print $NF}' | sort -u          # must be 0x4000 or larger
strings -a jniLibs/arm64-v8a/libcortiq_ffi.so | grep -c -i vulkan   # non-zero
llvm-nm --defined-only jniLibs/arm64-v8a/libcortiq_ffi.so \
  | grep -c cortiq_set_peer                        # the ABI you expect to bind
```

## iOS

`ios/Frameworks/libcortiq_ffi.a` (arm64, from the same release) is linked
via `ios/Flutter/Cortiq.xcconfig`. Getting it into the binary takes three
settings that all have to hold at once, and losing any one of them puts the
app back on the demo engine **without failing the build** — the Dart side
looks the ABI up at runtime, so a missing symbol is a fallback, not an error:

- `-force_load` pulls in every archive member, but it exports nothing: a
  static library's symbols do not reach an executable's export trie on their
  own, and that trie is the table `dlsym` reads. Through 1.1.24 the runtime's
  code sat in the binary with no way to call into it.
- `-Wl,-exported_symbol,_cortiq_*` puts the entry points in that trie. It also
  makes them roots, which keeps alive the code behind them — including the
  `cblas_sgemm` call that makes Accelerate necessary below.
- `STRIP_STYLE = non-global`, because Xcode's default for an app ("all")
  empties that trie again when the archive is stripped.

The same xcconfig links Accelerate (the engine's Apple sgemm path calls
`cblas_sgemm`) and, from 0.5.31, Metal, QuartzCore, CoreGraphics and
IOSurface for the wgpu backend. That backend is behind the same non-default
cargo feature Android needs, so both slices are built with it — an `.a`
around 53 MB instead of 88 MB is one built without `--features gpu`:

```bash
cargo build --release -p cortiq-ffi --target aarch64-apple-ios --features gpu
cargo build --release -p cortiq-ffi --target aarch64-apple-ios-sim --features gpu
```

No Xcode project surgery required; drop in a newer `.a` to update — then
check the built binary actually exports the ABI, because nothing else will
tell you:

```bash
xcrun dyld_info -exports build/ios/iphoneos/Runner.app/Runner | grep -c cortiq
```

`libcortiq_ffi_sim.a` (simulator) has no release asset, so it is built from
the release tag in a worktree of the cmf checkout — which keeps it level
with the device slice instead of lagging it:

```bash
git -C <cmf checkout> worktree add --detach /tmp/cmf-<VER> v<VER>
cd /tmp/cmf-<VER> && cargo build --release -p cortiq-ffi \
  --target aarch64-apple-ios-sim
cp target/aarch64-apple-ios-sim/release/libcortiq_ffi.a \
  ios/Frameworks/libcortiq_ffi_sim.a
```

Apple's `nm` cannot read these archives ("Unknown attribute kind", a newer
rustc LLVM than Xcode's reader), and neither can it list the archive index —
`nm -g` comes back empty on a perfectly good `.a`. To check that the symbols
the app looks up are really there, link against it instead:

```bash
xcrun --sdk iphoneos clang -arch arm64 -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -miphoneos-version-min=13.0 probe.c \
  -Wl,-force_load,ios/Frameworks/libcortiq_ffi.a \
  -framework Metal -framework Foundation -framework QuartzCore \
  -framework CoreGraphics -framework IOSurface -o /tmp/probe
```

where `probe.c` declares the entry points and references them from `main` —
a missing symbol fails the link, which is the same thing the app's own build
would hit.

## Companion: the network split (0.5.70+)

`cortiq_set_peer` routes every later generation through a desktop holding
the **same** `.cmf` file, and `cortiq_worker_start` does the reverse — this
device serves a span of its own copy to somebody else's coordinator. The
Companion screen drives both; `lib/data/models/companion.dart` holds the
roles and the peer-stats shape.

What the engine measured, and why the screen offers roles rather than a
percentage (`docs/MOBILE_SPLIT.ru.md` in the cmf repo):

- **A split does not make a token faster.** A token walks the layers in
  order, so distribution buys memory, not parallelism: every configuration
  where both sides compute measured slower than the faster side alone
  (Bonsai 1.7B — Mac 28.6 tok/s, phone 14.3, halved over USB 14.0). So the
  app never offers to "speed up" a model that already fits.
- **`head: true` is the cheap win.** The head does not shrink as layers move
  away — 29 ms of a 73 ms token on a phone — so the app always hands it to
  the peer along with the sampler and takes back a token id: 12.6 → 26.0
  tok/s on Bonsai, 9.1 → 15.7 on a 34.7B MoE. The wire drops to 16 bytes a
  token.
- **The transport is ranked by its tail, not its bandwidth.** A 4 KB round
  trip is 1.89 ms p50 / 2.94 ms p99 on a cable against 8.95 / 94.81 on good
  5 GHz Wi-Fi. One round trip per token means the p99 is what the user sees,
  so the screen labels the transport and warns on Wi-Fi.
- The file must be on **both** sides even at `split: 0` — the tokenizer and
  chat template are read locally — and the handshake compares `dir_hash`, so
  a mismatched model is refused rather than silently producing a chimera.
- The token travels in clear text and there is no call to stop a started
  worker; the screen says both.

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
