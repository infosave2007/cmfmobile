import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/companion.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../companion/companion_screen.dart';
import '../models/models_screen.dart';
import '../server/server_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final index = ref.watch(shellIndexProvider);
    final serverRunning = ref.watch(
        serverControllerProvider.select((s) => s.running));
    // A split is easy to forget about and changes where every reply comes
    // from, so the tab carries the same dot the server does.
    final companionActive = ref.watch(companionControllerProvider.select(
        (s) => s.role != CompanionRole.local || s.workerListening));

    // Engine failures (bad file, unsupported arch, OOM) must be loud —
    // a silent spinner reset reads as "nothing happened".
    ref.listen(engineControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.engineLoadFailed(next.error!)),
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
        ));
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ChatScreen(),
          ModelsScreen(),
          ServerScreen(),
          CompanionScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(shellIndexProvider.notifier).select(i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l.navChat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.layers_outlined),
            selectedIcon: const Icon(Icons.layers),
            label: l.navModels,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: serverRunning,
              smallSize: 8,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.wifi_tethering_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: serverRunning,
              smallSize: 8,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.wifi_tethering),
            ),
            label: l.navServer,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: companionActive,
              smallSize: 8,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.devices_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: companionActive,
              smallSize: 8,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.devices),
            ),
            label: l.navCompanion,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
