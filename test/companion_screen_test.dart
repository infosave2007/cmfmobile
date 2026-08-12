import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:cmf_mobile/features/companion/companion_screen.dart';
import 'package:cmf_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool supportsCompanion = true,
    String address = '',
    Locale locale = const Locale('en'),
  }) async {
    // The screen is a ListView, which does not build children below the fold —
    // a surface tall enough to hold the whole page keeps the finders honest
    // about what is on it rather than about where the viewport ends.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'companionAddress': address});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          engineProvider.overrideWithValue(
              _FakeEngine(supportsCompanion: supportsCompanion)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CompanionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the roles and the standing warnings', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Companion'), findsWidgets);
    expect(find.text('Here'), findsOneWidget);
    expect(find.text('On the desktop'), findsOneWidget);
    expect(find.text('Serve layers'), findsOneWidget);
    // The two limits of the ABI are stated on the screen, not hidden.
    expect(
      find.textContaining('runs until the app is closed'),
      findsOneWidget,
    );
    expect(find.textContaining('clear text'), findsOneWidget);
    // And the requirement that decides whether any of it works at all.
    expect(find.textContaining('same .cmf file'), findsOneWidget);
  });

  testWidgets('a fresh install can still reach the address field',
      (tester) async {
    // With no address saved, the fields are hidden until the user asks for
    // the desktop role — and asking for it needs an address. The screen must
    // not be able to lock itself out of its own configuration.
    await pumpScreen(tester);
    expect(find.text('Desktop address'), findsNothing);

    await tester.tap(find.text('On the desktop'));
    await tester.pumpAndSettle();

    expect(find.text('Desktop address'), findsOneWidget);
    expect(find.text('Shared token'), findsOneWidget);
  });

  // Separate tests, not two pumps in one: SharedPreferences caches its
  // instance per isolate, so a second setMockInitialValues in the same test
  // would be read straight past.
  testWidgets('a LAN address is labeled Wi-Fi and carries the tail warning',
      (tester) async {
    await pumpScreen(tester, address: '192.168.1.5:9911');

    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.textContaining('99th percentile'), findsOneWidget);
  });

  testWidgets('loopback is a cable, and gets no warning', (tester) async {
    await pumpScreen(tester, address: '127.0.0.1:9911');

    expect(find.text('Cable'), findsOneWidget);
    expect(find.textContaining('99th percentile'), findsNothing);
  });

  testWidgets('says so plainly when the runtime cannot split', (tester) async {
    await pumpScreen(tester, supportsCompanion: false);

    expect(find.textContaining('cannot split'), findsOneWidget);
    expect(find.text('Serve layers'), findsNothing);
  });

  testWidgets('renders in Russian too', (tester) async {
    await pumpScreen(tester, locale: const Locale('ru'));
    expect(find.text('Где считать'), findsOneWidget);
    expect(find.text('Здесь'), findsOneWidget);
  });

  testWidgets('a refused address is reported in the UI language',
      (tester) async {
    // This shipped once as a hardcoded English sentence in a Russian screen.
    await pumpScreen(tester, locale: const Locale('ru'));
    await tester.tap(find.text('На десктопе'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Адрес должен быть'), findsOneWidget);
    expect(find.textContaining('host:port'), findsOneWidget);
    expect(find.textContaining('address must be'), findsNothing);
  });
}

class _FakeEngine extends InferenceEngine {
  _FakeEngine({required bool supportsCompanion})
      : _supports = supportsCompanion;

  final bool _supports;

  @override
  bool get supportsCompanion => _supports;

  @override
  bool get isAvailable => true;

  @override
  String get name => 'fake';

  @override
  LocalModel? get loadedModel => null;

  @override
  Future<void> loadModel(
    LocalModel model, {
    int threads = 0,
    String engineFlags = '',
  }) async {}

  @override
  Future<void> unload() async {}

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) =>
      Stream.value(const GenerationEvent(done: true));

  @override
  void cancel() {}
}
