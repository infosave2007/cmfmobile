import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/util/formats.dart';
import '../../l10n/app_localizations.dart';

/// Chat history (topics) — like the sidebar in GPT-style apps: every
/// session keeps its own context and can be reopened, renamed or deleted.
void showSessionsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final l = AppLocalizations.of(context);
        final chat = ref.watch(chatControllerProvider);
        final dateFormat = DateFormat.yMMMd(
            Localizations.localeOf(context).toLanguageTag());

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(
                  children: [
                    Text(l.chatSessions,
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.chatNewChat),
                      onPressed: () {
                        ref
                            .read(chatControllerProvider.notifier)
                            .newSession();
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: chat.sessions.length,
                  itemBuilder: (context, i) {
                    final session = chat.sessions[i];
                    final title = session.displayTitle();
                    final selected = session.id == chat.currentId;
                    return ListTile(
                      selected: selected,
                      leading: Icon(selected
                          ? Icons.chat_bubble
                          : Icons.chat_bubble_outline),
                      title: Text(
                        title.isEmpty ? l.chatUntitled : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${dateFormat.format(session.createdAt)} · '
                        '${l.chatSessionTokens(
                          formatCount(session.totalPromptTokens),
                          formatCount(session.totalCompletionTokens),
                        )}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        ref
                            .read(chatControllerProvider.notifier)
                            .selectSession(session.id);
                        Navigator.pop(sheetContext);
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          switch (action) {
                            case 'rename':
                              final controller = TextEditingController(
                                  text: session.displayTitle());
                              final name = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text(l.chatRenameTitle),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: Text(l.actionCancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                          dialogContext,
                                          controller.text.trim()),
                                      child: Text(l.actionSave),
                                    ),
                                  ],
                                ),
                              );
                              if (name != null && name.isNotEmpty) {
                                await ref
                                    .read(chatControllerProvider.notifier)
                                    .renameSession(session.id, name);
                              }
                            case 'delete':
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text(l.chatDeleteChat),
                                  content:
                                      Text(l.chatDeleteChatConfirm),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(
                                          dialogContext, false),
                                      child: Text(l.actionCancel),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(
                                                dialogContext)
                                            .colorScheme
                                            .error,
                                      ),
                                      onPressed: () => Navigator.pop(
                                          dialogContext, true),
                                      child: Text(l.actionDelete),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref
                                    .read(chatControllerProvider.notifier)
                                    .deleteSession(session.id);
                              }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(l.chatRename),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l.chatDeleteChat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
