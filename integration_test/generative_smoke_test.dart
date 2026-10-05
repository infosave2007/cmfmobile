// Real generic-CMF regression on a connected device. This is intentionally
// separate from Decision: it proves the chat/load/generate FFI path still
// streams a real model after a native-runtime upgrade.
//
// Prerequisite: build/install the .dev APK, then copy the verified
// hy-mt2-1.8b-q1t.cmf fixture to app_flutter/generation-test.cmf. The Flutter
// integration runner uninstalls its temporary .dev package when it finishes,
// so seed the file immediately before each invocation.
import 'dart:convert';
import 'dart:io';

import 'package:cmf_mobile/app.dart';
import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _fixtureBytes = 694894587;
const _fixtureSha256 =
    'aeb52bf287fb52f6e67f452dd72302087420f3b9e2081ed0cb86fd65cf289424';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'generic CMF streams a real local reply',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: CmfApp()));
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CmfApp)),
      );
      final engine = container.read(engineProvider);
      expect(engine.isAvailable, true);
      expect(engine.name, contains('0.8.12'));

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/generation-test.cmf');
      expect(
        await file.exists(),
        true,
        reason: 'Copy the generative CMF fixture into ${file.path} first',
      );
      expect(await file.length(), _fixtureBytes);
      final fixtureSha256 = await sha256.bind(file.openRead()).first;
      expect(fixtureSha256.toString(), _fixtureSha256);
      final metadata = await CmfReader.readMetadata(file.path);
      expect(metadata.isDecision, false);
      expect(metadata.isSkill, false);
      final model = LocalModel(
        id: 'generation-test',
        filePath: file.path,
        sizeBytes: await file.length(),
        modifiedAt: DateTime.now(),
        meta: metadata,
      );

      // Do not route through EngineController: persisted user settings can
      // enable GPU or arbitrary CMF flags. This release regression has a
      // deliberately fixed CPU/auto configuration.
      engine.setGpu(false);
      await engine.loadModel(model, threads: 0, engineFlags: '');
      expect(engine.loadedModel?.id, model.id);

      final stopwatch = Stopwatch()..start();
      final text = StringBuffer();
      var firstTokenMs = -1;
      GenerationStats? stats;
      await for (final event in engine.generate(
        const GenerationRequest(
          messages: [
            ChatMessage(
              role: ChatRole.user,
              content:
                  'Translate only the word "hello" into Russian. Output only the translation.',
            ),
          ],
          temperature: 0,
          topP: 1,
          maxTokens: 16,
        ),
      )) {
        if (event.done) {
          stats = event.stats;
        } else {
          if (firstTokenMs < 0) firstTokenMs = stopwatch.elapsedMilliseconds;
          text.write(event.delta);
        }
      }
      stopwatch.stop();
      final reply = text.toString().trim();
      final completedStats = stats;
      expect(completedStats, isNotNull);
      if (completedStats == null) return;
      expect(completedStats.completionTokens, greaterThan(0));
      expect(completedStats.finishReason, 'stop');
      // This is a functional smoke report. `tokensPerSecond` includes prefill;
      // it must not be interpreted as steady-state decode throughput.
      final report = <String, Object?>{
        'runtime': engine.name,
        'model_bytes': _fixtureBytes,
        'model_sha256': fixtureSha256.toString(),
        'arch': metadata.archName,
        'quant': metadata.quantType,
        'gpu_enabled': false,
        'gpu_backend_available': engine.gpuBackendAvailable,
        'threads': 'auto',
        'engine_flags': '',
        'first_token_ms': firstTokenMs,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        'completion_tokens': completedStats.completionTokens,
        'reported_tokens_per_second_including_prefill':
            completedStats.tokensPerSecond,
        'finish_reason': completedStats.finishReason,
        'reply': reply,
        'translation_contains_expected_russian': reply.toLowerCase().contains(
          'привет',
        ),
      };
      debugPrint('CMF_GENERATIVE_DEVICE_REPORT ${jsonEncode(report)}');
      expect(reply, isNotEmpty);
      expect(
        reply.toLowerCase(),
        contains('привет'),
        reason:
            'The fixed English-to-Russian prompt must contain its expected translation',
      );
      await engine.unload();
      expect(engine.loadedModel, isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
