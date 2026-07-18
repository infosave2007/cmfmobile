import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/util/formats.dart';
import '../../l10n/app_localizations.dart';
import '../models/load_model_helper.dart';

void showModelPickerSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final l = AppLocalizations.of(context);
        final models = ref.watch(modelsProvider).value ?? const [];
        final engineState = ref.watch(engineControllerProvider);

        if (models.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.modelsEmptyTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l.chatNoModelBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ref.read(shellIndexProvider.notifier).select(1);
                  },
                  child: Text(l.chatGoToModels),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l.chatModelPickerTitle,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final model in models.where((m) => m.isValid))
                ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: engineState.loadedModelId == model.id &&
                            !engineState.isLoading
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(model.id),
                  subtitle: Text(
                    '${model.meta!.archName} · ${model.meta!.quantType} · '
                    '${formatBytes(model.sizeBytes)}',
                  ),
                  trailing: engineState.loadedModelId == model.id
                      ? (engineState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check))
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await loadModelWithMemoryCheck(context, ref, model);
                  },
                ),
              if (engineState.loadedModel != null &&
                  !engineState.isLoading) ...[
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(Icons.eject_outlined),
                  title: Text(l.modelsUnload),
                  subtitle: Text(l.modelsUnloadHint,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    ref.read(engineControllerProvider.notifier).unload();
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
