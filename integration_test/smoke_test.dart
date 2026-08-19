// Drives the real app on a real device: every bottom-tab screen, the import
// catalog and the server switch. Run with
//   flutter test integration_test/smoke_test.dart -d <device-id>
//
// Deliberately light on assertions and heavy on reporting: the point is to
// find out what a screen actually does on device, and a hard expect() on the
// first one would hide everything after it. Each check appends to [report],
// which is printed at the end.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cmf_mobile/app.dart';
import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/features/models/import_screen.dart';

final List<String> report = [];
void note(String line) {
  report.add(line);
  debugPrint('SMOKE | $line');
}

/// pumpAndSettle() never returns while a CircularProgressIndicator spins, and
/// several of these screens show one on purpose. Pump a fixed budget instead.
Future<void> settle(WidgetTester tester,
    {Duration budget = const Duration(seconds: 6)}) async {
  final end = budget.inMilliseconds ~/ 100;
  for (var i = 0; i < end; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
        listen: false);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CmfApp()));
    await settle(tester, budget: const Duration(seconds: 8));
  }

  testWidgets('engine: the native runtime is linked, not the demo fallback',
      (tester) async {
    await boot(tester);
    final isDemo = containerOf(tester).read(isDemoEngineProvider);
    note(isDemo
        ? 'ENGINE: FAIL — running the DEMO engine; libcortiq_ffi symbols did '
            'not resolve via DynamicLibrary.process()'
        : 'ENGINE: ok — native cortiq runtime resolved');
    expect(isDemo, isFalse,
        reason: 'device build fell back to the demo engine');
  });

  testWidgets('shell: every bottom-tab destination opens', (tester) async {
    await boot(tester);
    // Both icons per tab: NavigationDestination swaps in selectedIcon for
    // whichever tab is current, so the outline variant of the tab the app
    // opens on (Chat) is never in the tree.
    const tabs = <String, List<IconData>>{
      'Chat': [Icons.chat_bubble_outline, Icons.chat_bubble],
      'Models': [Icons.layers_outlined, Icons.layers],
      'Server': [Icons.wifi_tethering_outlined, Icons.wifi_tethering],
      'Companion': [Icons.devices_outlined, Icons.devices],
      'Settings': [Icons.tune_outlined, Icons.tune],
    };
    for (final entry in tabs.entries) {
      final icon = entry.value
          .map(find.byIcon)
          .firstWhere((f) => f.evaluate().isNotEmpty,
              orElse: () => find.byIcon(entry.value.first));
      if (icon.evaluate().isEmpty) {
        note('NAV ${entry.key}: FAIL — destination icon not found');
        continue;
      }
      await tester.tap(icon.first);
      await settle(tester, budget: const Duration(seconds: 3));
      final errors = find.byType(ErrorWidget);
      note('NAV ${entry.key}: ${errors.evaluate().isEmpty ? "ok" : "FAIL — "
          "ErrorWidget on screen"}');
    }
  });

  testWidgets('import: the ready-CMF catalog loads', (tester) async {
    await boot(tester);
    await tester.tap(find.byIcon(Icons.layers_outlined).first);
    await settle(tester, budget: const Duration(seconds: 3));

    final hf = find.byIcon(Icons.cloud_download_outlined);
    if (hf.evaluate().isEmpty) {
      note('IMPORT: FAIL — "get from HF" button not reachable');
      return;
    }
    await tester.tap(hf.first);
    // The catalog is one author listing plus a file tree per repo, over the
    // phone's own connection: give it a real budget, not a widget-test one.
    await settle(tester, budget: const Duration(seconds: 45));

    expect(find.byType(ImportScreen), findsOneWidget,
        reason: 'import screen did not open');

    final cards = find.byType(Card);
    final retry = find.byType(FilledButton);
    final spinner = find.byType(CircularProgressIndicator);
    if (cards.evaluate().isNotEmpty) {
      note('IMPORT: ok — catalog rendered ${cards.evaluate().length} entries');
    } else if (retry.evaluate().isNotEmpty) {
      // The error text sits right above the retry button.
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .toList();
      note('IMPORT: FAIL — catalog errored: ${texts.join(" | ")}');
    } else if (spinner.evaluate().isNotEmpty) {
      note('IMPORT: FAIL — still spinning after 45 s');
    } else {
      note('IMPORT: FAIL — catalog empty, no error, no spinner');
    }
  });

  testWidgets('server: the switch starts the OpenAI-compatible server',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined).first);
    await settle(tester, budget: const Duration(seconds: 3));

    final toggle = find.byType(Switch);
    if (toggle.evaluate().isEmpty) {
      note('SERVER: FAIL — no switch on the screen');
      return;
    }
    await tester.tap(toggle.first);
    // First start on iOS raises the system Local Network prompt; that dialog
    // is outside the app, so a false here may mean "not granted", not "broken".
    await settle(tester, budget: const Duration(seconds: 12));
    final state = containerOf(tester).read(serverControllerProvider);
    note('SERVER: running=${state.running} starting=${state.starting} '
        'error=${state.error ?? "none"}');
    if (state.running) {
      await tester.tap(find.byType(Switch).first);
      await settle(tester, budget: const Duration(seconds: 5));
      note('SERVER: stopped=${!containerOf(tester)
          .read(serverControllerProvider).running}');
    }
  });

  tearDownAll(() {
    debugPrint('===== SMOKE SUMMARY =====');
    for (final line in report) {
      debugPrint(line);
    }
    debugPrint('=========================');
  });
}
