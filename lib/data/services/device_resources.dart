import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';

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
    const runtimeOverhead = 384 * 1024 * 1024;
    return model.sizeBytes + kvCache + runtimeOverhead;
  }

  /// Apps can't take all physical RAM: the OS, other apps and platform
  /// limits (iOS jetsam) leave roughly half usable for a big allocation.
  Future<MemoryCheck> checkFit(LocalModel model) async {
    final total = await totalRamBytes();
    final usable = total > 0 ? (total * 0.55).round() : 1 << 62;
    return MemoryCheck(
      requiredBytes: estimateRequiredBytes(model),
      totalRamBytes: total,
      usableRamBytes: usable,
    );
  }
}
