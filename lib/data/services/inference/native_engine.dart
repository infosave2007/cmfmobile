import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../../core/util/performance_hint.dart';
import '../../models/chat.dart';
import '../../models/local_model.dart';
import '../cmf_format.dart';
import 'demo_engine.dart' show DemoEngine;
import 'engine_tuning.dart';
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
// The worker outlives a single generation: its thread is the one the engine
// pins to the big cores, so keeping it saves both the isolate spin-up and
// the re-pin on every reply.
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
typedef _GpuAvailableNative = ffi.Bool Function();
typedef _GpuAvailableDart = bool Function();
typedef _SetThreadsNative = ffi.Void Function(ffi.Int32);
typedef _SetThreadsDart = void Function(int);
typedef _WorkerTidsNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Int32>, ffi.Int32);
typedef _WorkerTidsDart = int Function(ffi.Pointer<ffi.Int32>, int);
typedef _CancelNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _CancelDart = void Function(ffi.Pointer<ffi.Void>);

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
      try {
        // cortiq-ffi >= 0.5.30. cortiq_set_gpu is accepted even by a runtime
        // with no Vulkan/Metal backend linked in, so cortiq_gpu_available is
        // the only way to tell whether the switch does anything;
        // cortiq_set_threads replaces the process-wide CMF_THREADS; the
        // worker tids feed Android's performance hints.
        _gpuAvailable = lib.lookupFunction<_GpuAvailableNative,
            _GpuAvailableDart>('cortiq_gpu_available');
        _setThreads = lib.lookupFunction<_SetThreadsNative, _SetThreadsDart>(
            'cortiq_set_threads');
        _workerTids = lib.lookupFunction<_WorkerTidsNative, _WorkerTidsDart>(
            'cortiq_worker_tids');
      } catch (_) {
        _gpuAvailable = null;
        _setThreads = null;
        _workerTids = null;
      }
      try {
        // cortiq-ffi >= 0.5.32. Without it, cancelling can only be noticed
        // between tokens — which never happens during a prefill, so Stop
        // does nothing for the first minute of a long prompt.
        _cancelNative =
            lib.lookupFunction<_CancelNative, _CancelDart>('cortiq_cancel');
      } catch (_) {
        _cancelNative = null;
      }
    } catch (_) {
      _lib = null;
    }
  }

  ffi.DynamicLibrary? _lib;
  _FreeDart? _free;
  _SetOptionsDart? _setOptions;
  _SetGpuDart? _setGpu;
  _GpuAvailableDart? _gpuAvailable;
  _SetThreadsDart? _setThreads;
  _WorkerTidsDart? _workerTids;
  _CancelDart? _cancelNative;
  String _version = '';

  ffi.Pointer<ffi.Void> _handle = ffi.nullptr;
  LocalModel? _loaded;

  /// Pool size pushed to the engine for the loaded model (null = engine
  /// default). Surfaced through [name] so About shows what actually runs.
  int? _poolThreads;

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
  bool? get gpuBackendAvailable => _gpuAvailable?.call();

  @override
  String get name {
    final base =
        _version.isEmpty ? 'cortiq-native' : 'cortiq-native $_version';
    final pool = _poolThreads;
    return pool == null ? base : '$base · $pool threads';
  }

  @override
  LocalModel? get loadedModel => _loaded;

  @override
  Future<void> loadModel(
    LocalModel model, {
    int threads = 0,
    String engineFlags = '',
  }) async {
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
    // The pool is built inside cortiq_load and lives as long as the handle,
    // so all of this has to be set before the call, not before the
    // generation. From 0.5.30 the thread count has a proper entry point —
    // and the engine's own auto-sizing knows the big cluster better than we
    // do (it reads cpu_capacity with a max-frequency fallback), so on auto
    // we hand the decision over rather than second-guessing it.
    final setThreads = _setThreads;
    if (setThreads != null) {
      setThreads(threads);
      _poolThreads = threads > 0 ? threads : null;
      // threads: null — sized natively above; this also clears a CMF_THREADS
      // an older runtime may have been given.
      EngineTuning.apply(threads: null, flags: engineFlags);
    } else {
      _poolThreads =
          EngineTuning.apply(threads: threads, flags: engineFlags);
    }
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
    // The pool exists only once a model is loaded, so this is the first
    // moment its real size is knowable — and on auto it is the only way to
    // know what the engine picked.
    _workerIds = _readWorkerTids();
    if (_workerIds.isNotEmpty) _poolThreads = _workerIds.length;
  }

  /// Kernel thread ids of the engine's worker pool, empty when the runtime
  /// predates 0.5.30 or is not on Android/Linux. Used for the platform
  /// performance hints, which need the threads that actually do the work.
  List<int> get workerThreadIds => _workerIds;
  List<int> _workerIds = const [];

  List<int> _readWorkerTids() {
    final workerTids = _workerTids;
    if (workerTids == null) return const [];
    const cap = 32;
    final buffer = calloc<ffi.Int32>(cap);
    try {
      final total = workerTids(buffer, cap);
      if (total <= 0) return const [];
      return [
        for (var i = 0; i < (total < cap ? total : cap); i++) buffer[i],
      ];
    } finally {
      calloc.free(buffer);
    }
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
      _poolThreads = null;
      _workerIds = const [];
    }
    _stopWorker();
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
    var cycleStart = DateTime.now();
    void fail(String message) {
      if (done.isCompleted) return;
      controller.addError(StateError(message));
      controller.close();
      receivePort.close();
      done.complete();
    }

    receivePort.listen((message) {
      switch (message) {
        case final String token:
          completionTokens++;
          controller.add(GenerationEvent(delta: token));
          if (completionTokens % _hintCycle == 0) {
            final now = DateTime.now();
            PerformanceHint.report(now.difference(cycleStart));
            cycleStart = now;
          }
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
          fail(error);
      }
    });

    // A native crash takes the worker isolate down with it; without this the
    // stream would simply never complete.
    _onWorkerLost = fail;
    await PerformanceHint.start(_workerIds, _hintCycleTarget);
    cycleStart = DateTime.now();
    try {
      final commands = await _workerCommands();
      commands.send(_GenArgs(
        sendPort: receivePort.sendPort,
        handleAddress: _handle.address,
        cancelFlagAddress: cancelFlag.address,
        messagesJson: messagesJson,
        fallbackPrompt: renderPrompt(request.messages),
        maxTokens: request.maxTokens,
      ));
    } catch (e) {
      fail('failed to start generation: $e');
    }
    await done.future;
    await PerformanceHint.stop(); // clocks go straight back
    _onWorkerLost = null;
    if (identical(_activeCancel, cancelFlag)) _activeCancel = null;
    calloc.free(cancelFlag);
  }

  /// Tokens per ADPF work cycle, and what a cycle is asked to cost. The
  /// target is deliberately ambitious: a phone rarely does 40 ms a token on a
  /// model worth loading, so the system is being asked for whatever clock it
  /// can spare while a reply streams — and the session closes with it.
  static const _hintCycle = 16;
  static const _hintCycleTarget = Duration(milliseconds: 40 * _hintCycle);

  @override
  void cancel() {
    // The shared byte stops decoding at the next token — which is all an
    // older runtime can offer, and is useless while a long prompt is still
    // prefilling because no token arrives to check it.
    _activeCancel?.value = 1;
    // 0.5.32+ can also break out of the prefill loop. Safe from this
    // isolate: the ABI documents the flag as thread-safe and expects the
    // call from a thread other than the blocked one.
    final cancelNative = _cancelNative;
    if (cancelNative != null && _handle != ffi.nullptr) {
      cancelNative(_handle);
    }
  }

  // --- generation worker ---------------------------------------------------

  Future<SendPort>? _worker;
  Isolate? _workerIsolate;
  ReceivePort? _workerEvents;
  void Function(String message)? _onWorkerLost;

  Future<SendPort> _workerCommands() => _worker ??= _startWorker();

  Future<SendPort> _startWorker() async {
    final handshake = ReceivePort();
    // onExit and onError share one port: either means the worker is gone and
    // whoever waits on it — the handshake or a running generation — will
    // never be answered otherwise.
    final events = ReceivePort();
    final ready = Completer<SendPort>();
    handshake.listen((message) {
      if (!ready.isCompleted) ready.complete(message as SendPort);
      handshake.close();
    });
    events.listen((message) {
      _worker = null;
      _workerIsolate = null;
      final reason = message is List
          ? 'generation isolate died: ${message.firstOrNull}'
          : 'generation isolate exited';
      if (!ready.isCompleted) ready.completeError(StateError(reason));
      _onWorkerLost?.call(reason);
      handshake.close();
      events.close();
      if (identical(_workerEvents, events)) _workerEvents = null;
    });
    try {
      _workerIsolate = await Isolate.spawn(
        _generateWorker,
        handshake.sendPort,
        onExit: events.sendPort,
        onError: events.sendPort,
        errorsAreFatal: false,
        debugName: 'cortiq-generate',
      );
    } catch (_) {
      handshake.close();
      events.close();
      _worker = null;
      rethrow;
    }
    _workerEvents = events;
    return ready.future;
  }

  void _stopWorker() {
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerEvents?.close();
    _workerEvents = null;
    _worker = null;
  }
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

// Long-lived generation worker: streams tokens from the blocking generate
// call, one job at a time (the runtime serializes per handle anyway). The
// token callback executes synchronously on this isolate's thread — the same
// thread the engine pins to the big cores on the first call.
void _generateWorker(SendPort handshake) {
  final jobs = ReceivePort();
  handshake.send(jobs.sendPort);

  final lib = _openLibrary();
  final lastError = lib
      .lookupFunction<_LastErrorNative, _LastErrorNative>('cortiq_last_error');
  _GenDart gen;
  bool multiTurn;
  try {
    gen = lib.lookupFunction<_GenNative, _GenDart>('cortiq_chat_messages');
    multiTurn = true;
  } catch (_) {
    // pre-0.3.10 library: only the single-turn entry point exists
    gen = lib.lookupFunction<_GenNative, _GenDart>('cortiq_chat');
    multiTurn = false;
  }

  jobs.listen((message) {
    final args = message as _GenArgs;
    final port = args.sendPort;
    try {
      final payload = multiTurn ? args.messagesJson : args.fallbackPrompt;
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
  });
}
