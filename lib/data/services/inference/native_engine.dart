import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../models/chat.dart';
import '../../models/local_model.dart';
import '../cmf_format.dart';
import 'demo_engine.dart' show DemoEngine;
import 'inference_engine.dart';

// C ABI of cortiq-ffi >= 0.3.10 (cmf crates/cortiq-ffi, native/cortiq_ffi.h):
//   const char* cortiq_version(void);
//   const char* cortiq_last_error(void);           — thread-local
//   void*       cortiq_load(const char* path);     — mmap, NULL on error
//   void        cortiq_free(void* handle);
//   int32_t     cortiq_chat(h, prompt, max_tokens, cb, user);
//   int32_t     cortiq_chat_messages(h, messages_json, max_tokens, cb, user);
//   int32_t     cortiq_complete(h, prompt, max_tokens, cb, user);
//   int32_t     cortiq_set_options(h, options_json);  — partial JSON,
//               keys: temperature top_p top_k repetition_penalty min_p
//               seed greedy; sticky per handle
// Callbacks fire synchronously on the calling thread and the call blocks,
// so generation runs in a worker isolate; cancellation is a shared byte in
// native memory that the callback checks (returning false stops decoding).
typedef _VersionNative = ffi.Pointer<Utf8> Function();
typedef _LastErrorNative = ffi.Pointer<Utf8> Function();
typedef _LoadNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef _LoadDart = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef _FreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _FreeDart = void Function(ffi.Pointer<ffi.Void>);
typedef _TokenCbNative = ffi.Bool Function(
    ffi.Pointer<Utf8>, ffi.Pointer<ffi.Void>);
typedef _GenNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<Utf8>,
    ffi.Uint32,
    ffi.Pointer<ffi.NativeFunction<_TokenCbNative>>,
    ffi.Pointer<ffi.Void>);
typedef _GenDart = int Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<Utf8>,
    int,
    ffi.Pointer<ffi.NativeFunction<_TokenCbNative>>,
    ffi.Pointer<ffi.Void>);
typedef _SetOptionsNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>);
typedef _SetOptionsDart = int Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>);
typedef _SetGpuNative = ffi.Void Function(ffi.Bool);
typedef _SetGpuDart = void Function(bool);

ffi.DynamicLibrary _openLibrary() {
  if (Platform.isAndroid) return ffi.DynamicLibrary.open('libcortiq_ffi.so');
  if (Platform.isIOS) return ffi.DynamicLibrary.process();
  final override = Platform.environment['CORTIQ_FFI_LIB'];
  return ffi.DynamicLibrary.open(override ?? 'libcortiq_ffi.dylib');
}

/// FFI binding to the cortiq runtime (CMF inference in Rust).
///
/// Optional: when libcortiq_ffi is not bundled, [isAvailable] is false and
/// the app falls back to [DemoEngine]. Build/bundling: native/README.md.
class NativeCortiqEngine implements InferenceEngine {
  NativeCortiqEngine() {
    try {
      final lib = _openLibrary();
      lib.lookup('cortiq_load'); // probe
      _lib = lib;
      _free = lib.lookupFunction<_FreeNative, _FreeDart>('cortiq_free');
      _version = lib
          .lookupFunction<_VersionNative, _VersionNative>('cortiq_version')()
          .toDartString();
      try {
        _setOptions = lib.lookupFunction<_SetOptionsNative, _SetOptionsDart>(
            'cortiq_set_options');
        _setGpu = lib.lookupFunction<_SetGpuNative, _SetGpuDart>(
            'cortiq_set_gpu');
      } catch (_) {
        _setOptions = null; // pre-0.3.10 library
        _setGpu = null;
      }
    } catch (_) {
      _lib = null;
    }
  }

  ffi.DynamicLibrary? _lib;
  _FreeDart? _free;
  _SetOptionsDart? _setOptions;
  _SetGpuDart? _setGpu;
  String _version = '';

  ffi.Pointer<ffi.Void> _handle = ffi.nullptr;
  LocalModel? _loaded;

  /// The native runtime allows one generate call per handle at a time
  /// (cortiq_ffi.h), and both the chat and the embedded server share this
  /// engine — so generations are serialized through this chain.
  Future<void> _generations = Future.value();

  /// Cancel flag of the generation currently running (1 = stop). Allocated
  /// per generation and freed when its worker isolate reports completion.
  ffi.Pointer<ffi.Uint8>? _activeCancel;

