import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../models/chat.dart';
import '../../models/local_model.dart';
import 'inference_engine.dart';

// C ABI of the cortiq FFI shim (native/cortiq_ffi.h), built from the
// cmfpublic Rust workspace via `cargo ndk` / `cargo lipo`:
//   void*       cortiq_load(const char* path, int32_t threads);
//   void        cortiq_free(void* ctx);
//   int32_t     cortiq_generate(void* ctx, const char* request_json,
//                               void (*on_event)(const char* event_json));
//   void        cortiq_cancel(void* ctx);
//   const char* cortiq_last_error(void);
typedef _LoadNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<Utf8>, ffi.Int32);
typedef _LoadDart = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>, int);
typedef _FreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _FreeDart = void Function(ffi.Pointer<ffi.Void>);
typedef _EventCallbackNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _GenerateNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<Utf8>,
    ffi.Pointer<ffi.NativeFunction<_EventCallbackNative>>);
typedef _GenerateDart = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>,
    ffi.Pointer<ffi.NativeFunction<_EventCallbackNative>>);
typedef _CancelNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _CancelDart = void Function(ffi.Pointer<ffi.Void>);
typedef _LastErrorNative = ffi.Pointer<Utf8> Function();
typedef _LastErrorDart = ffi.Pointer<Utf8> Function();

/// FFI binding to the cortiq-engine runtime (CMF inference in Rust).
///
/// The native library is optional: on devices where it is not bundled the
/// engine reports [isAvailable] == false and the app falls back to
/// [DemoEngine]. Build instructions live in native/README.md.
class NativeCortiqEngine implements InferenceEngine {
  NativeCortiqEngine() {
    _tryOpen();
  }

  ffi.DynamicLibrary? _lib;
  _LoadDart? _load;
  _FreeDart? _free;
  _GenerateDart? _generate;
  _CancelDart? _cancel;
  _LastErrorDart? _lastError;

  ffi.Pointer<ffi.Void>? _ctx;
  LocalModel? _loaded;

  void _tryOpen() {
    try {
      if (Platform.isAndroid) {
        _lib = ffi.DynamicLibrary.open('libcortiq_ffi.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        // Statically linked into the app binary on Apple platforms.
        _lib = ffi.DynamicLibrary.process();
        // Probe for the symbol; process() always opens.
        _lib!.lookup('cortiq_load');
      } else {
        _lib = ffi.DynamicLibrary.open('libcortiq_ffi.dylib');
      }
      _load = _lib!.lookupFunction<_LoadNative, _LoadDart>('cortiq_load');
      _free = _lib!.lookupFunction<_FreeNative, _FreeDart>('cortiq_free');
      _generate = _lib!
          .lookupFunction<_GenerateNative, _GenerateDart>('cortiq_generate');
      _cancel =
          _lib!.lookupFunction<_CancelNative, _CancelDart>('cortiq_cancel');
      _lastError = _lib!
          .lookupFunction<_LastErrorNative, _LastErrorDart>('cortiq_last_error');
    } catch (_) {
      _lib = null;
    }
  }

  @override
  bool get isAvailable => _lib != null;

  @override
  String get name => 'cortiq-native';

  @override
  LocalModel? get loadedModel => _loaded;

  String _errorText() {
    final p = _lastError?.call();
    if (p == null || p == ffi.nullptr) return 'unknown native error';
    return p.toDartString();
  }

  @override
  Future<void> loadModel(LocalModel model, {int threads = 4}) async {
    if (!isAvailable) {
      throw StateError('native cortiq runtime is not bundled');
    }
    await unload();
    final pathPtr = model.filePath.toNativeUtf8();
    try {
      final ctx = _load!(pathPtr, threads);
      if (ctx == ffi.nullptr) {
        throw StateError('cortiq_load failed: ${_errorText()}');
      }
      _ctx = ctx;
      _loaded = model;
    } finally {
      calloc.free(pathPtr);
    }
  }

  @override
  Future<void> unload() async {
    final ctx = _ctx;
    if (ctx != null) {
      _free!(ctx);
      _ctx = null;
      _loaded = null;
    }
  }

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) {
    final ctx = _ctx;
    if (ctx == null) {
      return Stream.error(StateError('no model loaded'));
    }
    final controller = StreamController<GenerationEvent>();
    final started = DateTime.now();

    late final ffi.NativeCallable<_EventCallbackNative> callable;
    callable = ffi.NativeCallable<_EventCallbackNative>.listener(
        (ffi.Pointer<Utf8> eventJson) {
      try {
        final event =
            jsonDecode(eventJson.toDartString()) as Map<String, dynamic>;
        final delta = event['delta'] as String? ?? '';
        final done = event['done'] as bool? ?? false;
        if (!done) {
          controller.add(GenerationEvent(delta: delta));
          return;
        }
        final usage = event['usage'] as Map<String, dynamic>? ?? const {};
        final elapsed = DateTime.now().difference(started);
        final completion = usage['completion_tokens'] as int? ?? 0;
        controller.add(GenerationEvent(
          done: true,
          stats: GenerationStats(
            promptTokens: usage['prompt_tokens'] as int? ?? 0,
            completionTokens: completion,
            tokensPerSecond:
                (event['tokens_per_second'] as num?)?.toDouble() ??
                    (elapsed.inMilliseconds > 0
                        ? completion * 1000 / elapsed.inMilliseconds
                        : 0),
            latencyMs: elapsed.inMilliseconds,
            finishReason: event['finish_reason'] as String? ?? 'stop',
            taskUsed: event['task_used'] as String?,
          ),
        ));
        controller.close();
        callable.close();
      } catch (e) {
        controller.addError(e);
      }
    });

    final requestJson = jsonEncode({
      'messages': [
        for (final m in request.messages)
          {'role': m.role.name, 'content': m.content},
      ],
      'temperature': request.temperature,
      'top_p': request.topP,
      'max_tokens': request.maxTokens,
      if (request.task != null) 'cortiq': {'task': request.task},
    });
    final reqPtr = requestJson.toNativeUtf8();
    final rc = _generate!(ctx, reqPtr, callable.nativeFunction);
    calloc.free(reqPtr);
    if (rc != 0) {
      controller.addError(StateError('cortiq_generate: ${_errorText()}'));
      controller.close();
      callable.close();
    }
    return controller.stream;
  }

  @override
  void cancel() {
    final ctx = _ctx;
    if (ctx != null) _cancel!(ctx);
  }
}
