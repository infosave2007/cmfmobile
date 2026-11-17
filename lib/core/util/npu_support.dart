import 'dart:io';

import 'package:flutter/services.dart';

import '../../data/services/inference/inference_engine.dart';

const _channel = MethodChannel('cmf/native_dir');
bool _configured = false;

/// Tell the runtime where the NPU module's DSP half is: a file the platform
/// side copies out of the APK on first use. Once per process; a no-op off
/// Android and on a runtime without an NPU lane. Without a directory the
/// runtime reports the module as unavailable.
Future<void> configureNpu(InferenceEngine engine) async {
  if (_configured || !Platform.isAndroid) return;
  try {
    final dir = await _channel.invokeMethod<String>('npuDir');
    if (dir != null && dir.isNotEmpty) {
      engine.configureNpu(dir);
      _configured = true;
    }
  } on PlatformException {
    // Without the directory the runtime falls back to the loader's default
    // search path and reports what it could not find.
  } on MissingPluginException {
    // Tests and non-Android hosts.
  }
}
