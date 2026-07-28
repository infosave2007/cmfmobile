import 'dart:ffi' as ffi;

import 'package:cmf_mobile/data/services/inference/engine_tuning.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the live process environment. `Platform.environment` is a snapshot
/// the VM caches at startup, so it cannot see a `setenv` — but the engine
/// reads through libc, exactly like this.
String? getenv(String name) {
  final getenv = ffi.DynamicLibrary.process().lookupFunction<
      ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>),
      ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)>('getenv');
  final namePtr = name.toNativeUtf8();
  try {
    final value = getenv(namePtr);
    return value == ffi.nullptr ? null : value.toDartString();
  } finally {
    calloc.free(namePtr);
  }
}

void main() {
  group('parseFlags', () {
    test('keeps CMF_ keys and drops everything else', () {
      final flags = EngineTuning.parseFlags('''
CMF_REPACK=1
# a comment
CMF_PREFILL_CHUNK = 256

PATH=/tmp
cmf_repack=1
LD_PRELOAD=/data/local/tmp/evil.so
CMF_BROKEN
''');
      expect(flags, {'CMF_REPACK': '1', 'CMF_PREFILL_CHUNK': '256'});
    });

    test('drops values that would smuggle a second argument', () {
      expect(EngineTuning.parseFlags('CMF_KV=f16 --wat'), isEmpty);
    });

    test('empty text yields no flags', () {
      expect(EngineTuning.parseFlags(''), isEmpty);
      expect(EngineTuning.parseFlags('   \n\n'), isEmpty);
    });
  });

  group('apply', () {
    final env = getenv;

    test('pushes the explicit thread count and the flags to the environment',
        () {
      expect(EngineTuning.apply(threads: 3, flags: 'CMF_REPACK=1'), 3);
      expect(env('CMF_THREADS'), '3');
      expect(env('CMF_REPACK'), '1');
    });

    test('clears what the previous load set', () {
      EngineTuning.apply(threads: 3, flags: 'CMF_REPACK=1\nCMF_MLOCK=1');
      EngineTuning.apply(threads: 5, flags: 'CMF_MLOCK=1');

      expect(env('CMF_THREADS'), '5');
      expect(env('CMF_MLOCK'), '1');
      expect(env('CMF_REPACK'), isNull,
          reason: 'a flag the user removed must not survive the reload');
    });

    test('auto on a flat topology hands the pool back to the engine', () {
      EngineTuning.apply(threads: 4);
      expect(env('CMF_THREADS'), '4');

      // The test host has no Android sysfs, so auto cannot detect a big
      // cluster — the stale explicit value has to go.
      expect(EngineTuning.apply(threads: 0), isNull);
      expect(env('CMF_THREADS'), isNull);
    });
  });

  group('gpuHelpsQuant', () {
    test('withholds the GPU flag for a quantization with no GPU kernel', () {
      // Measured: same pool, same free memory, idle CPU — 13.30 tok/s with
      // the flag off against 0.94 with it on (native/TUNING.md).
      expect(EngineTuning.gpuHelpsQuant('VBIT'), isFalse);
      expect(EngineTuning.gpuHelpsQuant('vbit'), isFalse);
      expect(EngineTuning.gpuHelpsQuant('VBIT_RO'), isFalse);
    });

    test('lets everything else through — the engine is the authority', () {
      expect(EngineTuning.gpuHelpsQuant('Q8_2F'), isTrue);
      expect(EngineTuning.gpuHelpsQuant('Q1'), isTrue);
      expect(EngineTuning.gpuHelpsQuant('SOMETHING_NEW'), isTrue);
      expect(EngineTuning.gpuHelpsQuant(null), isTrue);
      expect(EngineTuning.gpuHelpsQuant(''), isTrue);
    });
  });

  group('flagsForLoad', () {
    test('leaves the flags alone when the GPU is off', () {
      expect(EngineTuning.flagsForLoad('', gpuEnabled: false), '');
      expect(EngineTuning.flagsForLoad('CMF_MLOCK=1', gpuEnabled: false),
          'CMF_MLOCK=1');
    });

    test('a value the user set explicitly is never overridden', () {
      const explicit = 'CMF_GPU_WGPU_GRAPH=1';
      expect(EngineTuning.flagsForLoad(explicit, gpuEnabled: true), explicit);
    });

    // The mobile default itself only applies on a device; off-device this
    // returns the flags unchanged, which is what the host test sees.
    test('off-device the flags pass through', () {
      expect(EngineTuning.flagsForLoad('CMF_MLOCK=1', gpuEnabled: true),
          'CMF_MLOCK=1');
    });
  });

  group('resolveThreads', () {
    test('an explicit setting is passed through', () {
      expect(EngineTuning.resolveThreads(3), 3);
      expect(EngineTuning.resolveThreads(8), 8);
    });

    test('auto resolves to a usable pool size off-device too', () {
      // No Android sysfs under the test host, so this exercises the
      // fallback: it must still be something the converter can size a pool
      // with, never 0.
      expect(EngineTuning.resolveThreads(0), greaterThanOrEqualTo(1));
    });
  });
}
