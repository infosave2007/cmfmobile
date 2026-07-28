import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/util/formats.dart';
import '../../data/models/settings.dart';
import '../../data/services/inference/engine_tuning.dart';
import '../../l10n/app_localizations.dart';

/// Languages shipped by the app — the same seven as cortiq-gateway.
const appLanguages = <(String, String)>[
  ('en', 'English'),
  ('ru', 'Русский'),
  ('de', 'Deutsch'),
  ('fr', 'Français'),
  ('es', 'Español'),
  ('zh', '中文'),
  ('tr', 'Türkçe'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);
    final models = ref.watch(modelsProvider).value ?? const [];
    final engine = ref.watch(engineProvider);
    final gpuBackend = engine.gpuBackendAvailable;
    final appVersion = ref.watch(appVersionProvider).value ?? '';
    final storageBytes =
        models.fold<int>(0, (sum, m) => sum + m.sizeBytes);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Section(title: l.settingsAppearance, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsTheme),
              trailing: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto, size: 16),
                      tooltip: l.settingsThemeSystem),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode, size: 16),
                      tooltip: l.settingsThemeLight),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode, size: 16),
                      tooltip: l.settingsThemeDark),
                ],
                selected: {settings.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (set) => notifier
                    .updateSettings((s) => s.copyWith(themeMode: set.first)),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsLanguage),
              trailing: DropdownButton<String?>(
                value: settings.localeCode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                      value: null,
                      child: Text(l.settingsLanguageSystem)),
                  for (final (code, name) in appLanguages)
                    DropdownMenuItem(value: code, child: Text(name)),
                ],
                onChanged: (code) => notifier.updateSettings((s) => code == null
                    ? s.copyWith(clearLocale: true)
                    : s.copyWith(localeCode: code)),
              ),
            ),
          ]),

          _Section(title: l.settingsGeneration, children: [
            _SliderTile(
              label: l.settingsTemperature,
              value: settings.temperature,
              min: 0,
              max: 2,
              divisions: 40,
              display: settings.temperature.toStringAsFixed(2),
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(temperature: v)),
            ),
            _SliderTile(
              label: l.settingsTopP,
              value: settings.topP,
              min: 0.05,
              max: 1,
              divisions: 19,
              display: settings.topP.toStringAsFixed(2),
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(topP: v)),
            ),
            _SliderTile(
              label: l.settingsMaxTokens,
              value: settings.maxTokens.toDouble(),
              min: 64,
              max: 8192,
              divisions: 127,
              display: '${settings.maxTokens}',
              onChanged: (v) => notifier
                  .updateSettings((s) => s.copyWith(maxTokens: v.round())),
            ),
            _SliderTile(
              label: l.settingsThreads,
              value: settings.threads.toDouble(),
              min: 0,
              max: 8,
              divisions: 8,
              display: settings.threads == 0
                  ? l.settingsThreadsAuto(EngineTuning.resolveThreads(0))
                  : '${settings.threads}',
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(threads: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l.settingsThreadsHint,
                  style: const TextStyle(fontSize: 11)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsUseGpu),
              // The switch reaches cortiq_set_gpu either way; whether
              // anything acts on it depends on the bundled runtime having a
              // Vulkan/Metal backend linked in (native/TUNING.md). Only a
              // runtime that says so — via the optional cortiq_gpu_available
              // — earns the note being dropped.
              subtitle: Text(
                gpuBackend == true
                    ? l.settingsUseGpuHint
                    : '${l.settingsUseGpuHint}\n${l.settingsUseGpuNeedsBackend}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: gpuBackend != true,
              value: settings.useGpu,
              onChanged: (v) {
                notifier.updateSettings((s) => s.copyWith(useGpu: v));
                engine.setGpu(v);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsDisableThinking),
              subtitle: Text(l.settingsDisableThinkingHint,
                  style: const TextStyle(fontSize: 11)),
              value: settings.disableThinking,
              onChanged: (v) => notifier
                  .updateSettings((s) => s.copyWith(disableThinking: v)),
            ),
          ]),

          _Section(title: l.settingsEngineSection, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                initialValue: settings.engineFlags,
                maxLines: 4,
                minLines: 2,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: l.settingsEngineFlags,
                  helperText: l.settingsEngineFlagsHint,
                  helperMaxLines: 3,
                  hintText: 'CMF_REPACK=1',
                ),
                onChanged: (v) =>
                    notifier.updateSettings((s) => s.copyWith(engineFlags: v)),
              ),
            ),
          ]),

          _Section(title: l.settingsServerSection, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsServerPort),
              subtitle: Text(l.settingsServerPortHint,
                  style: const TextStyle(fontSize: 11)),
              trailing: SizedBox(
                width: 96,
                child: TextFormField(
                  initialValue: '${settings.serverPort}',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onFieldSubmitted: (v) {
                    final port = int.tryParse(v);
                    if (port != null && port > 0 && port < 65536) {
                      notifier
                          .updateSettings((s) => s.copyWith(serverPort: port));
                    }
                  },
                ),
              ),
            ),
          ]),

          _Section(title: l.settingsHfSection, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                initialValue: settings.hfToken,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.settingsHfToken,
                  hintText: l.settingsHfTokenHint,
                ),
                onFieldSubmitted: (v) =>
                    notifier.updateSettings((s) => s.copyWith(hfToken: v.trim())),
              ),
            ),
          ]),

          _Section(title: l.settingsStorage, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sd_storage_outlined),
              title: Text(l.settingsStorageUsage(
                  formatBytes(storageBytes), models.length)),
            ),
          ]),

          _Section(title: l.settingsAbout, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(l.settingsVersionLine(appVersion)),
              subtitle: Text(l.settingsAboutLine(engine.name)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(display,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
