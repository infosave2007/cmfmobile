import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/formats.dart';
import '../../data/models/conversion.dart';
import '../../data/services/hf_api.dart';
import '../../data/services/inference/engine_tuning.dart';
import '../../l10n/app_localizations.dart';

/// The account whose ready-to-run .cmf repos are pinned above the search
/// results. The list itself is fetched live — every repo there tagged `cmf`
/// appears, so publishing a new one needs no app release. (The old approach
/// hardcoded three repo ids and silently ignored the rest of the account.)
const featuredAuthor = 'infosave';

/// A repo whose tags say it ships ready .cmf files. Cheap (tags come with
/// the search response); the authoritative check — listing the actual files —
/// happens when the repo is tapped.
bool looksLikeCmfRepo(HfModel model) => model.tags.contains('cmf');

/// Modalities this app cannot run: it is a text chat, so image, video and
/// music CMFs — valid files for the desktop tools — would only dead-end
/// here. They stay reachable through search; they are just not recommended.
const _nonTextTags = {
  'text-to-image',
  'text-to-video',
  'text-to-audio',
  'image-to-video',
  'diffusion',
  'video',
  'music',
  'audio',
};

bool isTextGenerationRepo(HfModel model) =>
    model.tags.toSet().intersection(_nonTextTags).isEmpty;

/// The quantization a ready-CMF repo carries, best effort: the file name is
/// authoritative when it says (bonsai-1.7b-q1.cmf), repo tags fall back
/// (q4tp / 2-bit / bitnet …). Empty when neither speaks.
String quantLabelFor(String? largestCmfName, List<String> tags) {
  const known = ['q8_2f', 'q4tp', 'q2tp', 'q1t', 'vbit', 'f16'];
  final name = (largestCmfName ?? '').toLowerCase();
  for (final q in known) {
    if (name.contains(q)) return q.toUpperCase();
  }
  // Plain q1/q8/q4 only match as a delimited token: "q1" inside "q1t" or a
  // hash must not count.
  final short = RegExp(r'(?:^|[-_.])(q[148])(?:[-_.]|$)').firstMatch(name);
  if (short != null) return short.group(1)!.toUpperCase();
  for (final q in known) {
    if (tags.contains(q)) return q.toUpperCase();
  }
  if (tags.contains('bitnet') || tags.contains('1-bit')) return 'Q1';
  if (tags.contains('2-bit')) return '2-BIT';
  if (tags.contains('4-bit')) return '4-BIT';
  return '';
}

class _FeaturedEntry {
  const _FeaturedEntry(
    this.model,
    this.cmfSizeBytes, {
    this.tooBig = false,
    this.quant = '',
  });
  final HfModel model;
  final int cmfSizeBytes;

  /// The file is bigger than this device can realistically hold in memory —
  /// still downloadable (the split needs the same file on both sides), but
  /// the card says so instead of letting a 12 GB download end in an OOM.
  final bool tooBig;

