import 'package:flutter/services.dart';

/// Holds the process at foreground scheduling priority while inference runs.
///
/// Android confines background processes to the little-core cpuset, and a
/// cpuset wins over the affinity mask the engine sets for its worker pool —
/// so a reply generated after the user switches away, or a serving session
/// with the screen off, would otherwise run several times slower. The
/// Android side ([InferenceService]) also takes a partial wake lock.
///
/// Reference-counted: chat generation and the server hold it independently,
/// and the service must survive the first of them finishing.
abstract final class ForegroundTask {
  static const _channel = MethodChannel('cmf/foreground');

  /// Reply generation — held for the length of one reply.
  static const generation = 'generation';

  /// The CMF server — held from start to stop.
  static const server = 'server';

  /// Serving layer spans to a desktop coordinator. Held for as long as the
  /// listener lives, which is the life of the process: the runtime has no
  /// call to stop it. The governor is the reason this matters — a worker that
  /// computes for a few milliseconds and then blocks on a socket never
  /// convinces `schedutil` to raise the clock, and that measured as half the
  /// throughput.
  static const companion = 'companion';

  static final Set<String> _holders = {};

  static Future<void> acquire(String reason) async {
    if (!_holders.add(reason)) return;
    await _invoke('start', {'reason': reason});
  }

  static Future<void> release(String reason) async {
    if (!_holders.remove(reason)) return;
    if (_holders.isEmpty) {
      await _invoke('stop', null);
    } else {
      // Another holder remains: re-label the notification for what is left.
      await _invoke('start', {'reason': _holders.first});
    }
  }

  static Future<void> _invoke(String method, Map<String, Object?>? args) async {
    try {
      await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      // iOS / tests: no such service, and iOS keeps app threads on the
      // performance cores anyway while the app is active.
    } on PlatformException {
      // Best-effort: a refused foreground start only costs speed.
    }
  }
}
