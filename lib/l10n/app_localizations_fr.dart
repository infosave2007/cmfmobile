// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Cortiq';

  @override
  String get navChat => 'Chat';

  @override
  String get navModels => 'Modèles';

  @override
  String get navServer => 'Serveur';

  @override
  String get navSettings => 'Réglages';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionCopy => 'Copier';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionLoad => 'Charger';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get chatEmptyTitle => 'Démarrez une conversation';

  @override
  String get chatEmptyBody =>
      'Tout s\'exécute localement sur cet appareil — pas de cloud, aucune donnée ne quitte votre téléphone.';

  @override
  String get chatNoModelTitle => 'Aucun modèle chargé';

  @override
  String get chatNoModelBody =>
      'Téléchargez un modèle depuis Hugging Face ou importez un fichier .cmf, puis chargez-le dans le moteur.';

  @override
  String get chatGoToModels => 'Ouvrir les modèles';

  @override
  String get chatInputHint => 'Message…';

  @override
  String get chatAttachDocument => 'Joindre un document';

  @override
  String get chatAttachmentsNotSupported =>
      'Ce modèle ne prend pas en charge les documents joints.';

  @override
  String chatAttachmentTooLarge(String limit) {
    return 'Fichier trop volumineux — jusqu\'à $limit de texte pris en charge.';
  }

  @override
  String get chatAttachmentUnreadable =>
      'Impossible de lire ce fichier comme du texte.';

  @override
  String get chatStop => 'Arrêter';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatRegenerate => 'Régénérer';

  @override
  String get chatSessions => 'Conversations';

  @override
  String get chatNewChat => 'Nouvelle conversation';

  @override
  String get chatRename => 'Renommer';

  @override
  String get chatRenameTitle => 'Renommer la conversation';

  @override
  String get chatDeleteChat => 'Supprimer la conversation';

  @override
  String get chatDeleteChatConfirm =>
      'Supprimer cette conversation et son historique ?';

  @override
  String get chatUntitled => 'Nouvelle conversation';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return '$prompt tokens de prompt · $completion de réponse';
  }

  @override
  String get chatModelPickerTitle => 'Modèle';

  @override
  String get chatModelLoading => 'Chargement du modèle…';

  @override
  String engineLoadFailed(String error) {
    return 'Échec du chargement du modèle : $error';
  }

  @override
  String get chatDemoBadge => 'moteur démo';

  @override
  String get chatDemoBanner =>
      'Le runtime natif cortiq n\'est pas inclus dans cette build — les réponses sont simulées. Voir native/README.md.';

  @override
  String get chatGenerationError => 'Échec de la génération';

  @override
  String get chatSuggestion1 =>
      'Explique le fonctionnement des masques de tâches CMF';

  @override
  String get chatSuggestion2 => 'Résume le document joint';

  @override
  String get chatSuggestion3 =>
      'Écris une requête SQL pour le chiffre d\'affaires mensuel';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps tok/s';
  }

  @override
  String get statsFinishLength => 'tronqué à la limite de tokens';

  @override
  String get modelsTitle => 'Modèles';

  @override
  String get modelsEmptyTitle => 'Aucun modèle pour l\'instant';

  @override
  String get modelsEmptyBody =>
      'Téléchargez un modèle depuis Hugging Face ou importez un fichier .cmf depuis cet appareil.';

  @override
  String get modelsImportFile => 'Importer un .cmf';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => 'chargé';

  @override
  String get modelsLoadIntoEngine => 'Charger dans le moteur';

  @override
  String get modelsUnload => 'Décharger';

  @override
  String get modelsUnloadHint => 'Libère la mémoire du modèle';

  @override
  String get modelsDeleteTitle => 'Supprimer le modèle';

  @override
  String modelsDeleteConfirm(String name) {
    return 'Supprimer « $name » de cet appareil ?';
  }

  @override
  String get modelsInvalidFile => 'Fichier CMF illisible';

  @override
  String modelsImportedSnack(String name) {
    return '$name importé';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n couches';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n ctx';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n tâches';
  }

  @override
  String get modelsAttachmentsOk => 'documents';

  @override
  String modelsMetaRam(String size) {
    return '~$size RAM';
  }

  @override
  String get memoryWarnTitle => 'Risque de mémoire insuffisante';

  @override
  String memoryWarnBody(String need, String total) {
    return 'Ce modèle nécessite environ $need de RAM, mais seulement $total sont utilisables actuellement. Le chargement peut échouer, être très lent, ou le système peut fermer l’application pendant la génération.';
  }

  @override
  String get memoryWarnLoadAnyway => 'Charger quand même';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle =>
      'Recherchez sur Hugging Face, convertissez en .cmf local et exécutez-le sur ce téléphone.';

  @override
  String get importSearchPlaceholder =>
      'Rechercher des modèles (ex. qwen3, llama)…';

  @override
  String get importFeaturedTitle => 'Recommandés';

  @override
  String get importReadyCmfBadge => 'CMF PRÊT';

  @override
  String get importNoResults => 'Aucun modèle trouvé.';

  @override
  String get importGatedBadge => 'accès restreint';

  @override
  String get importGatedHint =>
      'Dépôt à accès restreint : obtenez l’accès sur Hugging Face, puis ajoutez votre jeton dans les réglages.';

  @override
  String get importConfigureTitle => 'Configurer la conversion';

  @override
  String get importOutputName => 'Nom de sortie';

  @override
  String get importOutputNameHint => 'Lettres, chiffres, - et _';

  @override
  String get importQuantization => 'Quantification';

  @override
  String get importStartConvert => 'Convertir et télécharger';

  @override
  String get importStartedSnack => 'Conversion lancée';

  @override
  String get importJobsTitle => 'Conversions';

  @override
  String get importNoJobs => 'Aucune conversion pour l\'instant.';

  @override
  String get importKeepAwakeNote =>
      'L\'écran reste allumé tant qu\'une conversion est en cours.';

  @override
  String get importDeleteConfirm =>
      'Supprimer cette conversion et son fichier .cmf du stockage ?';

  @override
  String get importShowLog => 'Afficher le journal';

  @override
  String get importOnDeviceNote =>
      'La conversion sur l’appareil prend en charge Q8_ROW, Q8_2F, Q1T, Q1 et F16 (multithread). Les dépôts fournissant des .cmf sont téléchargés directement — quelle que soit la quantification.';

  @override
  String get quantDesktopOnly => 'bureau / .cmf uniquement';

  @override
  String get importStateRunning => 'en cours';

  @override
  String get importStateDone => 'terminé';

  @override
  String get importStateError => 'erreur';

  @override
  String get importStateCancelled => 'annulé';

  @override
  String get importPhaseListing => 'listage des fichiers';

  @override
  String get importPhaseDownloading => 'téléchargement';

  @override
  String get importPhaseConverting => 'conversion';

  @override
  String get importPhaseQuantizing => 'quantification';

  @override
  String get importPhaseFinalizing => 'finalisation';

  @override
  String get quantQ8_2fDesc =>
      '8 bits à deux champs (𝒲×θ) — la quantification la plus fidèle ; ~2× la taille de Q4TP.';

  @override
  String get quantQ8RowDesc =>
      '8 bits par ligne — simple et robuste. Conversion sur l\'appareil.';

  @override
  String get quantQ1tDesc =>
      'Ternaire ~2,25–3 bits avec overlay d’aberrations f16 — sous q4, sans entraînement. Fichier utile le plus petit, plus grande perte de qualité. Conversion sur l’appareil.';

  @override
  String get quantQ4Desc =>
      'Blocs 4 bits — le plus compact, qualité moindre. Nécessite un dépôt .cmf ou la toolchain de bureau.';

  @override
  String get quantVbitDesc =>
      '3–8 bits variables — budgets par expert. Nécessite un dépôt .cmf ou la toolchain de bureau.';

  @override
  String get quantQ1Desc =>
      '1,5 bit — pour les modèles entraînés en 1 bit (Bonsai, BitNet). Un modèle 27B tient dans ~5 Go. Conversion sur l\'appareil.';

  @override
  String get quantF16Desc =>
      '16 bits — sans quantification, fichier volumineux. Conversion sur l\'appareil.';

  @override
  String get serverTitle => 'Serveur';

  @override
  String get serverSubtitle =>
      'Partagez le modèle chargé sur le réseau : API de discussion ou de décision, selon le modèle.';

  @override
  String get serverStart => 'Démarrer le serveur';

  @override
  String get serverStop => 'Arrêter le serveur';

  @override
  String get serverStarting => 'Démarrage…';

  @override
  String get serverRunning => 'En marche';

  @override
  String get serverStopped => 'Arrêté';

  @override
  String get serverNoModelWarning =>
      'Aucun modèle chargé — les requêtes API renverront 503 tant que vous n\'en aurez pas chargé un dans l\'onglet Modèles.';

  @override
  String get serverAddresses => 'Adresses';

  @override
  String get serverQrHint =>
      'Scannez depuis un autre appareil pour obtenir l\'URL de base';

  @override
  String get serverAuthRequire => 'Exiger un token bearer';

  @override
  String get serverAuthHint =>
      'Les clients doivent envoyer Authorization: Bearer <token>';

  @override
  String get serverAccessToken => 'Token d\'accès';

  @override
  String get serverStatRequests => 'Requêtes';

  @override
  String get serverStatErrors => 'Erreurs';

  @override
  String get serverStatTokens => 'Tokens';

  @override
  String get serverStatSpeed => 'Vitesse moy.';

  @override
  String get serverStatUptime => 'Uptime';

  @override
  String get serverRecentRequests => 'Requêtes récentes';

  @override
  String get serverNoRequestsYet =>
      'Aucune requête pour l’instant. Connectez un client aux points d’accès ci-dessous.';

  @override
  String get serverKeepAwakeNote =>
      'L\'écran reste allumé tant que le serveur est en marche.';

  @override
  String get serverEndpointsTitle => 'Endpoints';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsGeneration => 'Génération';

  @override
  String get settingsTemperature => 'Température';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => 'Tokens max';

  @override
  String get settingsThreads => 'Threads CPU';

  @override
  String settingsThreadsAuto(int count) {
    return 'Auto ($count)';
  }

  @override
  String get settingsThreadsHint =>
      '« Auto » dimensionne le pool sur le cluster de gros cœurs auquel le moteur épingle ses workers ; au-delà, les threads n\'ajoutent que de l\'attente. Appliqué au prochain chargement du modèle.';

  @override
  String get settingsUseGpu => 'Utiliser le GPU (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint =>
      'Utilisez le GPU de l’appareil pour les modèles de discussion (au prochain chargement). Le premier lancement peut prendre plusieurs minutes pour compiler et mettre en cache les shaders. Sur téléphone, CMF Decision utilise actuellement le CPU.';

  @override
  String get settingsUseGpuNeedsBackend =>
      'Nécessite un moteur compilé avec le backend Vulkan/Metal — voir native/TUNING.md.';

  @override
  String get settingsDisableThinking => 'Désactiver la réflexion';

  @override
  String get settingsDisableThinkingHint =>
      'Les modèles de raisonnement (Qwen3/3.5) répondent directement, sans étape <think>';

  @override
  String get settingsEngineSection => 'Moteur';

  @override
  String get settingsEngineFlags => 'Options du moteur (avancé)';

  @override
  String get settingsEngineFlagsHint =>
      'Un CMF_KEY=value par ligne, transmis au moteur au chargement. Vide = valeurs par défaut.';

  @override
  String get settingsServerSection => 'Serveur';

  @override
  String get settingsServerPort => 'Port';

  @override
  String get settingsServerPortHint =>
      'Appliqué au prochain démarrage du serveur';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => 'Token d\'accès';

  @override
  String get settingsHfTokenHint => 'hf_… (pour les modèles à accès restreint)';

  @override
  String get settingsStorage => 'Stockage';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$size dans $count modèles';
  }

  @override
  String get settingsAbout => 'À propos';

  @override
  String settingsAboutLine(String engine) {
    return 'Protocole CMF v2 · moteur : $engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'Cortiq $version';
  }

  @override
  String get navCompanion => 'Split';

  @override
  String get companionTitle => 'Compagnon';

  @override
  String get companionSubtitle =>
      'Associez cet appareil à un ordinateur. Un partage ne rend pas un modèle plus rapide — un jeton parcourt les couches dans l\'ordre — il rend possible un modèle qui ne tiendrait pas ici.';

  @override
  String get companionUnsupported =>
      'Le moteur de cette version ne sait pas partager les couches ; il faut cortiq 0.5.70 ou plus récent.';

  @override
  String get companionWhereTitle => 'Où ça calcule';

  @override
  String get companionRoleLocal => 'Ici';

  @override
  String get companionRoleLocalHint => 'Tout s\'exécute sur cet appareil.';

  @override
  String get companionRoleDesktop => 'Sur l\'ordinateur';

  @override
  String get companionRoleDesktopHint =>
      'L\'ordinateur détient les couches, la tête et l\'échantillonneur ; cet appareil garde le tokeniseur et affiche la réponse. Pour un modèle qui ne tient pas ici.';

  @override
  String get companionRoleWorkerHint =>
      'Prêtez la mémoire de cet appareil à un ordinateur : une partie des couches du modèle est calculée ici. Utile seulement quand le modèle ne tient pas sur l\'ordinateur seul.';

  @override
  String get companionAddress => 'Adresse de l\'ordinateur';

  @override
  String get companionToken => 'Jeton partagé';

  @override
  String get companionTokenHint =>
      'La même chaîne sur les deux appareils. Obligatoire sauf en boucle locale.';

  @override
  String get companionOverCable => 'Câble';

  @override
  String get companionOverWifi => 'Wi-Fi';

  @override
  String get companionWifiWarning =>
      'En Wi-Fi, il y a un aller-retour par jeton, et c\'est la traîne que voit l\'utilisateur : environ 9 ms en typique mais 95 ms au 99e centile, contre 2,9 ms sur câble. Préférez le partage par USB — ou calculez ici.';

  @override
  String get companionCheck => 'Vérifier';

  @override
  String get companionCheckOk => 'Le pair a répondu.';

  @override
  String get companionNeedsModel =>
      'Chargez d\'abord le modèle : le tokeniseur et le gabarit de conversation sont lus dans le fichier local, même quand l\'ordinateur calcule.';

  @override
  String get companionServeTitle => 'Fournir des couches';

  @override
  String get companionWorkerPort => 'Port';

  @override
  String get companionWorkerStart => 'Commencer à fournir';

  @override
  String companionWorkerListening(String address) {
    return 'À l\'écoute sur $address';
  }

  @override
  String get companionWorkerOneWay =>
      'Le moteur n\'offre aucun appel pour arrêter l\'écoute : elle dure jusqu\'à la fermeture de l\'application.';

  @override
  String get companionStatsTitle => 'Le pair en ce moment';

  @override
  String get companionStatClock => 'Fréquence CPU';

  @override
  String get companionStatTemp => 'Température';

  @override
  String get companionStatMemory => 'Mémoire libre';

  @override
  String get companionStatThreads => 'Fils de travail';

  @override
  String get companionStatPlatform => 'Plateforme';

  @override
  String get companionStatUnknown => 'non communiqué';

  @override
  String get companionClockWarning =>
      'Le pair tourne bien en dessous de sa plage de fréquences. Un worker qui calcule brièvement puis attend sur la socket ne convainc jamais le gouverneur d\'accélérer — mesuré à environ la moitié du débit.';

  @override
  String get companionSameModel =>
      'Les deux appareils doivent détenir le même fichier .cmf. La poignée de main le compare et rejette un fichier étranger : un écart échoue franchement au lieu de produire n\'importe quoi.';

  @override
  String get companionWireNote =>
      'Les deux côtés doivent utiliser la même version du moteur. La poignée de main compare la version du protocole et le signale en cas d\'écart.';

  @override
  String get companionTokenClearText =>
      'Le jeton circule en clair. Utilisez un câble ou un réseau de confiance.';

  @override
  String get companionErrorAddress =>
      'L\'adresse doit être host:port, par exemple 192.168.1.5:9911.';

  @override
  String get companionPeerUnreachable =>
      'L\'ordinateur ne répond pas — arrêté, ou le câble ou le réseau a disparu.';

  @override
  String get companionPeerWireVersion =>
      'L\'ordinateur utilise une autre version du moteur. Les deux côtés doivent être mis à jour.';

  @override
  String get companionPeerModelMismatch =>
      'L\'ordinateur détient un autre fichier de modèle. Les deux côtés ont besoin du même .cmf.';

  @override
  String get companionPeerFailed =>
      'L\'ordinateur n\'a pas pu terminer la réponse.';

  @override
  String companionStatusActive(String address) {
    return 'Calcule sur $address';
  }

  @override
  String companionStatusUnchecked(String address) {
    return 'Défini sur $address, pas encore vérifié';
  }

  @override
  String get companionStatusBroken => 'Ordinateur indisponible';

  @override
  String get companionDisconnect => 'Déconnecter';

  @override
  String get chatComputeHere => 'Calculer ici';

  @override
  String get quantQ4tpDesc =>
      'Recommandé : tuiles 4 bits sur une échelle par ligne — le meilleur rapport qualité/taille, le même format que produisent les outils de bureau.';

  @override
  String get quantQ2tpDesc =>
      'Profil MoE 2/4 bits : experts gate/up en 2 bits, le reste en q4tp. Sur un modèle dense, c\'est du q4tp pur.';

  @override
  String get importCheckingRepo => 'Vérification du contenu du dépôt…';

  @override
  String get importReadyCmfTitle => 'CMF prêt — pas de conversion';

  @override
  String get importReadyCmfBody =>
      'Ce dépôt contient un fichier .cmf prêt. Il se télécharge tel quel, avec sa quantification d\'origine.';

  @override
  String get importDownloadButton => 'Télécharger';

  @override
  String importDownloadSize(String size) {
    return 'Téléchargement : $size';
  }

  @override
  String importEstimatedOutput(String size) {
    return '≈ $size';
  }

  @override
  String get importEstimateNote =>
      'Les tailles de sortie sont des estimations : embeddings et normes restent en f16 dans tous les profils.';

  @override
  String get importTooBigBadge => 'dépasse la RAM de l\'appareil';

  @override
  String get importTabReady => 'Prêts';

  @override
  String get importTabConvert => 'Depuis HF';

  @override
  String get decisionTitle => 'Décisions';

  @override
  String get decisionSubtitle =>
      'Choisissez une compétence, décrivez la demande : une décision, pas un texte généré.';

  @override
  String get decisionSkill => 'Compétence';

  @override
  String get decisionInput => 'Demande';

  @override
  String get decisionExample => 'Utiliser un exemple';

  @override
  String get decisionPolicy => 'Politique de décision';

  @override
  String get decisionBalanced => 'Équilibrée';

  @override
  String get decisionCareful => 'S’abstenir en cas de doute';

  @override
  String get decisionBestEffort => 'Accepter l’incertitude';

  @override
  String get decisionRun => 'Décider';

  @override
  String get decisionAccepted => 'Décision acceptée';

  @override
  String get decisionAbstained => 'Confiance insuffisante';

  @override
  String get decisionAbstainBody =>
      'Aucune décision fiable. Précisez la demande ou changez de compétence.';

  @override
  String get decisionConfidence => 'Score de confiance';

  @override
  String get decisionTotal => 'Temps total';

  @override
  String get decisionResonance => 'Temps de résonance';

  @override
  String get decisionExplain => 'Pourquoi cette décision ?';

  @override
  String get decisionErrorHelp =>
      'Une erreur de reconstruction plus faible indique une meilleure correspondance. La confiance n’est pas une précision mesurée.';

  @override
  String get decisionCopy => 'Copier le JSON';

  @override
  String get decisionOffline =>
      'Les décisions locales restent sur le téléphone. Seule une requête d’oracle confirmée envoie le texte au fournisseur. Importez vos compétences comme CMF Decision créé avec Cortiq 0.8+.';

  @override
  String get oracleTitle => 'Oracle';

  @override
  String get oracleDescription =>
      'API compatible OpenAI facultative pour les décisions locales incertaines. Chaque requête nécessite votre confirmation.';

  @override
  String get oracleEnabled => 'Activer l’oracle manuel';

  @override
  String get oracleModel => 'ID du modèle';

  @override
  String get oracleKeyHelp =>
      'La clé reste dans le stockage chiffré et n’est pas transmise via l’API du téléphone.';

  @override
  String get oracleSave => 'Enregistrer';

  @override
  String get oracleDelete => 'Supprimer la clé et réinitialiser';

  @override
  String get oracleAsk => 'Interroger l’oracle';

  @override
  String get oracleConfirm =>
      'Envoyer la demande et les critères au fournisseur ? Des frais d’API peuvent s’appliquer.';

  @override
  String get oracleAnswer => 'Réponse de l’oracle';

  @override
  String get oracleNotTraining =>
      'Réponse externe, pas une décision locale. Aucun réentraînement du modèle.';

  @override
  String get oracleManual =>
      'Désactivé par défaut · confirmation à chaque requête';

  @override
  String get modelKindDecision => 'Décisions';

  @override
  String get modelKindChat => 'Chat';

  @override
  String get modelDecisionHelp =>
      'Choisit une option ou s’abstient. Ne rédige pas de réponses.';

  @override
  String get modelChatHelp => 'Génère du texte et répond aux messages.';

  @override
  String get modelOpenDecisions => 'Ouvrir les décisions';

  @override
  String get skillBanking => 'Demandes bancaires';

  @override
  String get skillAssistant => 'Requêtes à l’assistant';

  @override
  String get skillCommands => 'Commandes de l’appareil';

  @override
  String get oracleApiUrl => 'URL de base de l’API';

  @override
  String get oracleApiKey => 'Clé API';

  @override
  String get oracleStorageError =>
      'Le stockage sécurisé est indisponible. Réessayez.';

  @override
  String get oracleUrlError =>
      'Utilisez une URL de base HTTPS sans identifiants, paramètres ni fragment.';

  @override
  String get oracleModelError =>
      'Saisissez un ID de modèle de 200 caractères maximum.';

  @override
  String get oracleKeyError => 'Saisissez une clé API sans espaces.';

  @override
  String get oracleRequestError =>
      'Impossible d’obtenir une réponse de l’oracle. Vérifiez la connexion et les réglages de l’API.';

  @override
  String oracleHttpError(int status) {
    return 'Le fournisseur a renvoyé HTTP $status. Vérifiez la clé API, l’ID du modèle et le solde.';
  }

  @override
  String get oracleInvalidResponse =>
      'La réponse de l’oracle ne correspond pas aux résultats autorisés par la compétence et a été rejetée.';

  @override
  String get decisionFailed =>
      'Impossible d’obtenir une décision locale. Vérifiez qu’un modèle CMF Decision et une compétence sont chargés.';

  @override
  String get modelKindSkill => 'Extension';

  @override
  String get modelSkillHelp =>
      'Une extension pour un modèle de chat de base, pas un modèle autonome. Elle ne s’ouvre pas comme un chat ou un modèle de décision.';
}
