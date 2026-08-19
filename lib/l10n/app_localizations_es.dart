// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Cortiq';

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
    return 'Este modelo necesita unos $need de RAM, pero ahora solo hay unos $total utilizables. La carga puede fallar, ir muy lenta o el sistema puede cerrar la app durante la generación.';
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
  String get importFeaturedTitle => 'Recomendados';

  @override
  String get importReadyCmfBadge => 'CMF LISTO';

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
  String get importKeepAwakeNote =>
      'La pantalla permanece encendida mientras hay una conversión en curso.';

  @override
  String get importDeleteConfirm =>
      '¿Eliminar esta conversión y su archivo .cmf del almacenamiento?';

  @override
  String get importShowLog => 'Ver registro';

  @override
  String get importOnDeviceNote =>
      'La conversión en el dispositivo admite Q8_ROW, Q8_2F, Q1T, Q1 y F16 (multihilo). Los repositorios con .cmf listos se descargan directamente — en cualquier cuantización.';

  @override
  String get quantDesktopOnly => 'solo escritorio / .cmf';

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
      '8 bits de dos campos (𝒲×θ): la cuantización más fiel; ~2× el tamaño de Q4TP.';

  @override
  String get quantQ8RowDesc =>
      '8 bits por fila: simple y robusto. Se convierte en el dispositivo.';

  @override
  String get quantQ1tDesc =>
      'Ternario ~2,25–3 bits con superposición de valores atípicos f16 — por debajo de q4, sin entrenamiento. El archivo útil más pequeño, mayor pérdida de calidad. Se convierte en el dispositivo.';

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
  String settingsThreadsAuto(int count) {
    return 'Automático ($count)';
  }

  @override
  String get settingsThreadsHint =>
      '«Automático» ajusta el grupo al clúster de núcleos grandes al que el motor fija sus workers; más hilos solo añaden espera. Se aplica en la próxima carga del modelo.';

  @override
  String get settingsUseGpu => 'Usar GPU (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint =>
      'Activar la GPU discreta (se aplica en la próxima carga del modelo). La primera respuesta con GPU compila los sombreadores del controlador: puede tardar varios minutos, una sola vez; el resultado se guarda en caché.';

  @override
  String get settingsUseGpuNeedsBackend =>
      'Requiere un motor compilado con el backend Vulkan/Metal: consulta native/TUNING.md.';

  @override
  String get settingsDisableThinking => 'Desactivar pensamiento';

  @override
  String get settingsDisableThinkingHint =>
      'Los modelos de razonamiento (Qwen3/3.5) responden directamente, sin paso <think>';

  @override
  String get settingsEngineSection => 'Motor';

  @override
  String get settingsEngineFlags => 'Opciones del motor (avanzado)';

  @override
  String get settingsEngineFlagsHint =>
      'Un CMF_CLAVE=valor por línea, enviado al motor al cargar el modelo. Vacío = valores por defecto.';

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
    return 'Cortiq $version';
  }

  @override
  String get navCompanion => 'Split';

  @override
  String get companionTitle => 'Compañero';

  @override
  String get companionSubtitle =>
      'Empareja este dispositivo con un escritorio. Repartir las capas no acelera un modelo — un token recorre las capas en orden —, hace posible un modelo que aquí no cabría.';

  @override
  String get companionUnsupported =>
      'El motor de esta versión no puede repartir capas; hace falta cortiq 0.5.70 o posterior.';

  @override
  String get companionWhereTitle => 'Dónde se calcula';

  @override
  String get companionRoleLocal => 'Aquí';

  @override
  String get companionRoleLocalHint => 'Todo se ejecuta en este dispositivo.';

  @override
  String get companionRoleDesktop => 'En el escritorio';

  @override
  String get companionRoleDesktopHint =>
      'El escritorio guarda las capas, la cabeza y el muestreador; este dispositivo conserva el tokenizador y dibuja la respuesta. Para un modelo que aquí no cabe.';

  @override
  String get companionRoleWorkerHint =>
      'Presta la memoria de este dispositivo a un escritorio: aquí se calcula un tramo de las capas del modelo. Solo merece la pena cuando el modelo no cabe en el escritorio por sí solo.';

  @override
  String get companionAddress => 'Dirección del escritorio';

  @override
  String get companionToken => 'Token compartido';

  @override
  String get companionTokenHint =>
      'La misma cadena en ambos dispositivos. Obligatorio salvo en bucle local.';

  @override
  String get companionOverCable => 'Cable';

  @override
  String get companionOverWifi => 'Wi-Fi';

  @override
  String get companionWifiWarning =>
      'Por Wi-Fi hay una ida y vuelta por token, así que la cola lenta es lo que ve el usuario: unos 9 ms típicos pero 95 ms en el percentil 99, frente a 2,9 ms por cable. Mejor anclaje USB — o calcular aquí.';

  @override
  String get companionCheck => 'Comprobar';

  @override
  String get companionCheckOk => 'El par respondió.';

  @override
  String get companionNeedsModel =>
      'Carga primero el modelo: el tokenizador y la plantilla de chat se leen del archivo local aunque calcule el escritorio.';

  @override
  String get companionServeTitle => 'Servir capas';

  @override
  String get companionWorkerPort => 'Puerto';

  @override
  String get companionWorkerStart => 'Empezar a servir';

  @override
  String companionWorkerListening(String address) {
    return 'Escuchando en $address';
  }

  @override
  String get companionWorkerOneWay =>
      'El motor no ofrece ninguna llamada para detener la escucha: dura hasta que se cierra la aplicación.';

  @override
  String get companionStatsTitle => 'El par ahora mismo';

  @override
  String get companionStatClock => 'Frecuencia de CPU';

  @override
  String get companionStatTemp => 'Temperatura';

  @override
  String get companionStatMemory => 'Memoria libre';

  @override
  String get companionStatThreads => 'Hilos de trabajo';

  @override
  String get companionStatPlatform => 'Plataforma';

  @override
  String get companionStatUnknown => 'no informado';

  @override
  String get companionClockWarning =>
      'El par funciona muy por debajo de su rango de frecuencia. Un worker que calcula un instante y luego espera en el socket nunca convence al gobernador de subir la frecuencia: se midió como la mitad del rendimiento.';

  @override
  String get companionSameModel =>
      'Ambos dispositivos deben tener el mismo archivo .cmf. El apretón de manos lo compara y rechaza uno ajeno, de modo que una discrepancia falla de forma visible en lugar de producir disparates.';

  @override
  String get companionWireNote =>
      'Ambos lados deben usar la misma versión del motor. El apretón de manos compara la versión del protocolo y lo indica si difiere.';

  @override
  String get companionTokenClearText =>
      'El token viaja en texto plano. Usa un cable o una red de confianza.';

  @override
  String get companionErrorAddress =>
      'La dirección debe ser host:port, por ejemplo 192.168.1.5:9911.';

  @override
  String get companionPeerUnreachable =>
      'El escritorio no responde: detenido, o el cable o la red han desaparecido.';

  @override
  String get companionPeerWireVersion =>
      'El escritorio usa otra versión del motor. Hay que actualizar ambos lados.';

  @override
  String get companionPeerModelMismatch =>
      'El escritorio tiene otro archivo de modelo. Ambos lados necesitan el mismo .cmf.';

  @override
  String get companionPeerFailed =>
      'El escritorio no pudo terminar la respuesta.';

  @override
  String companionStatusActive(String address) {
    return 'Calculando en $address';
  }

  @override
  String companionStatusUnchecked(String address) {
    return 'Fijado en $address, sin comprobar';
  }

  @override
  String get companionStatusBroken => 'Escritorio no disponible';

  @override
  String get companionDisconnect => 'Desconectar';

  @override
  String get chatComputeHere => 'Calcular aquí';

  @override
  String get quantQ4tpDesc =>
      'Recomendado: mosaicos de 4 bits en una escalera por fila — el mejor punto calidad/tamaño, el mismo formato que producen las herramientas de escritorio.';

  @override
  String get quantQ2tpDesc =>
      'Perfil MoE 2/4 bits: expertos gate/up a 2 bits, el resto q4tp. En un modelo denso es q4tp puro.';

  @override
  String get importCheckingRepo => 'Comprobando qué contiene el repositorio…';

  @override
  String get importReadyCmfTitle => 'CMF listo — sin conversión';

  @override
  String get importReadyCmfBody =>
      'Este repositorio incluye un archivo .cmf listo. Se descarga tal cual, con la cuantización con la que se creó.';

  @override
  String get importDownloadButton => 'Descargar';

  @override
  String importDownloadSize(String size) {
    return 'Descarga: $size';
  }

  @override
  String importEstimatedOutput(String size) {
    return '≈ $size';
  }

  @override
  String get importEstimateNote =>
      'Los tamaños de salida son estimaciones: los embeddings y las normas permanecen en f16 en todos los perfiles.';

  @override
  String get importTooBigBadge => 'supera la RAM del dispositivo';

  @override
  String get importTabReady => 'Listos';

  @override
  String get importTabConvert => 'De HF';
}
