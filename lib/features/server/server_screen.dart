import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/formats.dart';
import '../../l10n/app_localizations.dart';

class ServerScreen extends ConsumerWidget {
  const ServerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final server = ref.watch(serverControllerProvider);
    final settings = ref.watch(settingsProvider).value;
    final engineState = ref.watch(engineControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.serverTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            l.serverSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          // Power card.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (server.running
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant)
                              .withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.wifi_tethering,
                          color: server.running
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server.starting
                                  ? l.serverStarting
                                  : server.running
                                      ? l.serverRunning
                                      : l.serverStopped,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                            ),
                            Text(
                              ':${server.running ? server.port : settings?.serverPort ?? 8080}'
                              ' · /v1',
                              style: AppTheme.mono(context,
                                  size: 12,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: server.running || server.starting,
                        onChanged: server.starting
                            ? null
                            : (on) => on
                                ? ref
                                    .read(serverControllerProvider
                                        .notifier)
                                    .start()
                                : ref
                                    .read(serverControllerProvider
                                        .notifier)
                                    .stop(),
                      ),
                    ],
                  ),
                  if (server.error != null) ...[
                    const SizedBox(height: 8),
                    Text(server.error!,
                        style: TextStyle(
                            color: scheme.error, fontSize: 12)),
                  ],
                  if (engineState.loadedModel == null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l.serverNoModelWarning,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (server.running) ...[
                    const SizedBox(height: 8),
                    Text(l.serverKeepAwakeNote,
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),

          if (server.running && server.urls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.serverAddresses,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: server.urls.first,
                          size: 168,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(l.serverQrHint,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                    ),
                    const SizedBox(height: 8),
                    for (final url in server.urls)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text(url, style: AppTheme.mono(context, size: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(l.copiedToClipboard)));
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Auth card.
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.serverAuthRequire,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(l.serverAuthHint,
                        style: const TextStyle(fontSize: 11)),
                    value: settings?.serverAuthEnabled ?? false,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings((s) => s.copyWith(serverAuthEnabled: v)),
                  ),
                  if (settings?.serverAuthEnabled == true)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l.serverAccessToken,
                          style: const TextStyle(fontSize: 12)),
                      subtitle: Text(settings?.serverToken ?? '',
                          style: AppTheme.mono(context, size: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: settings?.serverToken ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(l.copiedToClipboard)));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (server.running) ...[
            const SizedBox(height: 12),
            // Stats grid.
            Row(
              children: [
                _StatCard(
                    label: l.serverStatRequests,
                    value: '${server.requestCount}'),
                const SizedBox(width: 8),
                _StatCard(
                    label: l.serverStatErrors,
                    value: '${server.errorCount}'),
                const SizedBox(width: 8),
                _StatCard(
                  label: l.serverStatTokens,
                  value: formatCount(
                      server.promptTokens + server.completionTokens),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(
                  label: l.serverStatSpeed,
                  value: l.statsTokensPerSecond(
                      server.tokensPerSecond.toStringAsFixed(1)),
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: l.serverStatUptime,
                  value: server.startedAt == null
                      ? '—'
                      : formatDurationShort(
                          DateTime.now().difference(server.startedAt!)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.serverRecentRequests,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (server.requests.isEmpty)
                      Text(l.serverNoRequestsYet,
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant))
                    else
                      for (final r in server.requests.take(20))
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: r.ok
                                      ? scheme.primary
                                      : scheme.error,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${DateFormat.Hms().format(r.timestamp)} '
                                  '${r.method} ${r.path}',
                                  style:
                                      AppTheme.mono(context, size: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${r.statusCode} · ${r.latencyMs}ms'
                                '${r.completionTokens > 0 ? ' · ↓${r.completionTokens}' : ''}',
                                style: AppTheme.mono(context,
                                    size: 11,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.serverEndpointsTitle,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    'POST /v1/chat/completions\n'
                    'POST /v1/completions\n'
                    'GET  /v1/models\n'
                    'GET  /v1/cortiq/status\n'
                    'GET  /v1/cortiq/masks\n'
                    'POST /v1/cortiq/switch\n'
                    'GET  /healthz',
                    style: AppTheme.mono(context,
                        size: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(value,
                  style: AppTheme.mono(context, size: 16)
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
