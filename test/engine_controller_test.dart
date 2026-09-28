import 'dart:async';
import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledEngine extends InferenceEngine {
  LocalModel? current;
  final loaded = <String>[];
  Completer<void>? loadGate, unloadGate;
  bool failUnload = false;
  @override
  bool get isAvailable => true;
  @override
  String get name => 'test';
  @override
  LocalModel? get loadedModel => current;
  @override
  void cancel() {}
  @override
  Stream<GenerationEvent> generate(GenerationRequest request) =>
      const Stream.empty();
  @override
  Future<void> loadModel(
    LocalModel model, {
    int threads = 0,
    String engineFlags = '',
  }) async {
    loaded.add(model.id);
    await loadGate?.future;
    current = model;
  }

  @override
  Future<void> unload() async {
    await unloadGate?.future;
    if (failUnload) throw StateError('test');
    current = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalModel model(String id) => LocalModel(
    id: id,
    filePath: '/$id.cmf',
    sizeBytes: 1,
    modifiedAt: DateTime(2026),
  );
  late _ControlledEngine engine;
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    engine = _ControlledEngine();
    container = ProviderContainer(
      overrides: [engineProvider.overrideWithValue(engine)],
    );
  });
  tearDown(() => container.dispose());
  test(
    'overlapping selection cannot replace the in-flight model handle',
    () async {
      engine.loadGate = Completer<void>();
      final controller = container.read(engineControllerProvider.notifier);
      final loading = controller.loadModel(model('first'));
      expect(await controller.loadModel(model('second')), false);
      await controller.unload();
      expect(engine.loaded, ['first']);
      engine.loadGate!.complete();
      expect(await loading, true);
      expect(container.read(engineControllerProvider).loadedModelId, 'first');
    },
  );
  test(
    'loading is blocked while unloading and a failed unload restores usable state',
    () async {
      final controller = container.read(engineControllerProvider.notifier);
      await controller.loadModel(model('first'));
      engine.unloadGate = Completer<void>();
      engine.failUnload = true;
      final unloading = controller.unload();
      expect(await controller.loadModel(model('second')), false);
      engine.unloadGate!.complete();
      await unloading;
      final state = container.read(engineControllerProvider);
      expect(state.isLoading, false);
      expect(state.loadedModelId, 'first');
      expect(state.error, isNotNull);
    },
  );
}
