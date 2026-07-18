import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/conversion.dart';
import 'cmf_format.dart';
import 'hf_api.dart';
import 'model_repository.dart';
import 'safetensors.dart';

/// HuggingFace → .cmf conversion pipeline, mirroring cortiq-gateway's
/// import jobs (search → configure → convert with progress → done).
///
/// Two paths:
///  * repos that already publish .cmf files are downloaded directly
///    (any quantization);
///  * safetensors repos are converted on device in pure Dart — Q8_ROW and
///    F16 targets (Q8_2F/Q4/VBIT need the desktop cortiq toolchain).
class ConverterService {
  ConverterService({required this.hf, required this.models});

  final HfApi hf;
  final ModelRepository models;

  final List<ConversionJob> jobs = [];
  final _updates = StreamController<void>.broadcast();
  Stream<void> get updates => _updates.stream;

  final Set<String> _cancelRequested = {};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  void _notify({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify).inMilliseconds < 100) return;
    _lastNotify = now;
    if (!_updates.isClosed) _updates.add(null);
  }

  static String sanitizeName(String raw) {
    var name = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    name = name.replaceAll(RegExp(r'-+'), '-');
    return name.isEmpty ? 'model' : name;
  }

  Future<ConversionJob> start({
    required String repo,
    required QuantType quant,
    String? name,
    String? hfToken,
  }) async {
    final dir = await models.modelsDir();
    final outName = sanitizeName(
        (name == null || name.trim().isEmpty) ? repo.split('/').last : name);
    final job = ConversionJob(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(16),
      repo: repo,
      quant: quant,
      name: outName,
      outputPath: '${dir.path}/$outName.cmf',
      started: DateTime.now(),
    );
    jobs.insert(0, job);
    if (jobs.length > 20) jobs.removeLast();
    _notify(force: true);
    unawaited(_run(job, hfToken));
    return job;
  }

  void cancel(String jobId) {
    _cancelRequested.add(jobId);
    _notify(force: true);
  }

  Future<void> delete(String jobId, {bool deleteFile = false}) async {
    final job = jobs.where((j) => j.id == jobId).firstOrNull;
    if (job == null || job.state == JobState.running) return;
    if (deleteFile) {
      try {
        await File(job.outputPath).delete();
      } catch (_) {}
    }
    jobs.remove(job);
    _notify(force: true);
  }

  bool _isCancelled(ConversionJob job) => _cancelRequested.contains(job.id);

  void _progress(ConversionJob job, double frac, String phase) {
    job.progress = frac.clamp(0, 1);
    job.phase = phase;
    _notify();
  }

  Future<void> _run(ConversionJob job, String? hfToken) async {
    Directory? tempDir;
    try {
      job.addLog('→ converting ${job.repo} to ${job.name} '
          '(${job.quant.label})');
      _progress(job, 0.02, 'listing');
      final files = await hf.listFiles(job.repo, token: hfToken);

      final cmfFiles =
          files.where((f) => f.path.toLowerCase().endsWith('.cmf')).toList();
      if (cmfFiles.isNotEmpty) {
        await _downloadCmfDirectly(job, cmfFiles, hfToken);
      } else {
        if (!job.quant.supportedOnDevice) {
          throw StateError(
              '${job.quant.label} requires the desktop cortiq toolchain; '
              'on device choose Q8_ROW or F16, or pick a repo that ships '
              '.cmf files');
        }
        tempDir = Directory(
            '${(await getTemporaryDirectory()).path}/convert/${job.id}');
        await tempDir.create(recursive: true);
        await _convertSafetensors(job, files, tempDir, hfToken);
      }

      final size = await File(job.outputPath).length();
      job.sizeBytes = size;
      job.state = JobState.done;
      job.finished = DateTime.now();
      job.progress = 1;
      job.phase = 'done';
      job.addLog('✓ done (${(size / 1024 / 1024).toStringAsFixed(1)} MB)');
    } on CancelledException {
      job.state = JobState.cancelled;
      job.finished = DateTime.now();
      job.addLog('✗ cancelled');
      try {
        await File(job.outputPath).delete();
      } catch (_) {}
    } catch (e) {
      job.state = JobState.error;
      job.error = e.toString();
      job.finished = DateTime.now();
      job.addLog('✗ error: $e');
      try {
        await File(job.outputPath).delete();
      } catch (_) {}
    } finally {
      _cancelRequested.remove(job.id);
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
      _notify(force: true);
    }
  }

  Future<void> _downloadCmfDirectly(
      ConversionJob job, List<HfFileEntry> cmfFiles, String? hfToken) async {
    cmfFiles.sort((a, b) => b.size.compareTo(a.size));
    final src = cmfFiles.first;
    job.addLog('repo ships ${src.path} — downloading directly');
    await hf.download(
      job.repo,
      src.path,
      job.outputPath,
      token: hfToken,
      isCancelled: () => _isCancelled(job),
      onBytes: (received, total) {
        final t = total > 0 ? total : src.size;
        _progress(job, t > 0 ? received / t : 0, 'downloading');
      },
    );
  }

  Future<void> _convertSafetensors(ConversionJob job, List<HfFileEntry> files,
      Directory tempDir, String? hfToken) async {
    bool has(String name) => files.any((f) => f.path == name);
    if (!has('config.json')) {
      throw StateError('repo has no config.json (not a transformers model)');
    }
    if (!has('tokenizer.json')) {
      throw StateError('repo has no tokenizer.json '
          '(sentencepiece-only repos are not supported yet)');
    }

    // Resolve safetensors shards (single file or index + shards).
    List<String> shardNames;
    if (has('model.safetensors.index.json')) {
      final indexJson = jsonDecode(await hf.fetchText(
              job.repo, 'model.safetensors.index.json',
              token: hfToken)) as Map<String, dynamic>;
      final weightMap = indexJson['weight_map'] as Map<String, dynamic>;
      shardNames = weightMap.values.cast<String>().toSet().toList()..sort();
    } else if (has('model.safetensors')) {
      shardNames = ['model.safetensors'];
    } else {
      final loose = files
          .where((f) =>
              f.path.endsWith('.safetensors') && !f.path.contains('/'))
          .map((f) => f.path)
          .toList()
        ..sort();
      if (loose.isEmpty) {
        throw StateError('repo has no safetensors weights '
            '(GGUF-only repos need the desktop `cortiq import-gguf`)');
      }
      shardNames = loose;
    }

    // Phase 1: download (0.02 → 0.55), weighted by bytes.
    final config = jsonDecode(
            await hf.fetchText(job.repo, 'config.json', token: hfToken))
        as Map<String, dynamic>;
    String? tokenizerConfigText;
    if (has('tokenizer_config.json')) {
      tokenizerConfigText = await hf.fetchText(
          job.repo, 'tokenizer_config.json',
          token: hfToken);
    }
    final vocabPath = '${tempDir.path}/tokenizer.json';
    await hf.download(job.repo, 'tokenizer.json', vocabPath,
        token: hfToken, isCancelled: () => _isCancelled(job));

    final totalBytes = shardNames
        .map((n) => files.where((f) => f.path == n).firstOrNull?.size ?? 0)
        .fold<int>(0, (a, b) => a + b);
    var downloaded = 0;
    final shardPaths = <String>[];
    for (final shard in shardNames) {
      job.addLog('downloading $shard');
      final dest = '${tempDir.path}/$shard';
      final base = downloaded;
      await hf.download(
        job.repo,
        shard,
        dest,
        token: hfToken,
        isCancelled: () => _isCancelled(job),
        onBytes: (received, total) {
          final done = base + received;
          if (totalBytes > 0) {
            _progress(job, 0.02 + 0.53 * done / totalBytes, 'downloading');
          }
        },
      );
      downloaded += files.where((f) => f.path == shard).firstOrNull?.size ?? 0;
      shardPaths.add(dest);
    }
    if (_isCancelled(job)) throw const CancelledException();

    // Phase 2: plan tensors (header + directory).
    _progress(job, 0.56, 'converting');
    final header = _buildHeader(job, config, tokenizerConfigText);

    final shards = <SafetensorsFile>[];
    for (final p in shardPaths) {
      shards.add(await SafetensorsFile.open(p));
    }
    final plan = <(SafetensorsFile, SafetensorEntry, CmfTensorSpec)>[];
    for (final shard in shards) {
      for (final t in shard.tensors) {
        if (!t.isFloat) {
          job.addLog('skip ${t.name} (${t.dtype})');
          continue;
        }
        final dtype = _targetDtype(job.quant, t);
        final spec = CmfTensorSpec(
          name: t.name,
          dtype: dtype,
          shape: t.shape,
          nbytes: switch (dtype) {
            Cmf.dtQ8Row => t.shape[0] * t.shape[1] + t.shape[0] * 2,
            // Q1: per row, groups of 32 -> 6-byte tiles [f16 scale][4B signs].
            Cmf.dtQ1 => t.shape[0] * ((t.shape[1] + 31) ~/ 32) * 6,
            _ => t.numel * 2,
          },
        );
        plan.add((shard, t, spec));
      }
    }
    if (plan.isEmpty) throw StateError('no float tensors found');
    job.addLog('${plan.length} tensors, quant ${job.quant.label}');

    // Phase 3: stream-write CMF (0.58 → 0.97).
    final writer = CmfWriter(
      outputPath: job.outputPath,
      headerJson: header,
      tensors: [for (final p in plan) p.$3],
      vocabBytes: await File(vocabPath).readAsBytes(),
    );
    await writer.begin();
    final planBytes =
        plan.fold<int>(0, (sum, p) => sum + p.$2.nbytes);
    var processed = 0;
    try {
      for (final (shard, entry, spec) in plan) {
        if (_isCancelled(job)) throw const CancelledException();
        await writer.nextTensor();
        await _writeTensor(job, shard, entry, spec, writer);
        processed += entry.nbytes;
        _progress(job, 0.58 + 0.39 * processed / planBytes, 'quantizing');
      }
      _progress(job, 0.98, 'finalizing');
      await writer.finish();
    } catch (_) {
      await writer.abort();
      rethrow;
    }
  }

  /// Picks the CMF dtype for one tensor under the requested quantization.
  ///
  /// Q1 (1-bit trained models like Bonsai/BitNet) applies to transformer
  /// layer matrices only; embeddings, lm_head and norms stay f16, matching
  /// how such models are trained.
  static int _targetDtype(QuantType quant, SafetensorEntry t) {
    if (t.shape.length != 2) return Cmf.dtF16;
    switch (quant) {
      case QuantType.q8Row:
        return Cmf.dtQ8Row;
      case QuantType.q1:
        final inLayers = t.name.contains('.layers.');
        final isProjection = !t.name.contains('norm') &&
            !t.name.contains('embed') &&
            !t.name.contains('lm_head');
        return inLayers && isProjection ? Cmf.dtQ1 : Cmf.dtF16;
      default:
        return Cmf.dtF16;
    }
  }

  Map<String, dynamic> _buildHeader(
      ConversionJob job, Map<String, dynamic> config, String? tokCfgText) {
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
    int? padTokenId;
    if (tokCfgText != null) {
      try {
        final tokCfg = jsonDecode(tokCfgText) as Map<String, dynamic>;
        final ct = tokCfg['chat_template'];
        if (ct is String) chatTemplate = ct;
      } catch (_) {}
    }
    if (config['pad_token_id'] is int) {
      padTokenId = config['pad_token_id'] as int;
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
        'layer_types': List.filled(layers, 'FullAttention'),
        'rms_norm_eps': config['rms_norm_eps'] ?? 1e-6,
        'norm_style': modelType.contains('gemma') ? 'gemma' : 'qwen',
        'rope_theta': config['rope_theta'] ?? 10000.0,
        'tie_word_embeddings': config['tie_word_embeddings'] ?? false,
        'max_position_embeddings': config['max_position_embeddings'] ?? 0,
      },
      'quant_type': job.quant.label,
      'tokenizer_config': {
        'chat_template': ?chatTemplate,
        'eos_token_ids': eos,
        'bos_token_id': config['bos_token_id'],
        'pad_token_id': padTokenId,
      },
      'provenance': {
        'tool': 'cmf-mobile 1.0.0',
        'source_model': job.repo,
      },
    };
  }

  /// Streams one tensor through quantization in row slabs (≤ ~8 MB raw)
  /// so multi-GB models convert in constant memory.
  Future<void> _writeTensor(ConversionJob job, SafetensorsFile shard,
      SafetensorEntry entry, CmfTensorSpec spec, CmfWriter writer) async {
    final raf = await File(shard.path).open();
    try {
      final start = shard.dataStart + entry.begin;
      if (spec.dtype == Cmf.dtF16 && entry.dtype == 'F16') {
        // Fast path: raw copy.
        await raf.setPosition(start);
        var remaining = entry.nbytes;
        while (remaining > 0) {
          final take = min(remaining, 8 * 1024 * 1024);
          final chunk = Uint8List.fromList(await raf.read(take));
          await writer.writeTensorChunk(chunk);
          remaining -= chunk.length;
        }
        return;
      }

      if (spec.dtype == Cmf.dtQ8Row) {
        final rows = entry.shape[0], cols = entry.shape[1];
        final rowBytes = cols * entry.bytesPerElement;
        final rowsPerSlab = max(1, 8 * 1024 * 1024 ~/ rowBytes);
        final scales = Uint8List(rows * 2);
        final scaleData = ByteData.sublistView(scales);
        await raf.setPosition(start);
        for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
          final n = min(rowsPerSlab, rows - r0);
          final raw = Uint8List.fromList(await raf.read(n * rowBytes));
          final values = decodeFloats(raw, entry.dtype);
          final q = Int8List(n * cols);
          for (var r = 0; r < n; r++) {
            var maxAbs = 0.0;
            for (var c = 0; c < cols; c++) {
              final a = values[r * cols + c].abs();
              if (a > maxAbs) maxAbs = a;
            }
            final scale = maxAbs / 127.0;
            scaleData.setUint16(
                (r0 + r) * 2, f32ToF16Bits(scale), Endian.little);
            final inv = scale > 0 ? 1.0 / scale : 0.0;
            for (var c = 0; c < cols; c++) {
              q[r * cols + c] =
                  (values[r * cols + c] * inv).round().clamp(-127, 127);
            }
          }
          await writer.writeTensorChunk(Uint8List.sublistView(q));
        }
        await writer.writeTensorChunk(scales);
        return;
      }

      if (spec.dtype == Cmf.dtQ1) {
        // Per group of 32 weights: [f16 scale = mean(|w|)][4 bytes of sign
        // bits, LSB-first]; decode is w = scale * (2*bit - 1).
        final rows = entry.shape[0], cols = entry.shape[1];
        final groupsPerRow = (cols + 31) ~/ 32;
        final rowBytes = cols * entry.bytesPerElement;
        final rowsPerSlab = max(1, 8 * 1024 * 1024 ~/ rowBytes);
        await raf.setPosition(start);
        var offSpec = 0.0, total = 0.0; // 1-bit-ness sanity check
        for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
          final n = min(rowsPerSlab, rows - r0);
          final raw = Uint8List.fromList(await raf.read(n * rowBytes));
          final values = decodeFloats(raw, entry.dtype);
          final out = Uint8List(n * groupsPerRow * 6);
          final outData = ByteData.sublistView(out);
          for (var r = 0; r < n; r++) {
            for (var g = 0; g < groupsPerRow; g++) {
              final gStart = g * 32;
              final gLen = min(32, cols - gStart);
              var sumAbs = 0.0;
              for (var i = 0; i < gLen; i++) {
                sumAbs += values[r * cols + gStart + i].abs();
              }
              final scale = sumAbs / gLen;
              var bits = 0;
              for (var i = 0; i < gLen; i++) {
                final v = values[r * cols + gStart + i];
                if (v > 0) bits |= 1 << i;
                if (scale > 0 && (v.abs() - scale).abs() > 0.25 * scale) {
                  offSpec++;
                }
                total++;
              }
              final tile = (r * groupsPerRow + g) * 6;
              outData.setUint16(tile, f32ToF16Bits(scale), Endian.little);
              outData.setUint32(tile + 2, bits, Endian.little);
            }
          }
          await writer.writeTensorChunk(out);
        }
        if (total > 0 && offSpec / total > 0.05) {
          job.addLog(
              '⚠ ${entry.name}: ${(100 * offSpec / total).toStringAsFixed(0)}% '
              'of weights deviate from ±scale — source may not be 1-bit '
              'trained; Q1 will lose quality');
        }
        return;
      }

      // Generic float -> f16.
      final bpe = entry.bytesPerElement;
      final elemsPerSlab = max(1, 4 * 1024 * 1024 ~/ bpe);
      await raf.setPosition(start);
      var remaining = entry.numel;
      while (remaining > 0) {
        final n = min(remaining, elemsPerSlab);
        final raw = Uint8List.fromList(await raf.read(n * bpe));
        final values = decodeFloats(raw, entry.dtype);
        final out = Uint8List(n * 2);
        final outData = ByteData.sublistView(out);
        for (var i = 0; i < n; i++) {
          outData.setUint16(i * 2, f32ToF16Bits(values[i]), Endian.little);
        }
        await writer.writeTensorChunk(out);
        remaining -= n;
      }
    } finally {
      await raf.close();
    }
  }

  void dispose() => _updates.close();
}