  /// Quantization shown as a chip; empty when unknown.
  final String quant;
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
  // Ready CMF | Convert from HF | Jobs. Two separate entry points, as asked:
  // the ready catalog is a place of its own, and typing in search shows
  // results immediately instead of scrolling past the catalog first.
  late final TabController _tabs = TabController(length: 3, vsync: this);
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
    try {
      final repos = await hf.listAuthorModels(featuredAuthor, token: token);
      // Text-generation CMF repos only: this app cannot run image, video or
      // music models, and a toolkit repo tagged cmf ships no model at all.
      final cmfRepos =
          repos.where(looksLikeCmfRepo).where(isTextGenerationRepo).toList();
      final totalRam =
          await ref.read(deviceResourcesProvider).totalRamBytes();
      // Sizes come from per-repo file listings — fetched in parallel.
      final entries = await Future.wait(cmfRepos.map((model) async {
        var size = 0;
        String? largestName;
        try {
          final files = await hf.listFiles(model.id, token: token);
          final cmf = files
              .where((f) => f.path.toLowerCase().endsWith('.cmf'))
              .toList()
            ..sort((a, b) => b.size.compareTo(a.size));
          size = cmf.fold<int>(0, (s, f) => s + f.size);
          if (cmf.isNotEmpty) largestName = cmf.first.path;
        } catch (_) {}
        return _FeaturedEntry(
          model,
          size,
          // Weights alone nearly filling RAM means decode would page — the
          // same judgement the load-time check makes, applied before a
          // multi-gigabyte download instead of after it.
          tooBig: totalRam > 0 && size > totalRam * 0.7,
          quant: quantLabelFor(largestName, model.tags),
        );
      }));
      // Phone-sized first: sort by what actually fits, small to large. Repos
      // with no .cmf file at all are dropped, not shown empty.
      final withFiles = entries.where((e) => e.cmfSizeBytes > 0).toList()
        ..sort((a, b) => a.cmfSizeBytes.compareTo(b.cmfSizeBytes));
      if (mounted) setState(() => _featured = withFiles);
    } catch (_) {
      // Featured cards are best-effort; search still works offline.
    }
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
    // The sheet resolves the repo's contents FIRST. A repo that ships ready
    // .cmf files gets a download panel — never the quantization list, which
    // used to offer to "convert" a file that needs no conversion.
    final token = ref.read(settingsProvider).value?.hfToken;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _RepoSheet(
        model: model,
        resolveFiles: () =>
            ref.read(hfApiProvider).listFiles(model.id, token: token),
        onDownloadReady: () {
          Navigator.pop(sheetContext);
          _startDirect(model);
        },
        onStartConvert: (quant, name) async {
          Navigator.pop(sheetContext);
          final settings = ref.read(settingsProvider).value;
          await ref.read(converterProvider).start(
                repo: model.id,
                quant: quant,
                name: name,
                hfToken: settings?.hfToken,
                threads: EngineTuning.resolveThreads(settings?.threads ?? 0),
              );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(AppLocalizations.of(context).importStartedSnack)));
          _tabs.animateTo(2);
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
            Tab(text: l.importTabReady),
            Tab(text: l.importTabConvert),
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
          _buildReadyTab(l),
          _buildSearchTab(l),
          _JobsTab(jobs: jobs),
        ],
      ),
    );
  }

  /// The ready-CMF catalog: every text model of the account, smallest first,
  /// one tap to download. No search box in the way and nothing to configure.
  Widget _buildReadyTab(AppLocalizations l) {
    if (_featured.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final entry in _featured)
          _FeaturedCard(entry: entry, onTap: () => _startDirect(entry.model)),
      ],
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
          threads: EngineTuning.resolveThreads(settings?.threads ?? 0),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).importStartedSnack)));
    _tabs.animateTo(2);
  }

  Widget _buildResultsList(AppLocalizations l) {
    final results = _results!;
    if (results.isEmpty) {
      return Center(child: Text(l.importNoResults));
    }
    // Results only — the ready catalog lives on its own tab, so the first
    // typed letters show matches immediately instead of the same pinned list.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
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
                    // Wrap, not Row: the badge is a sentence in some locales
                    // and was pushing the size off the card's edge — clipped
                    // text where the one number the user needs should be.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                        if (entry.quant.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.quant,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ),
                        if (entry.cmfSizeBytes > 0)
                          Text(
                            formatBytes(entry.cmfSizeBytes),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant),
                          ),
                        if (entry.tooBig)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  scheme.errorContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l.importTooBigBadge,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onErrorContainer),
                            ),
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
                  // A repo tagged `cmf` will download directly — say so in
                  // the list, before the tap.
                  if (looksLikeCmfRepo(model))
                    Container(
                      margin: const EdgeInsets.only(left: 6),
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
                    // Flexible: "automatic-speech-recognition" was pushing
                    // the download/like counters off the card.
                    Flexible(
                      child: Text(model.pipelineTag!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant)),
                    ),
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

/// Resolves what a repo actually ships before offering anything: ready .cmf
/// files download as-is; safetensors repos get the quantization list, each
/// option carrying an estimated output size so the choice is informed before
/// a multi-gigabyte download starts.
class _RepoSheet extends StatefulWidget {
  const _RepoSheet({
    required this.model,
    required this.resolveFiles,
    required this.onDownloadReady,
    required this.onStartConvert,
  });

