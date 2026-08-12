// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Cortiq';

  @override
  String get navChat => '聊天';

  @override
  String get navModels => '模型';

  @override
  String get navServer => '服务器';

  @override
  String get navSettings => '设置';

  @override
  String get actionCancel => '取消';

  @override
  String get actionDelete => '删除';

  @override
  String get actionClose => '关闭';

  @override
  String get actionCopy => '复制';

  @override
  String get actionSave => '保存';

  @override
  String get actionRetry => '重试';

  @override
  String get actionLoad => '加载';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get chatEmptyTitle => '开始对话';

  @override
  String get chatEmptyBody => '一切都在本设备上本地运行——无需云端,数据不会离开手机。';

  @override
  String get chatNoModelTitle => '未加载模型';

  @override
  String get chatNoModelBody => '从 Hugging Face 获取模型或导入 .cmf 文件,然后加载到引擎中。';

  @override
  String get chatGoToModels => '打开模型页';

  @override
  String get chatInputHint => '输入消息…';

  @override
  String get chatAttachDocument => '附加文档';

  @override
  String get chatAttachmentsNotSupported => '该模型不支持文档附件。';

  @override
  String chatAttachmentTooLarge(String limit) {
    return '文件过大——最多支持 $limit 的文本。';
  }

  @override
  String get chatAttachmentUnreadable => '无法将此文件读取为文本。';

  @override
  String get chatStop => '停止';

  @override
  String get chatSend => '发送';

  @override
  String get chatRegenerate => '重新生成';

  @override
  String get chatSessions => '会话';

  @override
  String get chatNewChat => '新对话';

  @override
  String get chatRename => '重命名';

  @override
  String get chatRenameTitle => '重命名对话';

  @override
  String get chatDeleteChat => '删除对话';

  @override
  String get chatDeleteChatConfirm => '删除此对话及其历史记录?';

  @override
  String get chatUntitled => '新对话';

  @override
  String chatSessionTokens(String prompt, String completion) {
    return '提示 $prompt · 生成 $completion token';
  }

  @override
  String get chatModelPickerTitle => '模型';

  @override
  String get chatModelLoading => '正在加载模型…';

  @override
  String engineLoadFailed(String error) {
    return '模型加载失败：$error';
  }

  @override
  String get chatDemoBadge => '演示引擎';

  @override
  String get chatDemoBanner =>
      '此构建未包含原生 cortiq 运行时——回复为模拟内容。详见 native/README.md。';

  @override
  String get chatGenerationError => '生成失败';

  @override
  String get chatSuggestion1 => '解释 CMF 任务掩码的工作原理';

  @override
  String get chatSuggestion2 => '总结所附文档';

  @override
  String get chatSuggestion3 => '写一条按月统计营收的 SQL 查询';

  @override
  String statsTokensPerSecond(String tps) {
    return '$tps tok/s';
  }

  @override
  String get statsFinishLength => '已达最大 token 数被截断';

  @override
  String get modelsTitle => '模型';

  @override
  String get modelsEmptyTitle => '暂无模型';

  @override
  String get modelsEmptyBody => '从 Hugging Face 下载模型,或从本设备导入 .cmf 文件。';

  @override
  String get modelsImportFile => '导入 .cmf';

  @override
  String get modelsGetFromHf => 'Hugging Face';

  @override
  String get modelsLoadedBadge => '已加载';

  @override
  String get modelsLoadIntoEngine => '加载到引擎';

  @override
  String get modelsUnload => '卸载';

  @override
  String get modelsUnloadHint => '释放内存,节省电量';

  @override
  String get modelsDeleteTitle => '删除模型';

  @override
  String modelsDeleteConfirm(String name) {
    return '从本设备删除“$name”?';
  }

  @override
  String get modelsInvalidFile => '无法读取的 CMF 文件';

  @override
  String modelsImportedSnack(String name) {
    return '已导入 $name';
  }

  @override
  String modelsMetaLayers(int n) {
    return '$n 层';
  }

  @override
  String modelsMetaContext(String n) {
    return '$n 上下文';
  }

  @override
  String modelsMetaTasks(int n) {
    return '$n 个任务';
  }

  @override
  String get modelsAttachmentsOk => '文档';

  @override
  String modelsMetaRam(String size) {
    return '约 $size RAM';
  }

  @override
  String get memoryWarnTitle => '内存可能不足';

  @override
  String memoryWarnBody(String need, String total) {
    return '运行此模型约需 $need 内存，但当前仅有约 $total 可用。加载可能失败、运行极慢，或系统可能在生成过程中终止应用。';
  }

  @override
  String get memoryWarnLoadAnyway => '仍要加载';

  @override
  String get importTitle => 'Hugging Face';

  @override
  String get importSubtitle => '搜索 Hugging Face,转换为本地 .cmf,并在这台手机上运行。';

  @override
  String get importSearchPlaceholder => '搜索模型(如 qwen3、llama)…';

  @override
  String get importFeaturedTitle => '推荐';

  @override
  String get importReadyCmfBadge => '现成 .cmf——点按即可下载';

  @override
  String get importNoResults => '未找到模型。';

  @override
  String get importGatedBadge => 'gated';

  @override
  String get importGatedHint => 'gated 仓库——请在设置中填写 Hugging Face token。';

  @override
  String get importConfigureTitle => '配置转换';

  @override
  String get importOutputName => '输出名称';

  @override
  String get importOutputNameHint => '字母、数字、- 和 _';

  @override
  String get importQuantization => '量化';

  @override
  String get importStartConvert => '转换并下载';

  @override
  String get importStartedSnack => '转换已开始';

  @override
  String get importJobsTitle => '转换任务';

  @override
  String get importNoJobs => '暂无转换任务。';

  @override
  String get importDeleteConfirm => '删除此转换任务及其磁盘上的 .cmf 文件?';

  @override
  String get importShowLog => '查看日志';

  @override
  String get importOnDeviceNote =>
      '设备端转换支持 Q8_ROW、Q8_2F、Q1T、Q1 和 F16（多线程）。已包含 .cmf 文件的仓库将直接下载——任何量化格式均可。';

  @override
  String get quantDesktopOnly => '仅桌面 / .cmf';

  @override
  String get importStateRunning => '进行中';

  @override
  String get importStateDone => '已完成';

  @override
  String get importStateError => '出错';

  @override
  String get importStateCancelled => '已取消';

  @override
  String get importPhaseListing => '正在列出文件';

  @override
  String get importPhaseDownloading => '正在下载';

  @override
  String get importPhaseConverting => '正在转换';

  @override
  String get importPhaseQuantizing => '正在量化';

  @override
  String get importPhaseFinalizing => '正在完成';

  @override
  String get quantQ8_2fDesc => '8 位双字段（𝒲×θ）——质量/体积最佳。可在设备端转换。';

  @override
  String get quantQ8RowDesc => '8 位按行量化——简单可靠。可在设备上转换。';

  @override
  String get quantQ1tDesc =>
      '三值 ~2.25–3 位，带 f16 离群值叠加层——低于 q4，免训练。可用文件最小，质量损失最大。可在设备上转换。';

  @override
  String get quantQ4Desc => '4 位分块——体积最小,质量较低。需要 .cmf 仓库或桌面工具链。';

  @override
  String get quantVbitDesc => '3–8 位可变——按专家分配位宽。需要 .cmf 仓库或桌面工具链。';

  @override
  String get quantQ1Desc =>
      '1.5 位——适用于 1 位训练的模型(Bonsai、BitNet)。27B 模型仅需约 5 GB。可在设备上转换。';

  @override
  String get quantF16Desc => '16 位——不量化,文件较大。可在设备上转换。';

  @override
  String get serverTitle => '服务器';

  @override
  String get serverSubtitle => '通过 CMF 协议(兼容 OpenAI 的 API)向局域网提供已加载的模型。';

  @override
  String get serverStart => '启动服务器';

  @override
  String get serverStop => '停止服务器';

  @override
  String get serverStarting => '正在启动…';

  @override
  String get serverRunning => '运行中';

  @override
  String get serverStopped => '已停止';

  @override
  String get serverNoModelWarning => '未加载模型——在“模型”页加载模型之前,API 请求将返回 503。';

  @override
  String get serverAddresses => '地址';

  @override
  String get serverQrHint => '用其他设备扫码获取基础 URL';

  @override
  String get serverAuthRequire => '要求 bearer token';

  @override
  String get serverAuthHint => '客户端须发送 Authorization: Bearer <token>';

  @override
  String get serverAccessToken => '访问 token';

  @override
  String get serverStatRequests => '请求';

  @override
  String get serverStatErrors => '错误';

  @override
  String get serverStatTokens => 'Token 数';

  @override
  String get serverStatSpeed => '平均速度';

  @override
  String get serverStatUptime => '运行时长';

  @override
  String get serverRecentRequests => '最近请求';

  @override
  String get serverNoRequestsYet => '暂无请求。将任意兼容 OpenAI 的客户端指向这台手机即可。';

  @override
  String get serverKeepAwakeNote => '服务器运行期间屏幕保持常亮。';

  @override
  String get serverEndpointsTitle => '接口端点';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsGeneration => '生成';

  @override
  String get settingsTemperature => '温度';

  @override
  String get settingsTopP => 'Top-p';

  @override
  String get settingsMaxTokens => '最大 token 数';

  @override
  String get settingsThreads => 'CPU 线程数';

  @override
  String settingsThreadsAuto(int count) {
    return '自动（$count）';
  }

  @override
  String get settingsThreadsHint =>
      '“自动”会按引擎绑定工作线程的大核簇来设定线程数；超出部分只会增加等待。下次加载模型时生效。';

  @override
  String get settingsUseGpu => '使用 GPU (Vulkan/Metal)';

  @override
  String get settingsUseGpuHint => '启用离散 GPU 执行图（在下次加载模型时生效）。';

  @override
  String get settingsUseGpuNeedsBackend =>
      '需要带 Vulkan/Metal 后端的引擎构建，详见 native/TUNING.md。';

  @override
  String get settingsDisableThinking => '禁用思考';

  @override
  String get settingsDisableThinkingHint =>
      '推理模型（Qwen3/3.5）直接作答，不输出 <think> 步骤';

  @override
  String get settingsEngineSection => '引擎';

  @override
  String get settingsEngineFlags => '引擎参数（高级）';

  @override
  String get settingsEngineFlagsHint =>
      '每行一个 CMF_KEY=value，加载模型时传给运行时。留空则使用默认值。';

  @override
  String get settingsServerSection => '服务器';

  @override
  String get settingsServerPort => '端口';

  @override
  String get settingsServerPortHint => '下次启动服务器时生效';

  @override
  String get settingsHfSection => 'Hugging Face';

  @override
  String get settingsHfToken => '访问 token';

  @override
  String get settingsHfTokenHint => 'hf_…(gated 模型需要)';

  @override
  String get settingsStorage => '存储';

  @override
  String settingsStorageUsage(String size, int count) {
    return '$count 个模型,共 $size';
  }

  @override
  String get settingsAbout => '关于';

  @override
  String settingsAboutLine(String engine) {
    return 'CMF 协议 v2 · 引擎:$engine';
  }

  @override
  String settingsVersionLine(String version) {
    return 'Cortiq $version';
  }

  @override
  String get navCompanion => '协同';

  @override
  String get companionTitle => '协同';

  @override
  String get companionSubtitle =>
      '将本机与桌面端配对。拆分并不会让模型更快——一个词元要按顺序走完所有层——它让本机放不下的模型成为可能。';

  @override
  String get companionUnsupported => '此版本的运行时不支持拆分，需要 cortiq 0.5.70 或更新版本。';

  @override
  String get companionWhereTitle => '在哪里计算';

  @override
  String get companionRoleLocal => '本机';

  @override
  String get companionRoleLocalHint => '全部在本机运行。';

  @override
  String get companionRoleDesktop => '桌面端';

  @override
  String get companionRoleDesktopHint =>
      '桌面端持有各层、输出头和采样器；本机只保留分词器并显示回复。适用于本机放不下的模型。';

  @override
  String get companionRoleWorkerHint =>
      '把本机内存借给桌面端：模型的一段层在这里计算。只有当模型在桌面端单独放不下时才值得。';

  @override
  String get companionAddress => '桌面端地址';

  @override
  String get companionToken => '共享令牌';

  @override
  String get companionTokenHint => '两台设备上必须是同一字符串。除回环地址外均为必填。';

  @override
  String get companionOverCable => '数据线';

  @override
  String get companionOverWifi => 'Wi-Fi';

  @override
  String get companionWifiWarning =>
      '走 Wi-Fi 时每个词元都要往返一次，用户看到的正是长尾：典型约 9 毫秒，但第 99 百分位为 95 毫秒，而数据线只有 2.9 毫秒。建议使用 USB 网络共享，或就在本机计算。';

  @override
  String get companionCheck => '检查';

  @override
  String get companionCheckOk => '对端已响应。';

  @override
  String get companionNeedsModel => '请先加载模型：即使由桌面端计算，分词器和聊天模板也从本地文件读取。';

  @override
  String get companionServeTitle => '提供层';

  @override
  String get companionWorkerPort => '端口';

  @override
  String get companionWorkerStart => '开始提供';

  @override
  String companionWorkerListening(String address) {
    return '正在监听 $address';
  }

  @override
  String get companionWorkerOneWay => '运行时没有停止监听的接口，它会一直运行到应用关闭。';

  @override
  String get companionStatsTitle => '对端当前状态';

  @override
  String get companionStatClock => 'CPU 频率';

  @override
  String get companionStatTemp => '温度';

  @override
  String get companionStatMemory => '可用内存';

  @override
  String get companionStatThreads => '工作线程';

  @override
  String get companionStatPlatform => '平台';

  @override
  String get companionStatUnknown => '未提供';

  @override
  String get companionClockWarning =>
      '对端运行频率远低于其上限。一个只计算几毫秒随后就在套接字上等待的工作进程，永远说服不了调频策略升频——实测约为一半的吞吐量。';

  @override
  String get companionSameModel =>
      '两台设备必须持有同一个 .cmf 文件。握手会进行比对并拒绝不匹配的文件，因此不一致会明确报错，而不是产生乱码。';

  @override
  String get companionWireNote => '两端必须运行同一引擎版本。握手会比对协议版本，不一致时会明确说明。';

  @override
  String get companionTokenClearText => '令牌以明文传输。请使用数据线或可信网络。';
}
