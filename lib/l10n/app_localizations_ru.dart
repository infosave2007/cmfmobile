// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Cortiq';

  @override
  String get navChat => 'Чат';

  @override
  String get navModels => 'Модели';

  @override
  String get navServer => 'Сервер';

  @override
  String get navSettings => 'Настройки';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionCopy => 'Копировать';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionLoad => 'Загрузить';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get chatEmptyTitle => 'Начните диалог';

  @override
  String get chatEmptyBody =>
      'Всё работает локально на этом устройстве — без облака, данные не покидают телефон.';

  @override
  String get chatNoModelTitle => 'Модель не загружена';

  @override
  String get chatNoModelBody =>
      'Скачайте модель с Hugging Face или импортируйте файл .cmf, затем загрузите её в движок.';

  @override
  String get chatGoToModels => 'Открыть «Модели»';

  @override
  String get chatInputHint => 'Сообщение…';

  @override
  String get chatAttachDocument => 'Прикрепить документ';

  @override
  String get chatAttachmentsNotSupported =>
      'Эта модель не поддерживает вложения документов.';

  @override
  String chatAttachmentTooLarge(String limit) {
    return 'Файл слишком большой — поддерживается до $limit текста.';
  }

  @override
  String get chatAttachmentUnreadable => 'Не удалось прочитать файл как текст.';

  @override
  String get chatStop => 'Стоп';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatRegenerate => 'Сгенерировать заново';

  @override
  String get chatSessions => 'Чаты';

  @override
  String get chatNewChat => 'Новый чат';

  @override
  String get chatRename => 'Переименовать';

  @override
  String get chatRenameTitle => 'Переименовать чат';

  @override
  String get chatDeleteChat => 'Удалить чат';

  @override
  String get chatDeleteChatConfirm => 'Удалить этот чат и его историю?';

  @override
  String get chatUntitled => 'Новый чат';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return 'Токены: $prompt на входе · $completion на выходе';
  }

  @override
  String get chatModelPickerTitle => 'Модель';

  @override
  String get chatModelLoading => 'Загрузка модели…';

  @override
  String engineLoadFailed(String error) {
    return 'Не удалось загрузить модель: $error';
  }

  @override
  String get chatDemoBadge => 'демо-движок';

  @override
  String get chatDemoBanner =>
      'Нативный рантайм cortiq не включён в эту сборку — ответы симулируются. См. native/README.md.';

  @override
  String get chatGenerationError => 'Ошибка генерации';

  @override
  String get chatSuggestion1 => 'Объясни, как работают маски задач CMF';

  @override
  String get chatSuggestion2 =>
      'Сделай краткое содержание прикреплённого документа';

  @override
  String get chatSuggestion3 => 'Напиши SQL-запрос месячной выручки';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps ток/с';
  }

  @override
  String get statsFinishLength => 'обрезано по лимиту токенов';

  @override
  String get modelsTitle => 'Модели';

  @override
  String get modelsEmptyTitle => 'Моделей пока нет';

  @override
  String get modelsEmptyBody =>
      'Скачайте модель с Hugging Face или импортируйте файл .cmf с устройства.';

  @override
  String get modelsImportFile => 'Импорт .cmf';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => 'загружена';

  @override
  String get modelsLoadIntoEngine => 'Загрузить в движок';

  @override
  String get modelsUnload => 'Выгрузить';

  @override
  String get modelsUnloadHint => 'Освобождает память модели';

  @override
  String get modelsDeleteTitle => 'Удалить модель';

  @override
  String modelsDeleteConfirm(String name) {
    return 'Удалить «$name» с этого устройства?';
  }

  @override
  String get modelsInvalidFile => 'Нечитаемый файл CMF';

  @override
  String modelsImportedSnack(String name) {
    return 'Импортировано: $name';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n слоёв';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n контекст';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n задач';
  }

  @override
  String get modelsAttachmentsOk => 'документы';

  @override
  String modelsMetaRam(String size) {
    return '~$size RAM';
  }

  @override
  String get memoryWarnTitle => 'Может не хватить памяти';

  @override
  String memoryWarnBody(String need, String total) {
    return 'Для запуска модели нужно около $need оперативной памяти, а сейчас доступно лишь около $total. Загрузка может завершиться ошибкой, работать очень медленно, или система закроет приложение во время генерации.';
  }

  @override
  String get memoryWarnLoadAnyway => 'Всё равно загрузить';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle =>
      'Найдите модель на Hugging Face, сконвертируйте в локальный .cmf и запускайте на этом телефоне.';

  @override
  String get importSearchPlaceholder =>
      'Поиск моделей (например, qwen3, llama)…';

  @override
  String get importFeaturedTitle => 'Рекомендуемые';

  @override
  String get importReadyCmfBadge => 'ГОТОВЫЙ CMF';

  @override
  String get importNoResults => 'Модели не найдены.';

  @override
  String get importGatedBadge => 'ограниченный доступ';

  @override
  String get importGatedHint =>
      'Репозиторий с ограниченным доступом: получите доступ на Hugging Face и добавьте токен в настройках.';

  @override
  String get importConfigureTitle => 'Настройка конвертации';

  @override
  String get importOutputName => 'Имя файла';

  @override
  String get importOutputNameHint => 'Буквы, цифры, - и _';

  @override
  String get importQuantization => 'Квантизация';

  @override
  String get importStartConvert => 'Конвертировать и скачать';

  @override
  String get importStartedSnack => 'Конвертация запущена';

  @override
  String get importJobsTitle => 'Задачи';

  @override
  String get importNoJobs => 'Конвертаций пока не было.';

  @override
  String get importKeepAwakeNote => 'Пока идёт конвертация, экран не гаснет.';

  @override
  String get importDeleteConfirm =>
      'Удалить эту конвертацию и её файл .cmf с диска?';

  @override
  String get importShowLog => 'Показать лог';

  @override
  String get importOnDeviceNote =>
      'На устройстве доступны Q8_ROW, Q8_2F, Q1T, Q1 и F16 (многопоточно). Репозитории с готовыми .cmf скачиваются напрямую — в любой квантизации.';

  @override
  String get quantDesktopOnly => 'только десктоп / .cmf';

  @override
  String get importStateRunning => 'выполняется';

  @override
  String get importStateDone => 'готово';

  @override
  String get importStateError => 'ошибка';

  @override
  String get importStateCancelled => 'отменено';

  @override
  String get importPhaseListing => 'чтение списка файлов';

  @override
  String get importPhaseDownloading => 'скачивание';

  @override
  String get importPhaseConverting => 'конвертация';

  @override
  String get importPhaseQuantizing => 'квантизация';

  @override
  String get importPhaseFinalizing => 'завершение';

  @override
  String get quantQ8_2fDesc =>
      '8 бит, два поля (𝒲×θ) — максимальная точность среди квантизаций; ~2× размера Q4TP.';

  @override
  String get quantQ8RowDesc =>
      '8 бит на строку — просто и надёжно. Конвертируется на устройстве.';

  @override
  String get quantQ1tDesc =>
      'Тернарный ~2,25–3 бит с оверлеем выбросов (f16) — ниже q4, без обучения. Самый компактный рабочий файл, наибольшая потеря качества. Конвертируется на устройстве.';

  @override
  String get quantQ4Desc =>
      '4 бита блочно — минимальный размер, ниже качество. Нужен .cmf-репозиторий или десктопный тулчейн.';

  @override
  String get quantVbitDesc =>
      'Переменные 3–8 бит — бюджеты по экспертам. Нужен .cmf-репозиторий или десктопный тулчейн.';

  @override
  String get quantQ1Desc =>
      '1,5 бита — для 1-битно обученных моделей (Bonsai, BitNet). Модель 27B помещается в ~5 ГБ. Конвертируется на устройстве.';

  @override
  String get quantF16Desc =>
      '16 бит — без квантизации, большой файл. Конвертируется на устройстве.';

  @override
  String get serverTitle => 'Сервер';

  @override
  String get serverSubtitle =>
      'Предоставьте доступ к модели по сети: API чата или решений — в зависимости от модели.';

  @override
  String get serverStart => 'Запустить сервер';

  @override
  String get serverStop => 'Остановить сервер';

  @override
  String get serverStarting => 'Запуск…';

  @override
  String get serverRunning => 'Работает';

  @override
  String get serverStopped => 'Остановлен';

  @override
  String get serverNoModelWarning =>
      'Модель не загружена — запросы к API будут получать 503, пока вы не загрузите её на вкладке «Модели».';

  @override
  String get serverAddresses => 'Адреса';

  @override
  String get serverQrHint =>
      'Отсканируйте с другого устройства, чтобы получить базовый URL';

  @override
  String get serverAuthRequire => 'Требовать bearer-токен';

  @override
  String get serverAuthHint =>
      'Клиенты должны отправлять Authorization: Bearer <токен>';

  @override
  String get serverAccessToken => 'Токен доступа';

  @override
  String get serverStatRequests => 'Запросы';

  @override
  String get serverStatErrors => 'Ошибки';

  @override
  String get serverStatTokens => 'Токены';

  @override
  String get serverStatSpeed => 'Средняя скорость';

  @override
  String get serverStatUptime => 'Аптайм';

  @override
  String get serverRecentRequests => 'Последние запросы';

  @override
  String get serverNoRequestsYet =>
      'Запросов пока нет. Подключите клиент через указанные ниже эндпоинты.';

  @override
  String get serverKeepAwakeNote => 'Пока сервер работает, экран не гаснет.';

  @override
  String get serverEndpointsTitle => 'Эндпоинты';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'Системная';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Системный';

  @override
  String get settingsGeneration => 'Генерация';

  @override
  String get settingsTemperature => 'Температура';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => 'Макс. токенов';

  @override
  String get settingsThreads => 'Потоки CPU';

  @override
  String settingsThreadsAuto(int count) {
    return 'Авто ($count)';
  }

  @override
  String get settingsThreadsHint =>
      '«Авто» подбирает размер пула под кластер больших ядер, на который движок пиннит воркеров; лишние потоки только добавляют ожидание. Применяется при следующей загрузке модели.';

  @override
  String get settingsUseGpu => 'Использовать GPU (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint =>
      'Использовать GPU телефона для чат-моделей — после следующей загрузки. Первый запуск может занять несколько минут для компиляции и кеширования шейдеров. CMF Decision на телефоне пока работает на CPU.';

  @override
  String get settingsUseGpuNeedsBackend =>
      'Нужна сборка движка с бэкендом Vulkan/Metal — см. native/TUNING.md.';

  @override
  String get settingsDisableThinking => 'Отключить рассуждения';

  @override
  String get settingsDisableThinkingHint =>
      'Модели с рассуждением (Qwen3/3.5) отвечают сразу, без блока <think>';

  @override
  String get settingsEngineSection => 'Движок';

  @override
  String get settingsEngineFlags => 'Флаги движка (для опытных)';

  @override
  String get settingsEngineFlagsHint =>
      'По одному CMF_KEY=value в строке. Параметры применятся при загрузке модели. Пусто — значения по умолчанию.';

  @override
  String get settingsServerSection => 'Сервер';

  @override
  String get settingsServerPort => 'Порт';

  @override
  String get settingsServerPortHint =>
      'Применится при следующем запуске сервера';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => 'Токен доступа';

  @override
  String get settingsHfTokenHint =>
      'hf_… (для моделей с ограниченным доступом)';

  @override
  String get settingsStorage => 'Хранилище';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$size в $count моделях';
  }

  @override
  String get settingsAbout => 'О приложении';

  @override
  String settingsAboutLine(String engine) {
    return 'Протокол CMF v2 · движок: $engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'Cortiq $version';
  }

  @override
  String get navCompanion => 'Сплит';

  @override
  String get companionTitle => 'Компаньон';

  @override
  String get companionSubtitle =>
      'Свяжите это устройство с десктопом. Сплит не ускоряет модель — токен идёт по слоям последовательно, — он позволяет запустить ту, которая сюда не помещается.';

  @override
  String get companionUnsupported =>
      'Движок этой сборки не умеет сплит: нужен cortiq 0.5.70 или новее.';

  @override
  String get companionWhereTitle => 'Где считать';

  @override
  String get companionRoleLocal => 'Здесь';

  @override
  String get companionRoleLocalHint => 'Всё считается на этом устройстве.';

  @override
  String get companionRoleDesktop => 'На десктопе';

  @override
  String get companionRoleDesktopHint =>
      'Десктоп держит слои, голову и сэмплер; это устройство оставляет себе токенизатор и рисует ответ. Для модели, которая сюда не помещается.';

  @override
  String get companionRoleWorkerHint =>
      'Одолжить память этого устройства десктопу: часть слоёв модели считается здесь. Имеет смысл только тогда, когда на десктопе модель не помещается.';

  @override
  String get companionAddress => 'Адрес десктопа';

  @override
  String get companionToken => 'Общий токен';

  @override
  String get companionTokenHint =>
      'Одна и та же строка на обоих устройствах. Обязателен для всех адресов, кроме loopback.';

  @override
  String get companionOverCable => 'Кабель';

  @override
  String get companionOverWifi => 'Wi-Fi';

  @override
  String get companionWifiWarning =>
      'По Wi-Fi на каждый токен приходится один круг, поэтому пользователь видит именно хвост: около 9 мс типично, но 95 мс на 99-м процентиле против 2.9 мс по кабелю. Лучше USB-тетеринг — или считать здесь.';

  @override
  String get companionCheck => 'Проверить';

  @override
  String get companionCheckOk => 'Удалённое устройство ответило.';

  @override
  String get companionNeedsModel =>
      'Сначала загрузите модель: токенизатор и шаблон чата читаются из локального файла, даже когда считает десктоп.';

  @override
  String get companionServeTitle => 'Отдавать слои';

  @override
  String get companionWorkerPort => 'Порт';

  @override
  String get companionWorkerStart => 'Начать отдавать';

  @override
  String companionWorkerListening(String address) {
    return 'Слушает на $address';
  }

  @override
  String get companionWorkerOneWay =>
      'Сервис работает до закрытия приложения: движок пока не поддерживает его отдельную остановку.';

  @override
  String get companionStatsTitle => 'Удалённое устройство';

  @override
  String get companionStatClock => 'Частота CPU';

  @override
  String get companionStatTemp => 'Температура';

  @override
  String get companionStatMemory => 'Свободная память';

  @override
  String get companionStatThreads => 'Рабочих потоков';

  @override
  String get companionStatPlatform => 'Платформа';

  @override
  String get companionStatUnknown => 'не сообщается';

  @override
  String get companionClockWarning =>
      'Удалённое устройство работает на пониженной частоте. Короткие вычисления с ожиданием сети могут мешать автоматическому повышению частоты и снижать производительность.';

  @override
  String get companionSameModel =>
      'На обоих устройствах должен быть одинаковый файл .cmf. При подключении файлы проверяются; при несовпадении появится ошибка.';

  @override
  String get companionWireNote =>
      'Используйте одинаковую версию движка на обоих устройствах. Совместимость протокола проверяется при подключении.';

  @override
  String get companionTokenClearText =>
      'Токен уходит открытым текстом. Используйте кабель или доверенную сеть.';

  @override
  String get companionErrorAddress =>
      'Адрес должен быть в виде host:port, например 192.168.1.5:9911.';

  @override
  String get companionPeerUnreachable =>
      'Десктоп не отвечает — остановлен, или пропал кабель либо сеть.';

  @override
  String get companionPeerWireVersion =>
      'На десктопе другая версия движка. Обновить нужно обе стороны.';

  @override
  String get companionPeerModelMismatch =>
      'На десктопе другой файл модели. На обеих сторонах нужен один и тот же .cmf.';

  @override
  String get companionPeerFailed => 'Десктоп не смог завершить ответ.';

  @override
  String companionStatusActive(String address) {
    return 'Считает $address';
  }

  @override
  String companionStatusUnchecked(String address) {
    return 'Задан $address, ещё не проверен';
  }

  @override
  String get companionStatusBroken => 'Десктоп недоступен';

  @override
  String get companionDisconnect => 'Отключить';

  @override
  String get chatComputeHere => 'Считать здесь';

  @override
  String get quantQ4tpDesc =>
      'Рекомендуется: 4-битные тайлы на построчной лестнице масштабов — лучший баланс качества и размера, тот же формат, что делают десктопные инструменты.';

  @override
  String get quantQ2tpDesc =>
      'Профиль 2/4 бита для MoE: эксперты gate/up — 2 бита, остальное q4tp. На плотной модели это обычный q4tp.';

  @override
  String get importCheckingRepo => 'Проверяем, что лежит в репозитории…';

  @override
  String get importReadyCmfTitle => 'Готовый CMF — без конвертации';

  @override
  String get importReadyCmfBody =>
      'В репозитории лежит готовый файл .cmf. Он скачивается как есть, с той квантизацией, с которой собран.';

  @override
  String get importDownloadButton => 'Скачать';

  @override
  String importDownloadSize(String size) {
    return 'Скачивание: $size';
  }

  @override
  String importEstimatedOutput(String size) {
    return '≈ $size';
  }

  @override
  String get importEstimateNote =>
      'Размеры на выходе приблизительны: эмбеддинги и нормы остаются f16 в любом профиле.';

  @override
  String get importTooBigBadge => 'больше памяти устройства';

  @override
  String get importTabReady => 'Готовые';

  @override
  String get importTabConvert => 'Из HF';

  @override
  String get decisionTitle => 'Решения';

  @override
  String get decisionSubtitle =>
      'Выберите навык, опишите запрос — получите решение, а не сгенерированный ответ.';

  @override
  String get decisionSkill => 'Навык';

  @override
  String get decisionInput => 'Текст запроса';

  @override
  String get decisionExample => 'Подставить пример';

  @override
  String get decisionPolicy => 'Режим решения';

  @override
  String get decisionBalanced => 'Сбалансированный';

  @override
  String get decisionCareful => 'Отказ при сомнении';

  @override
  String get decisionBestEffort => 'Допускать неопределённость';

  @override
  String get decisionRun => 'Принять решение';

  @override
  String get decisionAccepted => 'Решение принято';

  @override
  String get decisionAbstained => 'Недостаточно уверенности';

  @override
  String get decisionAbstainBody =>
      'Надёжного решения нет. Уточните запрос или выберите другой навык.';

  @override
  String get decisionConfidence => 'Оценка уверенности';

  @override
  String get decisionTotal => 'Общее время';

  @override
  String get decisionResonance => 'Время резонанса';

  @override
  String get decisionExplain => 'Почему это решение?';

  @override
  String get decisionErrorHelp =>
      'Чем меньше ошибка реконструкции, тем ближе соответствие. Оценка уверенности не равна измеренной точности.';

  @override
  String get decisionCopy => 'Копировать JSON';

  @override
  String get decisionOffline =>
      'Локальные решения остаются на телефоне. Только подтверждённый вызов оракула отправляет текст провайдеру. Свои навыки импортируйте как CMF Decision, созданный в Cortiq 0.8+.';

  @override
  String get oracleTitle => 'Оракул';

  @override
  String get oracleDescription =>
      'Необязательный OpenAI-совместимый API для случаев, когда локальному навыку не хватает уверенности. Каждый запрос требует подтверждения.';

  @override
  String get oracleEnabled => 'Включить ручной вызов оракула';

  @override
  String get oracleModel => 'ID модели';

  @override
  String get oracleKeyHelp =>
      'Ключ хранится в защищённом хранилище телефона и не передаётся через API телефона.';

  @override
  String get oracleSave => 'Сохранить';

  @override
  String get oracleDelete => 'Удалить ключ и сбросить';

  @override
  String get oracleAsk => 'Спросить оракула';

  @override
  String get oracleConfirm =>
      'Отправить этот запрос и критерии навыка выбранному провайдеру? Вызов API может быть платным.';

  @override
  String get oracleAnswer => 'Ответ оракула';

  @override
  String get oracleNotTraining =>
      'Внешний ответ, не локальное решение. Модель не переобучается.';

  @override
  String get oracleManual =>
      'По умолчанию выключен · подтверждение каждого запроса';

  @override
  String get modelKindDecision => 'Решения';

  @override
  String get modelKindChat => 'Чат';

  @override
  String get modelDecisionHelp =>
      'Выбирает вариант или воздерживается от решения. Не генерирует ответы в чате.';

  @override
  String get modelChatHelp => 'Генерирует текст и отвечает на сообщения.';

  @override
  String get modelOpenDecisions => 'Открыть решения';

  @override
  String get skillBanking => 'Банковские обращения';

  @override
  String get skillAssistant => 'Запросы помощнику';

  @override
  String get skillCommands => 'Команды устройству';

  @override
  String get oracleApiUrl => 'Базовый URL API';

  @override
  String get oracleApiKey => 'Ключ API';

  @override
  String get oracleStorageError =>
      'Защищённое хранилище недоступно. Попробуйте ещё раз.';

  @override
  String get oracleUrlError =>
      'Укажите базовый HTTPS-адрес без логина, пароля, параметров запроса и фрагмента.';

  @override
  String get oracleModelError => 'Укажите ID модели: не более 200 символов.';

  @override
  String get oracleKeyError => 'Укажите ключ API без пробелов.';

  @override
  String get oracleRequestError =>
      'Не удалось получить ответ оракула. Проверьте соединение и настройки API.';

  @override
  String oracleHttpError(int status) {
    return 'Провайдер вернул HTTP $status. Проверьте ключ API, ID модели и баланс.';
  }

  @override
  String get oracleInvalidResponse =>
      'Ответ оракула не соответствует допустимым результатам навыка и не принят.';

  @override
  String get decisionFailed =>
      'Не удалось получить локальное решение. Проверьте, что загружены модель CMF Decision и навык.';

  @override
  String get modelKindSkill => 'Дополнение';

  @override
  String get modelSkillHelp =>
      'Дополнение к базовой чат-модели, а не самостоятельная модель. Его нельзя открыть как чат или модель решений.';
}
