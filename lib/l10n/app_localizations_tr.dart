// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Cortiq';

  @override
  String get navChat => 'Sohbet';

  @override
  String get navModels => 'Modeller';

  @override
  String get navServer => 'Sunucu';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionDelete => 'Sil';

  @override
  String get actionClose => 'Kapat';

  @override
  String get actionCopy => 'Kopyala';

  @override
  String get actionSave => 'Kaydet';

  @override
  String get actionRetry => 'Yeniden dene';

  @override
  String get actionLoad => 'Yükle';

  @override
  String get copiedToClipboard => 'Panoya kopyalandı';

  @override
  String get chatEmptyTitle => 'Bir sohbet başlatın';

  @override
  String get chatEmptyBody =>
      'Her şey bu cihazda yerel olarak çalışır — bulut yok, veriler telefonunuzdan çıkmaz.';

  @override
  String get chatNoModelTitle => 'Yüklü model yok';

  @override
  String get chatNoModelBody =>
      'Hugging Face\'ten bir model indirin veya bir .cmf dosyası içe aktarın, ardından motora yükleyin.';

  @override
  String get chatGoToModels => 'Modeller\'i aç';

  @override
  String get chatInputHint => 'Mesaj…';

  @override
  String get chatAttachDocument => 'Belge ekle';

  @override
  String get chatAttachmentsNotSupported =>
      'Bu model belge eklerini desteklemiyor.';

  @override
  String chatAttachmentTooLarge(String limit) {
    return 'Dosya çok büyük — en fazla $limit metin destekleniyor.';
  }

  @override
  String get chatAttachmentUnreadable => 'Bu dosya metin olarak okunamadı.';

  @override
  String get chatStop => 'Durdur';

  @override
  String get chatSend => 'Gönder';

  @override
  String get chatRegenerate => 'Yeniden oluştur';

  @override
  String get chatSessions => 'Sohbetler';

  @override
  String get chatNewChat => 'Yeni sohbet';

  @override
  String get chatRename => 'Yeniden adlandır';

  @override
  String get chatRenameTitle => 'Sohbeti yeniden adlandır';

  @override
  String get chatDeleteChat => 'Sohbeti sil';

  @override
  String get chatDeleteChatConfirm => 'Bu sohbet ve geçmişi silinsin mi?';

  @override
  String get chatUntitled => 'Yeni sohbet';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return '$prompt istem · $completion yanıt tokenı';
  }

  @override
  String get chatModelPickerTitle => 'Model';

  @override
  String get chatModelLoading => 'Model yükleniyor…';

  @override
  String engineLoadFailed(String error) {
    return 'Model yüklenemedi: $error';
  }

  @override
  String get chatDemoBadge => 'demo motor';

  @override
  String get chatDemoBanner =>
      'Yerel cortiq çalışma zamanı bu derlemede yok — yanıtlar simüle ediliyor. Bkz. native/README.md.';

  @override
  String get chatGenerationError => 'Oluşturma başarısız';

  @override
  String get chatSuggestion1 =>
      'CMF görev maskelerinin nasıl çalıştığını açıkla';

  @override
  String get chatSuggestion2 => 'Ekli belgeyi özetle';

  @override
  String get chatSuggestion3 => 'Aylık gelir için bir SQL sorgusu yaz';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps tok/sn';
  }

  @override
  String get statsFinishLength => 'maksimum token sınırında kesildi';

  @override
  String get modelsTitle => 'Modeller';

  @override
  String get modelsEmptyTitle => 'Henüz model yok';

  @override
  String get modelsEmptyBody =>
      'Hugging Face\'ten bir model indirin veya bu cihazdan bir .cmf dosyası içe aktarın.';

  @override
  String get modelsImportFile => '.cmf içe aktar';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => 'yüklü';

  @override
  String get modelsLoadIntoEngine => 'Motora yükle';

  @override
  String get modelsUnload => 'Bellekten çıkar';

  @override
  String get modelsUnloadHint => 'Belleği boşaltır, pil tasarrufu sağlar';

  @override
  String get modelsDeleteTitle => 'Modeli sil';

  @override
  String modelsDeleteConfirm(String name) {
    return '\"$name\" bu cihazdan silinsin mi?';
  }

  @override
  String get modelsInvalidFile => 'Okunamayan CMF dosyası';

  @override
  String modelsImportedSnack(String name) {
    return '$name içe aktarıldı';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n katman';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n bağlam';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n görev';
  }

  @override
  String get modelsAttachmentsOk => 'belgeler';

  @override
  String modelsMetaRam(String size) {
    return '~$size RAM';
  }

  @override
  String get memoryWarnTitle => 'Belleğe sığmayabilir';

  @override
  String memoryWarnBody(String need, String total) {
    return 'Bu modelin çalışması için yaklaşık $need RAM gerekir, ancak şu anda yalnızca $total kullanılabilir. Yükleme başarısız olabilir, çok yavaş çalışabilir veya sistem üretim sırasında uygulamayı kapatabilir.';
  }

  @override
  String get memoryWarnLoadAnyway => 'Yine de yükle';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle =>
      'Hugging Face\'te arayın, yerel bir .cmf dosyasına dönüştürün ve bu telefonda çalıştırın.';

  @override
  String get importSearchPlaceholder => 'Model ara (örn. qwen3, llama)…';

  @override
  String get importFeaturedTitle => 'Önerilenler';

  @override
  String get importReadyCmfBadge => 'HAZIR CMF';

  @override
  String get importNoResults => 'Model bulunamadı.';

  @override
  String get importGatedBadge => 'gated';

  @override
  String get importGatedHint =>
      'Gated depo — Ayarlar\'da bir Hugging Face tokenı girin.';

  @override
  String get importConfigureTitle => 'Dönüştürmeyi yapılandır';

  @override
  String get importOutputName => 'Çıktı adı';

  @override
  String get importOutputNameHint => 'Harf, rakam, - ve _';

  @override
  String get importQuantization => 'Kuantizasyon';

  @override
  String get importStartConvert => 'Dönüştür ve indir';

  @override
  String get importStartedSnack => 'Dönüştürme başlatıldı';

  @override
  String get importJobsTitle => 'Dönüştürmeler';

  @override
  String get importNoJobs => 'Henüz dönüştürme yok.';

  @override
  String get importDeleteConfirm =>
      'Bu dönüştürme ve .cmf dosyası diskten silinsin mi?';

  @override
  String get importShowLog => 'Günlüğü göster';

  @override
  String get importOnDeviceNote =>
      'Cihaz üzerinde dönüştürme Q8_ROW, Q8_2F, Q1T, Q1 ve F16 destekler (çok iş parçacıklı). Hazır .cmf içeren depolar doğrudan indirilir — her nicemlemede.';

  @override
  String get quantDesktopOnly => 'yalnızca masaüstü / .cmf';

  @override
  String get importStateRunning => 'çalışıyor';

  @override
  String get importStateDone => 'tamamlandı';

  @override
  String get importStateError => 'hata';

  @override
  String get importStateCancelled => 'iptal edildi';

  @override
  String get importPhaseListing => 'dosyalar listeleniyor';

  @override
  String get importPhaseDownloading => 'indiriliyor';

  @override
  String get importPhaseConverting => 'dönüştürülüyor';

  @override
  String get importPhaseQuantizing => 'kuantize ediliyor';

  @override
  String get importPhaseFinalizing => 'tamamlanıyor';

  @override
  String get quantQ8_2fDesc =>
      '8 bit çift alan (𝒲×θ) — en yüksek doğruluklu nicemleme; Q4TP\'nin ~2 katı boyut.';

  @override
  String get quantQ8RowDesc =>
      'Satır başına 8 bit — basit ve sağlam. Cihazda dönüştürülür.';

  @override
  String get quantQ1tDesc =>
      'Üçlü ~2,25–3 bit, f16 aykırı değer katmanıyla — q4 altında, eğitimsiz. En küçük kullanılabilir dosya, en büyük kalite kaybı. Cihazda dönüştürülür.';

  @override
  String get quantQ4Desc =>
      '4 bit blok — en küçük boyut, daha düşük kalite. Bir .cmf deposu veya masaüstü araç zinciri gerektirir.';

  @override
  String get quantVbitDesc =>
      'Değişken 3–8 bit — uzman başına bütçe. Bir .cmf deposu veya masaüstü araç zinciri gerektirir.';

  @override
  String get quantQ1Desc =>
      '1,5 bit — 1 bit eğitilmiş modeller için (Bonsai, BitNet). 27B bir model ~5 GB\'a sığar. Cihazda dönüştürülür.';

  @override
  String get quantF16Desc =>
      '16 bit — kuantizasyon yok, büyük dosya. Cihazda dönüştürülür.';

  @override
  String get serverTitle => 'Sunucu';

  @override
  String get serverSubtitle =>
      'Yüklü modeli CMF protokolüyle (OpenAI uyumlu API) ağınıza sunun.';

  @override
  String get serverStart => 'Sunucuyu başlat';

  @override
  String get serverStop => 'Sunucuyu durdur';

  @override
  String get serverStarting => 'Başlatılıyor…';

  @override
  String get serverRunning => 'Çalışıyor';

  @override
  String get serverStopped => 'Durduruldu';

  @override
  String get serverNoModelWarning =>
      'Yüklü model yok — Modeller sekmesinden bir model yükleyene kadar API istekleri 503 döndürecek.';

  @override
  String get serverAddresses => 'Adresler';

  @override
  String get serverQrHint =>
      'Temel URL\'yi almak için başka bir cihazdan tarayın';

  @override
  String get serverAuthRequire => 'Bearer token iste';

  @override
  String get serverAuthHint =>
      'İstemciler Authorization: Bearer <token> göndermeli';

  @override
  String get serverAccessToken => 'Erişim tokenı';

  @override
  String get serverStatRequests => 'İstekler';

  @override
  String get serverStatErrors => 'Hatalar';

  @override
  String get serverStatTokens => 'Token';

  @override
  String get serverStatSpeed => 'Ort. hız';

  @override
  String get serverStatUptime => 'Çalışma süresi';

  @override
  String get serverRecentRequests => 'Son istekler';

  @override
  String get serverNoRequestsYet =>
      'Henüz istek yok. OpenAI uyumlu herhangi bir istemciyi bu telefona yönlendirin.';

  @override
  String get serverKeepAwakeNote => 'Sunucu çalışırken ekran açık kalır.';

  @override
  String get serverEndpointsTitle => 'Uç noktalar';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsAppearance => 'Görünüm';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeLight => 'Açık';

  @override
  String get settingsThemeDark => 'Koyu';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsLanguageSystem => 'Sistem';

  @override
  String get settingsGeneration => 'Üretim';

  @override
  String get settingsTemperature => 'Sıcaklık';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => 'Maks. token';

  @override
  String get settingsThreads => 'CPU iş parçacığı';

  @override
  String settingsThreadsAuto(int count) {
    return 'Otomatik ($count)';
  }

  @override
  String get settingsThreadsHint =>
      '“Otomatik”, havuzu motorun iş parçacıklarını sabitlediği büyük çekirdek kümesine göre boyutlandırır; fazlası yalnızca bekleme ekler. Bir sonraki model yüklemesinde uygulanır.';

  @override
  String get settingsUseGpu => 'GPU kullan (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint =>
      'Ayrık GPU\'yu etkinleştir (bir sonraki model yüklemesinde geçerli olur). Cihazdaki ilk GPU yanıtı sürücünün gölgelendiricilerini derler — bu bir kereliğine birkaç dakika sürebilir; sonuç önbelleğe alınır.';

  @override
  String get settingsUseGpuNeedsBackend =>
      'Vulkan/Metal arka ucuyla derlenmiş bir çalışma zamanı gerektirir — bkz. native/TUNING.md.';

  @override
  String get settingsDisableThinking => 'Düşünmeyi devre dışı bırak';

  @override
  String get settingsDisableThinkingHint =>
      'Akıl yürüten modeller (Qwen3/3.5) <think> adımı olmadan doğrudan yanıt verir';

  @override
  String get settingsEngineSection => 'Motor';

  @override
  String get settingsEngineFlags => 'Motor bayrakları (gelişmiş)';

  @override
  String get settingsEngineFlagsHint =>
      'Her satırda bir CMF_ANAHTAR=değer, model yüklenirken çalışma zamanına aktarılır. Boş = varsayılanlar.';

  @override
  String get settingsServerSection => 'Sunucu';

  @override
  String get settingsServerPort => 'Port';

  @override
  String get settingsServerPortHint =>
      'Bir sonraki sunucu başlatmada uygulanır';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => 'Erişim tokenı';

  @override
  String get settingsHfTokenHint => 'hf_… (gated modeller için gerekli)';

  @override
  String get settingsStorage => 'Depolama';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$count modelde $size';
  }

  @override
  String get settingsAbout => 'Hakkında';

  @override
  String settingsAboutLine(String engine) {
    return 'CMF protokolü v2 · motor: $engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'Cortiq $version';
  }

  @override
  String get navCompanion => 'Bölme';

  @override
  String get companionTitle => 'Eşlik';

  @override
  String get companionSubtitle =>
      'Bu cihazı bir masaüstüyle eşleştirin. Katmanları bölmek modeli hızlandırmaz — bir jeton katmanları sırayla dolaşır — buraya sığmayacak bir modeli mümkün kılar.';

  @override
  String get companionUnsupported =>
      'Bu sürümün çalışma zamanı bölmeyi desteklemiyor; cortiq 0.5.70 veya üstü gerekiyor.';

  @override
  String get companionWhereTitle => 'Nerede hesaplanıyor';

  @override
  String get companionRoleLocal => 'Burada';

  @override
  String get companionRoleLocalHint => 'Her şey bu cihazda çalışır.';

  @override
  String get companionRoleDesktop => 'Masaüstünde';

  @override
  String get companionRoleDesktopHint =>
      'Katmanları, başlığı ve örnekleyiciyi masaüstü tutar; bu cihaz yalnızca sözcükleyiciyi tutar ve yanıtı çizer. Buraya sığmayan bir model için.';

  @override
  String get companionRoleWorkerHint =>
      'Bu cihazın belleğini bir masaüstüne ödünç verin: modelin bir bölüm katmanı burada hesaplanır. Yalnızca model masaüstüne tek başına sığmadığında değer.';

  @override
  String get companionAddress => 'Masaüstü adresi';

  @override
  String get companionToken => 'Ortak belirteç';

  @override
  String get companionTokenHint =>
      'Her iki cihazda aynı dizi. Geri döngü dışındaki adresler için zorunludur.';

  @override
  String get companionOverCable => 'Kablo';

  @override
  String get companionOverWifi => 'Wi-Fi';

  @override
  String get companionWifiWarning =>
      'Wi-Fi üzerinde her jeton için bir gidiş dönüş vardır, dolayısıyla kullanıcının gördüğü şey yavaş kuyruktur: tipik olarak yaklaşık 9 ms, ancak 99. yüzdelikte 95 ms; kabloda ise 2,9 ms. USB bağlantı paylaşımını tercih edin ya da burada hesaplayın.';

  @override
  String get companionCheck => 'Denetle';

  @override
  String get companionCheckOk => 'Karşı taraf yanıt verdi.';

  @override
  String get companionNeedsModel =>
      'Önce modeli yükleyin: hesaplamayı masaüstü yapsa bile sözcükleyici ve sohbet şablonu yerel dosyadan okunur.';

  @override
  String get companionServeTitle => 'Katman sun';

  @override
  String get companionWorkerPort => 'Bağlantı noktası';

  @override
  String get companionWorkerStart => 'Sunmaya başla';

  @override
  String companionWorkerListening(String address) {
    return '$address adresinde dinliyor';
  }

  @override
  String get companionWorkerOneWay =>
      'Çalışma zamanı dinleyiciyi durduracak bir çağrı sunmuyor; uygulama kapanana kadar çalışır.';

  @override
  String get companionStatsTitle => 'Karşı taraf şu anda';

  @override
  String get companionStatClock => 'CPU frekansı';

  @override
  String get companionStatTemp => 'Sıcaklık';

  @override
  String get companionStatMemory => 'Boş bellek';

  @override
  String get companionStatThreads => 'Çalışan iş parçacığı';

  @override
  String get companionStatPlatform => 'Platform';

  @override
  String get companionStatUnknown => 'bildirilmedi';

  @override
  String get companionClockWarning =>
      'Karşı taraf frekans aralığının çok altında çalışıyor. Kısa süre hesaplayıp sonra sokette bekleyen bir işçi, yöneticiyi hızlanmaya asla ikna edemez — ölçümde verimin yaklaşık yarısı.';

  @override
  String get companionSameModel =>
      'Her iki cihazda da aynı .cmf dosyası bulunmalıdır. El sıkışma bunu karşılaştırır ve yabancı bir dosyayı reddeder; böylece uyuşmazlık saçmalık üretmek yerine açıkça hata verir.';

  @override
  String get companionWireNote =>
      'Her iki taraf da aynı motor sürümünü çalıştırmalıdır. El sıkışma protokol sürümünü karşılaştırır ve farklıysa bunu söyler.';

  @override
  String get companionTokenClearText =>
      'Belirteç düz metin olarak iletilir. Kablo ya da güvendiğiniz bir ağ kullanın.';

  @override
  String get companionErrorAddress =>
      'Adres host:port biçiminde olmalıdır, örneğin 192.168.1.5:9911.';

  @override
  String get companionPeerUnreachable =>
      'Masaüstü yanıt vermiyor — durdurulmuş ya da kablo veya ağ kopmuş.';

  @override
  String get companionPeerWireVersion =>
      'Masaüstünde farklı bir motor sürümü çalışıyor. İki tarafın da güncellenmesi gerekir.';

  @override
  String get companionPeerModelMismatch =>
      'Masaüstünde farklı bir model dosyası var. İki tarafta da aynı .cmf gerekir.';

  @override
  String get companionPeerFailed => 'Masaüstü yanıtı tamamlayamadı.';

  @override
  String companionStatusActive(String address) {
    return '$address üzerinde hesaplıyor';
  }

  @override
  String companionStatusUnchecked(String address) {
    return '$address olarak ayarlandı, henüz denetlenmedi';
  }

  @override
  String get companionStatusBroken => 'Masaüstü kullanılamıyor';

  @override
  String get companionDisconnect => 'Bağlantıyı kes';

  @override
  String get chatComputeHere => 'Burada hesapla';

  @override
  String get quantQ4tpDesc =>
      'Önerilen: satır başına ölçek merdiveninde 4 bit döşemeler — en iyi kalite/boyut dengesi; masaüstü araçlarının ürettiği formatın aynısı.';

  @override
  String get quantQ2tpDesc =>
      '2/4 bit MoE profili: gate/up uzmanları 2 bit, geri kalanı q4tp. Yoğun bir modelde düz q4tp olur.';

  @override
  String get importCheckingRepo => 'Depoda ne olduğu denetleniyor…';

  @override
  String get importReadyCmfTitle => 'Hazır CMF — dönüştürme yok';

  @override
  String get importReadyCmfBody =>
      'Bu depo hazır bir .cmf dosyası içeriyor. Olduğu gibi, oluşturulduğu nicemlemeyle indirilir.';

  @override
  String get importDownloadButton => 'İndir';

  @override
  String importDownloadSize(String size) {
    return 'İndirme: $size';
  }

  @override
  String importEstimatedOutput(String size) {
    return '≈ $size';
  }

  @override
  String get importEstimateNote =>
      'Çıktı boyutları tahminidir: gömmeler ve normlar her profilde f16 kalır.';

  @override
  String get importTooBigBadge => 'cihaz belleğinden büyük';

  @override
  String get importTabReady => 'Hazır';

  @override
  String get importTabConvert => 'HF\'den';
}
