import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/formats.dart';
import '../../data/models/chat.dart';
import '../../data/models/companion.dart';
import '../../l10n/app_localizations.dart';
import 'model_picker_sheet.dart';
import 'sessions_sheet.dart';

const _attachmentTextLimit = 512 * 1024; // bytes of extracted text

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatAttachment> _pending = [];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    ref
        .read(chatControllerProvider.notifier)
        .send(text, List.of(_pending));
    _input.clear();
    setState(() => _pending.clear());
  }

  Future<void> _attach() async {
    final l = AppLocalizations.of(context);
    final engineState = ref.read(engineControllerProvider);
    final meta = engineState.loadedModel?.meta;
    if (meta == null || !meta.supportsAttachments) {
      _snack(l.chatAttachmentsNotSupported);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'txt', 'md', 'markdown', 'json', 'csv', 'log', 'xml', 'html', 'yaml',
        'yml', 'toml', 'dart', 'py', 'js', 'ts', 'java', 'kt', 'swift', 'c',
        'h', 'cpp', 'rs', 'go', 'sql', 'sh',
      ],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (bytes.length > _attachmentTextLimit) {
      _snack(AppLocalizations.of(context)
          .chatAttachmentTooLarge(formatBytes(_attachmentTextLimit)));
      return;
    }
    String text;
    try {
      text = String.fromCharCodes(bytes);
      if (text.contains('\x00')) throw const FormatException();
    } catch (_) {
      _snack(AppLocalizations.of(context).chatAttachmentUnreadable);
      return;
    }
    setState(() => _pending.add(ChatAttachment(
          name: file.name,
          text: text,
          sizeBytes: bytes.length,
        )));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chat = ref.watch(chatControllerProvider);
    final engineState = ref.watch(engineControllerProvider);
    final isDemo = ref.watch(isDemoEngineProvider);
    final session = chat.current;
    final messages = session?.messages ?? const <ChatMessage>[];
    final hasModel = engineState.loadedModel != null && !engineState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: _ModelChip(
          engineState: engineState,
          isDemo: isDemo,
          onTap: () => showModelPickerSheet(context, ref),
        ),
        actions: [
          IconButton(
            tooltip: l.chatNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () =>
                ref.read(chatControllerProvider.notifier).newSession(),
          ),
          IconButton(
            tooltip: l.chatSessions,
            icon: const Icon(Icons.history),
            onPressed: () => showSessionsSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isDemo && hasModel)
            MaterialBanner(
              dividerColor: Colors.transparent,
              leading: const Icon(Icons.science_outlined),
              content: Text(l.chatDemoBanner,
                  style: Theme.of(context).textTheme.bodySmall),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(
                    hasModel: hasModel,
                    onSuggestion: (s) => _input.text = s,
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final index = messages.length - 1 - i;
                      final msg = messages[index];
                      final isLast = i == 0;
                      return _MessageBubble(
                        key: ValueKey('${session!.id}:$index'),
                        message: msg,
                        sessionId: session.id,
                        generating: chat.generating && isLast,
                        onRegenerate: isLast &&
                                msg.role == ChatRole.assistant &&
                                !chat.generating
                            ? () => ref
                                .read(chatControllerProvider.notifier)
                                .regenerate()
                            : null,
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _input,
            attachments: _pending,
            generating: chat.generating,
            enabled: hasModel,
            onAttach: _attach,
            onRemoveAttachment: (a) => setState(() => _pending.remove(a)),
            onSend: _send,
            onStop: () => ref.read(chatControllerProvider.notifier).stop(),
          ),
        ],
      ),
    );
  }
}

class _ModelChip extends ConsumerWidget {
  const _ModelChip({
    required this.engineState,
    required this.isDemo,
    required this.onTap,
  });

  final EngineState engineState;
  final bool isDemo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final model = engineState.loadedModel;

