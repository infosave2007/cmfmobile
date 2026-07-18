// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'CMF Mobile';

  @override
  String get navChat => 'Chat';

  @override
  String get navModels => 'Modelos';

  @override
  String get navServer => 'Servidor';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionCopy => 'Copiar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionLoad => 'Cargar';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get chatEmptyTitle => 'Inicia una conversación';

  @override
  String get chatEmptyBody =>
      'Todo se ejecuta localmente en este dispositivo: sin nube, ningún dato sale de tu teléfono.';

  @override
  String get chatNoModelTitle => 'Ningún modelo cargado';

  @override
  String get chatNoModelBody =>
      'Descarga un modelo de Hugging Face o importa un archivo .cmf y cárgalo en el motor.';

  @override
  String get chatGoToModels => 'Abrir Modelos';

  @override
  String get chatInputHint => 'Mensaje…';

  @override
  String get chatAttachDocument => 'Adjuntar documento';

  @override
  String get chatAttachmentsNotSupported =>
      'Este modelo no admite documentos adjuntos.';

  @override
  String chatAttachmentTooLarge(String limit) {
    return 'El archivo es demasiado grande: se admite hasta $limit de texto.';
  }

  @override
  String get chatAttachmentUnreadable =>
      'No se pudo leer este archivo como texto.';

  @override
  String get chatStop => 'Detener';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatRegenerate => 'Regenerar';

  @override
  String get chatSessions => 'Chats';

  @override
  String get chatNewChat => 'Nuevo chat';

  @override
  String get chatRename => 'Renombrar';

  @override
  String get chatRenameTitle => 'Renombrar chat';

  @override
  String get chatDeleteChat => 'Eliminar chat';

  @override
  String get chatDeleteChatConfirm => '¿Eliminar este chat y su historial?';

  @override
  String get chatUntitled => 'Nuevo chat';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return '$prompt tokens de prompt · $completion de respuesta';
  }

  @override
  String get chatModelPickerTitle => 'Modelo';

  @override
  String get chatModelLoading => 'Cargando modelo…';

  @override
  String engineLoadFailed(String error) {
    return 'No se pudo cargar el modelo: $error';
  }

  @override
  String get chatDemoBadge => 'motor demo';

  @override
  String get chatDemoBanner =>
      'El runtime nativo cortiq no está incluido en esta compilación: las respuestas son simuladas. Consulta native/README.md.';

  @override
  String get chatGenerationError => 'Error de generación';

  @override
  String get chatSuggestion1 =>
      'Explica cómo funcionan las máscaras de tareas de CMF';

  @override
  String get chatSuggestion2 => 'Resume el documento adjunto';

  @override
  String get chatSuggestion3 =>
      'Escribe una consulta SQL de ingresos mensuales';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps tok/s';
  }

  @override
  String get statsFinishLength => 'cortado al límite de tokens';

  @override
  String get modelsTitle => 'Modelos';

  @override
  String get modelsEmptyTitle => 'Aún no hay modelos';

  @override
  String get modelsEmptyBody =>
      'Descarga un modelo de Hugging Face o importa un archivo .cmf desde este dispositivo.';

  @override
  String get modelsImportFile => 'Importar .cmf';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => 'cargado';

  @override
  String get modelsLoadIntoEngine => 'Cargar en el motor';

  @override
  String get modelsUnload => 'Expulsar';

  @override
  String get modelsUnloadHint => 'Libera memoria y ahorra batería';

  @override
  String get modelsDeleteTitle => 'Eliminar modelo';

  @override
  String modelsDeleteConfirm(String name) {
    return '¿Eliminar «$name» de este dispositivo?';
  }

  @override
  String get modelsInvalidFile => 'Archivo CMF ilegible';

  @override
  String modelsImportedSnack(String name) {
    return '$name importado';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n capas';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n ctx';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n tareas';
  }

  @override
  String get modelsAttachmentsOk => 'documentos';

  @override
  String modelsMetaRam(String size) {
    return '~$size RAM';
  }

  @override
  String get memoryWarnTitle => 'Puede que no quepa en memoria';

  @override
  String memoryWarnBody(String need, String total) {
    return 'Este modelo necesita alrededor de $need de RAM para funcionar. Este dispositivo tiene $total de RAM, de la que las apps solo pueden usar una parte: la carga puede fallar o ser muy lenta.';
  }

  @override
  String get memoryWarnLoadAnyway => 'Cargar de todos modos';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle =>
      'Busca en Hugging Face, convierte a un .cmf local y ejecútalo en este teléfono.';

  @override
  String get importSearchPlaceholder => 'Buscar modelos (p. ej. qwen3, llama)…';

  @override
  String get importNoResults => 'No se encontraron modelos.';

  @override
  String get importGatedBadge => 'gated';

  @override
  String get importGatedHint =>
      'Repositorio gated: configura un token de Hugging Face en Ajustes.';

  @override
  String get importConfigureTitle => 'Configurar conversión';

  @override
  String get importOutputName => 'Nombre de salida';

  @override
  String get importOutputNameHint => 'Letras, dígitos, - y _';

  @override
  String get importQuantization => 'Cuantización';

  @override
  String get importStartConvert => 'Convertir y descargar';

  @override
  String get importStartedSnack => 'Conversión iniciada';

  @override
  String get importJobsTitle => 'Conversiones';

  @override
  String get importNoJobs => 'Aún no hay conversiones.';

  @override
  String get importDeleteConfirm =>
      '¿Eliminar esta conversión y su archivo .cmf del almacenamiento?';

  @override
  String get importShowLog => 'Ver registro';

  @override
  String get importOnDeviceNote =>
      'La conversión en el dispositivo admite Q8_ROW, Q8_2F, Q1 y F16 (multihilo). Los repositorios con .cmf listos se descargan directamente — en cualquier cuantización.';

  @override
  String get importStateRunning => 'en curso';

  @override
  String get importStateDone => 'completado';

  @override
  String get importStateError => 'error';

  @override
  String get importStateCancelled => 'cancelado';

  @override
  String get importPhaseListing => 'listando archivos';

  @override
  String get importPhaseDownloading => 'descargando';

  @override
  String get importPhaseConverting => 'convirtiendo';

  @override
  String get importPhaseQuantizing => 'cuantizando';

  @override
  String get importPhaseFinalizing => 'finalizando';

  @override
  String get quantQ8_2fDesc =>
      '8 bits, dos campos (𝒲×θ) — mejor calidad/tamaño. Se convierte en el dispositivo.';

  @override
  String get quantQ8RowDesc =>
      '8 bits por fila: simple y robusto. Se convierte en el dispositivo.';

  @override
  String get quantQ4Desc =>
      'Bloques de 4 bits: el más pequeño, menor calidad. Requiere un repo .cmf o la toolchain de escritorio.';

  @override
  String get quantVbitDesc =>
      '3–8 bits variables: presupuestos por experto. Requiere un repo .cmf o la toolchain de escritorio.';

  @override
  String get quantQ1Desc =>
      '1,5 bits: para modelos entrenados en 1 bit (Bonsai, BitNet). Un modelo 27B cabe en ~5 GB. Se convierte en el dispositivo.';

  @override
  String get quantF16Desc =>
      '16 bits: sin cuantización, archivo grande. Se convierte en el dispositivo.';

  @override
  String get serverTitle => 'Servidor';

  @override
  String get serverSubtitle =>
      'Sirve el modelo cargado a tu red mediante el protocolo CMF (API compatible con OpenAI).';

  @override
  String get serverStart => 'Iniciar servidor';

  @override
  String get serverStop => 'Detener servidor';

  @override
  String get serverStarting => 'Iniciando…';

  @override
  String get serverRunning => 'En ejecución';

  @override
  String get serverStopped => 'Detenido';

  @override
  String get serverNoModelWarning =>
      'No hay ningún modelo cargado: las peticiones a la API devolverán 503 hasta que cargues uno en la pestaña Modelos.';

  @override
  String get serverAddresses => 'Direcciones';

  @override
  String get serverQrHint =>
      'Escanéalo desde otro dispositivo para obtener la URL base';

  @override
  String get serverAuthRequire => 'Requerir token bearer';

  @override
  String get serverAuthHint =>
      'Los clientes deben enviar Authorization: Bearer <token>';

  @override
  String get serverAccessToken => 'Token de acceso';

  @override
  String get serverStatRequests => 'Peticiones';

  @override
  String get serverStatErrors => 'Errores';

  @override
  String get serverStatTokens => 'Tokens';

  @override
  String get serverStatSpeed => 'Velocidad media';

  @override
  String get serverStatUptime => 'Tiempo activo';

  @override
  String get serverRecentRequests => 'Peticiones recientes';

  @override
  String get serverNoRequestsYet =>
      'Aún no hay peticiones. Apunta cualquier cliente compatible con OpenAI a este teléfono.';

  @override
  String get serverKeepAwakeNote =>
      'La pantalla permanece encendida mientras el servidor está en marcha.';

  @override
  String get serverEndpointsTitle => 'Endpoints';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Sistema';

  @override
  String get settingsGeneration => 'Generación';

  @override
  String get settingsTemperature => 'Temperatura';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => 'Tokens máx.';

  @override
  String get settingsThreads => 'Hilos de CPU';

  @override
  String get settingsServerSection => 'Servidor';

  @override
  String get settingsServerPort => 'Puerto';

  @override
  String get settingsServerPortHint =>
      'Se aplica en el próximo inicio del servidor';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => 'Token de acceso';

  @override
  String get settingsHfTokenHint => 'hf_… (necesario para modelos gated)';

  @override
  String get settingsStorage => 'Almacenamiento';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$size en $count modelos';
  }

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String settingsAboutLine(String engine) {
    return 'Protocolo CMF v2 · motor: $engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'CMF Mobile $version';
  }
}
