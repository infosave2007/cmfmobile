import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../models/local_model.dart';

class MemoryCheck {
  const MemoryCheck({
    required this.requiredBytes,
    required this.totalRamBytes,
    required this.usableRamBytes,
  });

  final int requiredBytes;
  final int totalRamBytes;
  final int usableRamBytes;

  bool get fits => requiredBytes <= usableRamBytes;
}

/// Estimates whether a model can run in this device's memory before loading
/// it, so users get a warning instead of an OOM kill.
class DeviceResources {
  int? _totalRam;

  Future<int> totalRamBytes() async {
    if (_totalRam != null) return _totalRam!;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        _totalRam = info.physicalRamSize * 1024 * 1024;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        _totalRam = info.physicalRamSize * 1024 * 1024;
      }
    } catch (_) {
      _totalRam = 0;
    }
    return _totalRam ??= 0;
  }

  /// Weights (mmap resident under load) + KV cache + runtime overhead.
  int estimateRequiredBytes(LocalModel model) {
    final meta = model.meta;
    var kvCache = 0;
    if (meta != null && meta.numLayers > 0) {
      // f16 K and V per token: 2 * layers * kv_heads * head_dim * 2 bytes.
      final kvHeads = meta.numKvHeads > 0 ? meta.numKvHeads : 8;
      final headDim = meta.headDim > 0
          ? meta.headDim
          : (meta.hiddenSize > 0 ? meta.hiddenSize ~/ 32 : 128);
      final perToken = 2 * meta.numLayers * kvHeads * headDim * 2;
      final ctx = min(meta.contextLength > 0 ? meta.contextLength : 4096, 4096);
      kvCache = perToken * ctx;
    }
    return model.sizeBytes + kvCache + kRuntimeOverheadBytes;
  }

  /// Engine, framework and scratch buffers on top of weights and KV cache.
  static const int kRuntimeOverheadBytes = 384 * 1024 * 1024;

  static const _memoryChannel = MethodChannel('cmf/device_memory');

  /// Actually-available memory right now: ActivityManager.availMem on
  /// Android, os_proc_available_memory on iOS. 0 when unavailable.
  Future<int> availableRamBytes() async {
    try {
      final info = await _memoryChannel
          .invokeMapMethod<String, dynamic>('memoryInfo');
      return (info?['availBytes'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// What this process may actually use. On iOS that is
  /// os_proc_available_memory — the per-process jetsam budget, which on an
  /// 8 GB phone is a few GB, not 8. Every "will it fit" judgement in the app
  /// must come through here: measuring against the device's total RAM
  /// instead promises models the loader then refuses.
  ///
  /// Prefers the platform's live figure (with 20% headroom for the OS
  /// watermark); falls back to the "roughly half of physical RAM" heuristic
  /// when the channel is unavailable.
  Future<int> usableRamBytes() async {
    final available = await availableRamBytes();
    if (available > 0) return (available * 0.8).round();
    final total = await totalRamBytes();
    return total > 0 ? (total * 0.55).round() : 1 << 62;
  }

  /// Pre-download check. A Hugging Face repo listing carries file sizes but
  /// no layer or context metadata, so the KV cache cannot be estimated the
  /// way [estimateRequiredBytes] does. Weights plus runtime overhead is a
  /// strict LOWER bound on what loading will need: whatever fails this can
  /// never load, and nothing loadable is wrongly rejected — the right bias
  /// for a warning shown before a multi-gigabyte download.
  Future<bool> weightsExceedBudget(int weightsBytes) async {
    if (weightsBytes <= 0) return false;
    final usable = await usableRamBytes();
    return usable > 0 && weightsBytes + kRuntimeOverheadBytes > usable;
  }

  Future<MemoryCheck> checkFit(LocalModel model) async {
    return MemoryCheck(
      requiredBytes: estimateRequiredBytes(model),
      totalRamBytes: await totalRamBytes(),
      usableRamBytes: await usableRamBytes(),
    );
  }
}
