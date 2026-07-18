import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/util/formats.dart';
import '../../data/models/local_model.dart';
import '../../l10n/app_localizations.dart';

/// Loads [model] into the engine, first checking the device has enough RAM;
/// if it likely doesn't, asks the user to confirm.
Future<void> loadModelWithMemoryCheck(
    BuildContext context, WidgetRef ref, LocalModel model) async {
  final check = await ref.read(deviceResourcesProvider).checkFit(model);
  if (!context.mounted) return;

  if (!check.fits) {
    final l = AppLocalizations.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.memory),
        title: Text(l.memoryWarnTitle),
        content: Text(l.memoryWarnBody(
          formatBytes(check.requiredBytes),
          formatBytes(check.totalRamBytes),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.memoryWarnLoadAnyway),
          ),
        ],
      ),
    );
    if (proceed != true) return;
  }
  await ref.read(engineControllerProvider.notifier).loadModel(model);
}
