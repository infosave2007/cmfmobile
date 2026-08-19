// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Cortiq';

  @override
  String get navChat => 'Chat';

  @override
  String get navModels => 'Modelle';

  @override
  String get navServer => 'Server';

  @override
  String get navSettings => 'Optionen';

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
    return 'Dieses Modell benötigt etwa $need RAM, aktuell sind aber nur rund $total nutzbar. Das Laden kann fehlschlagen, sehr langsam laufen, oder das System beendet die App während der Generierung.';
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
  String get importFeaturedTitle => 'Empfohlen';

  @override
  String get importReadyCmfBadge => 'CMF FERTIG';

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
  String get importKeepAwakeNote =>
      'Der Bildschirm bleibt an, solange eine Konvertierung läuft.';

  @override
  String get importDeleteConfirm =>
      'Diese Konvertierung und ihre .cmf-Datei vom Speicher löschen?';

  @override
  String get importShowLog => 'Log anzeigen';

  @override
  String get importOnDeviceNote =>
      'Auf dem Gerät werden Q8_ROW, Q8_2F, Q1T, Q1 und F16 unterstützt (mehrthreadig). Repos mit fertigen .cmf-Dateien werden direkt geladen — in jeder Quantisierung.';

  @override
  String get quantDesktopOnly => 'nur Desktop / .cmf';

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
      '8-Bit-Zweifeld (𝒲×θ) — die genaueste Quantisierung; ~2× so groß wie Q4TP.';

  @override
  String get quantQ8RowDesc =>
      '8 Bit pro Zeile — einfach und robust. Konvertiert auf dem Gerät.';

  @override
  String get quantQ1tDesc =>
      'Ternär ~2,25–3 Bit mit f16-Ausreißer-Overlay — unter q4, ohne Training. Kleinste nutzbare Datei, größter Qualitätsverlust. Konvertiert auf dem Gerät.';

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
  String settingsThreadsAuto(int count) {
    return 'Automatisch ($count)';
  }

  @override
  String get settingsThreadsHint =>
      '„Automatisch“ richtet den Pool nach dem Big-Core-Cluster aus, an den die Engine ihre Worker bindet; mehr Threads erzeugen nur Wartezeit. Wird beim nächsten Laden des Modells angewendet.';

  @override
  String get settingsUseGpu => 'GPU verwenden (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint =>
      'Diskrete GPU aktivieren (gilt ab dem nächsten Laden des Modells). Die erste GPU-Antwort kompiliert die Shader des Treibers — das kann einmalig mehrere Minuten dauern; das Ergebnis wird zwischengespeichert.';

  @override
  String get settingsUseGpuNeedsBackend =>
      'Erfordert eine Laufzeit mit Vulkan-/Metal-Backend — siehe native/TUNING.md.';

  @override
  String get settingsDisableThinking => 'Denken deaktivieren';

  @override
  String get settingsDisableThinkingHint =>
      'Reasoning-Modelle (Qwen3/3.5) antworten direkt, ohne <think>-Schritt';

  @override
  String get settingsEngineSection => 'Engine';

  @override
  String get settingsEngineFlags => 'Engine-Flags (für Fortgeschrittene)';

  @override
  String get settingsEngineFlagsHint =>
      'Ein CMF_SCHLÜSSEL=Wert pro Zeile, beim Laden des Modells an die Laufzeit übergeben. Leer = Standardwerte.';

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
    return 'Cortiq $version';
  }

  @override
  String get navCompanion => 'Split';

  @override
  String get companionTitle => 'Begleiter';

  @override
  String get companionSubtitle =>
      'Verbinden Sie dieses Gerät mit einem Desktop. Ein Split macht ein Modell nicht schneller — ein Token durchläuft die Schichten der Reihe nach —, sondern ermöglicht ein Modell, das hier nicht hineinpasst.';

  @override
  String get companionUnsupported =>
      'Die Laufzeit dieses Builds beherrscht kein Splitting; nötig ist cortiq 0.5.70 oder neuer.';

  @override
  String get companionWhereTitle => 'Wo gerechnet wird';

  @override
  String get companionRoleLocal => 'Hier';

  @override
  String get companionRoleLocalHint => 'Alles läuft auf diesem Gerät.';

  @override
  String get companionRoleDesktop => 'Auf dem Desktop';

  @override
  String get companionRoleDesktopHint =>
      'Der Desktop hält die Schichten, den Kopf und den Sampler; dieses Gerät behält den Tokenizer und zeichnet die Antwort. Für ein Modell, das hier nicht hineinpasst.';

  @override
  String get companionRoleWorkerHint =>
      'Leihen Sie einem Desktop den Speicher dieses Geräts: Ein Teil der Modellschichten wird hier gerechnet. Lohnt sich nur, wenn das Modell auf dem Desktop allein nicht hineinpasst.';

  @override
  String get companionAddress => 'Desktop-Adresse';

  @override
  String get companionToken => 'Gemeinsames Token';

  @override
  String get companionTokenHint =>
      'Dieselbe Zeichenkette auf beiden Geräten. Außer bei Loopback erforderlich.';

  @override
  String get companionOverCable => 'Kabel';

  @override
  String get companionOverWifi => 'WLAN';

  @override
  String get companionWifiWarning =>
      'Über WLAN fällt pro Token ein Roundtrip an, und der langsame Ausläufer landet direkt vor dem Nutzer: typisch etwa 9 ms, im 99. Perzentil aber 95 ms gegenüber 2,9 ms am Kabel. Besser USB-Tethering — oder hier rechnen.';

  @override
  String get companionCheck => 'Prüfen';

  @override
  String get companionCheckOk => 'Die Gegenstelle hat geantwortet.';

  @override
  String get companionNeedsModel =>
      'Laden Sie zuerst das Modell: Tokenizer und Chat-Vorlage werden aus der lokalen Datei gelesen, auch wenn der Desktop rechnet.';

  @override
  String get companionServeTitle => 'Schichten bereitstellen';

  @override
  String get companionWorkerPort => 'Port';

  @override
  String get companionWorkerStart => 'Bereitstellen starten';

  @override
  String companionWorkerListening(String address) {
    return 'Lauscht auf $address';
  }

  @override
  String get companionWorkerOneWay =>
      'Die Laufzeit bietet keinen Aufruf, den Listener zu stoppen — er läuft, bis die App geschlossen wird.';

  @override
  String get companionStatsTitle => 'Die Gegenstelle jetzt';

  @override
  String get companionStatClock => 'CPU-Takt';

  @override
  String get companionStatTemp => 'Temperatur';

  @override
  String get companionStatMemory => 'Freier Speicher';

  @override
  String get companionStatThreads => 'Worker-Threads';

  @override
  String get companionStatPlatform => 'Plattform';

  @override
  String get companionStatUnknown => 'nicht gemeldet';

  @override
  String get companionClockWarning =>
      'Die Gegenstelle läuft deutlich unter ihrem Taktbereich. Ein Worker, der kurz rechnet und dann am Socket wartet, überzeugt den Governor nie hochzutakten — gemessen etwa die halbe Durchsatzrate.';

  @override
  String get companionSameModel =>
      'Auf beiden Geräten muss dieselbe .cmf-Datei liegen. Der Handshake vergleicht sie und weist eine fremde ab, sodass eine Abweichung laut fehlschlägt statt Unsinn zu erzeugen.';

  @override
  String get companionWireNote =>
      'Beide Seiten müssen dieselbe Engine-Version fahren. Der Handshake vergleicht die Protokollversion und sagt es, wenn sie abweicht.';

  @override
  String get companionTokenClearText =>
      'Das Token wird im Klartext übertragen. Nutzen Sie ein Kabel oder ein Netz, dem Sie vertrauen.';

  @override
  String get companionErrorAddress =>
      'Die Adresse muss host:port lauten, zum Beispiel 192.168.1.5:9911.';

  @override
  String get companionPeerUnreachable =>
      'Der Desktop antwortet nicht — gestoppt, oder Kabel bzw. Netzwerk sind weg.';

  @override
  String get companionPeerWireVersion =>
      'Auf dem Desktop läuft eine andere Engine-Version. Beide Seiten müssen aktualisiert werden.';

  @override
  String get companionPeerModelMismatch =>
      'Der Desktop hält eine andere Modelldatei. Beide Seiten brauchen dieselbe .cmf.';

  @override
  String get companionPeerFailed =>
      'Der Desktop konnte die Antwort nicht abschließen.';

  @override
  String companionStatusActive(String address) {
    return 'Rechnet auf $address';
  }

  @override
  String companionStatusUnchecked(String address) {
    return 'Auf $address gesetzt, noch nicht geprüft';
  }

  @override
  String get companionStatusBroken => 'Desktop nicht erreichbar';

  @override
  String get companionDisconnect => 'Trennen';

  @override
  String get chatComputeHere => 'Hier rechnen';

  @override
  String get quantQ4tpDesc =>
      'Empfohlen: 4-Bit-Kacheln auf einer Skalenleiter pro Zeile — bestes Verhältnis von Qualität zu Größe, dasselbe Format wie die Desktop-Werkzeuge.';

  @override
  String get quantQ2tpDesc =>
      '2/4-Bit-MoE-Profil: Gate/Up-Experten mit 2 Bit, alles andere q4tp. Bei einem dichten Modell schlicht q4tp.';

  @override
  String get importCheckingRepo => 'Prüfe, was das Repo enthält…';

  @override
  String get importReadyCmfTitle => 'Fertiges CMF — keine Konvertierung';

  @override
  String get importReadyCmfBody =>
      'Dieses Repo enthält eine fertige .cmf-Datei. Sie wird unverändert heruntergeladen, mit ihrer ursprünglichen Quantisierung.';

  @override
  String get importDownloadButton => 'Herunterladen';

  @override
  String importDownloadSize(String size) {
    return 'Download: $size';
  }

  @override
  String importEstimatedOutput(String size) {
    return '≈ $size';
  }

  @override
  String get importEstimateNote =>
      'Ausgabegrößen sind Schätzungen: Embeddings und Normen bleiben in jedem Profil f16.';

  @override
  String get importTooBigBadge => 'größer als der Gerätespeicher';

  @override
  String get importTabReady => 'Fertig';

  @override
  String get importTabConvert => 'Aus HF';
}
