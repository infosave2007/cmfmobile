import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/conversion.dart';
import 'cmf_format.dart';
import 'safetensors.dart';

/// Pure-Dart core of the safetensors → CMF v2 converter — no Flutter
/// dependencies, so the exact same code runs in the app, in desktop tools
/// and in tests.
///
/// Every encoder mirrors the reference converter byte for byte
/// (cmfpublic crates/cortiq-cli/src/convert.rs): f16-rounded scales
/// (quantize against the SAME scale the reader dequantizes with),
/// round-half-to-even, reference clamps and layouts. Quantization runs on
/// an isolate pool sized by [ConvertInput.threads].

/// Smallest normal f16 — floor for degenerate rows (reference F16_TINY).
const double f16Tiny = 6.103515625e-5;

double f16Round(double x) => f16BitsToDouble(f32ToF16Bits(x));

/// Reference `f16_scale`: round to f16, floor at the smallest normal.
double f16ScaleOf(double raw) => math.max(f16Round(raw), f16Tiny);

/// Round half to even (numpy/np.round semantics, reference
/// `round_ties_even`).
double roundTiesEven(double x) {
  final floor = x.floorToDouble();
  final diff = x - floor;
  if (diff > 0.5) return floor + 1;
  if (diff < 0.5) return floor;
  return floor % 2 == 0 ? floor : floor + 1;
}

/// Canonicalize a source tensor name (reference `canon_name`): vision /
/// MTP towers are dropped, multimodal text wrappers unnest to `model.*`.
String? canonName(String raw) {
  if (raw.contains('.visual.') ||
      raw.startsWith('visual.') ||
      raw.startsWith('mtp.') ||
      raw.contains('.mtp.')) {
    return null;
  }
  for (final pfx in [
    'model.vision_embedder.',
    'model.embed_audio.',
    'model.embed_vision.',
  ]) {
    if (raw.startsWith(pfx)) return null;
  }
  for (final pfx in [
    'model.language_model.',
    'language_model.model.',
    'language_model.',
  ]) {
    if (raw.startsWith(pfx)) {
      return 'model.${raw.substring(pfx.length)}';
    }
  }
  return raw;
}

/// Noise-sensitive projections the reference converter keeps at f16.
bool forceF16(String name) =>
    name.endsWith('linear_attn.in_proj_a.weight') ||
    name.endsWith('linear_attn.in_proj_b.weight') ||
    name.endsWith('mlp.gate.weight');

/// Header quant_type label (reference: Q1 files carry VBIT — the enum has
/// no Q1 variant; per-tensor truth is in the directory).
String headerQuantLabel(QuantType quant) => switch (quant) {
      QuantType.q8Row => 'Q8_ROW',
      QuantType.q8_2f => 'Q8_2F',
      QuantType.q4Block => 'Q4_BLOCK',
      QuantType.vbit => 'VBIT',
      QuantType.q1 => 'VBIT',
      QuantType.f16 => 'F16',
    };

/// Per-tensor target dtype (reference dispatch): 2-D tensors with ≥32
/// elements quantize; q1 needs in_dim % 32 == 0, otherwise that tensor
/// falls back to q8_2f. Everything else stores f16.
int targetDtype(QuantType quant, String name, List<int> shape, int numel) {
  final twoD = shape.length == 2 && numel >= 32 && !forceF16(name);
  if (!twoD) return Cmf.dtF16;
  switch (quant) {
    case QuantType.q8Row:
      return Cmf.dtQ8Row;
    case QuantType.q8_2f:
      return Cmf.dtQ8_2f;
    case QuantType.q1:
      return shape[1] % 32 == 0 ? Cmf.dtQ1 : Cmf.dtQ8_2f;
    case QuantType.f16:
      return Cmf.dtF16;
    default:
      return Cmf.dtF16; // q4/vbit need the desktop toolchain
  }
}

int nbytesFor(int dtype, List<int> shape, int numel) => switch (dtype) {
      Cmf.dtQ8Row => shape[0] * shape[1] + shape[0] * 2,
      Cmf.dtQ8_2f => shape[0] * shape[1] + shape[0] * 2 + shape[1] * 2,
      Cmf.dtQ1 => (shape[0] * shape[1]) ~/ 32 * 6,
      _ => numel * 2,
    };

