// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CMF Mobile';

  @override
  String get navChat => 'Chat';

  @override
  String get navModels => 'Models';

  @override
  String get navServer => 'Server';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionLoad => 'Load';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get chatEmptyTitle => 'Start a conversation';

  @override
  String get chatEmptyBody =>
      'Everything runs locally on this device — no cloud, no data leaves your phone.';

  @override
  String get chatNoModelTitle => 'No model loaded';

  @override
  String get chatNoModelBody =>
      'Get a model from Hugging Face or import a .cmf file, then load it into the engine.';

  @override
  String get chatGoToModels => 'Open Models';

  @override
  String get chatInputHint => 'Message…';

  @override
  String get chatAttachDocument => 'Attach document';

  @override
  String get chatAttachmentsNotSupported =>
      'This model cannot take document attachments.';

  @override
  String chatAttachmentTooLarge(String limit) {
    return 'File is too large — up to $limit of text is supported.';
  }

  @override
  String get chatAttachmentUnreadable => 'Could not read this file as text.';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatSend => 'Send';

  @override
  String get chatRegenerate => 'Regenerate';

  @override
  String get chatSessions => 'Chats';

  @override
  String get chatNewChat => 'New chat';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatRenameTitle => 'Rename chat';

  @override
  String get chatDeleteChat => 'Delete chat';

  @override
  String get chatDeleteChatConfirm => 'Delete this chat and its history?';

  @override
  String get chatUntitled => 'New chat';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return '$prompt prompt · $completion completion tokens';
  }

  @override
  String get chatModelPickerTitle => 'Model';

  @override
  String get chatModelLoading => 'Loading model…';

  @override
  String engineLoadFailed(String error) {
    return 'Failed to load model: $error';
  }

  @override
  String get chatDemoBadge => 'demo engine';

  @override
  String get chatDemoBanner =>
      'The native cortiq runtime is not bundled in this build — replies are simulated. See native/README.md.';

  @override
  String get chatGenerationError => 'Generation failed';

  @override
  String get chatSuggestion1 => 'Explain how CMF task masks work';

  @override
  String get chatSuggestion2 => 'Summarize the attached document';

  @override
  String get chatSuggestion3 => 'Write a SQL query for monthly revenue';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps tok/s';
  }

  @override
  String get statsFinishLength => 'cut off at max tokens';

  @override
  String get modelsTitle => 'Models';

  @override
  String get modelsEmptyTitle => 'No models yet';

  @override
  String get modelsEmptyBody =>
      'Download a model from Hugging Face or import a .cmf file from this device.';

  @override
  String get modelsImportFile => 'Import .cmf';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => 'loaded';

  @override
  String get modelsLoadIntoEngine => 'Load into engine';

  @override
  String get modelsUnload => 'Unload';

  @override
  String get modelsUnloadHint => 'Frees memory and battery';

  @override
  String get modelsDeleteTitle => 'Delete model';

  @override
  String modelsDeleteConfirm(String name) {
    return 'Delete \"$name\" from this device?';
  }

  @override
  String get modelsInvalidFile => 'Unreadable CMF file';

  @override
  String modelsImportedSnack(String name) {
    return 'Imported $name';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n layers';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n ctx';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n tasks';
  }

  @override
  String get modelsAttachmentsOk => 'documents';

  @override
  String modelsMetaRam(String size) {
    return '~$size RAM';
  }

  @override
  String get memoryWarnTitle => 'Might not fit in memory';

  @override
  String memoryWarnBody(String need, String total) {
    return 'This model needs about $need of RAM to run, but only about $total is usable right now. Loading may fail, run very slowly, or the system may kill the app mid-generation.';
  }

  @override
  String get memoryWarnLoadAnyway => 'Load anyway';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle =>
      'Search Hugging Face, convert to a local .cmf, and run it on this phone.';

  @override
  String get importSearchPlaceholder => 'Search models (e.g. qwen3, llama)…';

  @override
  String get importFeaturedTitle => 'Recommended';

  @override
  String get importReadyCmfBadge => 'ready .cmf — tap to download';

  @override
  String get importNoResults => 'No models found.';

  @override
  String get importGatedBadge => 'gated';

  @override
  String get importGatedHint =>
      'Gated repo — set a Hugging Face token in Settings.';

  @override
  String get importConfigureTitle => 'Configure conversion';

  @override
  String get importOutputName => 'Output name';

  @override
  String get importOutputNameHint => 'Letters, digits, - and _';

  @override
  String get importQuantization => 'Quantization';

  @override
  String get importStartConvert => 'Convert & download';

  @override
  String get importStartedSnack => 'Conversion started';

  @override
  String get importJobsTitle => 'Conversions';

  @override
  String get importNoJobs => 'No conversions yet.';

  @override
  String get importDeleteConfirm =>
      'Delete this conversion and its .cmf file from disk?';

  @override
  String get importShowLog => 'Show log';

  @override
  String get importOnDeviceNote =>
      'On-device conversion supports Q8_ROW, Q8_2F, Q1T, Q1 and F16 (multi-threaded). Repos that already ship .cmf files are downloaded directly — any quantization.';

  @override
  String get quantDesktopOnly => 'desktop / .cmf only';

  @override
  String get importStateRunning => 'running';

  @override
  String get importStateDone => 'done';

  @override
  String get importStateError => 'error';

  @override
  String get importStateCancelled => 'cancelled';

  @override
  String get importPhaseListing => 'listing files';

  @override
  String get importPhaseDownloading => 'downloading';

  @override
  String get importPhaseConverting => 'converting';

  @override
  String get importPhaseQuantizing => 'quantizing';

  @override
  String get importPhaseFinalizing => 'finalizing';

  @override
  String get quantQ8_2fDesc =>
      '8-bit two-field (𝒲×θ) — best quality/size. Converts on device.';

  @override
  String get quantQ8RowDesc =>
      '8-bit per-row — simple, robust. Converts on device.';

  @override
  String get quantQ1tDesc =>
      'Ternary ~2.25–3 bit with an f16 outlier overlay — below q4, training-free. Smallest usable file, largest quality drop. Converts on device.';

  @override
  String get quantQ4Desc =>
      '4-bit block — smallest, lower quality. Needs a .cmf repo or the desktop toolchain.';

  @override
  String get quantVbitDesc =>
      'Variable 3–8 bit — per-expert budgets. Needs a .cmf repo or the desktop toolchain.';

  @override
  String get quantQ1Desc =>
      '1.5-bit — for 1-bit-trained models (Bonsai, BitNet). A 27B model fits in ~5 GB. Converts on device.';

  @override
  String get quantF16Desc =>
      '16-bit — no quantization, large file. Converts on device.';

  @override
  String get serverTitle => 'Server';

  @override
  String get serverSubtitle =>
      'Serve the loaded model to your network over the CMF protocol (OpenAI-compatible API).';

  @override
  String get serverStart => 'Start server';

  @override
  String get serverStop => 'Stop server';

  @override
  String get serverStarting => 'Starting…';

  @override
  String get serverRunning => 'Running';

  @override
  String get serverStopped => 'Stopped';

  @override
  String get serverNoModelWarning =>
      'No model is loaded — API requests will return 503 until you load one on the Models tab.';

  @override
  String get serverAddresses => 'Addresses';

  @override
  String get serverQrHint => 'Scan from another device to get the base URL';

  @override
  String get serverAuthRequire => 'Require bearer token';

  @override
  String get serverAuthHint =>
      'Clients must send Authorization: Bearer <token>';

  @override
  String get serverAccessToken => 'Access token';

  @override
  String get serverStatRequests => 'Requests';

  @override
  String get serverStatErrors => 'Errors';

  @override
  String get serverStatTokens => 'Tokens';

  @override
  String get serverStatSpeed => 'Avg speed';

  @override
  String get serverStatUptime => 'Uptime';

  @override
  String get serverRecentRequests => 'Recent requests';

  @override
  String get serverNoRequestsYet =>
      'No requests yet. Point any OpenAI-compatible client at this phone.';

  @override
  String get serverKeepAwakeNote =>
      'The screen stays awake while the server is running.';

  @override
  String get serverEndpointsTitle => 'Endpoints';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsGeneration => 'Generation';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => 'Max tokens';

  @override
  String get settingsThreads => 'Threads';

  @override
  String settingsThreadsAuto(int count) {
    return 'Auto ($count)';
  }

  @override
  String get settingsThreadsHint =>
      'Auto sizes the pool to the big-core cluster the engine pins its workers to; more threads than that only add wait time. Applied on next model load.';

  @override
  String get settingsUseGpu => 'Use GPU (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint =>
      'Enable discrete GPU execution graph (applies on next model load).';

  @override
  String get settingsUseGpuNeedsBackend =>
      'Needs a runtime built with the Vulkan/Metal backend — see native/TUNING.md.';

  @override
  String get settingsDisableThinking => 'Disable thinking';

  @override
  String get settingsDisableThinkingHint =>
      'Reasoning models (Qwen3/3.5) answer directly, with no <think> step';

  @override
  String get settingsEngineSection => 'Engine';

  @override
  String get settingsEngineFlags => 'Engine flags (advanced)';

  @override
  String get settingsEngineFlagsHint =>
      'One CMF_KEY=value per line, pushed to the runtime on model load. Empty = engine defaults.';

  @override
  String get settingsServerSection => 'Server';

  @override
  String get settingsServerPort => 'Port';

  @override
  String get settingsServerPortHint => 'Applied on next server start';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => 'Access token';

  @override
  String get settingsHfTokenHint => 'hf_… (needed for gated models)';

  @override
  String get settingsStorage => 'Storage';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$size in $count models';
  }

  @override
  String get settingsAbout => 'About';

  @override
  String settingsAboutLine(String engine) {
    return 'CMF protocol v2 · engine: $engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'CMF Mobile $version';
  }
}
