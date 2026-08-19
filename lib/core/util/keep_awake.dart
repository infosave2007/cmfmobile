import 'package:flutter/services.dart';

/// Keeps the screen on while long work runs (FLAG_KEEP_SCREEN_ON on Android,
/// isIdleTimerDisabled on iOS). Implemented as a tiny MethodChannel in
/// MainActivity.kt / AppDelegate.swift.
///
/// Reference-counted like [ForegroundTask]: the server, a companion worker and
/// a conversion hold it independently, and the hold must survive the first of
/// them finishing. A plain enable/disable pair let "stop the server" switch
/// the screen back off under a conversion that was still downloading.
abstract final class KeepAwake {
  static const _channel = MethodChannel('cmf/keep_awake');

  /// The CMF server — held from start to stop.
  static const server = 'server';

  /// Serving layer span to a desktop coordinator.
  static const companion = 'companion';

  /// One import job: download plus conversion. On iOS the screen going dark
  /// backgrounds the app and iOS then suspends it, which stops the transfer
  /// mid-file; on Android the process also drops to the little-core cpuset.
  static const conversion = 'conversion';

  static final Set<String> _holders = {};

  static Future<void> acquire(String reason) async {
    if (!_holders.add(reason)) return;
    if (_holders.length == 1) await _set(true);
  }

  static Future<void> release(String reason) async {
    if (!_holders.remove(reason)) return;
    if (_holders.isEmpty) await _set(false);
  }

  /// Visible for tests: drops every hold without touching the platform.
  static void resetForTest() => _holders.clear();

  static Future<void> _set(bool on) async {
    try {
      await _channel.invokeMethod<void>('setKeepAwake', on);
    } on MissingPluginException {
      // Tests / platforms without the channel: keep-awake is best-effort.
    }
  }
}