  @override
  bool get isAvailable => _lib != null;

  @override
  void setGpu(bool enable) {
    if (_setGpu != null) {
      _setGpu!(enable);
    }
  }

  @override
  String get name =>
      _version.isEmpty ? 'cortiq-native' : 'cortiq-native $_version';

  @override
  LocalModel? get loadedModel => _loaded;

  @override
  Future<void> loadModel(LocalModel model, {int threads = 4}) async {
    if (!isAvailable) {
      throw StateError('native cortiq runtime is not bundled');
    }
    // Structural pre-flight: a clear Dart error beats a native crash
    // mid-generation (missing attention tensors, mislabeled layers…).
    final problems = await CmfValidator.validate(model.filePath);
    if (problems.isNotEmpty) {
      throw StateError(problems.first);
    }
    await unload();
    // mmap + header parse can take a moment on big files — off the UI
    // isolate; the returned pointer is process-wide.
    final address = await Isolate.run(() {
      final lib = _openLibrary();
      final load = lib.lookupFunction<_LoadNative, _LoadDart>('cortiq_load');
      final lastError = lib
          .lookupFunction<_LastErrorNative, _LastErrorNative>(
              'cortiq_last_error');
      final pathPtr = model.filePath.toNativeUtf8();
      try {
        final handle = load(pathPtr);
        if (handle == ffi.nullptr) {
          throw StateError('cortiq_load: ${lastError().toDartString()}');
        }
        return handle.address;
      } finally {
        calloc.free(pathPtr);
      }
    });
    _handle = ffi.Pointer.fromAddress(address);
    _loaded = model;
  }

  @override
  Future<void> unload() async {
    if (_handle == ffi.nullptr) return;
    // A worker isolate dereferences the handle until its blocking call
    // returns, so freeing it mid-generation would be use-after-free.
    cancel();
    await _generations;
    if (_handle != ffi.nullptr) {
      _free!(_handle);
      _handle = ffi.nullptr;
      _loaded = null;
    }
  }

  /// Fallback transcript for pre-0.3.10 libraries without
  /// cortiq_chat_messages (single user turn through the template).
  static String renderPrompt(List<ChatMessage> messages) {
    if (messages.length == 1 && messages.single.role == ChatRole.user) {
      return messages.single.content;
    }
    final buffer = StringBuffer();
    for (final m in messages) {
      final label = switch (m.role) {
        ChatRole.system => 'System',
        ChatRole.user => 'User',
        ChatRole.assistant => 'Assistant',
      };
      buffer.writeln('$label: ${m.content}');
      buffer.writeln();
    }
    buffer.write('Assistant:');
    return buffer.toString();
  }

