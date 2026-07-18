# Changelog

All notable changes to CMF Mobile are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [SemVer](https://semver.org/).

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
