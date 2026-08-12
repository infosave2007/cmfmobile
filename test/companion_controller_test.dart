import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/companion.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeEngine engine;
  late ProviderContainer container;

  Future<void> boot({
    String address = '',
    String token = '',
    int workerPort = 9911,
  }) async {
    SharedPreferences.setMockInitialValues({
      'companionAddress': address,
      'companionToken': token,
      'companionWorkerPort': workerPort,
    });
    engine = _FakeEngine();
    container = ProviderContainer(
      overrides: [engineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
  }

  CompanionController controllerOf() =>
      container.read(companionControllerProvider.notifier);
  CompanionState stateOf() => container.read(companionControllerProvider);

  group('role: compute on the desktop', () {
    test('applies the configuration the measurements support', () async {
      await boot(address: '192.168.1.5:9911', token: 'secret');
      await controllerOf().useDesktop();

      expect(engine.peerAddr, '192.168.1.5:9911');
      expect(engine.peerToken, 'secret');
      // split 0 leaves only the tokenizer here, and the head travels with the
      // layers because it does not shrink as they move away. Both are the
      // point of the role, not tunables.
      expect(engine.peerSplit, 0);
      expect(engine.peerHead, isTrue);
      expect(stateOf().role, CompanionRole.desktop);
      expect(stateOf().error, isNull);
    });

    test('refuses an address the runtime would only reject later', () async {
      await boot(address: '192.168.1.5');
      await controllerOf().useDesktop();

      expect(engine.peerAddr, isNull, reason: 'engine must not be touched');
      expect(stateOf().role, CompanionRole.local);
      expect(stateOf().error, isNotNull);
    });

    test('surfaces the runtime error and stays local', () async {
      await boot(address: '192.168.1.5:9911');
      engine.failWith = StateError('cortiq_set_peer: wire version 4 != 5');
      await controllerOf().useDesktop();

      expect(stateOf().role, CompanionRole.local);
      expect(stateOf().error, contains('wire version'));
      expect(stateOf().busy, isFalse);
    });

    test('does nothing at all on a runtime without the ABI', () async {
      await boot(address: '192.168.1.5:9911');
      engine.companion = false;
      await controllerOf().useDesktop();

      expect(controllerOf().supported, isFalse);
      expect(engine.peerAddr, isNull);
      expect(stateOf().role, CompanionRole.local);
    });

    test('going local clears the peer in the runtime', () async {
      await boot(address: '192.168.1.5:9911');
      await controllerOf().useDesktop();
      await controllerOf().useLocal();

      expect(engine.clears, 1);
      expect(stateOf().role, CompanionRole.local);
      expect(stateOf().stats.isEmpty, isTrue);
    });
  });

  group('role: serve layers', () {
    test('binds every interface on the configured port', () async {
      await boot(token: 'secret', workerPort: 9999);
      await container
          .read(engineControllerProvider.notifier)
          .loadModel(_model());
      await controllerOf().startWorker();

      expect(engine.workerListen, '0.0.0.0:9999');
      expect(engine.workerModel, '/models/demo.cmf');
      expect(engine.workerToken, 'secret');
      expect(stateOf().workerListening, isTrue);
      expect(stateOf().workerListenAddress, '0.0.0.0:9999');
    });

    test('refuses without a loaded model — the file is what it serves',
        () async {
      await boot();
      await controllerOf().startWorker();

      expect(engine.workerListen, isNull);
      expect(stateOf().workerListening, isFalse);
      expect(stateOf().error, isNotNull);
    });

    test('a busy port is reported, not swallowed', () async {
      await boot(workerPort: 9911);
      await container
          .read(engineControllerProvider.notifier)
          .loadModel(_model());
      engine.failWith = StateError('cortiq_worker_start: address in use');
      await controllerOf().startWorker();

      expect(stateOf().workerListening, isFalse);
      expect(stateOf().error, contains('address in use'));
    });
  });

  group('peer stats', () {
    test('maps what the runtime reports', () async {
      await boot();
      engine.stats = const {
        'cpu_khz_cur': 691200,
        'cpu_khz_max': 2400000,
        'threads': 4,
        'platform': 'android/aarch64',
      };
      controllerOf().refreshStats();

      final stats = stateOf().stats;
      expect(stats.threads, 4);
      expect(stats.clockFraction, closeTo(0.288, 0.001));
      expect(stats.memAvailableKb, isNull);
    });

    test('no peer means empty, not a peer reporting zeros', () async {
      await boot();
      engine.stats = const {};
      controllerOf().refreshStats();

      expect(stateOf().stats.isEmpty, isTrue);
    });
  });
}

LocalModel _model() => LocalModel(
      id: 'demo',
      filePath: '/models/demo.cmf',
      sizeBytes: 1024,
      modifiedAt: DateTime(2026, 8, 12),
    );

class _FakeEngine extends InferenceEngine {
  bool companion = true;
  Object? failWith;

  String? peerAddr;
  String? peerToken;
  int? peerSplit;
  bool? peerHead;
  int clears = 0;

  String? workerModel;
  String? workerListen;
  String? workerToken;

  Map<String, dynamic> stats = const {};

  @override
  bool get supportsCompanion => companion;

  @override
  void setPeer({
    required String addr,
    String token = '',
    int split = 0,
    bool head = true,
    String dtype = 'f16',
  }) {
    if (failWith != null) throw failWith!;
    peerAddr = addr;
    peerToken = token;
    peerSplit = split;
    peerHead = head;
  }

  @override
  void clearPeer() => clears++;

  @override
  void startWorker({
    required String modelPath,
    required String listen,
    String token = '',
  }) {
    if (failWith != null) throw failWith!;
    workerModel = modelPath;
    workerListen = listen;
    workerToken = token;
  }

  @override
  Map<String, dynamic> peerStats() => stats;

  // --- the rest of the engine, enough to load a model and answer once ------

  @override
  bool get isAvailable => true;

  @override
  String get name => 'fake';

  LocalModel? _loaded;

  @override
  LocalModel? get loadedModel => _loaded;

  @override
  Future<void> loadModel(
    LocalModel model, {
    int threads = 0,
    String engineFlags = '',
  }) async =>
      _loaded = model;

  @override
  Future<void> unload() async => _loaded = null;

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) =>
      Stream.value(const GenerationEvent(done: true));

  @override
  void cancel() {}
}
