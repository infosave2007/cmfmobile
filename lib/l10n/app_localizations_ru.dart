// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'CMF Mobile';

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
    return '$prompt промпт · $completion ответ токенов';
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
  String get modelsUnloadHint => 'Освобождает память и батарею';

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
  String get importReadyCmfBadge => 'готовый .cmf — нажмите, чтобы скачать';

  @override
  String get importNoResults => 'Модели не найдены.';

  @override
  String get importGatedBadge => 'gated';

  @override
  String get importGatedHint =>
      'Закрытый репозиторий — укажите токен Hugging Face в настройках.';

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
      '8 бит, два поля (𝒲×θ) — лучшее качество/размер. Конвертируется на устройстве.';

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
      'Раздавайте загруженную модель в сеть по протоколу CMF (OpenAI-совместимый API).';

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
      'Запросов ещё не было. Направьте сюда любой OpenAI-совместимый клиент.';

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
  String get settingsDisableThinking => 'Отключить размышления';

  @override
  String get settingsDisableThinkingHint =>
      'Модели с рассуждением (Qwen3/3.5) отвечают сразу, без блока <think>';

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
  String get settingsHfTokenHint => 'hf_… (нужен для gated-моделей)';

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
    return 'CMF Mobile $version';
  }
}
