# CMF Mobile

**Run local AI models on your phone. Serve them to your network. Convert them straight from Hugging Face.**

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-brightgreen)]()
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Protocol](https://img.shields.io/badge/CMF-v2-00d4aa)](https://github.com/infosave2007/cmf)

CMF Mobile is the mobile companion of the [CMF ecosystem](https://github.com/infosave2007/cmf)
(Cortiq Model Format): a Flutter app that turns an Android or iOS device into a
fully local AI workstation — chat, model library, on-device Hugging Face
converter, and an OpenAI-compatible server speaking the CMF protocol.

*Читайте также: [README.ru.md](README.ru.md) — документация на русском.*

---

## Features

### 💬 Chat
- Streaming replies with **per-message token statistics**: latency, prompt/completion tokens, tok/s
- **Persistent chat topics** — every conversation keeps its own context, like GPT-style apps
- **Document attachments** (txt/md/code/json/…) inlined into the prompt when the model supports them
- Markdown rendering, copy, regenerate, stop

### 📦 Models
- Local `.cmf` library with parsed metadata: architecture, quantization, layers, context, task masks
- **RAM fit check** before loading — a warning instead of an OOM kill
- One-tap load / **unload** (frees memory and battery)
- Import `.cmf` files from device storage

### ⬇️ Hugging Face converter (like cortiq-gateway, but on the phone)
- Search the HF Hub, pick a model, pick a quantization, watch live progress
- **On-device conversion** of safetensors repos to CMF v2:
  - `Q8_ROW` — 8-bit per-row
  - `Q1` — **1.5-bit for 1-bit-trained models** (Bonsai/BitNet: a 27B model fits in ~5 GB)
  - `F16` — no quantization
- Repos that ship ready `.cmf` files download directly — any quantization (Q8_2F, VBIT, …)
- Job queue with phases, logs, cancel — same flow as the gateway's Import view

### 📡 Server
- The phone becomes a **CMF protocol server** (OpenAI-compatible):

  | Endpoint | Purpose |
  |---|---|
  | `POST /v1/chat/completions` | Chat, JSON + SSE streaming |
  | `POST /v1/completions` | Legacy completions |
  | `GET /v1/models` | Loaded model |
  | `GET /v1/cortiq/status` | Uptime, tokens, tok/s |
  | `GET /v1/cortiq/masks` | Task masks baked into the model |
  | `POST /v1/cortiq/switch` | Switch active task |
  | `GET /healthz` | Health check |

- QR code with the base URL, LAN address list, request log, live counters
- Optional **Bearer-token auth** (a mobile addition — the desktop server is local-first)
- Keep-awake while serving

### 🌍 Localization
Seven languages, matching cortiq-gateway: **English, Русский, Deutsch, Français, Español, 中文, Türkçe**.

## Quick start

```bash
flutter pub get
flutter gen-l10n
flutter run
```

Without the native runtime the app uses a clearly-labeled **demo engine** —
the whole UX works (streaming, stats, server, converter), replies are
simulated. To run real inference, build `libcortiq_ffi` from the cmfpublic
Rust workspace: see [native/README.md](native/README.md).

## Architecture

```
lib/
├── core/            theme, providers (Riverpod), utils
├── data/
│   ├── models/      domain: LocalModel, ChatSession, ConversionJob, …
│   └── services/
│       ├── cmf_format.dart       CMF v2 reader/writer (envelope, dir, hash64)
│       ├── safetensors.dart      safetensors parser + f16/bf16 decode
│       ├── converter_service.dart HF → .cmf pipeline (Q8_ROW / Q1 / F16)
│       ├── cmf_server.dart       on-device CMF protocol server (dart:io)
│       ├── inference/            engine abstraction: FFI native ⇄ demo
│       └── …                     model repo, chat store, settings, HF API
├── features/        chat / models / server / settings screens
└── l10n/            ARB translations (7 languages)
```

Key design points:

- **CMF v2 is parsed natively in Dart** — 128-byte envelope (`CMF\x01`),
  JSON header, 56-byte tensor directory records, murmur3-fmix64 integrity
  hashes. The writer produces spec-compliant files verified by unit tests.
- **Conversion is streaming**: tensors are quantized in ≤8 MB row slabs, so
  multi-GB models convert in constant memory.
- **The inference engine is pluggable**: `NativeCortiqEngine` binds the
  cortiq Rust runtime over `dart:ffi`; `DemoEngine` keeps development and
  simulators productive.

## Testing

```bash
flutter analyze   # 0 issues
flutter test      # format round-trip, hash, f16, safetensors
```

## License

[Apache-2.0](LICENSE) — same as the CMF ecosystem.
