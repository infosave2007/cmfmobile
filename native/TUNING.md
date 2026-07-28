# Making the engine fast on Android

Started as findings from reading `libcortiq_ffi.so` (arm64, v0.5.28) with
`llvm-nm` / `llvm-objdump`, when the C ABI exposed no tuning at all and the
app had to reach the runtime through its environment. **v0.5.30 closed most
of that**: `cortiq_set_threads`, `cortiq_gpu_available` and
`cortiq_worker_tids` are proper entry points now, and v0.5.31 added KV-cache
reuse between turns. The environment path below is still live — the app
looks the new symbols up optionally, so an older runtime keeps working — but
it is the fallback, not the plan.

## How the worker pool sizes and places itself

`cortiq_engine::pool::Pool::from_env`, called once per model from
`Pipeline::new` inside `cortiq_load`:

- reads **`CMF_THREADS`**; absent that, uses `min(available_parallelism() - 1, 8)`;
- below 2 it builds no pool at all and the model runs single-threaded.

Every worker — and the thread that calls `cortiq_chat*` — then runs
`pin_current_thread_to_big_cores`, which reads
`/sys/devices/system/cpu/cpuN/cpu_capacity`, keeps the cores whose capacity
reaches **62.5 %** of the maximum (`5 * max <= 8 * capacity` in the
disassembly) and calls `sched_setaffinity`. A flat topology is left alone.

The two did not agree on a phone: a 4+4 device got 7 workers pinned onto ~4
cores, and since matmuls split rows across the pool and join per layer, the
extra workers only added a second wait round.

**From 0.5.30 the app calls `cortiq_set_threads(n)` before the load** — the
Settings slider straight through, 0 meaning auto, which the engine resolves
itself (it now falls back to `cpufreq/cpuinfo_max_freq` where `cpu_capacity`
is missing, so the pool size and the affinity mask agree even on kernels
without EAS). After the load the app reads back the real pool size from
`cortiq_worker_tids` and shows it in Settings → About.

Against an older runtime the same decision is made in Dart by
[`EngineTuning`](../lib/data/services/inference/engine_tuning.dart), which
applies the same 62.5 % rule and publishes the result as `CMF_THREADS` via
libc `setenv`. Whichever path runs, the other is cleared, so the two can
never disagree.

Two caveats worth knowing when reading a profile:

- On a runtime older than 0.5.30 and a kernel without `cpu_capacity`, the
  engine pins nothing at all — `EngineTuning` can size the pool from the
  max-frequency fallback, but it cannot make the workers stay on the big
  cores.
- A **backgrounded process is confined to the background cpuset** (little
  cores), and a cpuset outranks an affinity mask — pinning cannot win it
  back. That is what
  [`InferenceService`](../android/app/src/main/kotlin/ai/cortiq/cmf_mobile/InferenceService.kt)
  is for: a foreground service plus a partial wake lock, held while a reply
  is generated and for as long as the server runs.

  Two things follow from that service being of type `dataSync`: Android 15
  budgets it at six hours a day and then calls `onTimeout` (handled — the
  service stops itself and inference falls back to background priority), and
  Play needs a foreground-service-type declaration for the listing. Without
  `POST_NOTIFICATIONS` the notification stays hidden, but the service — and
  with it the scheduling priority — still works.

## Environment knobs in the shipped binary

None of these have a UI; Settings → Engine → *Engine flags* passes
`CMF_KEY=value` lines through to the runtime at load time, which is how they
can be A/B'd on a real device (the app's per-message tok/s is the readout).
Their value formats are not documented here because they were recovered from
strings, not from source — check `cortiq-engine` before relying on one.

| Knob | Area |
|---|---|
| `CMF_THREADS`, `CMF_POOL_SPIN` | worker pool size, spin-waiting |
| `CMF_REPACK`, `CMF_X86_BLOCKED` | weight repacking for the GEMM kernels |
| `CMF_I8MM`, `CMF_SDOTR` | force the i8mm / sdot paths past runtime detection |
| `CMF_PREFILL_CHUNK`, `CMF_BATCH_K` | prefill batching |
| `CMF_KV`, `CMF_MAX_SEQ` | KV cache dtype / capacity |
| `CMF_MMAP_ADVISE`, `CMF_MLOCK` | page-cache behaviour for the mmapped weights |
| `CMF_O1`, `CMF_O1_M`, `CMF_O1_RECT`, `CMF_O1_WINDOW`, `CMF_O1_SINK` | O(1) attention for long contexts |
| `CMF_MTP` | multi-token prediction (the load line prints `MTP: …`) |
| `CMF_MOE_TOPK`, `CMF_MOE_TAU`, `CMF_MOE_MASK`, `CMF_MOE_MASK_COV` | MoE expert pruning |
| `CMF_ROUTE_*`, `CMF_PHASE_MASS` | dynamic routing |
| `CMF_GPU_MIN_ROWS`, `CMF_GPU_LMHEAD`, `CMF_GPU_WGPU_GRAPH`, `CMF_GPU_PROBE` | GPU graph (see below) |
| `CMF_PREFILL_PROF`, `CMF_DIT_PROF`, `CMF_VAE_PROF`, `CMF_TRACE_H`, `CMF_DEBUG_LAYERS`, `CMF_GRAPH_DEBUGL` | profiling / tracing |

