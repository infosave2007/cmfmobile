# Google Play — карточка и анкеты Cortiq: Local AI Models

Пакет: `ai.cortiq.cmf_mobile`. Всё ниже — в порядке форм Play Console.
Готовая графика лежит в `store_assets/googleplay/`.

## 1. Создание приложения (Create app)
- App name: **Cortiq: Local AI Models**
- Default language: **English (United States) – en-US**
- App or game: **App**
- Free or paid: **Free**
- Декларации: приложение соответствует правилам — ставим галочки.

## 2. Главная карточка (Main store listing)

**App name (30):**
```
Cortiq: Local AI Models
```

**Short description (80):**
```
Private AI chat on your phone. Runs fully offline — no cloud, no account.
```

**Full description (4000):**
```
Cortiq turns your phone into a fully local AI workstation. Chat with large language models that run entirely on your device — no cloud, no account, no data collection. Your conversations never leave your phone.

WHY CORTIQ

• 100% private — models run on-device, works completely offline
• Free and open source, no subscriptions, no tracking
• Powered by CMF (Cortiq Model Format), an efficient format for mobile AI

CHAT

• Streaming replies with per-message stats: latency, tokens, tokens/sec
• Persistent chat topics — every conversation keeps its own context
• Attach documents (txt, md, code, json and more) to your prompt
• Markdown rendering, copy, regenerate, stop
• "Disable thinking" mode — reasoning models answer directly

MODEL LIBRARY

• Local model library with full metadata: architecture, quantization, context size
• RAM fit check before loading — a warning instead of a crash
• One-tap load and unload to free memory and battery
• Import .cmf files from device storage

HUGGING FACE CONVERTER

• Search the Hugging Face Hub, pick a model and quantization, watch live progress
• On-device multi-threaded conversion of safetensors models to CMF
• Quantizations from full F16 down to ternary (~2-bit) for the smallest footprint
• Featured mobile-ready models download in one tap
• Resilient downloads: automatic retry and resume after network drops

LOCAL AI SERVER

• Serve loaded models to your network over an OpenAI-compatible API
• Use your phone as an AI backend for laptops and other devices
• QR code for instant connection setup

Cortiq is part of the open CMF ecosystem. Model performance depends on your device: newer phones with more RAM run larger models faster.
```

**Графика:**
- App icon (512×512): `googleplay/icon_512.png`
- Feature graphic (1024×500): `googleplay/feature_graphic_1024x500.png`
- Phone screenshots (2–8 шт.): все шесть из `googleplay/screenshots/` (1080×1920)
- 7-inch / 10-inch tablet: можно те же 1080×1920 (Play разрешает), либо пропустить пока

## 3. Настройки магазина (Store settings)
- Category: **Productivity** (App)
- Tags: AI, Productivity (по желанию)
- Contact email: **urevich55@gmail.com**
- Website: `https://github.com/infosave2007/cmfmobile`

## 4. Контент приложения (App content) — анкеты

**Privacy policy:**
```
https://github.com/infosave2007/cmfmobile/blob/master/PRIVACY.md
```

**App access:** All functionality is available without special access (никаких логинов не нужно).

**Ads:** No, my app does not contain ads.

**Content rating (IARC):**
- Email: urevich55@gmail.com; категория: **Utility, Productivity, Communication, or Other**
- Насилие/секс/наркотики/азартные игры/шокирующий контент — **No** на всё
- «Does the app allow users to interact or exchange content with other users?» — **No** (локальный чат с ИИ, не с людьми)
- Вопросы про ИИ: приложение **содержит генеративный ИИ** (чат-бот) → отвечаем Yes; контент создаётся ИИ на устройстве, не публикуется и не передаётся другим пользователям
- Итоговый рейтинг обычно Teen / 12+ из-за генеративного ИИ — это нормально

**Target audience:** возраст **18 and over** (проще всего: без анкеты для детей). Appeal to children: No.

**News app:** No. **COVID-19 apps:** No.

**Data safety (Безопасность данных):**
- «Does your app collect or share any of the required user data types?» — **No**
- «Is all of the user data collected by your app encrypted in transit?» — вопрос не появится после «No»
- Комментарий на случай ревью: приложение не собирает и не передаёт данные; запросы к huggingface.co идут напрямую с устройства и не содержат личных данных; аналитики и аккаунтов нет.

**Government apps:** No. **Financial features:** None of these / No.
**Health apps:** No health features.

## 5. Первый релиз
- **Тестирование → Внутреннее тестирование → Создать выпуск**
- Play App Signing: **согласиться** (Google хранит app signing key, наш `~/cmf-release.jks` — upload key)
- Загрузить: `build/app/outputs/bundle/release/app-release.aab` (versionName 1.1.17, versionCode 23)
- Release notes:
```
First public release: fully local AI chat, Hugging Face model converter, local OpenAI-compatible server.
```
- Добавить себя в список внутренних тестеров (email), сохранить и раскатить.
- Для продакшена: **Production → Create release** — можно повторно использовать тот же AAB. У новых личных аккаунтов Google может требовать закрытое тестирование (12 тестеров, 14 дней) перед продакшеном — если появится такое требование, начинаем с internal/closed трека.

## 6. Дальше — публикация через GitHub
После создания сервисного аккаунта (секрет `PLAY_SERVICE_ACCOUNT_JSON`):
```
gh workflow run android-release.yml -f build_number=24 -f track=internal
```
