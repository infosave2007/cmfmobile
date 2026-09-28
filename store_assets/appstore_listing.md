# App Store — карточка Cortiq: Local AI Models

## Name (30 chars max)
Cortiq: Local AI Models

## Subtitle (30 chars max)
Private on-device AI chat

## Promotional Text (170 chars max)
Local chat and CMF decisions on your phone. Download ready models, choose skills and connect an optional oracle only when you confirm.

## Description (4000 chars max)
Cortiq runs chat and decision models on your iPhone. Local processing is the default: download a model, then use it offline. Network sharing, desktop pairing and an external oracle are optional features you control.

WHY CORTIQ

• Local by default — downloaded models work offline
• Free and open source, no subscriptions, no tracking
• Powered by CMF (Cortiq Model Format), an efficient format for mobile AI

CHAT

• Streaming replies with per-message stats: latency, tokens, tokens/sec
• Persistent chat topics — every conversation keeps its own context
• Attach documents (txt, md, code, json and more) to your prompt
• Markdown rendering, copy, regenerate, stop
• "Disable thinking" mode — reasoning models answer directly

DECISIONS

• Choose a skill and get a structured decision, not generated chat text
• Clear abstention when the local model is uncertain
• Optional oracle: your HTTPS provider, model and securely stored API key
• Every external request requires confirmation and may incur API charges
• Chat, Decision models and skill add-ons are clearly distinguished

MODEL LIBRARY

• Local model library with full metadata: architecture, quantization, context size
• RAM fit check before loading — a warning instead of a crash
• One-tap load and unload to free model memory
• Import .cmf files from device storage

HUGGING FACE CONVERTER

• Search the Hugging Face Hub, pick a model and quantization, watch live progress
• On-device multi-threaded conversion of safetensors models to CMF
• Quantizations from full F16 down to ternary (~2-bit) for the smallest footprint
• Featured mobile-ready models download in one tap
• Resilient downloads: automatic retry and resume after network drops

LOCAL AI SERVER

• Serve chat models over an OpenAI-compatible API, or Decision models over the CMF decision API
• Use your phone as an AI backend for laptops and other devices
• QR code for instant connection setup

COMPANION — SPLIT A MODEL WITH YOUR DESKTOP

• Run a model too large for your phone by pairing it with your own computer
• The desktop holds the layers; your phone keeps the tokenizer and draws the reply
• Or lend your phone's memory to the desktop and compute a span of layers here
• Connect over USB cable or Wi-Fi, protected by a shared token
• A split does not make a model faster — it makes a model possible

Cortiq is part of the open CMF ecosystem. Model performance depends on your device: newer iPhones with more RAM run larger models faster.

## Keywords (100 chars max, comma-separated)
local ai,llm,offline,private,chat,hugging face,on-device,gpt,assistant,open source,qwen,gemma

## URLs
- Support URL: https://github.com/infosave2007/cmfmobile
- Marketing URL (optional): https://github.com/infosave2007/cmf
- Privacy Policy URL: https://github.com/infosave2007/cmfmobile/blob/master/PRIVACY.md

## What's New in 1.1.17
Stability improvements and performance optimizations for the Cortiq engine.

## What's New in 1.2.8
Conversions no longer stop when the screen goes dark — a download or a
conversion now keeps the device awake until it finishes.

Downloads survive a bad connection: if one parallel stream stalls, the rest of
the file is fetched on its own instead of the whole transfer being discarded.

The app can now use more of your device's memory, so larger models load on
phones that previously refused them.

The ready-to-use model catalog reports a problem and offers a retry instead of
spinning forever, and it now judges what fits using the memory the app can
actually use — so it stops offering models that could never load.

## App Privacy (анкета)
- Перед публичной отправкой 1.3 проверьте анкету с учётом необязательного оракула:
  подтверждённый запрос передаёт текст и критерии выбранному API-провайдеру.
  Предыдущую формулировку «пользовательские данные никогда не отправляются»
  переносить нельзя. Аналитики и рекламных идентификаторов приложение не добавляет.
  Подробности: `PRIVACY.md`. Загрузка тестовой сборки не обновляет анкету автоматически.

## Прочие поля
- Category: Primary — Productivity; Secondary — Developer Tools (или Utilities)
- Age Rating: заполняйте анкету «нет» на всё, КРОМЕ «Unrestricted Web Access» — НЕТ,
  и в новых вопросах про ИИ: приложение генерирует контент через ИИ → отметьте
  наличие генеративного ИИ, контент не модерируется, но и не публикуется. Итог обычно 17+ или 12+.
- Price: Free (Price Schedule → 0)
- App uses IDFA: No
