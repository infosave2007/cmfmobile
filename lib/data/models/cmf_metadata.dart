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

  /// Skills this file *is*, as declared in its header: standalone records
  /// cut against a base model (`base_dir_hash`). Non-empty means the file
  /// is a skill that plugs into that base, not a model that can run alone.
  /// Skills a model carries inside itself — Embryo's lookup records — are
  /// not listed here; see `cmfHeaderSkills`.
  final List<String> skills;
  final int requiredFeatures;

  /// Envelope feature bit 6, `SKILL_FILE` (CMF_V2_SPEC §9.1): the file is a
  /// standalone skill. A writer raises it for any `base_dir_hash` record, so
  /// on a well-formed file it agrees with [skills]; both are checked so a
  /// file carrying only one of the two signals still stays out of Chat.
  static const int featureSkillFile = 1 << 6;

  /// Envelope feature bit 11: a CMF Decision file, served by the decision
  /// ABI and without a chat head.
  static const int featureDecision = 1 << 11;

  bool get isDecision => (requiredFeatures & featureDecision) != 0;

  /// A skill plugs into a base model; it cannot be loaded and chatted with.
  bool get isSkill =>
      !isDecision &&
      ((requiredFeatures & featureSkillFile) != 0 || skills.isNotEmpty);

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
