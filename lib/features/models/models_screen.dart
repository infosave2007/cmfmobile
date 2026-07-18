import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/util/formats.dart';
import '../../data/models/local_model.dart';
import '../../l10n/app_localizations.dart';
import 'import_screen.dart';
import 'load_model_helper.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.firstOrNull?.path;
    if (path == null || !context.mounted) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final model =
        await ref.read(modelsProvider.notifier).importFile(path);
    messenger.showSnackBar(
        SnackBar(content: Text(l.modelsImportedSnack(model.id))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final modelsAsync = ref.watch(modelsProvider);
    final engineState = ref.watch(engineControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.modelsTitle)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import-file',
            tooltip: l.modelsImportFile,
            child: const Icon(Icons.file_open_outlined),
            onPressed: () => _importFile(context, ref),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'import-hf',
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(l.modelsGetFromHf),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const ImportScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(modelsProvider.notifier).refresh(),
        child: modelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (models) => models.isEmpty
              ? _EmptyLibrary(l: l)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: models.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ModelCard(
                    model: models[i],
                    engineState: engineState,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.layers_outlined,
                      size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l.modelsEmptyTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    l.modelsEmptyBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  const _ModelCard({required this.model, required this.engineState});

  final LocalModel model;
  final EngineState engineState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final meta = model.meta;
    final isLoaded =
        engineState.loadedModelId == model.id && !engineState.isLoading;
    final isLoading =
        engineState.loadedModelId == model.id && engineState.isLoading;
    final ramEstimate = ref
        .read(deviceResourcesProvider)
        .estimateRequiredBytes(model);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.id,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.modelsLoadedBadge,
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(l.modelsDeleteTitle),
                          content:
                              Text(l.modelsDeleteConfirm(model.id)),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(l.actionCancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(dialogContext)
                                          .colorScheme
                                          .error),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: Text(l.actionDelete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(modelsProvider.notifier)
                            .deleteModel(model);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'delete', child: Text(l.actionDelete)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (meta != null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaChip(text: meta.archName),
                  _MetaChip(text: meta.quantType),
                  _MetaChip(text: formatBytes(model.sizeBytes)),
                  _MetaChip(text: l.modelsMetaLayers(meta.numLayers)),
                  if (meta.contextLength > 0)
                    _MetaChip(
                        text: l.modelsMetaContext(
                            formatCount(meta.contextLength))),
                  _MetaChip(text: l.modelsMetaRam(formatBytes(ramEstimate))),
                  if (meta.tasks.isNotEmpty)
                    _MetaChip(
                        text: l.modelsMetaTasks(meta.tasks.length),
                        highlight: true),
                  if (meta.supportsAttachments)
                    _MetaChip(text: l.modelsAttachmentsOk, icon: Icons.attach_file),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : isLoaded
                        ? Tooltip(
                            message: l.modelsUnloadHint,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.eject_outlined,
                                  size: 18),
                              label: Text(l.modelsUnload),
                              onPressed: () => ref
                                  .read(engineControllerProvider.notifier)
                                  .unload(),
                            ),
                          )
                        : FilledButton.tonalIcon(
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(l.modelsLoadIntoEngine),
                            onPressed: () => loadModelWithMemoryCheck(
                                context, ref, model),
                          ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 16, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${l.modelsInvalidFile} — ${model.metaError}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.error),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, this.highlight = false, this.icon});

  final String text;
  final bool highlight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: highlight
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
