import 'dart:convert';
import 'dart:io';

import 'package:cmf_mobile/data/services/decision_oracle.dart';
import 'package:cmf_mobile/features/decisions/oracle_error_message.dart';
import 'package:cmf_mobile/features/decisions/oracle_settings_screen.dart';
import 'package:cmf_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const languages = ['en', 'ru', 'de', 'fr', 'es', 'zh', 'tr'];
  Map<String, dynamic> read(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;
  final english = read('en');
  final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
  Set<String> placeholders(String value) => RegExp(
    r'\{([a-zA-Z_]\w*)(?:\}|,)',
  ).allMatches(value).map((match) => match.group(1)!).toSet();

  for (final lang in languages) {
    test('$lang: every string and placeholder is present, no damaged text', () {
      final translated = read(lang);
      expect(translated['@@locale'], lang);
      expect(
        translated.keys.where((key) => !key.startsWith('@')).toSet(),
        keys,
      );
      for (final key in keys) {
        final value = translated[key] as String;
        expect(value.trim(), isNotEmpty, reason: '$lang/$key');
        expect(value, isNot(contains('\uFFFD')), reason: '$lang/$key');
        expect(
          placeholders(value),
          placeholders(english[key] as String),
          reason: '$lang/$key',
        );
      }
      // Use the same names wherever users switch between models and screens.
      expect(translated['modelKindChat'], translated['navChat']);
      expect(translated['modelKindDecision'], translated['decisionTitle']);
    });

    test(
      '$lang: typed oracle errors are localized; diagnostics never leak secrets',
      () {
        final l = lookupAppLocalizations(Locale(lang));
        final expected = read(lang);
        for (final (issue, key) in [
          (OracleValidationIssue.url, 'oracleUrlError'),
          (OracleValidationIssue.model, 'oracleModelError'),
          (OracleValidationIssue.key, 'oracleKeyError'),
        ]) {
          expect(
            oracleErrorMessage(
              OracleValidationException(issue, 'sensitive diagnostic'),
              l,
            ),
            expected[key],
          );
        }
        expect(
          oracleErrorMessage(OracleResponseException.http(401), l),
          (expected['oracleHttpError'] as String).replaceAll('{status}', '401'),
        );
        expect(
          oracleErrorMessage(OracleResponseException.invalid(), l),
          expected['oracleInvalidResponse'],
        );
        expect(
          oracleErrorMessage(StateError('sensitive diagnostic'), l),
          expected['oracleRequestError'],
        );
      },
    );

    for (final width in [320.0, 390.0]) {
      testWidgets(
        '$lang: oracle labels and validation fit ${width.toInt()}px, 130% text',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = lookupAppLocalizations(Locale(lang));
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const OracleSettingsScreen(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l.oracleApiUrl), findsOneWidget);
          expect(find.text(l.oracleApiKey), findsOneWidget);
          expect(
            find.text('API key'),
            lang == 'en' ? findsOneWidget : findsNothing,
          );
          await tester.enterText(
            find.widgetWithText(TextField, l.oracleApiUrl),
            'http://example.com',
          );
          final save = find.widgetWithText(FilledButton, l.oracleSave);
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text(l.oracleUrlError), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
