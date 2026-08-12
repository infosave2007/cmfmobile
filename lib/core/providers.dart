import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/models/chat.dart';
import '../data/models/companion.dart';
import '../data/models/local_model.dart';
import '../data/models/server.dart';
import '../data/models/settings.dart';
import '../data/services/chat_store.dart';
import '../data/services/cmf_server.dart';
import '../data/services/converter_service.dart';
import '../data/services/device_resources.dart';
import '../data/services/hf_api.dart';
import '../data/services/inference/demo_engine.dart';
import '../data/services/inference/inference_engine.dart';
import '../data/services/inference/native_engine.dart';
import '../data/services/model_repository.dart';
import '../data/services/settings_repository.dart';
import 'util/foreground_task.dart';
import 'util/keep_awake.dart';

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());
final modelRepositoryProvider = Provider((ref) => ModelRepository());
final chatStoreProvider = Provider((ref) => ChatStore());
final hfApiProvider = Provider((ref) => HfApi());
final deviceResourcesProvider = Provider((ref) => DeviceResources());

final appVersionProvider = FutureProvider<String>(
    (ref) async => (await PackageInfo.fromPlatform()).version);

final engineProvider = Provider<InferenceEngine>((ref) {
  final native = NativeCortiqEngine();
  if (native.isAvailable) return native;
  return DemoEngine();
});

final isDemoEngineProvider =
    Provider<bool>((ref) => ref.watch(engineProvider) is DemoEngine);

