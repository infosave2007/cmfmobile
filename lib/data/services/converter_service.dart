import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/conversion.dart';
import 'cmf_format.dart';
import 'converter_core.dart';
import 'hf_api.dart';
import 'model_repository.dart';

/// HuggingFace → .cmf conversion pipeline, mirroring cortiq-gateway's
/// import jobs (search → configure → convert with progress → done).
///
/// Two paths:
///  * repos that already publish .cmf files are downloaded directly
///    (any quantization);
///  * safetensors repos are converted on device by [convertSafetensorsToCmf]
///    — Q4TP (recommended), Q2TP, Q8_ROW, Q8_2F, Q4_BLOCK, Q1T, Q1 and F16
///    targets on a parallel isolate pool (VBIT still needs the desktop
///    cortiq toolchain).
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
    int threads = 4,
  }) async {
    final dir = await models.modelsDir();
    final outName = sanitizeName(
      (name == null || name.trim().isEmpty) ? repo.split('/').last : name,
    );
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
    unawaited(_run(job, hfToken, threads));
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

  Future<void> _run(ConversionJob job, String? hfToken, int threads) async {
    Directory? tempDir;
    try {
      // A featured ready-CMF repo receives a placeholder quant value. Do not
      // present it as the downloaded file's actual quantization.
      job.addLog('→ inspecting ${job.repo}');
      _progress(job, 0.02, 'listing');
      final files = await hf.listFiles(job.repo, token: hfToken);

      final cmfFiles = files
          .where((f) => f.path.toLowerCase().endsWith('.cmf'))
          .toList();
      if (cmfFiles.isNotEmpty) {
        job.directDownload = true;
        await _downloadCmfDirectly(job, cmfFiles, hfToken, threads);
      } else {
        if (!job.quant.supportedOnDevice) {
          throw StateError(
            '${job.quant.label} requires the desktop cortiq toolchain; '
            'on device choose Q8_ROW, Q8_2F, Q1 or F16, or pick a repo '
            'that ships .cmf files',
          );
        }
        job.addLog(
          '→ converting ${job.repo} to ${job.name} '
          '(${job.quant.label}, $threads threads)',
        );
        tempDir = Directory(
          '${(await getTemporaryDirectory()).path}/convert/${job.id}',
        );
        await tempDir.create(recursive: true);
        await _convertSafetensors(job, files, tempDir, hfToken, threads);
      }

      final size = await File(job.outputPath).length();
      job.sizeBytes = size;
      try {
        job.resultQuant = (await CmfReader.readMetadata(
          job.outputPath,
        )).quantType;
      } catch (_) {
        // Display-only; a parse hiccup must not fail the finished job.
      }
      job.state = JobState.done;
      job.finished = DateTime.now();
      job.progress = 1;
      job.phase = 'done';
      job.addLog('✓ done (${(size / 1024 / 1024).toStringAsFixed(1)} MB)');
    } on CancelledException {
      await _markCancelled(job);
    } on ConvertCancelled {
      await _markCancelled(job);
    } catch (e) {
      job.state = JobState.error;
      job.error = e.toString();
      job.finished = DateTime.now();
      job.addLog('✗ error: $e');
      await _cleanupOutputs(job);
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

  Future<void> _markCancelled(ConversionJob job) async {
    job.state = JobState.cancelled;
    job.finished = DateTime.now();
    job.addLog('✗ cancelled');
    await _cleanupOutputs(job);
  }

  /// Removes the output and any staging sidecars (.part download,
  /// .tmp conversion) a failed or cancelled job may have left behind.
  Future<void> _cleanupOutputs(ConversionJob job) async {
    for (final path in [
      job.outputPath,
      '${job.outputPath}.part',
      '${job.outputPath}.tmp',
    ]) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _downloadCmfDirectly(
    ConversionJob job,
    List<HfFileEntry> cmfFiles,
    String? hfToken,
    int threads,
  ) async {
    cmfFiles.sort((a, b) => b.size.compareTo(a.size));
    final src = cmfFiles.first;
    final parallelism = threads.clamp(2, 8);
    job.addLog(
      'repo ships ${src.path} — downloading directly '
      '($parallelism connections)',
    );
    // Download into a sidecar and rename at the end, so an interrupted
    // download never leaves a partial .cmf in the model library.
    final partPath = '${job.outputPath}.part';
    await hf.downloadParallel(
      job.repo,
      src.path,
      partPath,
      totalSize: src.size,
      parallelism: parallelism,
      token: hfToken,
      isCancelled: () => _isCancelled(job),
      onBytes: (received, total) {
        final t = total > 0 ? total : src.size;
        _progress(job, t > 0 ? received / t : 0, 'downloading');
      },
    );
    if (src.size > 0) {
      final actual = await File(partPath).length();
      if (actual != src.size) {
        throw StateError(
          '${src.path} downloaded incompletely '
          '($actual of ${src.size} bytes) — retry the job',
        );
      }
    }
    await File(partPath).rename(job.outputPath);
  }

  Future<void> _convertSafetensors(
    ConversionJob job,
    List<HfFileEntry> files,
    Directory tempDir,
    String? hfToken,
    int threads,
  ) async {
    bool has(String name) => files.any((f) => f.path == name);
    if (!has('config.json')) {
      throw StateError('repo has no config.json (not a transformers model)');
    }
    if (!has('tokenizer.json')) {
      throw StateError(
        'repo has no tokenizer.json '
        '(sentencepiece-only repos are not supported yet)',
      );
    }

    // Resolve safetensors shards (single file or index + shards).
    List<String> shardNames;
    if (has('model.safetensors.index.json')) {
      final indexJson =
          jsonDecode(
                await hf.fetchText(
                  job.repo,
                  'model.safetensors.index.json',
                  token: hfToken,
                ),
              )
              as Map<String, dynamic>;
      final weightMap = indexJson['weight_map'] as Map<String, dynamic>;
      shardNames = weightMap.values.cast<String>().toSet().toList()..sort();
    } else if (has('model.safetensors')) {
      shardNames = ['model.safetensors'];
    } else {
      final loose =
          files
              .where(
                (f) => f.path.endsWith('.safetensors') && !f.path.contains('/'),
              )
              .map((f) => f.path)
              .toList()
            ..sort();
      if (loose.isEmpty) {
        throw StateError(
          'repo has no safetensors weights '
          '(GGUF-only repos need the desktop `cortiq import-gguf`)',
        );
      }
      shardNames = loose;
    }

    // Validate the architecture BEFORE the multi-GB download. Qwen MoE,
    // Qwen3.5 GatedDeltaNet and LFM2-MoE/ShortConv are supported.
    final config =
        jsonDecode(await hf.fetchText(job.repo, 'config.json', token: hfToken))
            as Map<String, dynamic>;
    ensureSupportedArch(config);

    // Phase 1: download (0.02 → 0.55), weighted by bytes.
    String? tokenizerConfigText;
    if (has('tokenizer_config.json')) {
      tokenizerConfigText = await hf.fetchText(
        job.repo,
        'tokenizer_config.json',
        token: hfToken,
      );
    }
    // LFM2 and newer Qwen releases may publish the authoritative template as
    // a sidecar rather than embedding it in tokenizer_config.json.
    if (has('chat_template.jinja')) {
      final sidecar = await hf.fetchText(
        job.repo,
        'chat_template.jinja',
        token: hfToken,
      );
      tokenizerConfigText = mergeTokenizerChatTemplate(
        tokenizerConfigText,
        sidecar,
      );
    }
    final vocabPath = '${tempDir.path}/tokenizer.json';
    await hf.download(
      job.repo,
      'tokenizer.json',
      vocabPath,
      token: hfToken,
      isCancelled: () => _isCancelled(job),
    );

    final totalBytes = shardNames
        .map((n) => files.where((f) => f.path == n).firstOrNull?.size ?? 0)
        .fold<int>(0, (a, b) => a + b);
    var downloaded = 0;
    final shardPaths = <String>[];
    for (final shard in shardNames) {
      job.addLog('downloading $shard');
      final dest = '${tempDir.path}/$shard';
      final base = downloaded;
      final shardSize =
          files.where((f) => f.path == shard).firstOrNull?.size ?? 0;
      await hf.downloadParallel(
        job.repo,
        shard,
        dest,
        totalSize: shardSize,
        parallelism: threads.clamp(2, 8),
        token: hfToken,
        isCancelled: () => _isCancelled(job),
        onBytes: (received, total) {
          final done = base + received;
          if (totalBytes > 0) {
            _progress(job, 0.02 + 0.53 * done / totalBytes, 'downloading');
          }
        },
      );
      if (shardSize > 0) {
        final actual = await File(dest).length();
        if (actual != shardSize) {
          throw StateError(
            '$shard downloaded incompletely '
            '($actual of $shardSize bytes) — retry the job',
          );
        }
      }
      downloaded += shardSize;
      shardPaths.add(dest);
    }
    if (_isCancelled(job)) throw const CancelledException();

    // Phase 2: parallel quantization on the isolate pool (0.56 → 0.98).
    _progress(job, 0.56, 'quantizing');
    await convertSafetensorsToCmf(
      ConvertInput(
        shardPaths: shardPaths,
        config: config,
        tokenizerConfigText: tokenizerConfigText,
        vocabPath: vocabPath,
        outputPath: job.outputPath,
        quant: job.quant,
        sourceRepo: job.repo,
        threads: threads,
      ),
      onLog: job.addLog,
      isCancelled: () => _isCancelled(job),
      onProgress: (done, total) {
        if (total > 0) {
          _progress(job, 0.56 + 0.42 * done / total, 'quantizing');
        }
      },
    );
    _progress(job, 0.99, 'finalizing');
  }

  void dispose() => _updates.close();
}
