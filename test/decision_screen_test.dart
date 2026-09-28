import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:cmf_mobile/features/decisions/decision_screen.dart';
import 'package:cmf_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _Engine extends InferenceEngine {
  @override
  bool get isAvailable => true;
  @override
  String get name => 'test';
  @override
  LocalModel? get loadedModel => null;
  @override
  Future<void> loadModel(
    LocalModel m, {
    int threads = 0,
    String engineFlags = '',
  }) async {}
  @override
  Future<void> unload() async {}
  @override
  void cancel() {}
  @override
  Stream<GenerationEvent> generate(GenerationRequest r) => const Stream.empty();
  @override
  Future<Map<String, dynamic>> decisionRequest(
    String method,
    String path, [
    Map<String, dynamic> body = const {},
  ]) async => {
    'status': 200,
    'body': path == '/v1/skills'
        ? {
            'skills': [
              {'id': 'banking77'},
              {'id': 'custom-skill'},
            ],
          }
        : {
            'accepted': true,
            'choice': 'card_arrival',
            'confidence': 0.99,
            'device': 'cpu',
            'oracle': false,
            'timings_us': {'total': 21027, 'resonance': 4669},
            'errors': [
              {'label': 'card_arrival', 'error': 0.25},
            ],
          },
  };
}

void main() {
  for (final lang in ['en', 'ru', 'de', 'fr', 'es', 'zh', 'tr']) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'decision screen: clear skill, no overflow, no stale result ($lang, $width)',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [engineProvider.overrideWithValue(_Engine())],
              child: MaterialApp(
                locale: Locale(lang),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: const DecisionScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final run = find.byKey(const Key('decision-run'));
          expect(tester.widget<FilledButton>(run).onPressed, isNull);
          await tester.enterText(
            find.byKey(const Key('decision-input')),
            'Where is my card?',
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(run);
          await tester.pumpAndSettle();
          await tester.tap(run);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('card_arrival'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('card_arrival'), findsOneWidget);
          expect(
            find.textContaining(
              ['ru', 'de', 'fr', 'es', 'tr'].contains(lang) ? '99,0%' : '99.0%',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const Key('decision-input')),
            -150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(
            find.byKey(const Key('decision-input')),
            'Different request',
          );
          await tester.pump();
          expect(find.text('card_arrival'), findsNothing);
        },
      );
    }
  }
}
