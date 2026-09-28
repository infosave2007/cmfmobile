import 'dart:async';
import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/cmf_metadata.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/device_resources.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:cmf_mobile/features/chat/model_picker_sheet.dart';
import 'package:cmf_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LocalModel _model(String id, {bool decision = false}) => LocalModel(
  id: id,
  filePath: '/$id.cmf',
  sizeBytes: 100,
  modifiedAt: DateTime(2026),
  meta: CmfMetadata.fromJson({
    'archName': decision ? 'cortiq-decision-ph-v1' : 'llama',
    'requiredFeatures': decision ? 0x800 : 1,
  }),
);
final _models = [
  _model('decision-guide-chat'),
  _model('support', decision: true),
];

class _Models extends ModelsController {
  @override
  Future<List<LocalModel>> build() async => _models;
}

class _Memory extends DeviceResources {
  @override
  Future<MemoryCheck> checkFit(LocalModel model) async => const MemoryCheck(
    requiredBytes: 100,
    totalRamBytes: 1000,
    usableRamBytes: 1000,
  );
}

class _Engine extends InferenceEngine {
  LocalModel? model;
  final gate = Completer<void>();
  @override
  bool get isAvailable => true;
  @override
  String get name => 'test';
  @override
  LocalModel? get loadedModel => model;
  @override
  Future<void> loadModel(
    LocalModel m, {
    int threads = 0,
    String engineFlags = '',
  }) async {
    await gate.future;
    model = m;
  }

  @override
  Future<void> unload() async {
    model = null;
  }

  @override
  void cancel() {}
  @override
  Stream<GenerationEvent> generate(GenerationRequest r) => const Stream.empty();
}

class _Picker extends ConsumerWidget {
  const _Picker();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ElevatedButton(
    onPressed: () => showModelPickerSheet(context, ref),
    child: const Text('pick'),
  );
}

void main() {
  for (final lang in ['en', 'ru', 'de', 'fr', 'es', 'zh', 'tr']) {
    testWidgets(
      '$lang: model kind is metadata-driven; selection survives closing picker and parent',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final engine = _Engine();
        final container = ProviderContainer(
          overrides: [
            engineProvider.overrideWithValue(engine),
            modelsProvider.overrideWith(_Models.new),
            deviceResourcesProvider.overrideWithValue(_Memory()),
          ],
        );
        addTearDown(container.dispose);
        await container.read(modelsProvider.future);
        container.read(shellIndexProvider.notifier).select(1);
        final l = lookupAppLocalizations(Locale(lang));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) =>
                      ref.watch(engineControllerProvider).loadedModelId == null
                      ? const _Picker()
                      : const Text('parent replaced'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('pick'));
        await tester.pumpAndSettle();
        expect(find.textContaining('${l.modelKindChat} ·'), findsOneWidget);
        expect(find.textContaining('${l.modelKindDecision} ·'), findsOneWidget);
        await tester.tap(find.text('support'));
        await tester.pumpAndSettle();
        expect(find.text('parent replaced'), findsOneWidget);
        engine.gate.complete();
        await tester.pumpAndSettle();
        expect(
          container.read(engineControllerProvider).loadedModelId,
          'support',
        );
        expect(container.read(shellIndexProvider), 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
