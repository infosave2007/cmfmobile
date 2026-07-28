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
397), Android 14, engine v0.5.31, `bonsai-1.7b-coding` (VBIT, 591 MB, qwen3 arch, 28 layers), driven
through the app's own server. Decode is the median of three 96-token
generations, prefill the best of two 1349-token prompts with `max_tokens=1`.

`pool` is what `/v1/cortiq/status` reports, which counts workers besides the
calling thread — the Settings slider reads one higher.

| config | pool | decode | prefill | trustworthy? |
|---|---|---|---|---|
| CPU, threads auto | 4 | **13.22 tok/s** | 54.0 s | yes |
| CPU, threads 7 (slider) | 6 | 11.69 tok/s | 59.3 s | yes |
| GPU on | 2 | 1.04 tok/s | 56.7 s | **no** |
| GPU on, `CMF_GPU_MIN_ROWS=64` | 2 | 0.96 tok/s | 57.3 s | **no** |
| CPU, slider 2, GPU off | 1 | 0.92 tok/s | 56.4 s | **no** |

**Only the first two rows survive.** They ran minutes apart on a freshly
loaded device, so the ~13 % decode difference between a pool sized to the big
cluster and one sized past it is a real comparison — and it is the one this
app's auto-sizing exists for.

Everything below them was measured on a device that had drifted, and the
drift dwarfs whatever was being tested. By the end of the session
`MemAvailable` was 527 MB against a 591 MB model, 3.2 GB had gone to zram,
and a generation showed near-zero process CPU while wall time ran — the
weights were being paged back in rather than multiplied. On top of that,
an HTTP request abandoned on a client timeout does **not** cancel the
generation behind it: the engine serializes per handle, so each timed-out
probe stayed queued and the next request measured the queue.

So the "GPU costs 13×" and "decode falls off a cliff below four workers"
readings are both unsupported. The GPU may well be a loss on this hardware —
the source says a VBIT model has no GPU matvec to win with — but this
session did not measure it.

To measure it properly: reboot the phone first, check `MemAvailable` before
each run and keep it well above the model size, give the device a minute
between configurations, and never abandon a request on a timeout — read it
to completion or restart the server between runs.

Reproduce with any HTTP client against the app's server; the numbers above
came from `/v1/chat/completions` plus `/v1/cortiq/status`, which reports the
pool size the engine actually built.

## Open items for the engine

Not fixable from this repository:

1. **Prefill does not scale with the pool.** 54.0 s with four workers, 59.3 s
   with six, for the same 1349-token prompt — and at 25 tok/s it is only
   twice the decode rate, where a batched prefill should be several times
   faster. This is the pair of readings the session can stand behind, and it
   is what a user feels as "it thinks for a minute" on a long chat. Worth
   `CMF_PREFILL_PROF`, `CMF_PREFILL_CHUNK` and `CMF_BATCH_K` before anything
   else.
2. **`cortiq_set_threads` is overridden when the GPU is on.** With the slider
   at 4 the app passes 4, the model is reloaded, and the engine still reports
   a 2-worker pool. Either the embedder's number should win or the ABI should
   say it did not — as it stands the setting shows one number and the runtime
   uses another.
3. **A generation cannot be abandoned from the outside.** A client that gives
   up on an HTTP request leaves the generation running and the next request
   queued behind it, with no way to cancel. `/v1/chat/completions` honouring
   a dropped connection would make the server much harder to wedge — and it
   is what turned a benchmark run into a queue here.
4. **`cortiq_gpu_available()` could answer per model.** For a dtype whose
   matvec has no GPU kernel — VBIT — `cortiq_set_gpu(true)` cannot help, and
   the app could grey the switch out instead of letting a user find that out
   the slow way. (The op-level probe, on by default, already picks the faster
   arm for the classes it arbitrates; VBIT returns to the CPU kernel before
   reaching it.)

Closed since this document was first written, all in the engine:
`cortiq_set_threads`, `cortiq_gpu_available` and `cortiq_worker_tids` in the
C ABI (0.5.30); the `cpufreq/cpuinfo_max_freq` fallback for big-core
detection on kernels without `cpu_capacity` (0.5.30); KV-cache reuse between
turns, so a turn that continues the history prefills only the new message,
with `CMF_KV_REUSE=0` as the off switch (0.5.31).