/// Rejects architectures the on-device converter cannot produce
/// correctly. Hybrid models (qwen3.5-style GatedDeltaNet layers) need the
/// reference converter, which folds the linear-attention operator into
/// the canonical linear core at convert time — without that fold the
/// engine crashes at generate.
void ensureSupportedArch(Map<String, dynamic> config) {
  final layerTypes =
      (config['layer_types'] as List?)?.cast<String>() ?? const [];
  final hasLinear = layerTypes.any((t) => t != 'full_attention') ||
      config.containsKey('linear_conv_kernel_dim') ||
      config.containsKey('linear_num_key_heads');
  if (hasLinear) {
    throw StateError(
        'hybrid architecture (${config['model_type']}: GatedDeltaNet/linear '
        'attention layers) — on-device conversion supports dense attention '
        'models only. Use desktop `cortiq convert`, or download a ready '
        '.cmf of this model');
  }
  if (config['num_experts'] != null ||
      config.containsKey('num_local_experts')) {
    throw StateError(
        'MoE architecture (${config['model_type']}) — on-device conversion '
        'supports dense models only. Use desktop `cortiq convert`, or '
        'download a ready .cmf');
  }
}

class ConvertInput {
  const ConvertInput({
    required this.shardPaths,
    required this.config,
    required this.vocabPath,
    required this.outputPath,
    required this.quant,
    required this.sourceRepo,
    this.tokenizerConfigText,
    this.threads = 4,
  });

  final List<String> shardPaths;
  final Map<String, dynamic> config;
  final String? tokenizerConfigText;
  final String vocabPath;
  final String outputPath;
  final QuantType quant;
  final String sourceRepo;
  final int threads;
}

Map<String, dynamic> buildCmfHeader(
    Map<String, dynamic> config, String? tokCfgText, QuantType quant,
    {required String sourceRepo, required int numQuantTensors}) {
  final modelType = config['model_type'] as String? ?? 'llama';
  final hidden = config['hidden_size'] as int? ?? 0;
  final heads = config['num_attention_heads'] as int? ?? 1;
  final layers = config['num_hidden_layers'] as int? ?? 0;
  final eosRaw = config['eos_token_id'];
  final eos = eosRaw is List
      ? eosRaw.whereType<int>().toList()
      : eosRaw is int
          ? [eosRaw]
          : <int>[];

  String? chatTemplate;
  if (tokCfgText != null) {
    try {
      final tokCfg = jsonDecode(tokCfgText) as Map<String, dynamic>;
      final ct = tokCfg['chat_template'];
      if (ct is String) chatTemplate = ct;
    } catch (_) {}
  }

  return {
    'format': 'cmf',
    'version': Cmf.version,
    'arch': {
      'arch_name': modelType,
      'hidden_size': hidden,
      'intermediate_size': config['intermediate_size'] ?? 0,
      'num_layers': layers,
      'num_attention_heads': heads,
      'num_kv_heads': config['num_key_value_heads'] ?? heads,
      'head_dim': config['head_dim'] ?? (heads > 0 ? hidden ~/ heads : 0),
      'vocab_size': config['vocab_size'] ?? 0,
      'layer_types': [
        for (var i = 0; i < layers; i++)
          // Dense-only (ensureSupportedArch): map config layer_types when
          // present, otherwise every layer is full attention.
          'FullAttention',
      ],
      'rms_norm_eps': config['rms_norm_eps'] ?? 1e-6,
      'norm_style': modelType.contains('gemma') ? 'gemma' : 'qwen',
      'rope_theta': config['rope_theta'] ?? 10000.0,
      'tie_word_embeddings': config['tie_word_embeddings'] ?? false,
      'max_position_embeddings': config['max_position_embeddings'] ?? 0,
    },
    'quant_type': headerQuantLabel(quant),
    'tokenizer_config': {
      'chat_template': ?chatTemplate,
      'eos_token_ids': eos,
      'bos_token_id': config['bos_token_id'],
      'pad_token_id':
          config['pad_token_id'] is int ? config['pad_token_id'] : null,
    },
    'provenance': {
      'tool': 'cmf-mobile 1.0',
      'source_model': sourceRepo,
      'quantized_tensors': numQuantTensors,
    },
  };
}

