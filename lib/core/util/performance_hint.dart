import 'package:flutter/services.dart';

/// Android performance hints (ADPF) for the engine's worker threads.
///
/// Pinning the workers to the big cores does not say anything about the clock
/// they run at, and a generation looks to the governor like a series of short
/// bursts. A hint session names those threads and a target duration per work
/// cycle; reporting what a cycle actually cost lets the system decide to go
/// faster, and closing the session gives the clocks straight back.
///
/// API 31+ on Android, a no-op elsewhere. Every call is best-effort: a hint
/// that does not arrive costs speed, never correctness.
abstract final class PerformanceHint {
  static const _channel = MethodChannel('cmf/perf_hint');

  static bool _active = false;

  /// Opens a session for [threadIds] aiming at [target] per cycle. Returns
  /// false when the platform or the runtime cannot provide one.
  static Future<bool> start(List<int> threadIds, Duration target) async {
    if (threadIds.isEmpty || target <= Duration.zero) return false;
    final started = await _invoke<bool>('start', {
      'tids': threadIds,
      'targetNanos': target.inMicroseconds * 1000,
    });
    _active = started ?? false;
    return _active;
  }

  /// Reports what the last cycle actually took.
  static Future<void> report(Duration actual) async {
    if (!_active || actual <= Duration.zero) return;
    await _invoke<void>('report', {'actualNanos': actual.inMicroseconds * 1000});
  }

  static Future<void> stop() async {
    if (!_active) return;
    _active = false;
    await _invoke<void>('stop', null);
  }

  static Future<T?> _invoke<T>(String method, Map<String, Object?>? args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // iOS / tests: no hint manager to talk to
    } on PlatformException {
      return null;
    }
  }
}
