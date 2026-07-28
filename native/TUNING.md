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
397), 8 GB RAM plus Xiaomi's 4 GB "memory extension" — which is swap on
flash, not RAM, and it evicts an mmapped model eagerly. Android 14, engine
v0.5.31, `bonsai-1.7b-coding` (VBIT, 591 MB, qwen3, 28 layers), driven
through the app's own server.

**Read the pool size from `/proc/<pid>/task/*/comm`, not from the engine.**
`/v1/cortiq/status` reported `· 1 threads` while four `cmf-pool-*` threads
were alive and pinned to the big cores, decoding at full speed. Every
configuration label in the first pass of this investigation came off that
string, so those labels — and the "pool width" conclusions drawn from them —
were wrong. Counting the threads is the only external ground truth.

The decisive comparison, every variable held down — same fresh boot, pool
size counted in `/proc` rather than read off the engine, CPU verified idle:

| config | pool (counted) | free RAM | decode | prefill |
|---|---|---|---|---|
| GPU off, threads auto | 4 | 1490 MB | **13.30 tok/s** | 53.3 s |
| GPU off, repeated | 4 | 901 MB | 13.25 tok/s | — |
| **GPU on, threads auto** | **4** | 1506 MB | **0.94 tok/s** | 58.1 s |
| GPU on, `CMF_GPU_WGPU_GRAPH=0` | 4 | 1630 MB | **11.18 tok/s** | 63.9 s |
| GPU on, engine v0.5.32, no workaround | 4 | 1585 MB | **11.69 tok/s** | 58.3 s |

The last two rows are the fix verified on the device — first by forcing
`CMF_GPU_WGPU_GRAPH=0` from the app, then by v0.5.32 doing it correctly on
its own with that workaround removed. Either way the whole-token graph stays
out of the race and 12× of the 14× comes back. The 16 % still missing against the
GPU-off baseline is what the per-op probe costs while it alternates arms on a
model where the GPU cannot win any of them — which is why the app also
withholds the flag entirely for quantizations with no GPU kernel.

**Turning the GPU on costs 14× on decode and gives prefill nothing.** Three
decode runs at 0.98 / 0.92 / 0.94 — a 3 % spread, not noise. The pool is four
threads in both rows, so the earlier "the engine halves the pool" reading was
another artifact of the unreliable status string; memory is equal to within
1 %; the CPU was 4.8 % busy before the run.

A correction worth keeping, because it cost two rounds of wrong reasoning:
the file's header says `quant_type: VBIT`, but that field is informational —
the tensors are 58 % `q8_2f` and 42 % `q1`, which is what both the app and
the engine actually work with. So the "VBIT has no GPU matvec" explanation
for the slowdown was wrong; the graph race was the whole of it.

Reading the engine (v0.5.28 source; the measurements are 0.5.31, so this
narrows rather than proves) rules out every op gate for this model — a dense
qwen3 in VBIT, 2048-row attention projections and 6140-row FFN:

| path | gate | this model |
|---|---|---|
| `QTensor::matvec` | VBIT arm | returns into the CPU kernel before any GPU check |
| matvec ≥ 8M elements | `Q4Block`, `Q1`, `Q1T` only | VBIT is not one of them |
| dense FFN | `gate_proj.rows() >= min_rows` | 6140 vs 65536 — skipped |
| attention | `wq.rows() >= min_rows \|\| is_q1` | 2048 vs 65536 — skipped |
| MoE, GDN | other architectures | not applicable |
| wgpu whole-layer graph | `discrete_active()` | an Adreno is not discrete |
| `enabled_here()` itself | thread-local + cached flag | cheap |

So no *operation* reaches the GPU — and the cost is not there. It is the
**whole-token graph**, and the engine's own source names the failure mode:

> tiled mobile GPUs (Adreno/Mali) drain the pipeline at every barrier — field
> report: 0.2 tok/s on-graph vs 15 tok/s on the CPU