    final String label;
    if (engineState.isLoading) {
      label = l.chatModelLoading;
    } else if (model != null) {
      label = model.id;
    } else {
      label = l.chatModelPickerTitle;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (engineState.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                model != null ? Icons.memory : Icons.expand_more,
                size: 18,
                color: model != null ? scheme.primary : null,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (isDemo && model != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(l.chatDemoBadge,
                    style: TextStyle(
                        fontSize: 10, color: scheme.onTertiaryContainer)),
              ),
            ],
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.hasModel, required this.onSuggestion});

  final bool hasModel;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Centred when there is room, scrollable when there is not. The keyboard
    // takes about half a phone's height, and a plain Center can only overflow:
    // the suggestion chips were being cut off with nothing to scroll.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasModel ? Icons.auto_awesome : Icons.download_outlined,
                  size: 32,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                hasModel ? l.chatEmptyTitle : l.chatNoModelTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasModel ? l.chatEmptyBody : l.chatNoModelBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!hasModel)
                FilledButton.icon(
                  icon: const Icon(Icons.layers_outlined),
                  label: Text(l.chatGoToModels),
                  onPressed: () =>
                      ref.read(shellIndexProvider.notifier).select(1),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in [
                      l.chatSuggestion1,
                      l.chatSuggestion2,
                      l.chatSuggestion3,
                    ])
                      ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        onPressed: () => onSuggestion(s),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.sessionId,
    required this.generating,
    this.onRegenerate,
  });

  final ChatMessage message;
  final String sessionId;
  final bool generating;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    // Only the actively generating bubble subscribes to per-token updates;
    // it renders plain text while streaming (markdown is parsed once, when
    // the reply lands in the session on completion).
    final streamText = generating && !isUser
        ? ref.watch(streamingReplyProvider.select(
            (s) => s != null && s.sessionId == sessionId ? s.text : null))
        : null;
    final content = streamText ?? message.content;

    final bubble = Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser
            ? null
            : Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final a in message.attachments)
                    Chip(
                      avatar: const Icon(Icons.description_outlined, size: 14),
                      label: Text(a.name,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          if (content.isEmpty && generating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (isUser)
            SelectableText(message.content)
          else if (streamText != null)
            Text(streamText)
          else
            MarkdownBody(data: message.content, selectable: true),
          if (message.error != null)
            _ErrorNote(error: message.error!),
        ],
      ),
    );

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: bubble,
        ),
        if (!isUser && (message.stats != null || onRegenerate != null))
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.stats != null)
                  _StatsLine(stats: message.stats!),
                IconButton(
                  icon: const Icon(Icons.copy, size: 15),
                  visualDensity: VisualDensity.compact,
                  tooltip: l.actionCopy,
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.copiedToClipboard)));
                  },
                ),
                if (onRegenerate != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: l.chatRegenerate,
                    onPressed: onRegenerate,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A failed reply, said in the user's language.
///
/// When the split is on, the interesting failure is not "generation failed"
/// but "the desktop went away" — and the only thing the user can do about it
/// from here is move the work back to this device. So that is the button.
/// It is never done automatically: the desktop was chosen deliberately, and
/// quietly moving a conversation onto the phone would change both where the
/// data goes and how fast it comes back.
class _ErrorNote extends ConsumerWidget {
  const _ErrorNote({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final peerActive = ref.watch(
        companionControllerProvider.select((s) => s.role == CompanionRole.desktop));
    final failure = peerActive ? classifyPeerFailure(error) : null;

    final headline = switch (failure) {
      PeerFailure.unreachable => l.companionPeerUnreachable,
      PeerFailure.wireVersion => l.companionPeerWireVersion,
      PeerFailure.modelMismatch => l.companionPeerModelMismatch,
      PeerFailure.other => l.companionPeerFailed,
      null => '${l.chatGenerationError}: ${cleanEngineError(error)}',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 14, color: scheme.error),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  headline,
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
              ),
            ],
          ),
          if (failure != null) ...[
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.smartphone, size: 16),
              label: Text(l.chatComputeHere),
              onPressed: () => ref
                  .read(chatControllerProvider.notifier)
                  .computeHereAndRetry(),
            ),
            // The runtime's own words stay available, just demoted: they name
            // the address and the errno, which is what a bug report needs.
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                cleanEngineError(error),
                style: TextStyle(
                    fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.stats});

  final GenerationStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = AppTheme.mono(context,
        size: 11, color: scheme.onSurfaceVariant);
    final parts = [
      '${(stats.latencyMs / 1000).toStringAsFixed(1)}s',
      '↑${formatCount(stats.promptTokens)}',
      '↓${formatCount(stats.completionTokens)}',
      l.statsTokensPerSecond(stats.tokensPerSecond.toStringAsFixed(1)),
      if (stats.finishReason == 'length') l.statsFinishLength,
    ];
    return Text(parts.join(' · '), style: style);
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.attachments,
    required this.generating,
    required this.enabled,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final List<ChatAttachment> attachments;
  final bool generating;
  final bool enabled;
  final VoidCallback onAttach;
  final ValueChanged<ChatAttachment> onRemoveAttachment;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final a in attachments)
                        InputChip(
                          avatar: const Icon(Icons.description_outlined,
                              size: 14),
                          label: Text(
                              '${a.name} · ${formatBytes(a.sizeBytes)}',
                              style: const TextStyle(fontSize: 11)),
                          onDeleted: () => onRemoveAttachment(a),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: l.chatAttachDocument,
                  onPressed: enabled && !generating ? onAttach : null,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled && !generating,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration:
                        InputDecoration(hintText: l.chatInputHint),
                  ),
                ),
                const SizedBox(width: 6),
                generating
                    ? IconButton.filledTonal(
                        icon: const Icon(Icons.stop),
                        tooltip: l.chatStop,
                        onPressed: onStop,
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: l.chatSend,
                        onPressed: enabled ? onSend : null,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
