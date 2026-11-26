import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/content_report.dart';
import '../../l10n/app_localizations.dart';

/// The in-app report for an AI reply (Google Play's AI-generated content
/// policy): a reason, an optional comment, the user's choice whether to
/// include the prompt, and exactly what will be sent. The reply is collapsed
/// in the chat as soon as it is reported.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required int index,
}) async {
  final sent = await showModalBottomSheet<bool?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(sessionId: sessionId, index: index),
  );
  if (sent == null || !context.mounted) return;
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(sent ? l.reportSent : l.reportQueued)),
  );
}

String reasonLabel(AppLocalizations l, ReportReason r) => switch (r) {
      ReportReason.sexual => l.reportReasonSexual,
      ReportReason.hateful => l.reportReasonHateful,
      ReportReason.violent => l.reportReasonViolent,
      ReportReason.selfHarm => l.reportReasonSelfHarm,
      ReportReason.harassment => l.reportReasonHarassment,
      ReportReason.illegal => l.reportReasonIllegal,
      ReportReason.misinformation => l.reportReasonMisinformation,
      ReportReason.other => l.reportReasonOther,
    };

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.sessionId, required this.index});

  final String sessionId;
  final int index;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  bool _includePrompt = true;
  bool _sending = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    final sent = await ref.read(chatControllerProvider.notifier).reportReply(
          widget.sessionId,
          widget.index,
          reason: reason,
          comment: _comment.text,
          includePrompt: _includePrompt,
        );
    if (mounted) Navigator.of(context).pop(sent);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reportTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.reportIntro, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      key: Key('report-reason-${r.name}'),
                      value: r,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(reasonLabel(l, r)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('report-comment'),
              controller: _comment,
              maxLines: 3,
              minLines: 1,
              maxLength: ContentReport.maxCommentChars,
              decoration: InputDecoration(
                labelText: l.reportComment,
                border: const OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              value: _includePrompt,
              onChanged: (v) => setState(() => _includePrompt = v ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.reportIncludePrompt),
            ),
            Text(l.reportDisclosure, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
                  child: Text(l.actionCancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('report-send'),
                  onPressed: _reason == null || _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined, size: 18),
                  label: Text(l.reportSend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