/// Converts downloaded safetensors shards into a CMF v2 file, quantizing
/// on [ConvertInput.threads] parallel isolates.
Future<void> convertSafetensorsToCmf(
  ConvertInput input, {
  void Function(int doneBytes, int totalBytes)? onProgress,
  void Function(String line)? onLog,
  bool Function()? isCancelled,
}) async {
  // Plan: every float tensor gets a canonical name, a target dtype and a
  // pre-assigned slot in the output file.
  final tasks = <TensorTask>[];
  final specs = <CmfTensorSpec>[];
  for (final path in input.shardPaths) {
    final shard = await SafetensorsFile.open(path);
    for (final t in shard.tensors) {
      final name = canonName(t.name);
      if (name == null) {
        onLog?.call('skip ${t.name} (multimodal/MTP tower)');
        continue;
      }
      if (!t.isFloat) {
        onLog?.call('skip ${t.name} (${t.dtype})');
        continue;
      }
      final dtype = targetDtype(input.quant, name, t.shape, t.numel);
      final spec = CmfTensorSpec(
        name: name,
        dtype: dtype,
        shape: t.shape,
        nbytes: nbytesFor(dtype, t.shape, t.numel),
      );
      specs.add(spec);
      tasks.add(TensorTask(
        shardPath: path,
        shardDataStart: shard.dataStart,
        srcDtype: t.dtype,
        srcBegin: t.begin,
        srcNbytes: t.nbytes,
        shape: t.shape,
        name: name,
        outDtype: dtype,
        outNbytes: spec.nbytes,
        outOffset: 0, // assigned after begin()
      ));
    }
  }
  if (specs.isEmpty) throw StateError('no float tensors found');

  final quantCount =
      specs.where((s) => s.dtype != Cmf.dtF16).length;
  final header = buildCmfHeader(
    input.config,
    input.tokenizerConfigText,
    input.quant,
    sourceRepo: input.sourceRepo,
    numQuantTensors: quantCount,
  );

  final writer = CmfWriter(
    outputPath: input.outputPath,
    headerJson: header,
    tensors: specs,
    vocabBytes: await File(input.vocabPath).readAsBytes(),
  );
  await writer.begin();
  for (var i = 0; i < tasks.length; i++) {
    tasks[i] = tasks[i].withOutOffset(writer.dataOffset + specs[i].offset);
  }

  // Balance tensors across workers by size (largest first, round-robin).
  final workers = math.max(1, math.min(input.threads, tasks.length));
  final order = List<int>.generate(tasks.length, (i) => i)
    ..sort((a, b) => tasks[b].srcNbytes.compareTo(tasks[a].srcNbytes));
  final partitions = List.generate(workers, (_) => <TensorTask>[]);
  final partitionBytes = List.filled(workers, 0);
  for (final i in order) {
    var target = 0;
    for (var w = 1; w < workers; w++) {
      if (partitionBytes[w] < partitionBytes[target]) target = w;
    }
    partitions[target].add(tasks[i]);
    partitionBytes[target] += tasks[i].srcNbytes;
  }

  final totalBytes = tasks.fold<int>(0, (s, t) => s + t.srcNbytes);
  var doneBytes = 0;
  final hashes = <String, int>{};
  final errors = <String>[];
  final isolates = <Isolate>[];
  final active = partitions.where((p) => p.isNotEmpty).toList();
  var runningWorkers = active.length;
  final allDone = Completer<void>();

  try {
    for (final partition in active) {
      final port = ReceivePort();
      void workerFinished() {
        port.close();
        runningWorkers--;
        if (runningWorkers == 0 && !allDone.isCompleted) allDone.complete();
      }

      port.listen((message) {
        switch (message) {
          case ('p', final int bytes):
            doneBytes += bytes;
            onProgress?.call(doneBytes, totalBytes);
          case ('h', final String name, final int hash):
            hashes[name] = hash;
          case ('d', null):
            workerFinished();
          case ('e', final String error):
            errors.add(error);
            workerFinished();
          case final List<dynamic> isolateError:
            errors.add('${isolateError.firstOrNull}');
            workerFinished();
        }
      });
      isolates.add(await Isolate.spawn(
        quantizeWorker,
        WorkerArgs(
          tasks: partition,
          outputPath: input.outputPath,
          sendPort: port.sendPort,
        ),
        onError: port.sendPort,
        errorsAreFatal: true,
      ));
    }

    // Wait for the pool; poll so cancellation stays responsive.
    while (!allDone.isCompleted) {
      await Future.any([
        allDone.future,
        Future<void>.delayed(const Duration(milliseconds: 300)),
      ]);
      if (isCancelled?.call() == true && !allDone.isCompleted) {
        for (final iso in isolates) {
          iso.kill(priority: Isolate.immediate);
        }
        await writer.abort();
        throw const ConvertCancelled();
      }
    }

    if (errors.isNotEmpty) {
      await writer.abort();
      throw StateError(errors.first);
    }
    for (final spec in specs) {
      spec.hash = hashes[spec.name] ?? 0;
    }
    await writer.finish();
  } catch (_) {
    for (final iso in isolates) {
      iso.kill(priority: Isolate.immediate);
    }
    rethrow;
  }
}

