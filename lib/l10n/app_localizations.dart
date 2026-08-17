import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Cortiq'**
  String get appTitle;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get navModels;

  /// No description provided for @navServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get navServer;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get actionLoad;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything runs locally on this device — no cloud, no data leaves your phone.'**
  String get chatEmptyBody;

  /// No description provided for @chatNoModelTitle.
  ///
  /// In en, this message translates to:
  /// **'No model loaded'**
  String get chatNoModelTitle;

  /// No description provided for @chatNoModelBody.
  ///
  /// In en, this message translates to:
  /// **'Get a model from Hugging Face or import a .cmf file, then load it into the engine.'**
  String get chatNoModelBody;

  /// No description provided for @chatGoToModels.
  ///
  /// In en, this message translates to:
  /// **'Open Models'**
  String get chatGoToModels;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatInputHint;

  /// No description provided for @chatAttachDocument.
  ///
  /// In en, this message translates to:
  /// **'Attach document'**
  String get chatAttachDocument;

  /// No description provided for @chatAttachmentsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This model cannot take document attachments.'**
  String get chatAttachmentsNotSupported;

  /// No description provided for @chatAttachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large — up to {limit} of text is supported.'**
  String chatAttachmentTooLarge(String limit);

  /// No description provided for @chatAttachmentUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read this file as text.'**
  String get chatAttachmentUnreadable;

  /// No description provided for @chatStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStop;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatRegenerate;

  /// No description provided for @chatSessions.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatSessions;

  /// No description provided for @chatNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNewChat;

  /// No description provided for @chatRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRename;

  /// No description provided for @chatRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename chat'**
  String get chatRenameTitle;

  /// No description provided for @chatDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get chatDeleteChat;

  /// No description provided for @chatDeleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat and its history?'**
  String get chatDeleteChatConfirm;

  /// No description provided for @chatUntitled.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatUntitled;

  /// No description provided for @chatSessionTokens.
  ///
  /// In en, this message translates to:
  /// **'{prompt} prompt · {completion} completion tokens'**
  String chatSessionTokens(String prompt, String completion);

  /// No description provided for @chatModelPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatModelPickerTitle;

  /// No description provided for @chatModelLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading model…'**
  String get chatModelLoading;

  /// No description provided for @engineLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load model: {error}'**
  String engineLoadFailed(String error);

  /// No description provided for @chatDemoBadge.
  ///
  /// In en, this message translates to:
  /// **'demo engine'**
  String get chatDemoBadge;

  /// No description provided for @chatDemoBanner.
  ///
  /// In en, this message translates to:
  /// **'The native cortiq runtime is not bundled in this build — replies are simulated. See native/README.md.'**
  String get chatDemoBanner;

  /// No description provided for @chatGenerationError.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get chatGenerationError;

  /// No description provided for @chatSuggestion1.
  ///
  /// In en, this message translates to:
  /// **'Explain how CMF task masks work'**
  String get chatSuggestion1;

  /// No description provided for @chatSuggestion2.
  ///
  /// In en, this message translates to:
  /// **'Summarize the attached document'**
  String get chatSuggestion2;

  /// No description provided for @chatSuggestion3.
  ///
  /// In en, this message translates to:
  /// **'Write a SQL query for monthly revenue'**
  String get chatSuggestion3;

  /// No description provided for @statsTokensPerSecond.
  ///
  /// In en, this message translates to:
  /// **'{tps} tok/s'**
  String statsTokensPerSecond(String tps);

  /// No description provided for @statsFinishLength.
  ///
  /// In en, this message translates to:
  /// **'cut off at max tokens'**
  String get statsFinishLength;

  /// No description provided for @modelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get modelsTitle;

  /// No description provided for @modelsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No models yet'**
  String get modelsEmptyTitle;

  /// No description provided for @modelsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Download a model from Hugging Face or import a .cmf file from this device.'**
  String get modelsEmptyBody;

  /// No description provided for @modelsImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import .cmf'**
  String get modelsImportFile;

  /// No description provided for @modelsGetFromHf.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face'**
  String get modelsGetFromHf;

  /// No description provided for @modelsLoadedBadge.
  ///
  /// In en, this message translates to:
  /// **'loaded'**
  String get modelsLoadedBadge;

  /// No description provided for @modelsLoadIntoEngine.
  ///
  /// In en, this message translates to:
  /// **'Load into engine'**
  String get modelsLoadIntoEngine;

  /// No description provided for @modelsUnload.
  ///
  /// In en, this message translates to:
  /// **'Unload'**
  String get modelsUnload;

  /// No description provided for @modelsUnloadHint.
  ///
  /// In en, this message translates to:
  /// **'Frees memory and battery'**
  String get modelsUnloadHint;

  /// No description provided for @modelsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get modelsDeleteTitle;

  /// No description provided for @modelsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from this device?'**
  String modelsDeleteConfirm(String name);

  /// No description provided for @modelsInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Unreadable CMF file'**
  String get modelsInvalidFile;

  /// No description provided for @modelsImportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Imported {name}'**
  String modelsImportedSnack(String name);

  /// No description provided for @modelsMetaLayers.
  ///
  /// In en, this message translates to:
  /// **'{n} layers'**
  String modelsMetaLayers(int n);

  /// No description provided for @modelsMetaContext.
  ///
  /// In en, this message translates to:
  /// **'{n} ctx'**
  String modelsMetaContext(String n);

  /// No description provided for @modelsMetaTasks.
  ///
  /// In en, this message translates to:
  /// **'{n} tasks'**
  String modelsMetaTasks(int n);

  /// No description provided for @modelsAttachmentsOk.
  ///
  /// In en, this message translates to:
  /// **'documents'**
  String get modelsAttachmentsOk;

  /// No description provided for @modelsMetaRam.
  ///
  /// In en, this message translates to:
  /// **'~{size} RAM'**
  String modelsMetaRam(String size);

  /// No description provided for @memoryWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Might not fit in memory'**
  String get memoryWarnTitle;

  /// No description provided for @memoryWarnBody.
  ///
  /// In en, this message translates to:
  /// **'This model needs about {need} of RAM to run, but only about {total} is usable right now. Loading may fail, run very slowly, or the system may kill the app mid-generation.'**
  String memoryWarnBody(String need, String total);

  /// No description provided for @memoryWarnLoadAnyway.
  ///
  /// In en, this message translates to:
  /// **'Load anyway'**
  String get memoryWarnLoadAnyway;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face'**
  String get importTitle;

  /// No description provided for @importSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search Hugging Face, convert to a local .cmf, and run it on this phone.'**
  String get importSubtitle;

  /// No description provided for @importSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search models (e.g. qwen3, llama)…'**
  String get importSearchPlaceholder;

  /// No description provided for @importFeaturedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get importFeaturedTitle;

  /// No description provided for @importReadyCmfBadge.
  ///
  /// In en, this message translates to:
  /// **'READY CMF'**
  String get importReadyCmfBadge;

  /// No description provided for @importNoResults.
  ///
  /// In en, this message translates to:
  /// **'No models found.'**
  String get importNoResults;

  /// No description provided for @importGatedBadge.
  ///
  /// In en, this message translates to:
  /// **'gated'**
  String get importGatedBadge;

  /// No description provided for @importGatedHint.
  ///
  /// In en, this message translates to:
  /// **'Gated repo — set a Hugging Face token in Settings.'**
  String get importGatedHint;

  /// No description provided for @importConfigureTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure conversion'**
  String get importConfigureTitle;

  /// No description provided for @importOutputName.
  ///
  /// In en, this message translates to:
  /// **'Output name'**
  String get importOutputName;

  /// No description provided for @importOutputNameHint.
  ///
  /// In en, this message translates to:
  /// **'Letters, digits, - and _'**
  String get importOutputNameHint;

  /// No description provided for @importQuantization.
  ///
  /// In en, this message translates to:
  /// **'Quantization'**
  String get importQuantization;

  /// No description provided for @importStartConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert & download'**
  String get importStartConvert;

  /// No description provided for @importStartedSnack.
  ///
  /// In en, this message translates to:
  /// **'Conversion started'**
  String get importStartedSnack;

  /// No description provided for @importJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversions'**
  String get importJobsTitle;

  /// No description provided for @importNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No conversions yet.'**
  String get importNoJobs;

  /// No description provided for @importDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversion and its .cmf file from disk?'**
  String get importDeleteConfirm;

  /// No description provided for @importShowLog.
  ///
  /// In en, this message translates to:
  /// **'Show log'**
  String get importShowLog;

  /// No description provided for @importOnDeviceNote.
  ///
  /// In en, this message translates to:
  /// **'On-device conversion supports Q8_ROW, Q8_2F, Q1T, Q1 and F16 (multi-threaded). Repos that already ship .cmf files are downloaded directly — any quantization.'**
  String get importOnDeviceNote;

  /// No description provided for @quantDesktopOnly.
  ///
  /// In en, this message translates to:
  /// **'desktop / .cmf only'**
  String get quantDesktopOnly;

  /// No description provided for @importStateRunning.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get importStateRunning;

  /// No description provided for @importStateDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get importStateDone;

  /// No description provided for @importStateError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get importStateError;

  /// No description provided for @importStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get importStateCancelled;

  /// No description provided for @importPhaseListing.
  ///
  /// In en, this message translates to:
  /// **'listing files'**
  String get importPhaseListing;

  /// No description provided for @importPhaseDownloading.
  ///
  /// In en, this message translates to:
  /// **'downloading'**
  String get importPhaseDownloading;

  /// No description provided for @importPhaseConverting.
  ///
  /// In en, this message translates to:
  /// **'converting'**
  String get importPhaseConverting;

  /// No description provided for @importPhaseQuantizing.
  ///
  /// In en, this message translates to:
  /// **'quantizing'**
  String get importPhaseQuantizing;

  /// No description provided for @importPhaseFinalizing.
  ///
  /// In en, this message translates to:
  /// **'finalizing'**
  String get importPhaseFinalizing;

  /// No description provided for @quantQ8_2fDesc.
  ///
  /// In en, this message translates to:
  /// **'8-bit two-field (𝒲×θ) — highest-fidelity quantization; ~2× the size of Q4TP.'**
  String get quantQ8_2fDesc;

  /// No description provided for @quantQ8RowDesc.
  ///
  /// In en, this message translates to:
  /// **'8-bit per-row — simple, robust. Converts on device.'**
  String get quantQ8RowDesc;

  /// No description provided for @quantQ1tDesc.
  ///
  /// In en, this message translates to:
  /// **'Ternary ~2.25–3 bit with an f16 outlier overlay — below q4, training-free. Smallest usable file, largest quality drop. Converts on device.'**
  String get quantQ1tDesc;

  /// No description provided for @quantQ4Desc.
  ///
  /// In en, this message translates to:
  /// **'4-bit block — smallest, lower quality. Needs a .cmf repo or the desktop toolchain.'**
  String get quantQ4Desc;

  /// No description provided for @quantVbitDesc.
  ///
  /// In en, this message translates to:
  /// **'Variable 3–8 bit — per-expert budgets. Needs a .cmf repo or the desktop toolchain.'**
  String get quantVbitDesc;

  /// No description provided for @quantQ1Desc.
  ///
  /// In en, this message translates to:
  /// **'1.5-bit — for 1-bit-trained models (Bonsai, BitNet). A 27B model fits in ~5 GB. Converts on device.'**
  String get quantQ1Desc;

  /// No description provided for @quantF16Desc.
  ///
  /// In en, this message translates to:
  /// **'16-bit — no quantization, large file. Converts on device.'**
  String get quantF16Desc;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverTitle;

  /// No description provided for @serverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Serve the loaded model to your network over the CMF protocol (OpenAI-compatible API).'**
  String get serverSubtitle;

  /// No description provided for @serverStart.
  ///
  /// In en, this message translates to:
  /// **'Start server'**
  String get serverStart;

  /// No description provided for @serverStop.
  ///
  /// In en, this message translates to:
  /// **'Stop server'**
  String get serverStop;

  /// No description provided for @serverStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get serverStarting;

  /// No description provided for @serverRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get serverRunning;

  /// No description provided for @serverStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get serverStopped;

  /// No description provided for @serverNoModelWarning.
  ///
  /// In en, this message translates to:
  /// **'No model is loaded — API requests will return 503 until you load one on the Models tab.'**
  String get serverNoModelWarning;

  /// No description provided for @serverAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get serverAddresses;

  /// No description provided for @serverQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan from another device to get the base URL'**
  String get serverQrHint;

  /// No description provided for @serverAuthRequire.
  ///
  /// In en, this message translates to:
  /// **'Require bearer token'**
  String get serverAuthRequire;

  /// No description provided for @serverAuthHint.
  ///
  /// In en, this message translates to:
  /// **'Clients must send Authorization: Bearer <token>'**
  String get serverAuthHint;

  /// No description provided for @serverAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get serverAccessToken;

  /// No description provided for @serverStatRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get serverStatRequests;

  /// No description provided for @serverStatErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get serverStatErrors;

  /// No description provided for @serverStatTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get serverStatTokens;

  /// No description provided for @serverStatSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get serverStatSpeed;

  /// No description provided for @serverStatUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get serverStatUptime;

  /// No description provided for @serverRecentRequests.
  ///
  /// In en, this message translates to:
  /// **'Recent requests'**
  String get serverRecentRequests;

  /// No description provided for @serverNoRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No requests yet. Point any OpenAI-compatible client at this phone.'**
  String get serverNoRequestsYet;

  /// No description provided for @serverKeepAwakeNote.
  ///
  /// In en, this message translates to:
  /// **'The screen stays awake while the server is running.'**
  String get serverKeepAwakeNote;

  /// No description provided for @serverEndpointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get serverEndpointsTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get settingsGeneration;

  /// No description provided for @settingsTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get settingsTemperature;

  /// No description provided for @settingsTopP.
  ///
  /// In en, this message translates to:
  /// **'Top-p'**
  String get settingsTopP;

  /// No description provided for @settingsMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Max tokens'**
  String get settingsMaxTokens;

  /// No description provided for @settingsThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get settingsThreads;

  /// No description provided for @settingsThreadsAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto ({count})'**
  String settingsThreadsAuto(int count);

  /// No description provided for @settingsThreadsHint.
  ///
  /// In en, this message translates to:
  /// **'Auto sizes the pool to the big-core cluster the engine pins its workers to; more threads than that only add wait time. Applied on next model load.'**
  String get settingsThreadsHint;

  /// No description provided for @settingsUseGpu.
  ///
  /// In en, this message translates to:
  /// **'Use GPU (Vulkan/Metal)'**
  String get settingsUseGpu;

  /// No description provided for @settingsUseGpuHint.
  ///
  /// In en, this message translates to:
  /// **'Enable the discrete GPU (applies at the next model load). The first GPU answer on a device compiles the driver\'s shaders — this can take several minutes, once; the result is cached.'**
  String get settingsUseGpuHint;

  /// No description provided for @settingsUseGpuNeedsBackend.
  ///
  /// In en, this message translates to:
  /// **'Needs a runtime built with the Vulkan/Metal backend — see native/TUNING.md.'**
  String get settingsUseGpuNeedsBackend;

  /// No description provided for @settingsDisableThinking.
  ///
  /// In en, this message translates to:
  /// **'Disable thinking'**
  String get settingsDisableThinking;

  /// No description provided for @settingsDisableThinkingHint.
  ///
  /// In en, this message translates to:
  /// **'Reasoning models (Qwen3/3.5) answer directly, with no <think> step'**
  String get settingsDisableThinkingHint;

  /// No description provided for @settingsEngineSection.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get settingsEngineSection;

  /// No description provided for @settingsEngineFlags.
  ///
  /// In en, this message translates to:
  /// **'Engine flags (advanced)'**
  String get settingsEngineFlags;

  /// No description provided for @settingsEngineFlagsHint.
  ///
  /// In en, this message translates to:
  /// **'One CMF_KEY=value per line, pushed to the runtime on model load. Empty = engine defaults.'**
  String get settingsEngineFlagsHint;

  /// No description provided for @settingsServerSection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServerSection;

  /// No description provided for @settingsServerPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settingsServerPort;

  /// No description provided for @settingsServerPortHint.
  ///
  /// In en, this message translates to:
  /// **'Applied on next server start'**
  String get settingsServerPortHint;

  /// No description provided for @settingsHfSection.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face'**
  String get settingsHfSection;

  /// No description provided for @settingsHfToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get settingsHfToken;

  /// No description provided for @settingsHfTokenHint.
  ///
  /// In en, this message translates to:
  /// **'hf_… (needed for gated models)'**
  String get settingsHfTokenHint;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsStorageUsage.
  ///
  /// In en, this message translates to:
  /// **'{size} in {count} models'**
  String settingsStorageUsage(String size, int count);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutLine.
  ///
  /// In en, this message translates to:
  /// **'CMF protocol v2 · engine: {engine}'**
  String settingsAboutLine(String engine);

  /// No description provided for @settingsVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Cortiq {version}'**
  String settingsVersionLine(String version);

  /// No description provided for @navCompanion.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get navCompanion;

  /// No description provided for @companionTitle.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get companionTitle;

  /// No description provided for @companionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pair this device with a desktop. A split does not make a model faster — a token walks the layers in order — it makes a model possible that would not fit here.'**
  String get companionSubtitle;

  /// No description provided for @companionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This build\'s runtime cannot split; it needs cortiq 0.5.70 or newer.'**
  String get companionUnsupported;

  /// No description provided for @companionWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Where it computes'**
  String get companionWhereTitle;

  /// No description provided for @companionRoleLocal.
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get companionRoleLocal;

  /// No description provided for @companionRoleLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Everything runs on this device.'**
  String get companionRoleLocalHint;

  /// No description provided for @companionRoleDesktop.
  ///
  /// In en, this message translates to:
  /// **'On the desktop'**
  String get companionRoleDesktop;

  /// No description provided for @companionRoleDesktopHint.
  ///
  /// In en, this message translates to:
  /// **'The desktop holds the layers, the head and the sampler; this device keeps the tokenizer and draws the reply. Use it for a model this device cannot hold.'**
  String get companionRoleDesktopHint;

  /// No description provided for @companionRoleWorkerHint.
  ///
  /// In en, this message translates to:
  /// **'Lend this device\'s memory to a desktop: a span of the model\'s layers is computed here. Worth it only when the model does not fit on the desktop alone.'**
  String get companionRoleWorkerHint;

  /// No description provided for @companionAddress.
  ///
  /// In en, this message translates to:
  /// **'Desktop address'**
  String get companionAddress;

  /// No description provided for @companionToken.
  ///
  /// In en, this message translates to:
  /// **'Shared token'**
  String get companionToken;

  /// No description provided for @companionTokenHint.
  ///
  /// In en, this message translates to:
  /// **'The same string on both devices. Required unless the address is loopback.'**
  String get companionTokenHint;

  /// No description provided for @companionOverCable.
  ///
  /// In en, this message translates to:
  /// **'Cable'**
  String get companionOverCable;

  /// No description provided for @companionOverWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get companionOverWifi;

  /// No description provided for @companionWifiWarning.
  ///
  /// In en, this message translates to:
  /// **'Over Wi-Fi there is one round trip per token, so the slow tail lands in front of the user: about 9 ms typical but 95 ms at the 99th percentile, against 2.9 ms on a cable. Prefer USB tethering, or compute here.'**
  String get companionWifiWarning;

  /// No description provided for @companionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get companionCheck;

  /// No description provided for @companionCheckOk.
  ///
  /// In en, this message translates to:
  /// **'The peer answered.'**
  String get companionCheckOk;

  /// No description provided for @companionNeedsModel.
  ///
  /// In en, this message translates to:
  /// **'Load the model first — the tokenizer and chat template are read from the local file even when the desktop does the computing.'**
  String get companionNeedsModel;

  /// No description provided for @companionServeTitle.
  ///
  /// In en, this message translates to:
  /// **'Serve layers'**
  String get companionServeTitle;

  /// No description provided for @companionWorkerPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get companionWorkerPort;

  /// No description provided for @companionWorkerStart.
  ///
  /// In en, this message translates to:
  /// **'Start serving'**
  String get companionWorkerStart;

  /// No description provided for @companionWorkerListening.
  ///
  /// In en, this message translates to:
  /// **'Listening on {address}'**
  String companionWorkerListening(String address);

  /// No description provided for @companionWorkerOneWay.
  ///
  /// In en, this message translates to:
  /// **'The runtime offers no call to stop the listener, so it runs until the app is closed.'**
  String get companionWorkerOneWay;

  /// No description provided for @companionStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'The peer right now'**
  String get companionStatsTitle;

  /// No description provided for @companionStatClock.
  ///
  /// In en, this message translates to:
  /// **'CPU clock'**
  String get companionStatClock;

  /// No description provided for @companionStatTemp.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get companionStatTemp;

  /// No description provided for @companionStatMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory free'**
  String get companionStatMemory;

  /// No description provided for @companionStatThreads.
  ///
  /// In en, this message translates to:
  /// **'Worker threads'**
  String get companionStatThreads;

  /// No description provided for @companionStatPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get companionStatPlatform;

  /// No description provided for @companionStatUnknown.
  ///
  /// In en, this message translates to:
  /// **'not reported'**
  String get companionStatUnknown;

  /// No description provided for @companionClockWarning.
  ///
  /// In en, this message translates to:
  /// **'The peer is running well below its clock range. A worker that computes briefly and then waits on the socket never convinces the governor to speed up, which measured as about half the throughput.'**
  String get companionClockWarning;

  /// No description provided for @companionSameModel.
  ///
  /// In en, this message translates to:
  /// **'Both devices must hold the same .cmf file. The handshake compares it and refuses a stranger, so a mismatch fails loudly instead of producing nonsense.'**
  String get companionSameModel;

  /// No description provided for @companionWireNote.
  ///
  /// In en, this message translates to:
  /// **'Both sides must run the same engine version. The handshake compares the wire version and says so when they differ.'**
  String get companionWireNote;

  /// No description provided for @companionTokenClearText.
  ///
  /// In en, this message translates to:
  /// **'The token travels in clear text. Use a cable, or a network you trust.'**
  String get companionTokenClearText;

  /// No description provided for @companionErrorAddress.
  ///
  /// In en, this message translates to:
  /// **'The address must be host:port, for example 192.168.1.5:9911.'**
  String get companionErrorAddress;

  /// No description provided for @companionPeerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The desktop is not answering — stopped, or the cable or network is gone.'**
  String get companionPeerUnreachable;

  /// No description provided for @companionPeerWireVersion.
  ///
  /// In en, this message translates to:
  /// **'The desktop runs a different engine version. Both sides have to be updated.'**
  String get companionPeerWireVersion;

  /// No description provided for @companionPeerModelMismatch.
  ///
  /// In en, this message translates to:
  /// **'The desktop holds a different model file. Both sides need the same .cmf.'**
  String get companionPeerModelMismatch;

  /// No description provided for @companionPeerFailed.
  ///
  /// In en, this message translates to:
  /// **'The desktop could not finish the reply.'**
  String get companionPeerFailed;

  /// No description provided for @companionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Computing on {address}'**
  String companionStatusActive(String address);

  /// No description provided for @companionStatusUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Set to {address}, not checked yet'**
  String companionStatusUnchecked(String address);

  /// No description provided for @companionStatusBroken.
  ///
  /// In en, this message translates to:
  /// **'Desktop unavailable'**
  String get companionStatusBroken;

  /// No description provided for @companionDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get companionDisconnect;

  /// No description provided for @chatComputeHere.
  ///
  /// In en, this message translates to:
  /// **'Compute here'**
  String get chatComputeHere;

  /// No description provided for @quantQ4tpDesc.
  ///
  /// In en, this message translates to:
  /// **'Recommended: 4-bit tiles on a per-row scale ladder — the best quality/size point, same format the desktop tools produce.'**
  String get quantQ4tpDesc;

  /// No description provided for @quantQ2tpDesc.
  ///
  /// In en, this message translates to:
  /// **'2/4-bit MoE profile: gate/up experts at 2-bit, everything else q4tp. On a dense model this is plain q4tp.'**
  String get quantQ2tpDesc;

  /// No description provided for @importCheckingRepo.
  ///
  /// In en, this message translates to:
  /// **'Checking what the repo ships…'**
  String get importCheckingRepo;

  /// No description provided for @importReadyCmfTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready CMF — no conversion'**
  String get importReadyCmfTitle;

  /// No description provided for @importReadyCmfBody.
  ///
  /// In en, this message translates to:
  /// **'This repo ships a ready .cmf file. It downloads as-is, keeping the quantization it was built with.'**
  String get importReadyCmfBody;

  /// No description provided for @importDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get importDownloadButton;

  /// No description provided for @importDownloadSize.
  ///
  /// In en, this message translates to:
  /// **'Download: {size}'**
  String importDownloadSize(String size);

  /// No description provided for @importEstimatedOutput.
  ///
  /// In en, this message translates to:
  /// **'≈ {size}'**
  String importEstimatedOutput(String size);

  /// No description provided for @importEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Output sizes are estimates: embeddings and norms stay f16 in every profile.'**
  String get importEstimateNote;

  /// No description provided for @importTooBigBadge.
  ///
  /// In en, this message translates to:
  /// **'larger than device RAM'**
  String get importTooBigBadge;

  /// No description provided for @importTabReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get importTabReady;

  /// No description provided for @importTabConvert.
  ///
  /// In en, this message translates to:
  /// **'From HF'**
  String get importTabConvert;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
