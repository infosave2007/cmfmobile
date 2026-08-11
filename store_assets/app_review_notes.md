# App Review — ответ на Guideline 2.1 (Information Needed)

Как использовать:
1. В разделе «Reply» замените `<DEVICE>` на устройство, где снято видео.
   Если снимали в облаке реальных устройств BrowserStack, подставьте:
   `iPhone 17 running iOS 26 (physical device, BrowserStack real-device cloud)`.
   Строк с `<DEVICE>` две — в пунктах 1 и 2.
2. App Store Connect → My Apps → Cortiq → страница отклонённой версии →
   Resolution Center (сообщение от App Review) → **Reply**: вставьте текст
   «Reply» и прикрепите видео к ответу.
3. App Store Connect → App Review Information → **Notes**: вставьте тот же
   текст (Apple просит хранить его там для будущих сабмитов) → Save.
4. В самой версии выберите билд **1.1.23 (30)** — в нём переписаны purpose
   strings, о которых Apple напоминает в подсказке по Guideline 5.1.1 →
   Submit for Review.

---

## Reply (вставить в Resolution Center, English)

Thank you for the review. Below is all of the requested information. A screen
recording captured on a physical device is attached to this reply.

**1. Screen recording**

The attached recording was captured on a <DEVICE>. It begins with launching
the app from the Home Screen and walks through the typical user flow across
the core features: browsing the model library, downloading a featured model
from Hugging Face, loading it into memory, chatting with the model fully
on-device (streaming replies with token statistics), attaching a text
document to a prompt, and starting the optional local-network AI server.

Regarding the specific flows listed in your checklist:
- **Account registration / login / deletion:** the app has no account system
  at all — no registration, no login, no user profiles, nothing to delete.
  It is fully functional immediately after installation.
- **Paid content, purchases, subscriptions:** none. The app is completely
  free, with no in-app purchases, no subscriptions and no advertising.
- **User-generated content:** nothing is shared or published. AI responses
  are generated locally on the device, are visible only to the user, and are
  never uploaded to any server, so there is no content feed and therefore no
  reporting or blocking mechanism.
- **Permission prompts:** the only runtime permission the app ever requests
  is the iOS Local Network permission, which appears when the user starts the
  optional local server; it is shown in the recording. The camera,
  microphone, photo-library and location usage descriptions present in
  Info.plist exist only because bundled framework components statically
  reference those APIs, which upload validation requires us to declare
  (ITMS-90683). The app never requests or uses any of those capabilities at
  runtime. In build 1.1.23 we rewrote each of those purpose strings to state
  this plainly, so the declarations no longer describe functionality the app
  does not have.

**2. Devices and OS versions tested**

- <DEVICE> — the device used for the attached recording, exercising the full
  flow: model download, on-device inference, and the local server.
- iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max and iPad Pro 13-inch (M5) on
  iOS/iPadOS 26 simulators — user-interface and layout testing across screen
  sizes, including iPad.
- Android hardware is used for day-to-day inference testing of the shared
  engine (the same runtime powers our Android build), which is why the
  on-device model loading and generation paths are well exercised.

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

No login credentials, demo accounts, sample files or configuration are
required — there is nothing to unlock. Every feature is reachable from a
fresh install:

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

Note on review conditions: the models are large files (roughly 1 GB for the
smallest featured model), so the download step needs a Wi-Fi connection and a
few minutes. If it is more convenient for the reviewer, the recording shows
this step in full so it does not have to be repeated on the review device.

**5. External services, tools and platforms**

- **Hugging Face Hub (huggingface.co)** — the only external service the app
  contacts. It is used solely to search for and download publicly available
  open-source AI models over anonymous HTTPS: no API key, no authentication,
  no account, and no personal or device data is sent.
- **AI provider: none.** All inference runs locally on the device through the
  bundled Cortiq runtime, our own open-source engine (Apache-2.0). No prompt
  or response is ever sent off the device.
- **No** analytics or tracking SDKs, **no** authentication services, **no**
  payment processors, **no** advertising networks, **no** backend of our own.
  The app collects no data whatsoever, which is what our App Privacy answers
  declare.

**6. Regional differences**

None. The app's features and content are identical in all regions. The UI is
localized into seven languages (English, Russian, German, French, Spanish,
Chinese, Turkish); language follows the device setting.

**7. Regulated industries / protected material**

The app does not operate in a regulated industry (no health, finance,
gambling, government or similar functionality) and contains no protected
third-party material. The application itself is our own software, published
as open source under Apache-2.0. The AI models are not bundled with the app:
the user downloads them directly from the public Hugging Face Hub under the
models' own open-source licenses, and the featured models we highlight are
openly licensed, including two we publish ourselves
(huggingface.co/infosave). AI-generated content is produced locally, shown
only to the user, and never published.

We are happy to provide any further information or a longer recording if that
would help complete the review.

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