## Performance hints (ADPF)

Affinity says *where* the workers run, not *how fast*. A generation looks to
the governor like a series of short bursts, so it ramps lazily. Since
0.5.30 the pool registers its kernel thread ids and hands them out through
`cortiq_worker_tids`; the app opens a `PerformanceHintManager` session over
exactly those threads (API 31+,
[`PerformanceHint.kt`](../android/app/src/main/kotlin/ai/cortiq/cmf_mobile/PerformanceHint.kt)),
reports what every 16 tokens actually cost, and closes the session when the
reply ends so the clocks go straight back. The target is a deliberately
ambitious 40 ms a token — the point is to ask for the headroom that exists
while a reply streams, not to describe a deadline.

Both the chat and the embedded server get this: the session lives in
`NativeCortiqEngine`, around the generate call itself.

## Turning the GPU on

The engine has a GPU path — `cortiq_engine::gpu` with `enabled_here`,
`min_rows`, the probe cache and the graph-race state, driven by
`CMF_GPU_WGPU_GRAPH`, `CMF_GPU_MIN_ROWS`, `CMF_GPU_LMHEAD`,
`CMF_GPU_PROBE` — and `wgpu` in the name says which backend it uses:
Vulkan on Android, Metal on iOS.

**Shipped since v0.5.31** — with one deliberate gap:

| slice | GPU backend |
|---|---|
| arm64-v8a | Vulkan |
| x86_64 | Vulkan |
| armeabi-v7a | none, CPU-only by choice |
| iOS arm64 (device) | Metal |
| iOS simulator | none — built locally, lags the release |

`cortiq_set_gpu` is accepted by every build, GPU or not, so the app asks
`cortiq_gpu_available()` instead: it reports whether the backend is linked
in *and* an adapter comes up on this device. Only then does the Settings
switch drop its "needs a runtime built with the Vulkan/Metal backend" note.

To verify a build yourself:

```bash
llvm-nm -D -u libcortiq_ffi.so | grep dlopen      # wgpu reaches libvulkan through it
strings -a libcortiq_ffi.so | grep -c -i wgpu     # thousands when linked in, ~3 when not
strings -a libcortiq_ffi.a  | grep -c MTLCreateSystemDefaultDevice   # iOS
```

### Rebuilding it in the cmf workspace

The release workflow does all of this (and verifies the alignment of every
Android library before publishing). Building by hand:

```bash
RUSTFLAGS='-C link-arg=-Wl,-z,max-page-size=16384' \
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 \
  -o android/app/src/main/jniLibs \
  build --release -p cortiq-ffi --features gpu
```

The `max-page-size` flag is not optional: without it the libraries come out
4 KB-aligned and will not load on an Android 15 device with 16 KB pages.
`wgpu` reaches Vulkan through `dlopen("libvulkan.so")`, so nothing extra
gets packaged. On iOS, build `aarch64-apple-ios` with the same feature —
the frameworks its Metal backend needs are already in
`ios/Flutter/Cortiq.xcconfig`.

### What to expect

Decode is memory-bandwidth-bound and the GPU shares the same LPDDR as the
CPU, so token-by-token generation often gains little — sometimes less than
nothing once the driver round-trips are counted. Prefill and the `lm_head`
projection are compute-bound and are where a mobile GPU pays off, which is
exactly what `CMF_GPU_MIN_ROWS` (offload only matrices at least this tall)
and `CMF_GPU_LMHEAD` are for. Tune both from Settings → Engine → Engine
flags and read the result off the per-message tok/s.

Two more things worth budgeting for: WGSL has no int8 dot-product
extension, so quantized weights may have to be dequantized before they hit
the GPU — spending bandwidth to save compute, the wrong trade for decode —
and sustained GPU load throttles a phone faster than the CPU path does.

## Open items for the engine

Not fixable from this repository:

1. **KV cache across turns.** `Pipeline::generate_from_ids` calls
   `LayerKvCache::clear`, and the app sends the whole conversation on every
   turn, so each turn appears to re-prefill the full history — linear per
   turn, quadratic over a session. Confirm against `cortiq-engine`; if it
   holds, reusing the common prefix is the biggest latency win available.
   Quick check without touching the source: compare first-token latency on
   turn 1 and turn 10 of one long chat.
2. **`cpu_capacity` fallback in `pin_current_thread_to_big_cores`.** On
   kernels without it the pinning silently does nothing; reading
   `cpufreq/cpuinfo_max_freq` instead would keep the workers off the little
   cores there too.
3. **A thread-count parameter in the C ABI**, so the pool no longer has to be
   configured through a process-wide environment variable — and
   `cortiq_gpu_available()` alongside it (see above).
4. **ADPF (`PerformanceHintManager`, API 31+)** needs the worker thread ids
   to report work duration to the governor; the ABI exposes none.
