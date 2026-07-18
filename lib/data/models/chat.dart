import 'dart:math' as math;

enum ChatRole { system, user, assistant }

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.text,
    required this.sizeBytes,
  });

  final String name;

  /// Extracted text content, inlined into the prompt.
  final String text;
  final int sizeBytes;

  Map<String, dynamic> toJson() =>
      {'name': name, 'text': text, 'sizeBytes': sizeBytes};

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        name: json['name'] as String,
        text: json['text'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
      );
}

/// Per-response generation statistics (mirrors the `usage` + `cortiq`
/// fields of the CMF server protocol).
class GenerationStats {
  const GenerationStats({
    required this.promptTokens,
    required this.completionTokens,
    required this.tokensPerSecond,
    required this.latencyMs,
    this.finishReason,
    this.taskUsed,
  });

  final int promptTokens;
  final int completionTokens;
  final double tokensPerSecond;
  final int latencyMs;
  final String? finishReason;
  final String? taskUsed;

  int get totalTokens => promptTokens + completionTokens;

  Map<String, dynamic> toJson() => {
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'tokensPerSecond': tokensPerSecond,
        'latencyMs': latencyMs,
        'finishReason': finishReason,
        'taskUsed': taskUsed,
      };

  factory GenerationStats.fromJson(Map<String, dynamic> json) =>
      GenerationStats(
        promptTokens: json['promptTokens'] as int? ?? 0,
        completionTokens: json['completionTokens'] as int? ?? 0,
        tokensPerSecond: (json['tokensPerSecond'] as num?)?.toDouble() ?? 0,
        latencyMs: json['latencyMs'] as int? ?? 0,
        finishReason: json['finishReason'] as String?,
        taskUsed: json['taskUsed'] as String?,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.attachments = const [],
    this.stats,
    this.error,
  });

  final ChatRole role;
  final String content;
  final List<ChatAttachment> attachments;
  final GenerationStats? stats;
  final String? error;

  ChatMessage copyWith({
    String? content,
    GenerationStats? stats,
    String? error,
  }) =>
      ChatMessage(
        role: role,
        content: content ?? this.content,
        attachments: attachments,
        stats: stats ?? this.stats,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (stats != null) 'stats': stats!.toJson(),
        if (error != null) 'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: ChatRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => ChatRole.user,
        ),
        content: json['content'] as String? ?? '',
        attachments: (json['attachments'] as List?)
                ?.map((a) =>
                    ChatAttachment.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
        stats: json['stats'] == null
            ? null
            : GenerationStats.fromJson(json['stats'] as Map<String, dynamic>),
        error: json['error'] as String?,
      );
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.createdAt,
    this.title,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  final DateTime createdAt;
  String? title;
  final List<ChatMessage> messages;

  String displayTitle() {
    if (title != null && title!.isNotEmpty) return title!;
    final firstUser = messages.where((m) => m.role == ChatRole.user);
    if (firstUser.isEmpty) return '';
    final t = firstUser.first.content.trim().replaceAll('\n', ' ');
    return t.substring(0, math.min(48, t.length));
  }

  int get totalPromptTokens => messages
      .map((m) => m.stats?.promptTokens ?? 0)
      .fold(0, (a, b) => a + b);
  int get totalCompletionTokens => messages
      .map((m) => m.stats?.completionTokens ?? 0)
      .fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        title: json['title'] as String?,
        messages: (json['messages'] as List?)
                ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
