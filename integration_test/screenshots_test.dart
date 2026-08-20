// Drives the app through the App Store screenshot set on a simulator.
//
//   xcrun simctl boot <udid>
//   # seed a .cmf into the app container, then:
//   flutter test integration_test/screenshots_test.dart -d <udid>
//
// The capture itself is done from the host with `xcrun simctl io screenshot`,
// because that grabs the whole device surface including the status bar —
// takeScreenshot() only returns the Flutter view and would drop it. The two
// sides meet through a marker file: this test writes
// `Documents/.shot/<name>`, the host script sees it, captures, and deletes
// it. The dwell below is a ceiling, not a fixed sleep, so a fast host does
// not wait and a slow one is not raced.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cmf_mobile/app.dart';

late Directory shotDir;

Future<void> pumpFor(WidgetTester tester, Duration d) async {
  for (var i = 0; i < d.inMilliseconds ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Asks the host for a screenshot and waits until it confirms by deleting the
/// marker. Keeps pumping so the UI stays live while the host captures.
Future<void> shoot(WidgetTester tester, String name) async {
  final marker = File('${shotDir.path}/$name');
  await marker.writeAsString('go');
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!marker.existsSync()) {
      debugPrint('SHOT | $name captured');
      return;
    }
  }
  debugPrint('SHOT | $name TIMED OUT — host never captured');
}

/// Taps the first hit of [finder] if it is there, and says so either way.
Future<bool> tapIfPresent(WidgetTester tester, Finder finder, String what,
    {Duration settle = const Duration(seconds: 3)}) async {
  if (finder.evaluate().isEmpty) {
    debugPrint('SHOT | skipped: $what not found');
    return false;
  }
  await tester.tap(finder.first, warnIfMissed: false);
  await pumpFor(tester, settle);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture the store screenshot set', (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    shotDir = Directory('${docs.path}/.shot');
    await shotDir.create(recursive: true);

    // `flutter test integration_test` reinstalls the app, and that wipes the
    // data container — so the model cannot be seeded from the host before the
    // run. A simulator app can read host paths, so copy it in from here.
    const seed = String.fromEnvironment('SEED_MODEL');
    final models = Directory('${docs.path}/models');
    await models.create(recursive: true);
    final dest = File('${models.path}/${seed.split('/').last}');
    if (seed.isEmpty) {
      debugPrint('SHOT | no SEED_MODEL given — library will be empty');
    } else if (dest.existsSync()) {
      debugPrint('SHOT | model already in place');
    } else if (File(seed).existsSync()) {
      await File(seed).copy(dest.path);
      debugPrint('SHOT | seeded ${await dest.length()} bytes');
    } else {
      debugPrint('SHOT | seed unreadable from the sandbox: $seed');
    }

    await tester.pumpWidget(const ProviderScope(child: CmfApp()));
    await pumpFor(tester, const Duration(seconds: 8));

    // --- Model library, with the seeded model listed ---
    await tapIfPresent(tester, find.byIcon(Icons.layers_outlined), 'Models tab');
    await shoot(tester, '02_models');

    // --- Load the model into the engine, so the chat is a real one ---
    if (await tapIfPresent(tester, find.text('Load into engine'), 'load button',
        settle: const Duration(seconds: 5))) {
      // Loading a 319 MB file on a simulator is not instant.
      for (var i = 0; i < 24; i++) {
        await pumpFor(tester, const Duration(seconds: 5));
        if (find.text('loaded').evaluate().isNotEmpty) break;
      }
      debugPrint('SHOT | model loaded: '
          '${find.text('loaded').evaluate().isNotEmpty}');
    }

    // --- Hugging Face catalog ---
    if (await tapIfPresent(
        tester, find.byIcon(Icons.cloud_download_outlined), 'HF button')) {
      await pumpFor(tester, const Duration(seconds: 25));
      await shoot(tester, '03_huggingface');
      await tapIfPresent(tester, find.byType(BackButton), 'back');
    }

    // --- Chat: ask something real and wait for the model to answer ---
    await tapIfPresent(tester, find.byIcon(Icons.chat_bubble_outline), 'Chat tab');
    final field = find.byType(TextField);
    if (field.evaluate().isNotEmpty) {
      await tester.enterText(field.first,
          'Write a SQL query that sums revenue by month.');
      await pumpFor(tester, const Duration(seconds: 1));
      await tapIfPresent(tester, find.byIcon(Icons.arrow_upward), 'send',
          settle: const Duration(seconds: 2));
      // Generation on a simulator CPU takes its time; stop early once the
      // stop button is gone, which means the reply finished.
      for (var i = 0; i < 60; i++) {
        await pumpFor(tester, const Duration(seconds: 5));
        if (find.byIcon(Icons.stop).evaluate().isEmpty && i > 2) break;
      }
    }
    await shoot(tester, '01_home');
    await shoot(tester, '04_chat');

    // --- Server ---
    await tapIfPresent(tester, find.byIcon(Icons.wifi_tethering_outlined), 'Server tab');
    final toggle = find.byType(Switch);
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle.first, warnIfMissed: false);
      await pumpFor(tester, const Duration(seconds: 6));
    }
    await shoot(tester, '05_server');
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(find.byType(Switch).first, warnIfMissed: false);
      await pumpFor(tester, const Duration(seconds: 3));
    }

    // --- Split / Companion: the feature the July set predates ---
    await tapIfPresent(tester, find.byIcon(Icons.devices_outlined), 'Split tab');
    await shoot(tester, '07_split');

    // --- Settings ---
    await tapIfPresent(tester, find.byIcon(Icons.tune_outlined), 'Settings tab');
    await shoot(tester, '06_settings');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