final converterProvider = Provider<ConverterService>((ref) {
  final service = ConverterService(
    hf: ref.watch(hfApiProvider),
    models: ref.watch(modelRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final cmfServerProvider = Provider<CmfServer>((ref) {
  final server = CmfServer(engine: ref.watch(engineProvider));
  ref.onDispose(server.dispose);
  return server;
});

// ---------------------------------------------------------------------------
// Shell navigation (lets feature screens switch tabs, e.g. "Open Models")
// ---------------------------------------------------------------------------

class ShellIndexController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final shellIndexProvider =
    NotifierProvider<ShellIndexController, int>(ShellIndexController.new);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsRepositoryProvider).load();

  Future<void> updateSettings(AppSettings Function(AppSettings) change) async {
    final current = state.value ?? const AppSettings();
    final next = change(current);
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

// ---------------------------------------------------------------------------
// Model library
// ---------------------------------------------------------------------------

class ModelsController extends AsyncNotifier<List<LocalModel>> {
  @override
  Future<List<LocalModel>> build() => ref.read(modelRepositoryProvider).list();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(modelRepositoryProvider).list());
  }

  Future<void> deleteModel(LocalModel model) async {
    await ref.read(modelRepositoryProvider).delete(model);
    final engine = ref.read(engineControllerProvider.notifier);
    if (ref.read(engineControllerProvider).loadedModelId == model.id) {
      await engine.unload();
    }
    await refresh();
  }

  Future<LocalModel> importFile(String path) async {
    final model = await ref.read(modelRepositoryProvider).importFile(path);
    await refresh();
    return model;
  }
}

final modelsProvider = AsyncNotifierProvider<ModelsController,
    List<LocalModel>>(ModelsController.new);

// ---------------------------------------------------------------------------
// Engine state (which model is loaded)
// ---------------------------------------------------------------------------

class EngineState {
  const EngineState({
    this.loadedModelId,
    this.loadedModel,
    this.isLoading = false,
    this.error,
  });

  final String? loadedModelId;
  final LocalModel? loadedModel;
  final bool isLoading;
  final String? error;
}

class EngineController extends Notifier<EngineState> {
  @override
  EngineState build() => const EngineState();

  Future<void> loadModel(LocalModel model) async {
    state = EngineState(
        isLoading: true, loadedModelId: model.id, loadedModel: model);
    try {
      final settings = ref.read(settingsProvider).value;
      final engine = ref.read(engineProvider);
      // The runtime decides what the GPU is worth: it times each op class
      // against the CPU and keeps the winner, so the switch can be passed
      // through as the user set it.
      engine.setGpu(settings?.useGpu ?? false);
      await engine.loadModel(
        model,
        threads: settings?.threads ?? 0,
        engineFlags: settings?.engineFlags ?? '',
      );
      state = EngineState(loadedModelId: model.id, loadedModel: model);
    } catch (e) {
      state = EngineState(error: e.toString());
    }
  }

  Future<void> unload() async {
    await ref.read(engineProvider).unload();
    state = const EngineState();
  }
}

final engineControllerProvider =
    NotifierProvider<EngineController, EngineState>(EngineController.new);

// ---------------------------------------------------------------------------
// Chat (sessions with persistent context, like GPT chats)
// ---------------------------------------------------------------------------

class ChatState {
  const ChatState({
    this.sessions = const [],
    this.currentId,
    this.generating = false,
    this.loaded = false,
  });

  final List<ChatSession> sessions;
  final String? currentId;
  final bool generating;
  final bool loaded;

  ChatSession? get current {
    for (final s in sessions) {
      if (s.id == currentId) return s;
    }
    return null;
  }

  ChatState copyWith({
    List<ChatSession>? sessions,
    String? currentId,
    bool? generating,
    bool? loaded,
  }) =>
      ChatState(
        sessions: sessions ?? this.sessions,
        currentId: currentId ?? this.currentId,
        generating: generating ?? this.generating,
        loaded: loaded ?? this.loaded,
      );
}

/// Text of the assistant reply currently being generated, updated on every
/// token. Kept outside [ChatState] so streaming repaints only the active
/// bubble instead of rebuilding the whole chat screen per delta.
class StreamingReplyController
    extends Notifier<({String sessionId, String text})?> {
  @override
  ({String sessionId, String text})? build() => null;

  void update(String sessionId, String text) =>
      state = (sessionId: sessionId, text: text);

  void clear() => state = null;
}

final streamingReplyProvider = NotifierProvider<StreamingReplyController,
    ({String sessionId, String text})?>(StreamingReplyController.new);

class ChatController extends Notifier<ChatState> {
  StreamSubscription<GenerationEvent>? _sub;

  @override
  ChatState build() {
    ref.onDispose(() => _sub?.cancel());
    _init();
    return const ChatState();
  }

  Future<void> _init() async {
    final sessions = await ref.read(chatStoreProvider).loadAll();
    state = ChatState(
      sessions: sessions,
      currentId: sessions.isEmpty ? null : sessions.first.id,
      loaded: true,
    );
    if (sessions.isEmpty) newSession();
  }

  void newSession() {
    // Reuse an existing empty session instead of stacking blanks.
    final empty =
        state.sessions.where((s) => s.messages.isEmpty).firstOrNull;
    if (empty != null) {
      state = state.copyWith(currentId: empty.id);
      return;
    }
    final session = ChatSession(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(16),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      sessions: [session, ...state.sessions],
      currentId: session.id,
    );
  }

  void selectSession(String id) => state = state.copyWith(currentId: id);

  Future<void> deleteSession(String id) async {
    await ref.read(chatStoreProvider).delete(id);
    final sessions = state.sessions.where((s) => s.id != id).toList();
    state = ChatState(
      sessions: sessions,
      currentId: state.currentId == id
          ? (sessions.isEmpty ? null : sessions.first.id)
          : state.currentId,
      loaded: true,
    );
    if (sessions.isEmpty) newSession();
  }

  Future<void> renameSession(String id, String title) async {
    final session = state.sessions.where((s) => s.id == id).firstOrNull;
    if (session == null) return;
    session.title = title;
    state = state.copyWith(sessions: [...state.sessions]);
    await ref.read(chatStoreProvider).save(session);
  }

  Future<void> send(String text, List<ChatAttachment> attachments) async {
    final session = state.current;
    if (session == null || state.generating) return;
    session.messages.add(ChatMessage(
      role: ChatRole.user,
      content: text,
      attachments: attachments,
    ));
    session.messages.add(const ChatMessage(role: ChatRole.assistant, content: ''));
    state = state.copyWith(sessions: [...state.sessions], generating: true);
    // Persist the user turn right away so it survives a crash or an app
    // kill during the (potentially long) generation that follows.
    unawaited(ref.read(chatStoreProvider).save(session));
    await _generate(session);
  }

  Future<void> regenerate() async {
    final session = state.current;
    if (session == null || state.generating) return;
    // Drop trailing assistant replies, keep the last user turn.
    while (session.messages.isNotEmpty &&
        session.messages.last.role == ChatRole.assistant) {
      session.messages.removeLast();
    }
    if (session.messages.isEmpty) return;
    session.messages.add(const ChatMessage(role: ChatRole.assistant, content: ''));
    state = state.copyWith(sessions: [...state.sessions], generating: true);
    await _generate(session);
  }

  Future<void> _generate(ChatSession session) async {
    final engine = ref.read(engineProvider);
    final settings = ref.read(settingsProvider).value ?? const AppSettings();

    // Full session history = the conversation context; attachments are
    // inlined into their message content for the model.
    final history = <ChatMessage>[
      for (final m in session.messages)
        if (!(m.role == ChatRole.assistant && m.content.isEmpty))
          m.attachments.isEmpty
              ? m
              : ChatMessage(
                  role: m.role,
                  content: '${m.content}\n\n${m.attachments.map(
                        (a) =>
                            '--- ${a.name} ---\n${a.text}\n--- end of ${a.name} ---',
                      ).join('\n\n')}',
                  attachments: m.attachments,
                ),
    ];

    var buffer = '';
    final streaming = ref.read(streamingReplyProvider.notifier);
    void updateLast(ChatMessage msg) {
      session.messages[session.messages.length - 1] = msg;
      state = state.copyWith(sessions: [...state.sessions]);
    }

    try {
      await _sub?.cancel();
      // Started from a user tap, so the foreground-service start is allowed;
      // it keeps the reply on the big cores if the user switches away.
      await ForegroundTask.acquire(ForegroundTask.generation);
      final stream = engine.generate(GenerationRequest(
        messages: history,
        temperature: settings.temperature,
        topP: settings.topP,
        maxTokens: settings.maxTokens,
        disableThinking: settings.disableThinking,
      ));
      final done = Completer<void>();
      _sub = stream.listen(
        (event) {
          if (event.done) {
            updateLast(ChatMessage(
              role: ChatRole.assistant,
              content: buffer,
              stats: event.stats,
            ));
          } else {
            // Per-token updates go to the streaming provider only; the
            // session (and the full message list) updates once, on done.
            buffer += event.delta;
            streaming.update(session.id, buffer);
          }
        },
        onError: (Object e) {
          _notePeerFailure(e);
          updateLast(ChatMessage(
            role: ChatRole.assistant,
            content: buffer,
            error: e.toString(),
          ));
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
    } catch (e) {
      _notePeerFailure(e);
      updateLast(ChatMessage(
        role: ChatRole.assistant,
        content: buffer,
        error: e.toString(),
      ));
    } finally {
      _sub = null;
      streaming.clear();
      state = state.copyWith(generating: false, sessions: [...state.sessions]);
      await ForegroundTask.release(ForegroundTask.generation);
      await ref.read(chatStoreProvider).save(session);
    }
  }

  void stop() => ref.read(engineProvider).cancel();

  /// A reply that failed through the desktop is the split's problem, not the
  /// model's — tell the companion so its screen stops looking healthy.
  void _notePeerFailure(Object error) {
    final failure = classifyPeerFailure(error.toString());
    if (failure == null) return;
    ref.read(companionControllerProvider.notifier).notePeerFailure(failure);
  }

  /// Moves the work back to this device and retries the last turn — what the
  /// chat offers when the desktop has gone away.
  Future<void> computeHereAndRetry() async {
    await ref.read(companionControllerProvider.notifier).useLocal();
    await regenerate();
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

class ServerState {
  const ServerState({
    this.running = false,
    this.starting = false,
    this.port = 8080,
    this.urls = const [],
    this.error,
    this.requests = const [],
    this.requestCount = 0,
    this.errorCount = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.tokensPerSecond = 0,
    this.startedAt,
  });

  final bool running;
  final bool starting;
  final int port;
  final List<String> urls;
  final String? error;
  final List<ServerRequestRecord> requests;
  final int requestCount;
  final int errorCount;
  final int promptTokens;
  final int completionTokens;
  final double tokensPerSecond;
  final DateTime? startedAt;
}

class ServerController extends Notifier<ServerState> {
  StreamSubscription<ServerRequestRecord>? _sub;

  @override
  ServerState build() {
    ref.onDispose(() {
      _sub?.cancel();
      KeepAwake.disable();
      ForegroundTask.release(ForegroundTask.server);
    });
    return const ServerState();
  }

  Future<void> start() async {
    final settings =
        ref.read(settingsProvider).value ?? const AppSettings();
    final server = ref.read(cmfServerProvider);
    state = ServerState(starting: true, port: settings.serverPort);
    try {
      await server.start(
        port: settings.serverPort,
        token: settings.serverAuthEnabled ? settings.serverToken : null,
      );
      await KeepAwake.enable(); // generation must survive screen-off
      // Without this the process drops to the background cpuset (little
      // cores) as soon as the user leaves the app — for a server that is the
      // normal case, not the exception.
      await ForegroundTask.acquire(ForegroundTask.server);
      final urls = await server.serverUrls();
      _sub = server.onRequest.listen((_) => _refreshSnapshot());
      state = ServerState(
        running: true,
        port: settings.serverPort,
        urls: urls,
        startedAt: server.startedAt,
      );
    } catch (e) {
      state = ServerState(port: settings.serverPort, error: e.toString());
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await ref.read(cmfServerProvider).stop();
    await KeepAwake.disable();
    await ForegroundTask.release(ForegroundTask.server);
    state = ServerState(port: state.port);
  }

  void _refreshSnapshot() {
    final server = ref.read(cmfServerProvider);
    state = ServerState(
      running: state.running,
      port: state.port,
      urls: state.urls,
      startedAt: state.startedAt,
      requests: List.of(server.requestLog),
      requestCount: server.stats.requests,
      errorCount: server.stats.errors,
      promptTokens: server.stats.promptTokens,
      completionTokens: server.stats.completionTokens,
      tokensPerSecond: server.stats.tokensPerSecondEma,
    );
  }
}

final serverControllerProvider =
    NotifierProvider<ServerController, ServerState>(ServerController.new);

// ---------------------------------------------------------------------------
// Companion (network split with a desktop)
// ---------------------------------------------------------------------------

class CompanionState {
  const CompanionState({
    this.role = CompanionRole.local,
    this.busy = false,
    this.error,
    this.fault,
    this.workerListenAddress,
    this.stats = PeerStats.empty,
    this.lastCheckOk,
    this.peerFailure,
  });

  /// The role currently applied to the engine — not the one saved in
  /// settings, which is only a starting point for the screen.
  final CompanionRole role;
  final bool busy;

  /// Verbatim text from the runtime. Not translated on purpose.
  final String? error;

  /// A refusal the app made itself; the screen turns it into words.
  final CompanionFault? fault;

  /// Address the worker listener bound to, or null when it is not running.
  final String? workerListenAddress;
  final PeerStats stats;

  /// Result of the last explicit check, null when none was run since the
  /// configuration changed.
  final bool? lastCheckOk;

  /// Why the last generation through the peer failed, null while it works.
  /// Set from the chat as well as from Check, because a desktop that dies
  /// mid-conversation is exactly the case the user needs told about.
  final PeerFailure? peerFailure;

  bool get workerListening => workerListenAddress != null;

  /// The peer is configured but the last attempt to use it failed.
  bool get peerBroken => role == CompanionRole.desktop && peerFailure != null;

  CompanionState copyWith({
    CompanionRole? role,
    bool? busy,
    String? error,
    CompanionFault? fault,
    bool clearError = false,
    String? workerListenAddress,
    PeerStats? stats,
    bool? lastCheckOk,
    bool clearCheck = false,
    PeerFailure? peerFailure,
    bool clearPeerFailure = false,
  }) =>
      CompanionState(
        role: role ?? this.role,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        fault: clearError ? null : (fault ?? this.fault),
        workerListenAddress: workerListenAddress ?? this.workerListenAddress,
        stats: stats ?? this.stats,
        lastCheckOk: clearCheck ? null : (lastCheckOk ?? this.lastCheckOk),
        peerFailure:
            clearPeerFailure ? null : (peerFailure ?? this.peerFailure),
      );
}

class CompanionController extends Notifier<CompanionState> {
  @override
  CompanionState build() {
    // Captured now rather than read on dispose: by then the container may be
    // tearing down and refuse a read.
    final engine = ref.read(engineProvider);
    ref.onDispose(() {
      // The peer is process-wide state in the runtime; leaving it set while
      // this controller is gone would route generations at a desktop nothing
      // is watching.
      engine.clearPeer();
      ForegroundTask.release(ForegroundTask.companion);
      KeepAwake.disable();
    });
    return const CompanionState();
  }

  /// False on the demo engine and on any runtime older than cortiq 0.5.70.
  bool get supported => ref.read(engineProvider).supportsCompanion;

  /// Routes generation through the desktop: it holds the layers, the head and
  /// the sampler, this device keeps the tokenizer and draws the tokens.
  ///
  /// This does not dial — the runtime connects on the first generation, so a
  /// wrong address or a desktop on another engine version surfaces as a chat
  /// error with the runtime's own text.
  Future<void> useDesktop() async {
    final engine = ref.read(engineProvider);
    if (!engine.supportsCompanion) return;
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final address = CompanionConfig.validate(settings.companionAddress);
    if (address == null) {
      state = state.copyWith(fault: CompanionFault.addressInvalid);
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      engine.setPeer(
        addr: address,
        token: settings.companionToken,
        // Role, not load percentage: 0 leaves this side with the tokenizer
        // only, which is the configuration the measurements support.
        split: 0,
        // The head does not shrink as layers move away, so leaving it here
        // caps the phone at its own head — 29 ms of a 73 ms token.
        head: true,
      );
      state = state.copyWith(
        role: CompanionRole.desktop,
        busy: false,
        clearCheck: true,
        clearPeerFailure: true,
      );
      await _persistRole(CompanionRole.desktop);
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  /// One short generation through whatever is configured, so the lazy dial
  /// happens here rather than in the middle of the user's first message.
  ///
  /// The runtime reports a wrong address, a missing token, a different model
  /// or a mismatched wire version as an error on this call — which is the
  /// point: a spinner that never resolves would say none of that.
  Future<void> check() async {
    if (ref.read(engineControllerProvider).loadedModel == null) {
      state = state.copyWith(
          fault: CompanionFault.modelNotLoaded, lastCheckOk: false);
      return;
    }
    state = state.copyWith(busy: true, clearError: true, clearCheck: true);
    try {
      final engine = ref.read(engineProvider);
      await for (final event in engine.generate(const GenerationRequest(
        messages: [ChatMessage(role: ChatRole.user, content: 'ping')],
        maxTokens: 1,
      ))) {
        if (event.done) break;
      }
      state = state.copyWith(
          busy: false, lastCheckOk: true, clearPeerFailure: true);
      refreshStats();
    } catch (e) {
      state = state.copyWith(
        busy: false,
        lastCheckOk: false,
        error: e.toString(),
        peerFailure: state.role == CompanionRole.desktop
            ? (classifyPeerFailure(e.toString()) ?? PeerFailure.other)
            : null,
      );
    }
  }

  /// Records that a generation elsewhere in the app (the chat, the server)
  /// failed through the peer, so the Split screen stops claiming everything
  /// is fine. Does not clear the peer: the user chose the desktop, and
  /// silently moving the work back here would change both where their data
  /// goes and how fast it comes back, without asking.
  void notePeerFailure(PeerFailure failure) {
    if (state.role != CompanionRole.desktop) return;
    state = state.copyWith(peerFailure: failure, lastCheckOk: false);
  }

  /// Back to computing on this device.
  Future<void> useLocal() async {
    ref.read(engineProvider).clearPeer();
    state = state.copyWith(
      role: CompanionRole.local,
      stats: PeerStats.empty,
      clearError: true,
      clearCheck: true,
      clearPeerFailure: true,
    );
    await _persistRole(CompanionRole.local);
  }

  /// Serves this device's copy of the loaded model to a desktop coordinator.
  ///
  /// One-way: the runtime has no call to stop the listener, so it lives until
  /// the app's process does. The screen says so rather than offering a Stop
  /// that would lie.
  Future<void> startWorker() async {
    final engine = ref.read(engineProvider);
    if (!engine.supportsCompanion || state.workerListening) return;
    final model = ref.read(engineControllerProvider).loadedModel;
    if (model == null) {
      state = state.copyWith(fault: CompanionFault.modelNotLoaded);
      return;
    }
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final listen = '0.0.0.0:${settings.companionWorkerPort}';
    state = state.copyWith(busy: true, clearError: true);
    try {
      engine.startWorker(
        modelPath: model.filePath,
        listen: listen,
        token: settings.companionToken,
      );
      // Same reasoning as the server: a background process is confined to the
      // little-core cpuset, and the governor already under-clocks a worker
      // that computes briefly and then blocks on a socket.
      await KeepAwake.enable();
      await ForegroundTask.acquire(ForegroundTask.companion);
      state = state.copyWith(
        role: CompanionRole.worker,
        busy: false,
        workerListenAddress: listen,
      );
      await _persistRole(CompanionRole.worker);
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  /// Reads what the peer costs right now. Called between turns — never inside
  /// a decode loop.
  void refreshStats() {
    final json = ref.read(engineProvider).peerStats();
    state = state.copyWith(
        stats: json.isEmpty ? PeerStats.empty : PeerStats.fromJson(json));
  }

  Future<void> _persistRole(CompanionRole role) => ref
      .read(settingsProvider.notifier)
      .updateSettings((s) => s.copyWith(companionRole: role));
}

final companionControllerProvider =
    NotifierProvider<CompanionController, CompanionState>(
        CompanionController.new);
