/// Parsed metadata of a CMF v2 file (envelope + JSON header essentials).
///
/// Layout reference: cmfpublic/docs/CMF_V2_SPEC.md — 128-byte envelope,
/// magic "CMF\x01", version 2, JSON header at offset 128.
class CmfMetadata {
  const CmfMetadata({
    required this.version,
    required this.archName,
    required this.quantType,
    required this.numLayers,
    required this.hiddenSize,
    this.numKvHeads = 0,
    this.headDim = 0,
    required this.vocabSize,
    required this.contextLength,
    required this.tensorCount,
    required this.hasVocab,
    required this.hasChatTemplate,
    required this.eosTokenIds,
    required this.tasks,
    required this.requiredFeatures,
    this.skills = const [],
  });

  final int version;
  final String archName;
  final String quantType;
  final int numLayers;
  final int hiddenSize;
  final int numKvHeads;
  final int headDim;
  final int vocabSize;
  final int contextLength;
  final int tensorCount;
  final bool hasVocab;
  final bool hasChatTemplate;
  final List<int> eosTokenIds;

  /// Task-mask names baked into the file (virtual sparsity skills).
  final List<String> tasks;

  /// Skills this file *is*, as declared in its header. Non-empty means the
  /// file is a skill cut from a base model, not a model that can run alone.
  final List<String> skills;
  final int requiredFeatures;

  /// A skill plugs into a base model; it cannot be loaded and chatted with.
  bool get isSkill => skills.isNotEmpty;

  /// Text attachments are inlined into the prompt, so any chat model with a
  /// template and a reasonable context window can accept them.
  bool get supportsAttachments => hasChatTemplate && contextLength >= 2048;

  Map<String, dynamic> toJson() => {
        'version': version,
        'archName': archName,
        'quantType': quantType,
        'numLayers': numLayers,
        'hiddenSize': hiddenSize,
        'numKvHeads': numKvHeads,
        'headDim': headDim,
        'vocabSize': vocabSize,
        'contextLength': contextLength,
        'tensorCount': tensorCount,
        'hasVocab': hasVocab,
        'hasChatTemplate': hasChatTemplate,
        'eosTokenIds': eosTokenIds,
        'tasks': tasks,
        'requiredFeatures': requiredFeatures,
        'skills': skills,
      };

  factory CmfMetadata.fromJson(Map<String, dynamic> json) => CmfMetadata(
        version: json['version'] as int? ?? 2,
        archName: json['archName'] as String? ?? '?',
        quantType: json['quantType'] as String? ?? '?',
        numLayers: json['numLayers'] as int? ?? 0,
        hiddenSize: json['hiddenSize'] as int? ?? 0,
        numKvHeads: json['numKvHeads'] as int? ?? 0,
        headDim: json['headDim'] as int? ?? 0,
        vocabSize: json['vocabSize'] as int? ?? 0,
        contextLength: json['contextLength'] as int? ?? 0,
        tensorCount: json['tensorCount'] as int? ?? 0,
        hasVocab: json['hasVocab'] as bool? ?? false,
        hasChatTemplate: json['hasChatTemplate'] as bool? ?? false,
        eosTokenIds:
            (json['eosTokenIds'] as List?)?.cast<int>() ?? const [],
        tasks: (json['tasks'] as List?)?.cast<String>() ?? const [],
        requiredFeatures: json['requiredFeatures'] as int? ?? 1,
        skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      );
}
