import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

/// Runtime tuning of the native cortiq runtime, pushed through the process
/// environment because the C ABI (native/cortiq_ffi.h) takes no such knobs.
///
/// The worker pool is built inside `cortiq_load` by
/// `cortiq_engine::pool::Pool::from_env`: it reads `CMF_THREADS`, and absent
/// that falls back to `min(available_parallelism() - 1, 8)` — below 2 it
/// runs single-threaded. Every worker then pins itself to the big cluster
/// (`sched_setaffinity` over the cores whose `cpu_capacity` reaches 62.5% of
/// the maximum). On a big.LITTLE phone the fallback therefore puts ~7
/// workers on ~4 cores, and since the matmuls split rows across the pool and
/// join on a barrier per layer, the extra workers only add a second wait
/// round. So the app sizes the pool to the big cluster itself.
///
/// Environment writes go through libc `setenv` — Dart's own
/// `Platform.environment` is a read-only snapshot, but the engine and the
/// Dart VM share one bionic/libSystem instance, so the variable is visible
/// to Rust's `std::env::var`. Everything here must run before
/// `cortiq_load`; the pool is built once per load.
abstract final class EngineTuning {
  static const _sysCpu = '/sys/devices/system/cpu';

  /// Same cutoff the engine's `pin_current_thread_to_big_cores` applies
  /// (`5 * max <= 8 * capacity`) — keep the two in sync or the pool ends up
  /// sized for a core set it is not allowed to run on.
  static const _bigCoreRatio = 0.625;

  static bool _probed = false;
  static int? _bigCores;

  /// Number of cores in the cluster the engine pins its workers to, or null
  /// when the topology is flat / unreadable (then the engine's own default
  /// is as good a guess as ours).
  static int? get bigCoreCount {
    if (!_probed) {
      _probed = true;
      _bigCores = _detectBigCores();
    }
    return _bigCores;
  }

  /// Thread count for a settings value where 0 means "auto".
  ///
  /// Also used for the converter's isolate pool, which is why it always
  /// returns a usable number instead of null.
  static int resolveThreads(int setting) {
    if (setting > 0) return setting;
    return bigCoreCount ?? math.max(1, Platform.numberOfProcessors - 1);
  }

  /// Variables this class set for the previous load, so that a knob the user
  /// removed — or a thread count switched back to auto — is cleared instead
  /// of lingering in the environment for the rest of the process.
  static final Set<String> _applied = {};

  /// Applies the tuning for the next `cortiq_load`. Returns the pool size
  /// that was pushed to the engine, or null when it was left to decide.
  ///
  /// [threads] null means the caller sized the pool through
  /// `cortiq_set_threads` instead — then any `CMF_THREADS` left over from an
  /// older runtime is cleared, so the two can never disagree.
  static int? apply({int? threads = 0, String flags = ''}) {
    final wanted = parseFlags(flags);
    // An explicit setting wins; on auto we only override the engine when the
    // cores are actually asymmetric — its own default is no worse otherwise.
    final pool = threads == null
        ? null
        : threads > 0
            ? threads
            : bigCoreCount;
    if (pool != null && pool >= 2) wanted['CMF_THREADS'] = '$pool';

    for (final stale in _applied.difference(wanted.keys.toSet())) {
      _unsetenv(stale);
    }
    _applied
      ..clear()
      ..addAll(wanted.keys);
    var appliedPool = wanted.containsKey('CMF_THREADS') ? pool : null;
    for (final entry in wanted.entries) {
      if (!_setenv(entry.key, entry.value) && entry.key == 'CMF_THREADS') {
        appliedPool = null;
      }
    }
    return appliedPool;
  }

  /// Parses the advanced "engine flags" setting: one `CMF_KEY=value` per
  /// line, `#` comments and blank lines ignored. Unknown-looking keys are
  /// dropped rather than passed on — a typo must not turn into a stray
  /// environment variable for the whole process.
  static Map<String, String> parseFlags(String text) {
    final flags = <String, String>{};
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      final value = line.substring(eq + 1).trim();
      if (!_flagKey.hasMatch(key) || !_flagValue.hasMatch(value)) continue;
      flags[key] = value;
    }
    return flags;
  }

  static final _flagKey = RegExp(r'^CMF_[A-Z0-9_]{1,32}$');

  /// Values reach the engine through the environment, so they stay on a
  /// short leash: the knobs take numbers and short identifiers, and nothing
  /// here should be able to carry whitespace or shell punctuation.
  static final _flagValue = RegExp(r'^[A-Za-z0-9_.,:/+-]{1,64}$');

  // --- platform plumbing ---------------------------------------------------

  static _SetenvDart? _setenvFn;
  static _UnsetenvDart? _unsetenvFn;
  static bool _libcResolved = false;

  static void _resolveLibc() {
    if (_libcResolved) return;
    _libcResolved = true;
    try {
      final process = ffi.DynamicLibrary.process();
      _setenvFn = process.lookupFunction<_SetenvNative, _SetenvDart>('setenv');
      _unsetenvFn =
          process.lookupFunction<_UnsetenvNative, _UnsetenvDart>('unsetenv');
    } catch (_) {
      // No POSIX environment API (Windows): nothing here can be tuned.
      _setenvFn = null;
      _unsetenvFn = null;
    }
  }

  static bool _setenv(String name, String value) {
    _resolveLibc();
    final setenv = _setenvFn;
    if (setenv == null) return false;
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      return setenv(namePtr, valuePtr, 1) == 0;
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  static void _unsetenv(String name) {
    _resolveLibc();
    final unsetenv = _unsetenvFn;
    if (unsetenv == null) return;
    final namePtr = name.toNativeUtf8();
    try {
      unsetenv(namePtr);
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Counts the cores the engine's affinity mask will contain. `cpu_capacity`
  /// is the scheduler's own view of relative core strength; kernels without
  /// it (or without EAS) fall back to max frequency, which orders the
  /// clusters the same way.
  static int? _detectBigCores() {
    if (!Platform.isAndroid) return null;
    final capacities = _readPerCore('cpu_capacity') ??
        _readPerCore('cpufreq/cpuinfo_max_freq');
    if (capacities == null || capacities.length < 2) return null;
    final max = capacities.reduce(math.max);
    if (max <= 0) return null;
    final cutoff = max * _bigCoreRatio;
    final big = capacities.where((c) => c >= cutoff).length;
    // A flat topology means the engine pins nothing, and a single strong
    // core means a pool would only contend with itself.
    if (big == capacities.length || big < 2) return null;
    return big;
  }

  static List<int>? _readPerCore(String relative) {
    final values = <int>[];
    for (var cpu = 0; cpu < 64; cpu++) {
      final file = File('$_sysCpu/cpu$cpu/$relative');
      final int value;
      try {
        if (!file.existsSync()) break;
        value = int.parse(file.readAsStringSync().trim());
      } on FileSystemException {
        // Offline core, or sysfs closed to apps: an incomplete picture is
        // worse than none, since the missing core may be the big one.
        return null;
      } on FormatException {
        return null;
      }
      values.add(value);
    }
    return values.isEmpty ? null : values;
  }
}

typedef _SetenvNative = ffi.Int32 Function(
    ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32);
typedef _SetenvDart = int Function(
    ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int);
typedef _UnsetenvNative = ffi.Int32 Function(ffi.Pointer<Utf8>);
typedef _UnsetenvDart = int Function(ffi.Pointer<Utf8>);
