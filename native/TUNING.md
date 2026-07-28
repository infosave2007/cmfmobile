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

### Measured, 2026-07-28

Xiaomi 2203129G (Snapdragon 778G+: 4×A78 at capacity ~1003–1024, 4×A55 at
397), Android 14, engine v0.5.31, `bonsai-1.7b-coding` (Q4T, 591 MB), driven
through the app's own server. Decode is the median of three 96-token
generations, prefill the best of two 1349-token prompts with `max_tokens=1`.

| config | pool | decode | prefill |
|---|---|---|---|
| CPU, threads auto | 4 | **13.22 tok/s** | 54.0 s |
| CPU, threads 7 (slider) | 6 | 11.69 tok/s | 59.3 s |
| GPU on | 2 | 1.04 tok/s | 56.7 s |
| GPU on, `CMF_GPU_MIN_ROWS=64` | 4 | 0.96 tok/s | 57.3 s |

Three things fall out of this, and only the first was expected:

1. **Auto-sizing the pool is worth ~13 % of decode** (13.22 vs 11.69) — the
   run-to-run spread inside each config is 2 %, so the gap is real. This is
   the whole point of sizing to the big cluster instead of the runtime's
   `min(cores - 1, 8)`.
2. **The GPU path costs 13× on decode** — 1.04 tok/s against 13.22 — and the
   reason is visible in the engine source. This model is `quant_type: VBIT`,
   and `QTensor::matvec` returns into the CPU `vbitmatvec` kernel *before*
   any GPU consideration, so its per-token math has no GPU path to win with.
   Turning the GPU on then costs twice: the engine halves the CPU pool
   (4 → 2 threads, observed) and adds graph work on top. Note the fourth row
   is not "GPU with a sane threshold": `CMF_GPU_MIN_ROWS` defaults to 65536
   on unified memory precisely so that only lm_head-class matrices offload,
   and setting it to 64 pushed every attention and FFN projection onto
   Vulkan instead. The switch is off by default and should stay off for
   VBIT models.
3. **Prefill ignores every knob**: 54–59 s across all four configs, i.e. it
   scales with neither the thread count nor the GPU. At 25 tok/s it is only
   twice the decode rate, where a batched prefill should be many times
   faster — this, not decode, is what a user feels as "it thinks for a
   minute" on a long chat. Worth profiling with `CMF_PREFILL_PROF`,
   `CMF_PREFILL_CHUNK` and `CMF_BATCH_K` before anything else in the engine.

Reproduce with any HTTP client against the app's server; the numbers above
came from `/v1/chat/completions` plus `/v1/cortiq/status`, which reports the
pool size the engine actually built.

## Open items for the engine

Not fixable from this repository. The first two come straight out of the
measurements above and outrank everything else:

1. **Prefill does not scale.** Same ~55 s for 1349 prompt tokens whether the
   pool has 2, 4 or 6 threads and whether the GPU is on — so the prefill path
   is not using the pool, and the GPU graph is not taking it either. At 25
   tok/s against a 13 tok/s decode, batching is buying almost nothing.
2. **GPU decode is a 13× regression** on an Adreno 642L with a Vulkan
   adapter the engine itself reports as available. Per-token matvecs should
   never reach the GPU; if `CMF_GPU_MIN_ROWS` is meant to prevent that, it
   does not.
3. **`cortiq_set_threads` is overridden when the GPU is on.** With the
   slider at 4 the app passes 4, the model is reloaded, and the engine still
   reports a 2-thread pool. Whatever the reasoning, the embedder's explicit
   number should win or the ABI should say it did not — as it stands the
   Settings slider shows 4 while the engine runs 2.
4. **Where the rest of the 13× goes is still open.** With the default
   threshold nothing is eligible to offload for this model (VBIT returns to
   the CPU kernel, the 2048- and 6140-row projections are far below 65536,
   and the wgpu graph defaults off on integrated GPUs), so the halved pool
   accounts for about 2× of the 13× and the remaining ~6× is unexplained
   from reading the source. It needs the engine's own tracing.
5. **The GPU flag should know what the model is made of.** For a dtype whose
   matvec has no GPU kernel — VBIT here — `cortiq_set_gpu(true)` can only
   lose: it halves the CPU pool and buys nothing back. Either the pool should
   not shrink when the loaded weights have no GPU path, or
   `cortiq_gpu_available()` should answer per model rather than per device,
   so the app can grey the switch out instead of letting a user find this the
   slow way. The op-level probe (`probe_arm`, on by default, freezes the
   faster arm after a 3× gap) already does the right thing for the classes it
   arbitrates — VBIT simply returns before reaching it.

Closed since this document was first written, all in the engine:
`cortiq_set_threads`, `cortiq_gpu_available` and `cortiq_worker_tids` in the
C ABI (0.5.30); the `cpufreq/cpuinfo_max_freq` fallback for big-core
detection on kernels without `cpu_capacity` (0.5.30); KV-cache reuse between
turns, so a turn that continues the history prefills only the new message,
with `CMF_KV_REUSE=0` as the off switch (0.5.31).
