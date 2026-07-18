import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../models/chat.dart';
import '../../models/local_model.dart';
import 'demo_engine.dart' show DemoEngine;
import 'inference_engine.dart';

// C ABI of cortiq-ffi (cmfpublic/crates/cortiq-ffi, native/cortiq_ffi.h):
//   const char* cortiq_version(void);
//   const char* cortiq_last_error(void);           — thread-local
//   void*       cortiq_load(const char* path);     — mmap, NULL on error
//   void        cortiq_free(void* handle);
//   int32_t     cortiq_chat(void* h, const char* prompt, uint32_t max_tokens,
//                           bool (*cb)(const char* token, void* user), void* user);
//   int32_t     cortiq_complete(...same...);
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
typedef _ChatNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<Utf8>,
    ffi.Uint32,
    ffi.Pointer<ffi.NativeFunction<_TokenCbNative>>,
    ffi.Pointer<ffi.Void>);
typedef _ChatDart = int Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<Utf8>,
    int,
    ffi.Pointer<ffi.NativeFunction<_TokenCbNative>>,
    ffi.Pointer<ffi.Void>);

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
    } catch (_) {
      _lib = null;
    }
  }

  ffi.DynamicLibrary? _lib;
  _FreeDart? _free;
  String _version = '';

  ffi.Pointer<ffi.Void> _handle = ffi.nullptr;
  LocalModel? _loaded;

  /// Cancel flag shared with the worker isolate (1 = stop).
  final ffi.Pointer<ffi.Uint8> _cancelFlag = calloc<ffi.Uint8>();

  @override
  bool get isAvailable => _lib != null;

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
    if (_handle != ffi.nullptr) {
      _free!(_handle);
      _handle = ffi.nullptr;
      _loaded = null;
    }
  }

  /// cortiq_chat wraps the prompt as a single user turn in the model's own
  /// chat template, so multi-turn context travels as a plain transcript.
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

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) {
    if (_handle == ffi.nullptr) {
      return Stream.error(StateError('no model loaded'));
    }
    _cancelFlag.value = 0;
    final controller = StreamController<GenerationEvent>();
    final started = DateTime.now();
    final prompt = renderPrompt(request.messages);
    final promptTokens = DemoEngine.estimateTokens(prompt);

    final receivePort = ReceivePort();
    var completionTokens = 0;
    receivePort.listen((message) {
      switch (message) {
        case final String token:
          completionTokens++;
          controller.add(GenerationEvent(delta: token));
        case ('done', final int count):
          final elapsed = DateTime.now().difference(started);
          controller.add(GenerationEvent(
            done: true,
            stats: GenerationStats(
              promptTokens: promptTokens,
              completionTokens: count >= 0 ? count : completionTokens,
              tokensPerSecond: elapsed.inMilliseconds > 0
                  ? (count >= 0 ? count : completionTokens) *
                      1000 /
                      elapsed.inMilliseconds
                  : 0,
              latencyMs: elapsed.inMilliseconds,
              finishReason: _cancelFlag.value != 0 ? 'cancelled' : 'stop',
              taskUsed: request.task,
            ),
          ));
          controller.close();
          receivePort.close();
        case ('error', final String error):
          controller.addError(StateError(error));
          controller.close();
          receivePort.close();
        case final List<dynamic> isolateError: // from Isolate.spawn onError
          controller.addError(StateError('${isolateError.firstOrNull}'));
          controller.close();
          receivePort.close();
      }
    });

    Isolate.spawn(
      _generateWorker,
      _GenArgs(
        sendPort: receivePort.sendPort,
        handleAddress: _handle.address,
        cancelFlagAddress: _cancelFlag.address,
        prompt: prompt,
        maxTokens: request.maxTokens,
      ),
      onError: receivePort.sendPort,
      errorsAreFatal: false,
    );
    return controller.stream;
  }

  @override
  void cancel() => _cancelFlag.value = 1;
}

class _GenArgs {
  const _GenArgs({
    required this.sendPort,
    required this.handleAddress,
    required this.cancelFlagAddress,
    required this.prompt,
    required this.maxTokens,
  });

  final SendPort sendPort;
  final int handleAddress;
  final int cancelFlagAddress;
  final String prompt;
  final int maxTokens;
}

// Streams tokens from the blocking cortiq_chat call. Runs in its own
// isolate; the callback executes synchronously on this isolate's thread.
void _generateWorker(_GenArgs args) {
  final port = args.sendPort;
  try {
    final lib = _openLibrary();
    final chat = lib.lookupFunction<_ChatNative, _ChatDart>('cortiq_chat');
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

    final promptPtr = args.prompt.toNativeUtf8();
    try {
      final count = chat(
        ffi.Pointer.fromAddress(args.handleAddress),
        promptPtr,
        args.maxTokens,
        callback.nativeFunction,
        ffi.nullptr,
      );
      if (count < 0 && cancelFlag.value == 0) {
        port.send(('error', 'cortiq_chat: ${lastError().toDartString()}'));
      } else {
        port.send(('done', count));
      }
    } finally {
      calloc.free(promptPtr);
      callback.close();
    }
  } catch (e) {
    port.send(('error', e.toString()));
  }
}
