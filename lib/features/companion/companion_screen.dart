import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/companion.dart';
import '../../l10n/app_localizations.dart';

/// Pairs this device with a desktop over the runtime's layer split.
///
/// The screen offers roles rather than a load percentage, because the
/// engine's measurements say a split buys memory and not speed: a token walks
/// the layers in order, so any configuration where both sides compute came
/// out slower than the faster side alone. What it does buy is a model this
/// device could not hold — a 34.7B MoE ran at 16.3 tok/s on a phone with 2 GB
/// free — and a desktop that can borrow this phone's memory.
class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  final _address = TextEditingController();
  final _token = TextEditingController();
  final _port = TextEditingController();
  bool _restored = false;

  /// The user asked for the desktop role, whether or not it took. Without
  /// this the fields would only appear once a peer was applied, and applying
  /// one needs an address — a fresh install could never enter the first one.
  bool _wantDesktop = false;

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    _port.dispose();
    super.dispose();
  }

  /// Fills the fields once, from the persisted configuration. Later rebuilds
  /// must not overwrite what the user is typing.
  void _restore(String address, String token, int workerPort) {
    if (_restored) return;
    _restored = true;
    _address.text = address;
    _token.text = token;
    _port.text = '$workerPort';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final companion = ref.watch(companionControllerProvider);
    final controller = ref.read(companionControllerProvider.notifier);
    final settings = ref.watch(settingsProvider).value;
    final loadedModel = ref.watch(engineControllerProvider).loadedModel;
    final supported = controller.supported;

    if (settings != null) {
      _restore(settings.companionAddress, settings.companionToken,
          settings.companionWorkerPort);
    }

    final overCable = CompanionConfig.isLoopback(_address.text);

    return Scaffold(
      appBar: AppBar(title: Text(l.companionTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            l.companionSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          if (!supported)
            _Banner(
              icon: Icons.info_outline,
              text: l.companionUnsupported,
              color: scheme.onSurfaceVariant,
            ),

          if (supported) ...[
            // --- where it computes ------------------------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.companionWhereTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SegmentedButton<CompanionRole>(
                      segments: [
                        ButtonSegment(
                          value: CompanionRole.local,
                          icon: const Icon(Icons.smartphone, size: 18),
                          label: Text(l.companionRoleLocal),
                        ),
                        ButtonSegment(
                          value: CompanionRole.desktop,
                          icon: const Icon(Icons.desktop_windows_outlined,
                              size: 18),
                          label: Text(l.companionRoleDesktop),
                        ),
                      ],
                      selected: {
                        companion.role == CompanionRole.desktop
                            ? CompanionRole.desktop
                            : CompanionRole.local
                      },
                      onSelectionChanged: companion.busy
                          ? null
                          : (selection) async {
                              final role = selection.first;
                              setState(() =>
                                  _wantDesktop = role == CompanionRole.desktop);
                              if (role == CompanionRole.desktop) {
                                await _saveFields();
                                await controller.useDesktop();
                              } else {
                                await controller.useLocal();
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      companion.role == CompanionRole.desktop
                          ? l.companionRoleDesktopHint
                          : l.companionRoleLocalHint,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),

                    if (_wantDesktop ||
                        companion.role == CompanionRole.desktop ||
                        _address.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _address,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l.companionAddress,
                          hintText: '127.0.0.1:9911',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: _address.text.isEmpty
                              ? null
                              : Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    overCable
                                        ? l.companionOverCable
                                        : l.companionOverWifi,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _token,
                        decoration: InputDecoration(
                          labelText: l.companionToken,
                          helperText: l.companionTokenHint,
                          helperMaxLines: 3,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (!overCable && _address.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _Banner(
                          icon: Icons.warning_amber_rounded,
                          text: l.companionWifiWarning,
                          color: scheme.error,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: companion.busy
                                ? null
                                : () async {
                                    await _saveFields();
                                    await controller.check();
                                  },
                            icon: companion.busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_ping, size: 18),
                            label: Text(l.companionCheck),
                          ),
                          const SizedBox(width: 12),
                          if (companion.lastCheckOk == true)
                            Expanded(
                              child: Text(
                                l.companionCheckOk,
                                style: TextStyle(
                                    fontSize: 12, color: scheme.primary),
                              ),
                            ),
                        ],
                      ),
                    ],

                    // The app's own refusals are translated; text from the
                    // runtime is shown verbatim, because it names the thing
                    // that went wrong ("wire version 4 != 5") and a
                    // translation would only make it harder to look up.
                    if (_faultText(l, companion.fault) case final String text)
                      ...[
                      const SizedBox(height: 10),
                      Text(text,
                          style:
                              TextStyle(color: scheme.error, fontSize: 12)),
                    ],
                    if (companion.error != null) ...[
                      const SizedBox(height: 10),
                      Text(companion.error!,
                          style:
                              TextStyle(color: scheme.error, fontSize: 12)),
                    ],
                    if (loadedModel == null) ...[
                      const SizedBox(height: 10),
                      _Banner(
                        icon: Icons.warning_amber_rounded,
                        text: l.companionNeedsModel,
                        color: scheme.error,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- serve layers to a desktop ----------------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.companionServeTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(l.companionRoleWorkerHint,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    if (companion.workerListening)
                      Row(
                        children: [
                          Icon(Icons.podcasts,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.companionWorkerListening(
                                  companion.workerListenAddress!),
                              style: AppTheme.mono(context, size: 12),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _port,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.companionWorkerPort,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: companion.busy || loadedModel == null
                                ? null
                                : () async {
                                    await _saveFields();
                                    await controller.startWorker();
                                  },
                            child: Text(l.companionWorkerStart),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Text(l.companionWorkerOneWay,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),

            // --- what the peer costs right now ------------------------------
            if (!companion.stats.isEmpty) ...[
              const SizedBox(height: 12),
              _PeerStatsCard(stats: companion.stats),
            ],
          ],

          const SizedBox(height: 16),
          _Note(text: l.companionSameModel),
          const SizedBox(height: 8),
          _Note(text: l.companionWireNote),
          const SizedBox(height: 8),
          _Note(text: l.companionTokenClearText),
        ],
      ),
    );
  }

  String? _faultText(AppLocalizations l, CompanionFault? fault) =>
      switch (fault) {
        CompanionFault.addressInvalid => l.companionErrorAddress,
        CompanionFault.modelNotLoaded => l.companionNeedsModel,
        null => null,
      };

  Future<void> _saveFields() async {
    final port = int.tryParse(_port.text.trim());
    await ref.read(settingsProvider.notifier).updateSettings((s) => s.copyWith(
          companionAddress: _address.text.trim(),
          companionToken: _token.text.trim(),
          companionWorkerPort:
              port != null && port > 0 && port < 65536 ? port : s.companionWorkerPort,
        ));
  }
}

class _PeerStatsCard extends StatelessWidget {
  const _PeerStatsCard({required this.stats});

  final PeerStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final clock = stats.clockFraction;
    // Below half its range on an active decode is the governor never waking
    // for a task that computes briefly and then blocks on a socket. It
    // measured as roughly half the throughput, so it is worth saying out loud
    // rather than leaving as a number nobody reads.
    final idling = clock != null && clock < 0.5;

    String orUnknown(String? value) => value ?? l.companionStatUnknown;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.companionStatsTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _StatRow(
              label: l.companionStatClock,
              value: orUnknown(clock == null
                  ? null
                  : '${(clock * 100).round()}%'
                      '  (${(stats.cpuKhzCurrent! / 1000).round()}'
                      '/${(stats.cpuKhzMax! / 1000).round()} MHz)'),
              alert: idling,
            ),
            _StatRow(
              label: l.companionStatTemp,
              value: orUnknown(stats.temperatureC == null
                  ? null
                  : '${stats.temperatureC!.toStringAsFixed(1)} °C'),
            ),
            _StatRow(
              label: l.companionStatMemory,
              value: orUnknown(stats.memAvailableKb == null
                  ? null
                  : '${(stats.memAvailableKb! / 1024 / 1024).toStringAsFixed(1)} GB'),
            ),
            _StatRow(
              label: l.companionStatThreads,
              value: orUnknown(stats.threads?.toString()),
            ),
            _StatRow(
              label: l.companionStatPlatform,
              value: orUnknown(stats.platform),
            ),
            if (idling) ...[
              const SizedBox(height: 8),
              Text(l.companionClockWarning,
                  style: TextStyle(fontSize: 11, color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Text(value,
              style: AppTheme.mono(context,
                  size: 12, color: alert ? scheme.error : null)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
