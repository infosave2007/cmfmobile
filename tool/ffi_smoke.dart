// End-to-end smoke test for the cortiq-ffi binding: real model, real
// inference, streamed through the same NativeCortiqEngine the app uses.
//
//   CORTIQ_FFI_LIB=/path/to/libcortiq_ffi.dylib \
//     dart run tool/ffi_smoke.dart /path/to/model.cmf "prompt"
import 'dart:io';

import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:cmf_mobile/data/services/inference/native_engine.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: ffi_smoke.dart <model.cmf> [prompt]');
    exit(2);
  }
  final path = args[0];
  final prompt = args.length > 1 ? args[1] : 'Reply with one short sentence: what is 2+2?';

  final engine = NativeCortiqEngine();
  stdout.writeln('engine available: ${engine.isAvailable} (${engine.name})');
  if (!engine.isAvailable) exit(1);

  final stat = File(path).statSync();
  final meta = await CmfReader.readMetadata(path);
  stdout.writeln('model: ${meta.archName} ${meta.quantType} '
      '${meta.numLayers}L ctx=${meta.contextLength}');

  final model = LocalModel(
    id: path.split('/').last,
    filePath: path,
    sizeBytes: stat.size,
    modifiedAt: stat.modified,
    meta: meta,
  );
  final loadStart = DateTime.now();
  await engine.loadModel(model);
  stdout.writeln(
      'loaded in ${DateTime.now().difference(loadStart).inMilliseconds}ms');

  stdout.writeln('--- prompt: $prompt');
  await for (final event in engine.generate(GenerationRequest(
    messages: [ChatMessage(role: ChatRole.user, content: prompt)],
    maxTokens: 64,
  ))) {
    if (event.done) {
      final s = event.stats!;
      stdout.writeln('\n--- done: ${s.completionTokens} tokens, '
          '${s.tokensPerSecond.toStringAsFixed(1)} tok/s, '
          '${s.latencyMs}ms, finish=${s.finishReason}');
    } else {
      stdout.write(event.delta);
    }
  }
  await engine.unload();
  exit(0);
}