class ConvertCancelled implements Exception {
  const ConvertCancelled();
  @override
  String toString() => 'cancelled';
}

class TensorTask {
  const TensorTask({
    required this.shardPath,
    required this.shardDataStart,
    required this.srcDtype,
    required this.srcBegin,
    required this.srcNbytes,
    required this.shape,
    required this.name,
    required this.outDtype,
    required this.outNbytes,
    required this.outOffset,
  });

  final String shardPath;
  final int shardDataStart;
  final String srcDtype;
  final int srcBegin;
  final int srcNbytes;
  final List<int> shape;
  final String name;
  final int outDtype;
  final int outNbytes;
  final int outOffset;

  TensorTask withOutOffset(int offset) => TensorTask(
        shardPath: shardPath,
        shardDataStart: shardDataStart,
        srcDtype: srcDtype,
        srcBegin: srcBegin,
        srcNbytes: srcNbytes,
        shape: shape,
        name: name,
        outDtype: outDtype,
        outNbytes: outNbytes,
        outOffset: offset,
      );
}

class WorkerArgs {
  const WorkerArgs({
    required this.tasks,
    required this.outputPath,
    required this.sendPort,
  });

  final List<TensorTask> tasks;
  final String outputPath;
  final SendPort sendPort;
}

/// Isolate entry: quantizes its share of tensors, writing each at its
/// pre-assigned absolute offset (positioned writes, no coordination).
Future<void> quantizeWorker(WorkerArgs args) async {
  final port = args.sendPort;
  RandomAccessFile? out;
  final shardFiles = <String, RandomAccessFile>{};
  try {
    out = await File(args.outputPath).open(mode: FileMode.append);
    for (final task in args.tasks) {
      final shard = shardFiles[task.shardPath] ??=
          await File(task.shardPath).open();
      final hash = await _processTensor(task, shard, out,
          onBytes: (n) => port.send(('p', n)));
      port.send(('h', task.name, hash));
    }
    port.send(('d', null));
  } catch (e) {
    port.send(('e', '${args.tasks.firstOrNull?.name}: $e'));
  } finally {
    await out?.close();
    for (final f in shardFiles.values) {
      await f.close();
    }
  }
}

