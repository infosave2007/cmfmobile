# Changelog

All notable changes to CMF Mobile are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [SemVer](https://semver.org/).

## [1.1.5] - 2026-07-21

### Changed
- **Massive Performance Boost on Mobile**: Integrated `cortiq-engine` v0.5.5 optimizations.
  - Eliminated severe memory allocation bottlenecks (`Vec` churn) on CPU inference paths, resolving the 0.2 tok/s degradation on big.LITTLE Android devices like Snapdragon 778G.
  - Dramatically accelerated cross-platform GPU inference (WGPU) by replacing expensive integer divisions with a branchless lookup table (LUT).

## [1.1.4] - 2026-07-21

### Fixed
- Upgraded `cmfpublic` to 0.5.3 to fix the GPU toggle. The backend now correctly switches to Vulkan/Metal instead of silently falling back to CPU when the toggle is activated.

## [1.1.3] - 2026-07-21

### Fixed
- Fixed a Dart compilation error in `NativeCortiqEngine` casting and interface implementation.

## [1.1.2] - 2026-07-21

### Added
- **GPU Toggle**: Added a UI setting under Generation to explicitly use the Vulkan/Metal GPU execution graph (applies on the next model load).
- **Localization**: Added full translation support for the GPU toggle setting across 7 languages.

## [1.1.1] - 2026-07-21

### Changed
- **Engine update**: Upgraded `libcortiq_ffi` to v0.5.1, incorporating Metal `TokenGraph` Q8 support and CPU `add_rmsnorm` fusion optimizations.

## [1.1.0] - 2026-07-19

### Added
- **On-device q1t conversion** — training-free ternary quantization
  (`{−s, 0, +s}` packed base-3, ~2.25–3 bit/param, below q4) with a per-row
  sparse f16 outlier overlay. Outliers are the top-|w| per row (the two-field
  mask without an activation Hessian) and a per-row α rescale folds into the
  group scales; the embedding, LM head and down-projection stay q8_2f. The
  output is byte-identical to the cortiq q1t reader.
- **Disable thinking** setting — reasoning models (Qwen3/3.5) answer directly
  instead of emitting a `<think>` block. Applied to every generation through the
  new `enable_thinking` option of the cortiq FFI.

### Changed
- Bundled cortiq runtime updated to **0.4.1** (Android arm64-v8a / armeabi-v7a /
  x86_64 and iOS arm64) — adds q1t decode and the `enable_thinking` sampler
  option.
- The conversion picker disables on-device-unsupported quantizations
  (Q4_BLOCK, VBIT) instead of letting a safetensors conversion start and then
  fail. Repos that already ship `.cmf` still download directly with any
  selection.

### Fixed
- Downloads now survive minutes-long network / DNS outages. Transient failures
  (`Failed host lookup`, connection reset, TLS, timeouts) retry within a
  5-minute no-progress window with capped exponential backoff, resuming from the
  last written byte; a 30-second idle timeout breaks a silently stalled socket
  instead of hanging forever. The single-connection fallback resumes too, and
  the range-support probe retries rather than silently dropping to one
  connection — the common "returned N bytes, expected M (Failed host lookup)"
  failure no longer aborts a large download after a brief blip.

### Tests
- Added a q1t round-trip: convert a synthetic model to q1t, decode the tensor
  through the reference q1t byte format, and verify the outlier overlay and
  ternary base reconstruct exactly.

## [1.0.8] - 2026-07-18

### Fixed
- Parallel Hugging Face downloads now resume large byte ranges from the exact
  last written byte after interrupted streams and temporary DNS failures.
- Useful partial progress resets the retry budget, so a multi-gigabyte range is
  no longer aborted merely because it required more than three connections.
- Range responses are bounded and their `Content-Range` is validated before
  writing, preventing malformed CDN responses from corrupting the destination.

### Tests
- Added a regression that downloads part of a range, survives three consecutive
  DNS failures, resumes at the next byte, and verifies the complete file.

## [1.0.7] - 2026-07-18

### Fixed
- Restored the standard Qwen2/Qwen3/Qwen3.5 MoE conversion path that was
  already supported by `cortiq convert` but remained blocked by the mobile
  architecture guard. Router and shared-expert gates remain F16 while expert
  matrices use the selected quantization.
- Added complete on-device `LiquidAI/LFM2.5-8B-A1B` conversion: all 2,302
  vendor tensor names map collision-free to the canonical CMF layout,
  ShortConv schedules and kernel geometry are preserved, and the header carries
  sigmoid routing, expert-selection bias semantics, top-k normalization, and
  per-expert dimensions.
- `chat_template.jinja` sidecars are now embedded into the CMF tokenizer bundle
  instead of silently falling back to an incorrect default chat template.
- Structural validation checks every routed expert's gate/up/down tensors before
  native loading. Unsupported `num_local_experts` layouts remain blocked rather
  than being mislabeled as supported.

### Tests
- Added independent end-to-end synthetic conversions for canonical Qwen MoE and
  LFM2 ShortConv+MoE, plus the exact public LFM2.5-8B-A1B config and tokenizer
  sidecar regression coverage. Existing Qwen3.5, Gemma, dense, downloader, and
  API tests remain unchanged and passing.

## [1.0.6] - 2026-07-18

### Changed
- Bundled cortiq runtime updated to **v0.3.12** for arm64-v8a,
  armeabi-v7a, x86_64, and iOS. The update adds LFM2-MoE inference with
  ShortConv mixers and sigmoid-routed experts, uses every core on all-A55
  devices, and includes Vulkan support in the 64-bit Android libraries.

### Fixed
- The mobile CMF structural validator now recognizes `ShortConv` layers and
  verifies their three canonical tensors instead of treating them as Qwen
  GatedDeltaNet layers and rejecting valid v0.3.12 models.

### Verified
- All downloaded runtime archives match the SHA-256 digests published in the
  cmf v0.3.12 GitHub Release and export the C ABI used by the app.

## [1.0.5] - 2026-07-18

### Added
- Added the ready-to-run
  [`infosave/Bonsai-1.7Bcmf`](https://huggingface.co/infosave/Bonsai-1.7Bcmf)
  Q1 model as the first featured download, above Bonsai 27B. Its 319 MiB CMF
  file downloads directly with the parallel downloader and needs no conversion.

### Verified
- All bundled Android ABIs and the iOS static library remain on cortiq runtime
  v0.3.11, which is required by the ready Bonsai CMF models.

## [1.0.4] - 2026-07-18

### Fixed
- OpenAI-compatible API validation now returns structured `400`/`404`
  responses for malformed JSON, empty or invalid messages and prompts,
  bad parameter types, unknown task masks, and model-name mismatches.
- Server responses no longer expose Dart exceptions or native runtime details;
  unexpected generation failures return a stable `internal_error` response.
- Token-limit completions now report `finish_reason: length`, including the
  final SSE chunk; streaming chat finishes with an empty delta and `[DONE]`.
- CORS preflight responses advertise `GET`, `POST`, and `OPTIONS`, while the
  request log and error counters retain the actual response status.

### Tests
- Added real loopback HTTP tests covering completions, error schemas, model
  and task validation, CORS, status accounting, and exception redaction.

## [1.0.3] - 2026-07-18

### Added
- **On-device Qwen3.5 GatedDeltaNet conversion**: nested `text_config`,
  hybrid layer schedules, faithful vendor GDN tensors, linear-core geometry,
  RoPE and Gemma-style norm semantics are preserved in the CMF header.
- **On-device Gemma conversion** matching the reference `cortiq convert`:
  Gemma 1 and Gemma 3 scaling/GeGLU/sliding-window fields, plus dense
  Gemma 4 12B/31B dual attention, global/local RoPE, V=K materialization,
  V-norm and final-logit soft-capping. Gemma 2 soft-capping and unsupported
  Gemma 4 MoE/E-series/KV-sharing fail before downloading model weights.
- **Parallel ready-CMF downloads** with 2–8 concurrent HTTP range requests
  and an automatic single-stream fallback for servers without range support.
- Safetensors shards use the same segmented downloader; interrupted CDN
  streams resume from the last received byte with three automatic retries.

### Fixed
- Ready `.cmf` jobs no longer claim to be converting to the placeholder
  Q8_2F quantization; the completed file reports its real per-tensor dtype.
- Structural validation now verifies all Q/K/V/O or all nine GatedDeltaNet
  tensors per layer before native inference.

## [1.0.2] - 2026-07-18

### Fixed
- **Honest quantization labels**: model cards and finished jobs now show
  the dominant tensor dtype read from the file's directory — a q1 file
  shows Q1 (not the header's informational VBIT, and not the quant that
  happened to be selected in the UI for a direct .cmf download).
- **Chat crash with on-device-converted hybrid models** (qwen3.5-style
  GatedDeltaNet): the converter labeled every layer FullAttention and
  passed linear-attention tensors through unfolded, which crashed the
  engine at generate. The converter now refuses hybrid/MoE architectures
  before downloading weights with a clear message (use desktop
  `cortiq convert` or a ready .cmf); dense models are unaffected.
- **Load-time structural validation**: the engine pre-checks the file
  (embed/lm_head presence, per-layer attention tensors vs layer_types)
  and reports a readable error instead of dying natively.
- Memory fit check now uses the platform's live available-RAM figure
  (ActivityManager / os_proc_available_memory) instead of a heuristic.

Verified on desktop through the app's own binding: bonsai-27b-q1.cmf
(27B hybrid, ready .cmf) loads in 0.7 s and generates at 6.2 tok/s.

## [1.0.1] - 2026-07-18

### Added
- **Q8_2F on-device conversion** — the recommended two-field quantization
  now converts right on the phone (f16-RMS column field + per-row
  residual scale, reference-exact).
- **Featured models**: ready-to-run `.cmf` repos pinned above the search
  results (infosave/Bonsai-27Bcmf — 27B at 1-bit in 4.8 GB); one tap
  starts the direct download.
- Engine load failures now surface as a snackbar with the error text.

### Changed
- Conversion is **multi-threaded**: quantization runs on an isolate pool
  sized by the CPU-threads setting (Qwen3-0.6B → Q8_2F in 143 s on 8
  threads), and no longer blocks the UI.
- Bundled cortiq runtime updated to **v0.3.11** (q1 speed batch) on all
  ABIs: arm64-v8a, armeabi-v7a, x86_64, iOS static lib.

### Fixed
- Converted files are now byte-exact against the reference converter:
  f16-rounded scales (previous output degraded inference), `quant_type`
  Q1→VBIT, q1 width guard with per-tensor q8_2f fallback, tensor-name
  canonicalization, f16 for noise-sensitive projections, QUANT_2F
  feature bit. Files converted by 1.0.0 should be re-converted.
- End-to-end verified: an app-converted Q8_2F model loads through the
  cortiq runtime and generates at 100 tok/s (`tool/convert_smoke.dart`).

## [1.0.0] - 2026-07-18

### Added
- **Chat** with streaming replies, per-message token stats (latency, ↑/↓
  tokens, tok/s), markdown, copy/regenerate/stop, and persistent chat
  topics with full context (GPT-style history).
- **Document attachments** (txt/md/code/json/…) inlined into the prompt,
  gated on model capability.
- **Model library**: CMF v2 metadata parsing (arch, quant, layers, context,
  task masks), import from device, load/unload, RAM fit check before load.
- **Hugging Face converter**: hub search, quantization picker, job queue
  with phases/progress/logs/cancel. On-device conversion of safetensors to
  CMF v2 in Q8_ROW, Q1 (1-bit-trained models) and F16; direct download of
  repos that ship `.cmf` files.
- **On-device CMF protocol server** (OpenAI-compatible):
  `/v1/chat/completions` (JSON + SSE), `/v1/completions`, `/v1/models`,
  `/v1/cortiq/status|masks|switch`, `/healthz`; QR code, LAN addresses,
  request log, live stats, optional Bearer-token auth, keep-awake.
- **Settings**: theme, 7 languages (en/ru/de/fr/es/zh/tr), generation
  params (temperature, top-p, max tokens, threads), server port, HF token,
  storage usage.
- **Native runtime**: `dart:ffi` binding to the `cortiq-ffi` C ABI
  (blocking generate in a worker isolate, streamed tokens, cancel via a
  shared native flag); `libcortiq_ffi.so` (arm64-v8a, cmf v0.3.9) bundled
  in the Android APK — real on-device inference out of the box, verified
  end-to-end with qwen3-5-4b Q8_2F (`tool/ffi_smoke.dart`). Demo engine
  remains as the clearly-labeled fallback where the library is absent.
- **CI/CD**: analyze+test+debug-APK on push; tag `v*` builds release APKs
  (universal + per-ABI) and an unsigned iOS archive into GitHub Releases.
- Unit tests: CMF envelope/header/directory round-trip, streaming hash64,
  f16 conversion, safetensors parsing.