On an integrated adapter the graph is meant to stay off; instead it *races*
the normal path, generations alternating arms until one wins. Every
graph-armed generation on this phone runs at that 0.2 tok/s.

It races because of one branch (`pipeline.rs`, the decode path):

```rust
let graph_on = match graph_env.as_deref() {
    Some("0") => false,
    Some(_)   => true,
    None      => GLOBAL_USE_GPU.load(..) || crate::gpu::wgpu_active(),
};
```

The unset branch never consults `wgpu_graph_default()` — the discrete-only
rule twenty lines above, whose comment promises that "integrated/mobile GPUs
keep the per-op probe path". So `cortiq_set_gpu(true)` alone makes the graph
eligible everywhere, `graph_trusted` is false on an Adreno, and the race
starts. Setting the variable to `0` short-circuits it, which is what this app
now does on mobile whenever the GPU is on — the per-op probe path, which
arbitrates each operation against the CPU, is left intact.

Prefill, meanwhile, sits at 53–58 s for 1349 tokens in every configuration
ever measured across two sessions — 25 tok/s, barely twice the decode rate,
where a batched prefill should be several times faster. That is the finding
with the most user-visible weight here.

Protocol that makes a run trustworthy, learned by breaking each rule: reboot
first and wait for `load average` to settle; keep `MemAvailable` well above
the model size and check it after the run too; count pool threads in `/proc`;
discard the first generation after a load; and never abandon a request on a
client timeout — the engine serializes per handle, so the generation keeps
running and the next request measures the queue.

## Open items for the engine

Not fixable from this repository:

1. ~~`execution_mode` reports a thread count that is not the pool.~~ Not an
   engine reporting bug at all — the string is composed by *this app*
   (`'Mobile { engine: ${engine.name} }'` in `cmf_server.dart`), and
   `engine.name` appends the count read from `cortiq_worker_tids`
   *immediately* after `cortiq_load`. The workers register their tids as they
   start, so only the first was there to count. Same wrong list went into the
   ADPF hint session, which therefore covered one thread instead of four.
   Engine 0.5.33 makes the load wait for every registration; the app also
   re-reads the pool before the first generation, so the number is right on
   older runtimes too. **The lesson stands even though the culprit moved:
   counting `cmf-pool-*` in `/proc` was the only trustworthy source, and two
   wrong conclusions in this document came from believing a number instead.**

2. **Prefill does not scale with the pool** — 53–65 s for 1349 prompt tokens
   in every configuration across three sessions, 25 tok/s against a 13 tok/s
   decode. Diagnosed engine-side as GDN recurrence, sequential over positions:
   only the heads parallelise, and chunked GEMM amortises the projections
   alone. So the knobs could not have helped, and the fix is algorithmic
   (chunked GDN). This is the largest remaining user-visible cost.
3. ~~A generation cannot be cancelled from outside.~~ Closed in v0.5.32 by
   `cortiq_cancel()`, which the runtime checks on each prefill chunk as well
   as each decode step — so Stop now works during the prefill minute, where
   the callback-based flag could never reach.
4. ~~The GPU flag is a pessimisation.~~ With the graph fixed in v0.5.33 the
   switch is a no-op on this hardware: 13.02 tok/s on, 13.30 off. The engine's
   per-op probe times each class against the CPU and settles on the CPU,
   which is the right outcome — decode is bandwidth-bound and an Adreno
   shares the same LPDDR. Nothing left to fix here.

Closed since this document was first written, all in the engine:
`cortiq_set_threads`, `cortiq_gpu_available` and `cortiq_worker_tids` in the
C ABI (0.5.30); the `cpufreq/cpuinfo_max_freq` fallback for big-core
detection on kernels without `cpu_capacity` (0.5.30); KV-cache reuse between
turns, so a turn that continues the history prefills only the new message,
with `CMF_KV_REUSE=0` as the off switch (0.5.31).
