// Real native CMF + HTTP + UI on the connected phone. No cloud oracle calls.
// Prerequisite: scripts/build_native.sh android-arm64; copy the verified CMF
// to the debug app's app_flutter/decision-test.cmf (see docs/mobile-decision.md).
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cmf_mobile/app.dart';
import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/cmf_server.dart';
import 'package:cmf_mobile/data/services/decision_oracle.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'CMF Decision: three real skills, abstention, API, UI and secure oracle settings',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: CmfApp()));
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CmfApp)),
      );
      final engine = container.read(engineProvider);
      expect(engine.isAvailable, true);
      expect(engine.supportsDecisions, true);
      expect(engine.name, contains('0.8.12'));
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/decision-test.cmf');
      expect(
        await file.exists(),
        true,
        reason: 'Copy the CMF fixture into ${file.path} first',
      );
      expect(await file.length(), 304520292);
      final meta = await CmfReader.readMetadata(file.path);
      expect(meta.isDecision, true);
      expect(meta.isSkill, false);
      expect(meta.quantType, 'F32');
      expect(await CmfValidator.validate(file.path), isEmpty);
      final model = LocalModel(
        id: 'decision-test',
        filePath: file.path,
        sizeBytes: await file.length(),
        modifiedAt: DateTime.now(),
        meta: meta,
      );
      await container.read(engineControllerProvider.notifier).loadModel(model);
      expect(container.read(engineControllerProvider).error, isNull);
      final skills = await engine.decisionRequest('GET', '/v1/skills');
      expect((skills['body']['skills'] as List).length, 3);
      final measurements = <Map<String, dynamic>>[];
      for (final (skill, text, label) in [
        ('banking77', 'I still have not received my new card', 'card_arrival'),
        ('clinc150', 'What is the weather forecast for tomorrow?', 'weather'),
        ('massive', 'Play some jazz music', 'play_music'),
      ]) {
        final reply = await engine.decisionRequest('POST', '/v1/decide', {
          'skill': skill,
          'text': text,
        });
        expect(reply['status'], 200);
        expect(reply['body']['choice'], label);
        expect(reply['body']['accepted'], true);
        expect(reply['body']['oracle'], false);
        measurements.add({
          'skill': skill,
          'choice': label,
          'timings_us': reply['body']['timings_us'],
          'device': reply['body']['device'],
        });
      }
      final unknown = await engine.decisionRequest('POST', '/v1/decide', {
        'skill': 'banking77',
        'text':
            'Calculate the quantum entanglement of purple dinosaurs on Jupiter',
      });
      expect(unknown['body']['accepted'], false);
      expect(unknown['body']['choice'], isNull);
      expect(
        (await engine.decisionRequest('POST', '/v1/decide', {
          'skill': 'missing',
          'text': 'x',
        }))['status'],
        404,
      );
      expect(
        (await engine.decisionRequest('POST', '/v1/decisions', {
          'cmf': {'oracle': true},
        }))['status'],
        400,
      );
      final skill = await engine.decisionRequest('GET', '/v1/skills/banking77');
      final rubric = skill['body']['rubric'];
      final typed = await engine.decisionRequest('POST', '/v1/decisions', {
        'model': 'cortiq/decision',
        'state': 'I still have not received my new card',
        'questions': {
          'intent': {
            'type': 'choice',
            'instructions': rubric['instructions'],
            'criteria': rubric['criteria'],
          },
        },
        'cmf': {'skill': 'banking77', 'oracle': false},
      });
      expect(typed['status'], 200);
      expect(jsonEncode(typed['body']), contains('card_arrival'));

      final server = CmfServer(engine: engine);
      final client = HttpClient();
      await server.start(port: 0, token: 'on-device-test');
      try {
        Future<(int, String)> request(
          String path, {
          bool auth = true,
          String body = '{}',
        }) async {
          final req = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}$path'),
          );
          if (auth) req.headers.set('Authorization', 'Bearer on-device-test');
          req.headers.contentType = ContentType.json;
          req.write(body);
          final response = await req.close();
          return (response.statusCode, await utf8.decodeStream(response));
        }

        expect((await request('/v1/decide', auth: false)).$1, 401);
        final reply = await request(
          '/v1/decide',
          body: jsonEncode({
            'skill': 'banking77',
            'text': 'I still have not received my new card',
          }),
        );
        expect(reply.$1, 200);
        expect(jsonDecode(reply.$2)['choice'], 'card_arrival');
        expect((await request('/v1/chat/completions')).$1, 409);
      } finally {
        client.close(force: true);
        await server.stop();
      }

      // This is the separate .dev app; never write keys into the store app.
      const store = OracleSettingsStore();
      await store.save(
        const OracleSettings(
          enabled: false,
          apiKey: 'device-test-not-a-real-key',
        ),
      );
      expect((await store.read()).apiKey, 'device-test-not-a-real-key');
      await store.clear();
      expect((await store.read()).enabled, false);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('decision-input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('decision-input')),
        'I still have not received my new card',
      );
      // `enterText` changes the controller immediately, but the button's
      // enabled state is rebuilt on the next frame.
      await tester.pump();
      final run = find.byKey(const Key('decision-run'));
      expect(tester.widget<FilledButton>(run).onPressed, isNotNull);
      await tester.ensureVisible(run);
      await tester.tap(run);
      final choice = find.byKey(const Key('decision-choice'));
      for (var i = 0; i < 100 && choice.evaluate().isEmpty; i++) {
        // Decision inference runs in a worker isolate. Advancing the widget
        // test's fake clock does not give that isolate wall-clock time.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      expect(choice, findsOneWidget);
      expect(tester.widget<SelectableText>(choice).data, 'card_arrival');
      expect(tester.takeException(), isNull);
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final screenshot = await binding.takeScreenshot('cmf-decision-device');
      await File(
        '${directory.path}/decision-screenshot.png',
      ).writeAsBytes(screenshot);
      binding.reportData ??= {};
      binding.reportData!['decision_measurements'] = measurements;
      debugPrint('CMF_DEVICE_REPORT ${jsonEncode(measurements)}');
      await container.read(engineControllerProvider.notifier).unload();
      expect(engine.loadedModel, isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
