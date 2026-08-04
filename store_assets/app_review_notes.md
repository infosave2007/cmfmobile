# App Review — ответ на Guideline 2.1 (Information Needed)

Как использовать:
1. Заполните `<ПЛЕЙСХОЛДЕРЫ>` в разделе «Reply» (модель iPhone и версия iOS).
2. Запишите скринкаст по сценарию внизу файла на физическом iPhone.
3. App Store Connect → My Apps → Cortiq → страница отклонённой версии →
   Resolution Center (сообщение от App Review) → **Reply**: вставьте текст
   «Reply» и прикрепите видео к ответу.
4. App Store Connect → App Review Information → **Notes**: вставьте тот же
   текст (Apple просит хранить его там для будущих сабмитов) → Save →
   Submit for Review.

---

## Reply (вставить в Resolution Center, English)

Thank you for the review. Below is the requested information. A screen
recording captured on a physical device is attached to this reply.

**1. Screen recording**

The attached recording was captured on a physical <IPHONE MODEL, e.g. iPhone 15 Pro>
running iOS <VERSION>. It starts with launching the app from the Home Screen
and walks through the full typical user flow: browsing the model library,
downloading a featured model from Hugging Face, loading it, chatting with the
model fully on-device (streaming replies with token statistics), attaching a
text document to a prompt, and starting the optional local-network AI server.

Please note the following about the flows your checklist mentions:
- The app has **no account system** — no registration, no login, no account
  deletion. It works immediately after install.
- The app is **completely free**: no purchases, no subscriptions, no paid
  content, no ads.
- There is **no shared or published user-generated content**. AI responses are
  generated locally on the device, are visible only to the user, and are never
  uploaded or shared, so there are no reporting/blocking mechanisms.
- The **only runtime permission prompt** is the iOS Local Network permission,
  which appears when the user starts the optional local server (shown in the
  recording). The camera, microphone, photo-library and location usage
  descriptions in Info.plist exist only because bundled framework components
  statically reference those APIs (App Store upload validation ITMS-90683
  requires the declarations); the app never requests or uses any of these
  capabilities at runtime, and their purpose strings state this explicitly.

**2. Devices and OS versions tested**

- <IPHONE MODEL> — iOS <VERSION> (physical device)
- iPhone 17 Pro, iPhone 17 Pro Max, iPad Pro 13-inch (M5) — iOS/iPadOS 26
  simulators (UI and layout testing)
- Distributed via TestFlight before submission.

**3. Purpose and target audience**

Cortiq turns an iPhone into a fully local, private AI workstation. Large
language models run entirely on the device: no cloud inference, no account,
no data collection, and it works completely offline once a model is
downloaded. The problem it solves: cloud AI assistants require accounts,
subscriptions and sending personal data to third-party servers. Cortiq's
value: free, private, offline AI chat, plus developer-oriented extras — an
on-device converter of Hugging Face models to the open CMF format, and an
optional OpenAI-compatible local server so other devices on the user's own
Wi-Fi network can use the phone as an AI backend. Target audience:
privacy-conscious users, developers and AI enthusiasts. The app is open
source (Apache-2.0): https://github.com/infosave2007/cmfmobile

**4. Setup and access instructions**

No login credentials, demo accounts or sample files are required. Everything
is accessible immediately:

1. Launch the app → tab "Models".
2. Tap a featured model (e.g. "Bonsai 1.7B", ~1 GB) → Download
   (Wi-Fi recommended). Progress, logs and cancel are shown in the job queue.
3. When downloaded, tap **Load** (the app checks available RAM first).
4. Tab "Chat" → type a message → the model answers on-device with streaming
   text and per-message token statistics. The paperclip attaches text
   documents (txt/md/code) to a prompt.
5. Optional server: tab "Server" → Start → allow the Local Network
   permission → the screen shows the URL and a QR code; any device on the
   same Wi-Fi can call the OpenAI-compatible API
   (POST /v1/chat/completions).

**5. External services, tools and platforms**

- **Hugging Face Hub (huggingface.co)** — the only external service the app
  communicates with. It is used solely to search and download publicly
  available open-source AI models over anonymous HTTPS (no API key, no
  authentication, no personal data sent).
- There are **no** analytics/tracking SDKs, no authentication services, no
  payment processors, and no cloud AI services — all AI inference runs
  on-device using the bundled open-source Cortiq runtime.

**6. Regional differences**

None. The app's features and content are identical in all regions. The UI is
localized into seven languages (English, Russian, German, French, Spanish,
Chinese, Turkish); language follows the device setting.

**7. Regulated industries / protected material**

The app does not operate in a regulated industry and contains no protected
third-party material. The app itself is our own open-source software
(Apache-2.0). AI models are downloaded by the user directly from the public
Hugging Face Hub under their respective open-source licenses; the featured
models are openly licensed. AI-generated content is produced locally, shown
only to the user, and never published.

---

## Сценарий скринкаста (записать на физическом iPhone, последняя iOS)

Требования Apple: физическое устройство, последняя iOS, запись начинается с
запуска приложения, без монтажа. Снимайте встроенной «Записью экрана»
(Настройки → Пункт управления → Запись экрана). Язык интерфейса лучше
переключить на английский (Настройки iPhone → Cortiq → Language). 2–4 минуты.

Подготовка до записи: модель Bonsai 1.7B уже скачана (но НЕ загружена в
память), чтобы не ждать гигабайт на видео. Сброс разрешения Local Network не
обязателен, но если хотите показать сам системный промпт — удалите и
поставьте приложение заново, скачав модель до записи.

1. **Запуск**: домашний экран → тап по иконке Cortiq → главный экран.
2. **Models**: открыть вкладку, показать библиотеку и карточку модели
   (метаданные: архитектура, квантизация, контекст).
3. **Hugging Face**: вкладка конвертера → поиск любой модели → открыть
   карточку → начать загрузку маленькой модели → показать прогресс/лог пару
   секунд → отменить (показали флоу загрузки, не ждём).
4. **Load**: вернуться в Models → Load у скачанной Bonsai 1.7B → показать
   проверку RAM и статус «loaded».
5. **Chat**: новый чат → вопрос (например, "Explain what a local AI model
   is in two sentences") → показать стриминговый ответ и статистику токенов
   под сообщением → прикрепить txt-файл скрепкой → задать вопрос по файлу.
6. **Server**: вкладка Server → Start → **системный промпт Local Network →
   Allow** (это единственный запрос разрешений — важно, чтобы он попал в
   кадр, если ставили приложение заново) → показать URL, QR-код и счётчики.
7. **Settings**: коротко показать настройки и About (версия).
8. Остановить запись.

Видео прикладывается прямо к ответу в Resolution Center (кнопка скрепки).
Если файл больше лимита — сожмите до 720p или выложите незалистированным
на YouTube/Drive и дайте ссылку в тексте ответа.
