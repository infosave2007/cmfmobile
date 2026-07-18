// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CMF Mobile';

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
    return '运行此模型约需 $need 内存。本设备共有 $total 内存,应用实际只能使用其中一部分——加载可能失败或非常缓慢。';
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
      '设备端转换支持 Q8_ROW、Q1 和 F16。已包含 .cmf 文件的仓库可直接下载——不限量化格式。';

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
  String get quantQ8_2fDesc => '8 位双字段(𝒲×θ)——质量/体积比最佳。需要 .cmf 仓库或桌面工具链。';

  @override
  String get quantQ8RowDesc => '8 位按行量化——简单可靠。可在设备上转换。';

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
    return 'CMF Mobile $version';
  }
}
