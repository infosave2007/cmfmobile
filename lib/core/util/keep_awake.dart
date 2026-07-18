import 'package:flutter/services.dart';

/// Keeps the screen on while the server runs (FLAG_KEEP_SCREEN_ON on
/// Android, isIdleTimerDisabled on iOS). Implemented as a tiny
/// MethodChannel in MainActivity.kt / AppDelegate.swift.
abstract final class KeepAwake {
  static const _channel = MethodChannel('cmf/keep_awake');

  static Future<void> enable() => _set(true);
  static Future<void> disable() => _set(false);

  static Future<void> _set(bool on) async {
    try {
      await _channel.invokeMethod<void>('setKeepAwake', on);
    } on MissingPluginException {
      // Tests / platforms without the channel: keep-awake is best-effort.
    }
  }
}
