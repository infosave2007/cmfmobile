import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/formats.dart';
import '../../data/models/conversion.dart';
import '../../l10n/app_localizations.dart';

/// HuggingFace import: search → configure quantization → conversion jobs
/// with live progress (the same flow as cortiq-gateway's Import view).
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _search = TextEditingController();
  Timer? _debounce;
  List<HfModel>? _results;
  bool _searching = false;
  String? _searchError;

  StreamSubscription<void>? _jobsSub;
  final Set<String> _seenDone = {};

  @override
  void initState() {
    super.initState();
    _runSearch('');
    _jobsSub = ref.read(converterProvider).updates.listen((_) {
      if (!mounted) return;
      setState(() {});
      // Refresh the model library when a conversion completes.
      for (final job in ref.read(converterProvider).jobs) {
        if (job.state == JobState.done && !_seenDone.contains(job.id)) {
          _seenDone.add(job.id);
          ref.read(modelsProvider.notifier).refresh();
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _jobsSub?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final token =
          ref.read(settingsProvider).value?.hfToken;
      final results =
          await ref.read(hfApiProvider).search(query, token: token);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _configure(HfModel model) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ConfigureSheet(
        model: model,
        onStart: (quant, name) async {
          Navigator.pop(sheetContext);
          final settings = ref.read(settingsProvider).value;
          await ref.read(converterProvider).start(
                repo: model.id,
                quant: quant,
                name: name,
                hfToken: settings?.hfToken,
                threads: settings?.threads ?? 4,
              );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(AppLocalizations.of(context).importStartedSnack)));
          _tabs.animateTo(1);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final jobs = ref.read(converterProvider).jobs;
    final running = jobs.where((j) => j.state == JobState.running).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.importTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.importTitle),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.importJobsTitle),
                  if (running > 0) ...[
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSearchTab(l),
          _JobsTab(jobs: jobs),
        ],
      ),
    );
  }

  Widget _buildSearchTab(AppLocalizations l) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: l.importSearchPlaceholder,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            l.importSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: _searchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_searchError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.error)),
                  ),
                )
              : (_results == null)
                  ? const Center(child: CircularProgressIndicator())
                  : _results!.isEmpty
                      ? Center(child: Text(l.importNoResults))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _results!.length,
                          itemBuilder: (context, i) => _HfModelCard(
                            model: _results![i],
                            onTap: () => _configure(_results![i]),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _HfModelCard extends StatelessWidget {
  const _HfModelCard({required this.model, required this.onTap});

  final HfModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (model.gated)
                    Tooltip(
                      message: l.importGatedHint,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l.importGatedBadge,
                          style: TextStyle(
                              fontSize: 10,
                              color: scheme.onErrorContainer),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (model.pipelineTag != null) ...[
                    Icon(Icons.category_outlined,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(model.pipelineTag!,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.download_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(formatCount(model.downloads),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  Icon(Icons.favorite_outline,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(formatCount(model.likes),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigureSheet extends StatefulWidget {
  const _ConfigureSheet({required this.model, required this.onStart});

  final HfModel model;
  final void Function(QuantType quant, String name) onStart;

  @override
  State<_ConfigureSheet> createState() => _ConfigureSheetState();
}

class _ConfigureSheetState extends State<_ConfigureSheet> {
  late final TextEditingController _name = TextEditingController(
      text: widget.model.id.split('/').last.toLowerCase());
  QuantType _quant = QuantType.q8Row;

  String _quantDescription(AppLocalizations l, QuantType q) => switch (q) {
        QuantType.q8_2f => l.quantQ8_2fDesc,
        QuantType.q8Row => l.quantQ8RowDesc,
        QuantType.q4Block => l.quantQ4Desc,
        QuantType.vbit => l.quantVbitDesc,
        QuantType.q1 => l.quantQ1Desc,
        QuantType.f16 => l.quantF16Desc,
      };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.importConfigureTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(widget.model.id,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l.importOutputName,
                  helperText: l.importOutputNameHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(l.importQuantization,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final q in QuantType.values)
                RadioListTile<QuantType>(
                  value: q,
                  // ignore: deprecated_member_use
                  groupValue: _quant,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _quant = v!),
                  dense: true,
                  title: Text(q.label),
                  subtitle: Text(_quantDescription(l, q),
                      style: const TextStyle(fontSize: 11)),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.importOnDeviceNote,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bolt),
                  label: Text(l.importStartConvert),
                  onPressed: () =>
                      widget.onStart(_quant, _name.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsTab extends ConsumerWidget {
  const _JobsTab({required this.jobs});

  final List<ConversionJob> jobs;

  String _phaseLabel(AppLocalizations l, ConversionJob job) {
    if (job.state == JobState.done) return l.importStateDone;
    if (job.state == JobState.error) return l.importStateError;
    if (job.state == JobState.cancelled) return l.importStateCancelled;
    return switch (job.phase) {
      'listing' => l.importPhaseListing,
      'downloading' => l.importPhaseDownloading,
      'converting' => l.importPhaseConverting,
      'quantizing' => l.importPhaseQuantizing,
      'finalizing' => l.importPhaseFinalizing,
      _ => job.phase,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (jobs.isEmpty) {
      return Center(child: Text(l.importNoJobs));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final job = jobs[i];
        final stateColor = switch (job.state) {
          JobState.running => scheme.primary,
          JobState.done => scheme.primary,
          JobState.error => scheme.error,
          JobState.cancelled => scheme.onSurfaceVariant,
        };
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
                        '${job.name}.cmf',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _phaseLabel(l, job),
                        style:
                            TextStyle(fontSize: 11, color: stateColor),
                      ),
                    ),
                    if (job.state == JobState.running)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: l.actionCancel,
                        onPressed: () =>
                            ref.read(converterProvider).cancel(job.id),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: l.actionDelete,
                        onPressed: () async {
                          final deleteFile = job.state == JobState.done;
                          final confirmed = !deleteFile ||
                              (await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) =>
                                        AlertDialog(
                                      content: Text(
                                          l.importDeleteConfirm),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(
                                                  dialogContext,
                                                  false),
                                          child:
                                              Text(l.actionCancel),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(
                                                  dialogContext, true),
                                          child:
                                              Text(l.actionDelete),
                                        ),
                                      ],
                                    ),
                                  ) ==
                                  true);
                          if (confirmed) {
                            await ref.read(converterProvider).delete(
                                job.id,
                                deleteFile: deleteFile);
                            ref
                                .read(modelsProvider.notifier)
                                .refresh();
                          }
                        },
                      ),
                  ],
                ),
                Text(
                  '${job.repo} · ${job.quant.label}'
                  '${job.sizeBytes != null ? ' · ${formatBytes(job.sizeBytes!)}' : ''}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (job.state == JobState.running) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: job.progress > 0.01 ? job.progress : null),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(job.progress * 100).toStringAsFixed(0)}%',
                    style: AppTheme.mono(context,
                        size: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
                if (job.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(job.error!,
                        style: TextStyle(
                            fontSize: 12, color: scheme.error)),
                  ),
                if (job.log.isNotEmpty)
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding:
                          const EdgeInsets.only(bottom: 8),
                      title: Text(l.importShowLog,
                          style: const TextStyle(fontSize: 12)),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            job.log
                                .sublist(job.log.length > 10
                                    ? job.log.length - 10
                                    : 0)
                                .join('\n'),
                            style: AppTheme.mono(context, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
