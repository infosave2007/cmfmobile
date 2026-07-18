/// Quantization options offered by the converter (same set as
/// cortiq-gateway's import screen).
enum QuantType {
  q8_2f('Q8_2F', 'q8_2f'),
  q8Row('Q8_ROW', 'q8'),
  q4Block('Q4_BLOCK', 'q4'),
  vbit('VBIT', 'vbit'),
  q1('Q1', 'q1'),
  f16('F16', 'f16');

  const QuantType(this.label, this.flag);
  final String label;
  final String flag;

  /// Quantizations the on-device Dart converter can produce itself.
  /// The rest require the native cortiq toolchain.
  bool get supportedOnDevice => switch (this) {
        QuantType.q8Row ||
        QuantType.q8_2f ||
        QuantType.q1 ||
        QuantType.f16 =>
          true,
        _ => false,
      };
}

/// A HuggingFace model card from the search API.
class HfModel {
  const HfModel({
    required this.id,
    this.pipelineTag,
    this.downloads = 0,
    this.likes = 0,
    this.gated = false,
    this.tags = const [],
  });

  final String id;
  final String? pipelineTag;
  final int downloads;
  final int likes;
  final bool gated;
  final List<String> tags;

  factory HfModel.fromJson(Map<String, dynamic> json) => HfModel(
        id: json['id'] as String? ?? json['modelId'] as String? ?? '?',
        pipelineTag: json['pipeline_tag'] as String?,
        downloads: json['downloads'] as int? ?? 0,
        likes: json['likes'] as int? ?? 0,
        gated: json['gated'] != null && json['gated'] != false,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      );
}

enum JobState { running, done, error, cancelled }

/// A conversion/download job, mirroring cortiq-gateway's Job object.
class ConversionJob {
  ConversionJob({
    required this.id,
    required this.repo,
    required this.quant,
    required this.name,
    required this.outputPath,
    required this.started,
    this.state = JobState.running,
    this.progress = 0,
    this.phase = 'starting',
    List<String>? log,
    this.finished,
    this.sizeBytes,
    this.error,
  }) : log = log ?? [];

  final String id;
  final String repo;
  final QuantType quant;
  final String name;
  final String outputPath;
  final DateTime started;

  JobState state;
  double progress;
  String phase;
  final List<String> log;
  DateTime? finished;
  int? sizeBytes;
  String? error;

  /// True when the repo ships ready .cmf files (the requested [quant]
  /// is not used — the file keeps whatever quantization it was built with).
  bool directDownload = false;

  /// Actual quantization read from the finished file's tensor directory.
  String? resultQuant;

  /// What the jobs UI should show as the quantization.
  String get displayQuant =>
      resultQuant ?? (directDownload ? '.cmf' : quant.label);

  void addLog(String line) {
    log.add(line);
    if (log.length > 200) log.removeAt(0);
  }
}