  void _applyOptions(GenerationRequest request) {
    final setOptions = _setOptions;
    if (setOptions == null || _handle == ffi.nullptr) return;
    final json = jsonEncode({
      'temperature': request.temperature,
      'top_p': request.topP,
      // Sticky per handle, so send it explicitly every time: false hides the
      // <think> block on reasoning templates, true re-enables it (toggling the
      // setting back on must actually stick). Ignored by pre-0.4.1 libraries
      // (unknown key), and by non-reasoning chat templates.
      'enable_thinking': !request.disableThinking,
    });
    final ptr = json.toNativeUtf8();
    try {
      setOptions(_handle, ptr); // sticky per handle; -1 is non-fatal here
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) {
    if (_handle == ffi.nullptr) {
      return Stream.error(StateError('no model loaded'));
    }
    final controller = StreamController<GenerationEvent>();
    _generations =
        _generations.then((_) => _runGeneration(request, controller));
    return controller.stream;
  }

  Future<void> _runGeneration(
    GenerationRequest request,
    StreamController<GenerationEvent> controller,
  ) async {
    // The model may have been unloaded while this generation waited its turn.
    if (_handle == ffi.nullptr) {
      controller.addError(StateError('no model loaded'));
      await controller.close();
      return;
    }
    final cancelFlag = calloc<ffi.Uint8>();
    _activeCancel = cancelFlag;
    // Options are sticky per handle — apply only once the previous
    // generation has finished, right before ours starts.
    _applyOptions(request);

    final started = DateTime.now();
    final messagesJson = jsonEncode([
      for (final m in request.messages)
        {'role': m.role.name, 'content': m.content},
    ]);
    final promptTokens = request.messages
        .map((m) => DemoEngine.estimateTokens(m.content))
        .fold<int>(0, (a, b) => a + b);

    final done = Completer<void>();
    final receivePort = ReceivePort();
    var completionTokens = 0;
    receivePort.listen((message) {
      switch (message) {
        case final String token:
          completionTokens++;
          controller.add(GenerationEvent(delta: token));
        case ('done', final int count):
          final elapsed = DateTime.now().difference(started);
          final tokens = count >= 0 ? count : completionTokens;
          controller.add(GenerationEvent(
            done: true,
            stats: GenerationStats(
              promptTokens: promptTokens,
              completionTokens: tokens,
              tokensPerSecond: elapsed.inMilliseconds > 0
                  ? tokens * 1000 / elapsed.inMilliseconds
                  : 0,
              latencyMs: elapsed.inMilliseconds,
              finishReason: cancelFlag.value != 0 ? 'cancelled' : 'stop',
              taskUsed: request.task,
            ),
          ));
          controller.close();
          receivePort.close();
          if (!done.isCompleted) done.complete();
        case ('error', final String error):
          controller.addError(StateError(error));
          controller.close();
          receivePort.close();
          if (!done.isCompleted) done.complete();
        case final List<dynamic> isolateError: // from Isolate.spawn onError
          controller.addError(StateError('${isolateError.firstOrNull}'));
          controller.close();
          receivePort.close();
          if (!done.isCompleted) done.complete();
      }
    });

    try {
      await Isolate.spawn(
        _generateWorker,
        _GenArgs(
          sendPort: receivePort.sendPort,
          handleAddress: _handle.address,
          cancelFlagAddress: cancelFlag.address,
          messagesJson: messagesJson,
          fallbackPrompt: renderPrompt(request.messages),
          maxTokens: request.maxTokens,
        ),
        onError: receivePort.sendPort,
        errorsAreFatal: false,
      );
    } catch (e) {
      controller.addError(StateError('failed to start generation: $e'));
      await controller.close();
      receivePort.close();
      if (!done.isCompleted) done.complete();
    }
    await done.future;
    if (identical(_activeCancel, cancelFlag)) _activeCancel = null;
    calloc.free(cancelFlag);
  }

  @override
  void cancel() => _activeCancel?.value = 1;
}

class _GenArgs {
  const _GenArgs({
    required this.sendPort,
    required this.handleAddress,
    required this.cancelFlagAddress,
    required this.messagesJson,
    required this.fallbackPrompt,
    required this.maxTokens,
  });

  final SendPort sendPort;
  final int handleAddress;
  final int cancelFlagAddress;
  final String messagesJson;
  final String fallbackPrompt;
  final int maxTokens;
}

// Streams tokens from the blocking generate call. Runs in its own
// isolate; the callback executes synchronously on this isolate's thread.
void _generateWorker(_GenArgs args) {
  final port = args.sendPort;
  try {
    final lib = _openLibrary();
    _GenDart gen;
    String payload;
    try {
      gen = lib.lookupFunction<_GenNative, _GenDart>('cortiq_chat_messages');
      payload = args.messagesJson;
    } catch (_) {
      gen = lib.lookupFunction<_GenNative, _GenDart>('cortiq_chat');
      payload = args.fallbackPrompt;
    }
    final lastError = lib.lookupFunction<_LastErrorNative, _LastErrorNative>(
        'cortiq_last_error');
    final cancelFlag =
        ffi.Pointer<ffi.Uint8>.fromAddress(args.cancelFlagAddress);

    final callback = ffi.NativeCallable<_TokenCbNative>.isolateLocal(
      (ffi.Pointer<Utf8> token, ffi.Pointer<ffi.Void> user) {
        port.send(token.toDartString());
        return cancelFlag.value == 0;
      },
      exceptionalReturn: false,
    );

    final payloadPtr = payload.toNativeUtf8();
    try {
      final count = gen(
        ffi.Pointer.fromAddress(args.handleAddress),
        payloadPtr,
        args.maxTokens,
        callback.nativeFunction,
        ffi.nullptr,
      );
      if (count < 0 && cancelFlag.value == 0) {
        port.send(('error', 'generate: ${lastError().toDartString()}'));
      } else {
        port.send(('done', count));
      }
    } finally {
      calloc.free(payloadPtr);
      callback.close();
    }
  } catch (e) {
    port.send(('error', e.toString()));
  }
}
