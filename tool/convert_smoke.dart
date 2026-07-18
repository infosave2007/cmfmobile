// End-to-end converter test: downloads a small HF model, converts it to
// CMF with the app's own converter core, then loads the result through
// the cortiq runtime and generates — the full mobile pipeline on desktop.
//
//   CORTIQ_FFI_LIB=/path/to/libcortiq_ffi.dylib \
//     dart run tool/convert_smoke.dart Qwen/Qwen3-0.6B q8_2f /tmp/work
import 'dart:convert';
import 'dart:io';

import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/models/conversion.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/converter_core.dart';
import 'package:cmf_mobile/data/services/hf_api.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:cmf_mobile/data/services/inference/native_engine.dart';

Future<void> main(List<String> args) async {
  final repo = args.isNotEmpty ? args[0] : 'Qwen/Qwen3-0.6B';
  final quant = QuantType.values.firstWhere(
      (q) => q.flag == (args.length > 1 ? args[1] : 'q8_2f'));
  final workDir = Directory(args.length > 2 ? args[2] : '/tmp/cmf-convert');
  await workDir.create(recursive: true);

  final hf = HfApi();
  final token = Platform.environment['HF_TOKEN'];

  stdout.writeln('== listing $repo');
  final files = await hf.listFiles(repo, token: token);
  final config = jsonDecode(await hf.fetchText(repo, 'config.json'))
      as Map<String, dynamic>;
  String? tokCfg;
  if (files.any((f) => f.path == 'tokenizer_config.json')) {
    tokCfg = await hf.fetchText(repo, 'tokenizer_config.json', token: token);
  }

  final shards = files
      .where((f) =>
          f.path.endsWith('.safetensors') && !f.path.contains('/'))
      .map((f) => f.path)
      .toList()
    ..sort();
  stdout.writeln('shards: $shards');

  final shardPaths = <String>[];
  for (final name in [...shards, 'tokenizer.json']) {
    final dest = '${workDir.path}/$name';
    if (!File(dest).existsSync()) {
      stdout.writeln('downloading $name…');
      await hf.download(repo, name, dest, token: token,
          onBytes: (r, t) => stdout.write(
              '\r  ${(r / 1024 / 1024).toStringAsFixed(0)} MB'
              '${t > 0 ? ' / ${(t / 1024 / 1024).toStringAsFixed(0)} MB' : ''}'));
      stdout.writeln();
    }
    if (name.endsWith('.safetensors')) shardPaths.add(dest);
  }

  final outputPath =
      '${workDir.path}/${repo.split('/').last.toLowerCase()}-${quant.flag}.cmf';
  stdout.writeln('== converting to $outputPath (${quant.label})');
  final started = DateTime.now();
  await convertSafetensorsToCmf(
    ConvertInput(
      shardPaths: shardPaths,
      config: config,
      tokenizerConfigText: tokCfg,
      vocabPath: '${workDir.path}/tokenizer.json',
      outputPath: outputPath,
      quant: quant,
      sourceRepo: repo,
      threads: 8,
    ),
    onLog: (line) => stdout.writeln('  $line'),
    onProgress: (done, total) => stdout.write(
        '\r  quantizing ${(100 * done / total).toStringAsFixed(0)}%'),
  );
  stdout.writeln('\nconverted in '
      '${DateTime.now().difference(started).inSeconds}s, '
      '${(File(outputPath).lengthSync() / 1024 / 1024).toStringAsFixed(0)} MB');

  final meta = await CmfReader.readMetadata(outputPath);
  stdout.writeln('meta: ${meta.archName} ${meta.quantType} '
      '${meta.numLayers}L vocab=${meta.vocabSize} '
      'template=${meta.hasChatTemplate}');

  stdout.writeln('== loading through cortiq runtime');
  final engine = NativeCortiqEngine();
  if (!engine.isAvailable) {
    stderr.writeln('native runtime unavailable (set CORTIQ_FFI_LIB)');
    exit(1);
  }
  final stat = File(outputPath).statSync();
  await engine.loadModel(LocalModel(
    id: 'converted',
    filePath: outputPath,
    sizeBytes: stat.size,
    modifiedAt: stat.modified,
    meta: meta,
  ));
  stdout.writeln('loaded (${engine.name})');

  await for (final event in engine.generate(GenerationRequest(
    messages: const [
      ChatMessage(role: ChatRole.user, content: 'Say hello in one short sentence.'),
    ],
    maxTokens: 48,
  ))) {
    if (event.done) {
      final s = event.stats!;
      stdout.writeln('\n== done: ${s.completionTokens} tok, '
          '${s.tokensPerSecond.toStringAsFixed(1)} tok/s, '
          'finish=${s.finishReason}');
    } else {
      stdout.write(event.delta);
    }
  }
  await engine.unload();
  exit(0);
}