Future<int> _processTensor(
    TensorTask task, RandomAccessFile shard, RandomAccessFile out,
    {required void Function(int bytes) onBytes}) async {
  final hash = CmfHash64();
  var writePos = task.outOffset;
  Future<void> emit(Uint8List bytes) async {
    hash.add(bytes);
    await out.setPosition(writePos);
    await out.writeFrom(bytes);
    writePos += bytes.length;
  }

  final srcStart = task.shardDataStart + task.srcBegin;
  final rows = task.shape.isNotEmpty ? task.shape[0] : 1;
  final cols = task.shape.length == 2 ? task.shape[1] : 0;
  final bpe = switch (task.srcDtype) {
    'F32' => 4,
    _ => 2, // F16 / BF16
  };

  switch (task.outDtype) {
    case Cmf.dtQ8Row:
      // [int8 q: rows×cols][f16 scales: rows]
      final scales = Uint8List(rows * 2);
      final scaleData = ByteData.sublistView(scales);
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = Uint8List.fromList(await shard.read(n * cols * bpe));
        final values = decodeFloats(raw, task.srcDtype);
        final q = Uint8List(n * cols);
        for (var r = 0; r < n; r++) {
          var absMax = 0.0;
          for (var c = 0; c < cols; c++) {
            final a = values[r * cols + c].abs();
            if (a > absMax) absMax = a;
          }
          final scale = f16ScaleOf(absMax / 127.0);
          scaleData.setUint16(
              (r0 + r) * 2, f32ToF16Bits(scale), Endian.little);
          for (var c = 0; c < cols; c++) {
            q[r * cols + c] = roundTiesEven(values[r * cols + c] / scale)
                .clamp(-128.0, 127.0)
                .toInt()
                .toUnsigned(8);
          }
        }
        await emit(q);
        onBytes(raw.length);
      }
      await emit(scales);

    case Cmf.dtQ8_2f:
      // Pass 1 — column field: f16(RMS over rows), floored at F16_TINY.
      final colSumSq = Float64List(cols);
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = Uint8List.fromList(await shard.read(n * cols * bpe));
        final values = decodeFloats(raw, task.srcDtype);
        for (var r = 0; r < n; r++) {
          for (var c = 0; c < cols; c++) {
            final v = values[r * cols + c];
            colSumSq[c] += v * v;
          }
        }
      }
      final col = Float32List(cols);
      final colBytes = Uint8List(cols * 2);
      final colData = ByteData.sublistView(colBytes);
      for (var c = 0; c < cols; c++) {
        final rms = math.max(math.sqrt(colSumSq[c] / rows), 1e-12);
        col[c] = math.max(f16Round(rms), f16Tiny);
        colData.setUint16(c * 2, f32ToF16Bits(col[c]), Endian.little);
      }
      // Pass 2 — per-row residual against the column field.
      final scales = Uint8List(rows * 2);
      final scaleData = ByteData.sublistView(scales);
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = Uint8List.fromList(await shard.read(n * cols * bpe));
        final values = decodeFloats(raw, task.srcDtype);
        final q = Uint8List(n * cols);
        for (var r = 0; r < n; r++) {
          var absMax = 0.0;
          for (var c = 0; c < cols; c++) {
            final a = (values[r * cols + c] / col[c]).abs();
            if (a > absMax) absMax = a;
          }
          final scale = f16ScaleOf(math.max(absMax, 1e-12) / 127.0);
          scaleData.setUint16(
              (r0 + r) * 2, f32ToF16Bits(scale), Endian.little);
          for (var c = 0; c < cols; c++) {
            final wn = values[r * cols + c] / col[c];
            q[r * cols + c] = roundTiesEven(wn / scale)
                .clamp(-127.0, 127.0)
                .toInt()
                .toUnsigned(8);
          }
        }
        await emit(q);
        onBytes(raw.length);
      }
      await emit(scales);
      await emit(colBytes);

    case Cmf.dtQ1:
      // Flat 32-groups (in_dim % 32 == 0): [f16 mean|w|][4B signs, LSB
      // first, bit = w >= 0].
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      final groupsPerRow = cols ~/ 32;
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = Uint8List.fromList(await shard.read(n * cols * bpe));
        final values = decodeFloats(raw, task.srcDtype);
        final tiles = Uint8List(n * groupsPerRow * 6);
        final tileData = ByteData.sublistView(tiles);
        for (var r = 0; r < n; r++) {
          for (var g = 0; g < groupsPerRow; g++) {
            final base = r * cols + g * 32;
            var sumAbs = 0.0;
            for (var i = 0; i < 32; i++) {
              sumAbs += values[base + i].abs();
            }
            final scale = f16ScaleOf(sumAbs / 32.0);
            final tile = (r * groupsPerRow + g) * 6;
            tileData.setUint16(tile, f32ToF16Bits(scale), Endian.little);
            for (var j = 0; j < 4; j++) {
              var byte = 0;
              for (var k = 0; k < 8; k++) {
                if (values[base + j * 8 + k] >= 0.0) byte |= 1 << k;
              }
              tiles[tile + 2 + j] = byte;
            }
          }
        }
        await emit(tiles);
        onBytes(raw.length);
      }

    default: // f16
      final numel = task.shape.isEmpty
          ? 1
          : task.shape.reduce((a, b) => a * b);
      await shard.setPosition(srcStart);
      if (task.srcDtype == 'F16') {
        var remaining = numel * 2;
        while (remaining > 0) {
          final take = math.min(remaining, 8 * 1024 * 1024);
          final chunk = Uint8List.fromList(await shard.read(take));
          await emit(chunk);
          onBytes(chunk.length);
          remaining -= chunk.length;
        }
      } else {
        final elemsPerSlab = math.max(1, 4 * 1024 * 1024 ~/ bpe);
        var remaining = numel;
        while (remaining > 0) {
          final n = math.min(remaining, elemsPerSlab);
          final raw = Uint8List.fromList(await shard.read(n * bpe));
          final values = decodeFloats(raw, task.srcDtype);
          final outBytes = Uint8List(n * 2);
          final outData = ByteData.sublistView(outBytes);
          for (var i = 0; i < n; i++) {
            outData.setUint16(i * 2, f32ToF16Bits(values[i]), Endian.little);
          }
          await emit(outBytes);
          onBytes(raw.length);
          remaining -= n;
        }
      }
  }

  if (writePos - task.outOffset != task.outNbytes) {
    throw StateError('${task.name}: wrote ${writePos - task.outOffset}, '
        'expected ${task.outNbytes}');
  }
  return hash.digest();
}