  final HfModel model;
  final Future<List<HfFileEntry>> Function() resolveFiles;
  final VoidCallback onDownloadReady;
  final void Function(QuantType quant, String name) onStartConvert;

  @override
  State<_RepoSheet> createState() => _RepoSheetState();
}

class _RepoSheetState extends State<_RepoSheet> {
  late final TextEditingController _name = TextEditingController(
      text: widget.model.id.split('/').last.toLowerCase());
  QuantType _quant = QuantType.q4tp;

  List<HfFileEntry>? _files;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.resolveFiles().then((files) {
      if (mounted) setState(() => _files = files);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  HfFileEntry? get _readyCmf {
    final cmf = _files
        ?.where((f) => f.path.toLowerCase().endsWith('.cmf'))
        .toList();
    if (cmf == null || cmf.isEmpty) return null;
    cmf.sort((a, b) => b.size.compareTo(a.size));
    return cmf.first;
  }

  /// Source weight bytes = every safetensors shard in the repo root.
  int get _weightBytes => _files == null
      ? 0
      : _files!
          .where((f) =>
              f.path.endsWith('.safetensors') && !f.path.contains('/'))
          .fold(0, (s, f) => s + f.size);

  /// Estimated .cmf size for [q]: source stores ~2 bytes per weight, so
  /// weights ≈ bytes/2, times the profile's bytes-per-weight.
  int _estimate(QuantType q) => (_weightBytes / 2 * q.bytesPerWeight).round();

  String _quantDescription(AppLocalizations l, QuantType q) => switch (q) {
        QuantType.q8_2f => l.quantQ8_2fDesc,
        QuantType.q4tp => l.quantQ4tpDesc,
        QuantType.q2tp => l.quantQ2tpDesc,
        QuantType.q8Row => l.quantQ8RowDesc,
        QuantType.q1t => l.quantQ1tDesc,
        QuantType.q4Block => l.quantQ4Desc,
        QuantType.vbit => l.quantVbitDesc,
        QuantType.q1 => l.quantQ1Desc,
        QuantType.f16 => l.quantF16Desc,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
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
              Text(
                _readyCmf != null
                    ? l.importReadyCmfTitle
                    : l.importConfigureTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(widget.model.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!,
                    style: TextStyle(color: scheme.error, fontSize: 12))
              else if (_files == null)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(l.importCheckingRepo,
                        style: const TextStyle(fontSize: 13)),
                  ],
                )
              else if (_readyCmf != null)
                ..._buildReadyPanel(l, scheme)
              else
                ..._buildConvertPanel(l, scheme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReadyPanel(AppLocalizations l, ColorScheme scheme) {
    final file = _readyCmf!;
    return [
      Text(l.importReadyCmfBody, style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(file.path,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            if (file.size > 0)
              Text(formatBytes(file.size),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.download_for_offline_outlined),
          label: Text(l.importDownloadButton),
          onPressed: widget.onDownloadReady,
        ),
      ),
    ];
  }

  List<Widget> _buildConvertPanel(AppLocalizations l, ColorScheme scheme) {
    return [
      TextField(
        controller: _name,
        decoration: InputDecoration(
          labelText: l.importOutputName,
          helperText: l.importOutputNameHint,
        ),
      ),
      const SizedBox(height: 12),
      if (_weightBytes > 0)
        Text(l.importDownloadSize(formatBytes(_weightBytes)),
            style:
                TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      Text(l.importQuantization,
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
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
                      fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              // The number that used to be discoverable only by running the
              // whole conversion: what this choice costs on disk.
              if (_weightBytes > 0 && q.supportedOnDevice)
                Text(
                  l.importEstimatedOutput(formatBytes(_estimate(q))),
                  style: TextStyle(
                      fontSize: 12,
                      color: q == _quant
                          ? scheme.primary
                          : scheme.onSurfaceVariant),
                ),
            ],
          ),
          subtitle: Text(_quantDescription(l, q),
              style: const TextStyle(fontSize: 11)),
        ),
      const SizedBox(height: 4),
      if (_weightBytes > 0)
        Text(l.importEstimateNote,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
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
              widget.onStartConvert(_quant, _name.text.trim()),
        ),
      ),
    ];
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
