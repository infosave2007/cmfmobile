import 'package:cmf_mobile/features/settings/settings_screen.dart';
import 'package:cmf_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('thread count defaults to auto and names the pool size',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpSettings(tester);

    expect(find.textContaining('Auto ('), findsOneWidget);
  });

  testWidgets('an install on the old default of 4 threads is migrated to auto',
      (tester) async {
    SharedPreferences.setMockInitialValues({'threads': 4});
    await _pumpSettings(tester);

    expect(find.textContaining('Auto ('), findsOneWidget);
  });

  testWidgets('a thread count the user picked is left alone', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'threads': 6, 'settingsSchema': 1});
    await _pumpSettings(tester);

    expect(find.textContaining('Auto ('), findsNothing);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('the GPU switch stays, and says what it still needs',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpSettings(tester);

    // No native runtime under the test host, so the engine is the demo one,
    // which reports no GPU backend — the same shape as a mobile build
    // without Vulkan/Metal linked in.
    expect(find.text('Use GPU (Vulkan/Metal)'), findsOneWidget);
    expect(find.textContaining('Vulkan/Metal backend'), findsOneWidget);
  });

  testWidgets('engine flags are editable and persisted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpSettings(tester);

    final field = find.widgetWithText(TextFormField, 'Engine flags (advanced)');
    await tester.scrollUntilVisible(field, 120);
    await tester.enterText(field, 'CMF_REPACK=1');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('engineFlags'), 'CMF_REPACK=1');
  });
}
