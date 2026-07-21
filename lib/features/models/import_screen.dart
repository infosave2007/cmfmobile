import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/formats.dart';
import '../../data/models/conversion.dart';
import '../../l10n/app_localizations.dart';

/// Ready-to-run .cmf repos pinned above the search results — one tap to
/// download, no conversion needed.
const featuredRepos = [
  'infosave/Bonsai-1.7Bcmf',
  'infosave/Bonsai-8B_2bit_cmf',
  'infosave/Bonsai-27Bcmf',
];

class _FeaturedEntry {
  const _FeaturedEntry(this.model, this.cmfSizeBytes);
  final HfModel model;
  final int cmfSizeBytes;
}

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
  List<_FeaturedEntry> _featured = const [];

  Future<void> _loadFeatured() async {
    final hf = ref.read(hfApiProvider);
    final token = ref.read(settingsProvider).value?.hfToken;
    final entries = <_FeaturedEntry>[];
    for (final repo in featuredRepos) {
      try {
        final model = await hf.fetchModel(repo, token: token);
        final files = await hf.listFiles(repo, token: token);
        final size = files
            .where((f) => f.path.toLowerCase().endsWith('.cmf'))
            .fold<int>(0, (s, f) => s + f.size);
        entries.add(_FeaturedEntry(model, size));
      } catch (_) {
        // Featured cards are best-effort; search still works offline.
      }
    }
    if (mounted) setState(() => _featured = entries);
  }

  @override
  void initState() {
    super.initState();
    _loadFeatured();
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

  /// One tap on a featured .cmf repo starts the direct download — no
  /// conversion, nothing to configure.
  Future<void> _startDirect(HfModel model) async {
    final settings = ref.read(settingsProvider).value;
    await ref.read(converterProvider).start(
          repo: model.id,
          quant: QuantType.q8_2f, // ignored: the repo ships .cmf
          hfToken: settings?.hfToken,
          threads: settings?.threads ?? 4,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).importStartedSnack)));
    _tabs.animateTo(1);
  }

  Widget _buildResultsList(AppLocalizations l) {
    final results = _results!
        .where((m) => !featuredRepos.contains(m.id))
        .toList();
    final showFeatured = _featured.isNotEmpty;
    if (!showFeatured && results.isEmpty) {
      return Center(child: Text(l.importNoResults));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (showFeatured) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l.importFeaturedTitle,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          for (final entry in _featured)
            _FeaturedCard(entry: entry, onTap: () => _startDirect(entry.model)),
          const SizedBox(height: 10),
        ],
        for (final model in results)
          _HfModelCard(model: model, onTap: () => _configure(model)),
      ],
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
                  : _buildResultsList(l),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.entry, required this.onTap});

  final _FeaturedEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final model = entry.model;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.primary.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.bolt, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.id,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l.importReadyCmfBadge,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (entry.cmfSizeBytes > 0)
                          Text(
                            formatBytes(entry.cmfSizeBytes),
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.download_for_offline_outlined,
                  color: scheme.primary),
            ],
          ),
        ),
      ),
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
        QuantType.q1t => l.quantQ1tDesc,
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
              // On-device-only quants that would fail for a safetensors repo
              // are disabled — a repo that ships .cmf downloads directly with
              // any of the enabled ones (the quant is ignored there).
              for (final q in QuantType.values)
                RadioListTile<QuantType>(
                  value: q,
                  // ignore: deprecated_member_use
                  groupValue: _quant,
                  // ignore: deprecated_member_use
                  onChanged: q.supportedOnDevice
                      ? (v) => setState(() => _quant = v!)
                      : null,
                  dense: true,
                  title: Row(
                    children: [
                      Text(q.label),
                      if (!q.supportedOnDevice) ...[
                        const SizedBox(width: 8),
                        Text(
                          l.quantDesktopOnly,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                  '${job.repo} · ${job.displayQuant}'
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
