import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local, privacy-first crash log: uncaught errors are appended to
/// `documents/crash.log` (size-capped), so field problems can be diagnosed
/// without shipping anything to a third-party service — in line with the
/// app's local-first design.
class CrashLog {
  static const int _maxBytes = 256 * 1024;
  static File? _file;

  static Future<void> install() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _file = File('${docs.path}/crash.log');
    } catch (_) {
      // No documents dir (tests, exotic platforms) — logging stays off.
    }
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      record('flutter', details.exceptionAsString(), details.stack);
      previousFlutter?.call(details);
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('platform', error.toString(), stack);
      return previousPlatform?.call(error, stack) ?? true;
    };
  }

  static void record(String source, String error, StackTrace? stack) {
    final file = _file;
    if (file == null) return;
    try {
      final entry = '--- ${DateTime.now().toIso8601String()} [$source]\n'
          '$error\n${stack ?? ''}\n';
      // Sync writes: the app may be crashing right now.
      if (file.existsSync() && file.lengthSync() > _maxBytes) {
        file.writeAsStringSync(entry); // simple rotation: start over
      } else {
        file.writeAsStringSync(entry, mode: FileMode.append);
      }
    } catch (_) {}
  }
}
