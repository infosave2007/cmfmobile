// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'CMF Mobile';

  @override
  String get navChat => 'Chat';

  @override
  String get navModels => 'Modelle';

  @override
  String get navServer => 'Server';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionCopy => 'Kopieren';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionRetry => 'Wiederholen';

  @override
  String get actionLoad => 'Laden';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get chatEmptyTitle => 'Starte eine Unterhaltung';

  @override
  String get chatEmptyBody =>
      'Alles läuft lokal auf diesem Gerät — keine Cloud, keine Daten verlassen dein Telefon.';

  @override
  String get chatNoModelTitle => 'Kein Modell geladen';

  @override
  String get chatNoModelBody =>
      'Lade ein Modell von Hugging Face herunter oder importiere eine .cmf-Datei und lade sie dann in die Engine.';

  @override
  String get chatGoToModels => 'Modelle öffnen';

  @override
  String get chatInputHint => 'Nachricht…';

  @override
  String get chatAttachDocument => 'Dokument anhängen';

  @override
  String get chatAttachmentsNotSupported =>
      'Dieses Modell unterstützt keine Dokumentanhänge.';

  @override
  String chatAttachmentTooLarge(String limit) {
    return 'Datei ist zu groß — unterstützt werden bis zu $limit Text.';
  }

  @override
  String get chatAttachmentUnreadable =>
      'Datei konnte nicht als Text gelesen werden.';

  @override
  String get chatStop => 'Stopp';

  @override
  String get chatSend => 'Senden';

  @override
  String get chatRegenerate => 'Neu generieren';

  @override
  String get chatSessions => 'Chats';

  @override
  String get chatNewChat => 'Neuer Chat';

  @override
  String get chatRename => 'Umbenennen';

  @override
  String get chatRenameTitle => 'Chat umbenennen';

  @override
  String get chatDeleteChat => 'Chat löschen';

  @override
  String get chatDeleteChatConfirm => 'Diesen Chat und seinen Verlauf löschen?';

  @override
  String get chatUntitled => 'Neuer Chat';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return '$prompt Prompt- · $completion Antwort-Token';
  }

  @override
  String get chatModelPickerTitle => 'Modell';

  @override
  String get chatModelLoading => 'Modell wird geladen…';

  @override
  String engineLoadFailed(String error) {
    return 'Modell konnte nicht geladen werden: $error';
  }

  @override
  String get chatDemoBadge => 'Demo-Engine';

  @override
  String get chatDemoBanner =>
      'Die native cortiq-Runtime ist in diesem Build nicht enthalten — Antworten werden simuliert. Siehe native/README.md.';

  @override
  String get chatGenerationError => 'Generierung fehlgeschlagen';

  @override
  String get chatSuggestion1 => 'Erkläre, wie CMF-Task-Masken funktionieren';

  @override
  String get chatSuggestion2 => 'Fasse das angehängte Dokument zusammen';

  @override
  String get chatSuggestion3 =>
      'Schreibe eine SQL-Abfrage für den Monatsumsatz';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps Tok/s';
  }

  @override
  String get statsFinishLength => 'bei max. Token abgeschnitten';

  @override
  String get modelsTitle => 'Modelle';

  @override
  String get modelsEmptyTitle => 'Noch keine Modelle';

  @override
  String get modelsEmptyBody =>
      'Lade ein Modell von Hugging Face herunter oder importiere eine .cmf-Datei von diesem Gerät.';

  @override
  String get modelsImportFile => '.cmf importieren';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => 'geladen';

  @override
  String get modelsLoadIntoEngine => 'In Engine laden';

  @override
  String get modelsUnload => 'Entladen';

  @override
  String get modelsUnloadHint => 'Gibt Speicher frei und schont den Akku';

  @override
  String get modelsDeleteTitle => 'Modell löschen';

  @override
  String modelsDeleteConfirm(String name) {
    return '„$name“ von diesem Gerät löschen?';
  }

  @override
  String get modelsInvalidFile => 'CMF-Datei nicht lesbar';

  @override
  String modelsImportedSnack(String name) {
    return '$name importiert';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n Layer';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n Kontext';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n Tasks';
  }

  @override
  String get modelsAttachmentsOk => 'Dokumente';

  @override
  String modelsMetaRam(String size) {
    return '~$size RAM';
  }

  @override
  String get memoryWarnTitle => 'Passt möglicherweise nicht in den Speicher';

  @override
  String memoryWarnBody(String need, String total) {
    return 'Dieses Modell benötigt etwa $need RAM. Dieses Gerät hat $total RAM, wovon Apps realistisch nur einen Teil nutzen können — das Laden kann fehlschlagen oder sehr langsam sein.';
  }

  @override
  String get memoryWarnLoadAnyway => 'Trotzdem laden';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle =>
      'Durchsuche Hugging Face, konvertiere in eine lokale .cmf-Datei und führe sie auf diesem Telefon aus.';

  @override
  String get importSearchPlaceholder => 'Modelle suchen (z. B. qwen3, llama)…';

  @override
  String get importNoResults => 'Keine Modelle gefunden.';

  @override
  String get importGatedBadge => 'gated';

  @override
  String get importGatedHint =>
      'Gated-Repo — hinterlege einen Hugging-Face-Token in den Einstellungen.';

  @override
  String get importConfigureTitle => 'Konvertierung konfigurieren';

  @override
  String get importOutputName => 'Ausgabename';

  @override
  String get importOutputNameHint => 'Buchstaben, Ziffern, - und _';

  @override
  String get importQuantization => 'Quantisierung';

  @override
  String get importStartConvert => 'Konvertieren & herunterladen';

  @override
  String get importStartedSnack => 'Konvertierung gestartet';

  @override
  String get importJobsTitle => 'Konvertierungen';

  @override
  String get importNoJobs => 'Noch keine Konvertierungen.';

  @override
  String get importDeleteConfirm =>
      'Diese Konvertierung und ihre .cmf-Datei vom Speicher löschen?';

  @override
  String get importShowLog => 'Log anzeigen';

  @override
  String get importOnDeviceNote =>
      'Auf dem Gerät werden Q8_ROW, Q8_2F, Q1 und F16 unterstützt (mehrthreadig). Repos mit fertigen .cmf-Dateien werden direkt geladen — in jeder Quantisierung.';

  @override
  String get importStateRunning => 'läuft';

  @override
  String get importStateDone => 'fertig';

  @override
  String get importStateError => 'Fehler';

  @override
  String get importStateCancelled => 'abgebrochen';

  @override
  String get importPhaseListing => 'Dateien werden aufgelistet';

  @override
  String get importPhaseDownloading => 'Wird heruntergeladen';

  @override
  String get importPhaseConverting => 'Wird konvertiert';

  @override
  String get importPhaseQuantizing => 'Wird quantisiert';

  @override
  String get importPhaseFinalizing => 'Wird abgeschlossen';

  @override
  String get quantQ8_2fDesc =>
      '8-Bit, zwei Felder (𝒲×θ) — bestes Qualität/Größe-Verhältnis. Konvertiert auf dem Gerät.';

  @override
  String get quantQ8RowDesc =>
      '8 Bit pro Zeile — einfach und robust. Konvertiert auf dem Gerät.';

  @override
  String get quantQ4Desc =>
      '4-Bit-Blöcke — am kleinsten, geringere Qualität. Benötigt ein .cmf-Repo oder die Desktop-Toolchain.';

  @override
  String get quantVbitDesc =>
      'Variabel 3–8 Bit — Budgets pro Experte. Benötigt ein .cmf-Repo oder die Desktop-Toolchain.';

  @override
  String get quantQ1Desc =>
      '1,5 Bit — für 1-Bit-trainierte Modelle (Bonsai, BitNet). Ein 27B-Modell passt in ~5 GB. Konvertiert auf dem Gerät.';

  @override
  String get quantF16Desc =>
      '16 Bit — keine Quantisierung, große Datei. Konvertiert auf dem Gerät.';

  @override
  String get serverTitle => 'Server';

  @override
  String get serverSubtitle =>
      'Stelle das geladene Modell über das CMF-Protokoll im Netzwerk bereit (OpenAI-kompatible API).';

  @override
  String get serverStart => 'Server starten';

  @override
  String get serverStop => 'Server stoppen';

  @override
  String get serverStarting => 'Wird gestartet…';

  @override
  String get serverRunning => 'Läuft';

  @override
  String get serverStopped => 'Gestoppt';

  @override
  String get serverNoModelWarning =>
      'Kein Modell geladen — API-Anfragen erhalten 503, bis du auf dem Tab „Modelle“ eines lädst.';

  @override
  String get serverAddresses => 'Adressen';

  @override
  String get serverQrHint =>
      'Mit einem anderen Gerät scannen, um die Basis-URL zu erhalten';

  @override
  String get serverAuthRequire => 'Bearer-Token erforderlich';

  @override
  String get serverAuthHint =>
      'Clients müssen Authorization: Bearer <Token> senden';

  @override
  String get serverAccessToken => 'Zugriffstoken';

  @override
  String get serverStatRequests => 'Anfragen';

  @override
  String get serverStatErrors => 'Fehler';

  @override
  String get serverStatTokens => 'Token';

  @override
  String get serverStatSpeed => 'Ø Geschwindigkeit';

  @override
  String get serverStatUptime => 'Laufzeit';

  @override
  String get serverRecentRequests => 'Letzte Anfragen';

  @override
  String get serverNoRequestsYet =>
      'Noch keine Anfragen. Verbinde einen beliebigen OpenAI-kompatiblen Client mit diesem Telefon.';

  @override
  String get serverKeepAwakeNote =>
      'Der Bildschirm bleibt an, solange der Server läuft.';

  @override
  String get serverEndpointsTitle => 'Endpunkte';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsGeneration => 'Generierung';

  @override
  String get settingsTemperature => 'Temperatur';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => 'Max. Token';

  @override
  String get settingsThreads => 'CPU-Threads';

  @override
  String get settingsServerSection => 'Server';

  @override
  String get settingsServerPort => 'Port';

  @override
  String get settingsServerPortHint => 'Gilt ab dem nächsten Serverstart';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => 'Zugriffstoken';

  @override
  String get settingsHfTokenHint => 'hf_… (für gated Modelle erforderlich)';

  @override
  String get settingsStorage => 'Speicher';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$size in $count Modellen';
  }

  @override
  String get settingsAbout => 'Über';

  @override
  String settingsAboutLine(String engine) {
    return 'CMF-Protokoll v2 · Engine: $engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'CMF Mobile $version';
  }
}
