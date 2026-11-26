/// A user's report about an AI-generated reply (Google Play's AI-generated
/// content policy, App Store guideline 1.2): flagged in the chat, kept in a
/// local outbox and delivered to the developer by `ContentReportService`.
library;

/// Why the reply was reported. The names are the wire values.
enum ReportReason {
  sexual,
  hateful,
  violent,
  selfHarm,
  harassment,
  illegal,
  misinformation,
  other,
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.createdAt,
    required this.reason,
    required this.reply,
    this.prompt,
    this.comment = '',
    this.model = '',
    this.appVersion = '',
    this.platform = '',
    this.sent = false,
  });

  final String id;
  final DateTime createdAt;
  final ReportReason reason;

  /// The reported AI reply, as shown in the chat.
  final String reply;

  /// The user turn that led to it, only when the user chose to include it.
  final String? prompt;

  /// The user's own words, optional.
  final String comment;

  /// Which model wrote the reply (file name / repository), for moderation of
  /// the model catalog.
  final String model;
  final String appVersion;
  final String platform;

  /// Delivered to the developer; unsent reports stay in the outbox.
  final bool sent;

  /// Long texts are cut so one report stays a small request.
  static const maxReplyChars = 4000;
  static const maxPromptChars = 2000;
  static const maxCommentChars = 1000;

  static String clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  ContentReport markSent() => ContentReport(
        id: id,
        createdAt: createdAt,
        reason: reason,
        reply: reply,
        prompt: prompt,
        comment: comment,
        model: model,
        appVersion: appVersion,
        platform: platform,
        sent: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'reason': reason.name,
        'reply': reply,
        if (prompt != null) 'prompt': prompt,
        'comment': comment,
        'model': model,
        'appVersion': appVersion,
        'platform': platform,
        'sent': sent,
      };

  factory ContentReport.fromJson(Map<String, dynamic> j) => ContentReport(
        id: j['id'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        reason: ReportReason.values.firstWhere(
          (r) => r.name == j['reason'],
          orElse: () => ReportReason.other,
        ),
        reply: j['reply'] as String? ?? '',
        prompt: j['prompt'] as String?,
        comment: j['comment'] as String? ?? '',
        model: j['model'] as String? ?? '',
        appVersion: j['appVersion'] as String? ?? '',
        platform: j['platform'] as String? ?? '',
        sent: j['sent'] as bool? ?? false,
      );
}
