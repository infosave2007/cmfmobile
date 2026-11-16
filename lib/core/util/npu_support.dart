import 'dart:io';

import 'package:flutter/services.dart';

import '../../data/services/inference/inference_engine.dart';

const _channel = MethodChannel('cmf/native_dir');
bool _configured = false;

/// Tell the runtime where the NPU libraries are: the app's native library
/// directory, which only the platform side knows. Once per process; a no-op
/// off Android and on a runtime without an NPU lane.
Future<void> configureNpu(InferenceEngine engine) async {
  if (_configured || !Platform.isAndroid) return;
  try {
    final dir = await _channel.invokeMethod<String>('nativeLibraryDir');
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
