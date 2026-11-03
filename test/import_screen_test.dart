import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/conversion.dart';
import 'package:cmf_mobile/data/services/converter_service.dart';
import 'package:cmf_mobile/data/services/hf_api.dart';
import 'package:cmf_mobile/data/services/model_repository.dart';
import 'package:cmf_mobile/features/models/import_screen.dart';
import 'package:cmf_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReadyCmfApi extends HfApi {
  _ReadyCmfApi()
    : super(client: MockClient((_) async => http.Response('', 500)));

  static const model = HfModel(id: 'infosave/demo', tags: ['cmf']);

  @override
  Future<List<HfModel>> listAuthorModels(
    String author, {
    String? token,
    int limit = 50,
  }) async => const [];

  @override
  Future<List<HfModel>> search(
    String query, {
    int limit = 24,
    String? token,
  }) async => const [model];

  @override
  Future<List<HfFileEntry>> listFiles(String repo, {String? token}) async =>
      const [
        HfFileEntry(path: 'demo-q8_2f.cmf', size: 1600),
        HfFileEntry(path: 'demo-q4tp.cmf', size: 900),
      ];
}

class _RecordingConverter extends ConverterService {
  _RecordingConverter() : super(hf: _ReadyCmfApi(), models: ModelRepository());

  String? selectedCmfPath;

  @override
  Future<ConversionJob> start({
    required String repo,
    required QuantType quant,
    String? name,
    String? hfToken,
    String? cmfPath,
    int threads = 4,
  }) async {
    selectedCmfPath = cmfPath;
    final job = ConversionJob(
      id: 'test',
      repo: repo,
      quant: quant,
      name: name ?? 'test',
      outputPath: '/tmp/test.cmf',
      started: DateTime(2026),
      cmfPath: cmfPath,
    );
    jobs.add(job);
    return job;
  }
}

Future<void> _pumpImportScreen(
  WidgetTester tester,
  _RecordingConverter converter,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hfApiProvider.overrideWithValue(_ReadyCmfApi()),
        converterProvider.overrideWithValue(converter),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ImportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('featured section is driven by the account, not a hardcoded list', () {
    // Publishing a new .cmf repo on this account must surface it in the app
    // without a release — the old three-entry constant silently hid the rest.
    expect(featuredAuthor, 'infosave');
  });

  test('non-text modalities never reach the featured list', () {
    // The app is a text chat: an image, video or music CMF is a valid file
    // it has no way to run — recommending one would dead-end the user.
    expect(
      isTextGenerationRepo(
        const HfModel(id: 'a/video', tags: ['cmf', 'text-to-video']),
      ),
      isFalse,
    );
    expect(
      isTextGenerationRepo(
        const HfModel(id: 'a/music', tags: ['cmf', 'music', 'audio']),
      ),
      isFalse,
    );
    expect(
      isTextGenerationRepo(
        const HfModel(id: 'a/img', tags: ['cmf', 'diffusion']),
      ),
      isFalse,
    );
    expect(
      isTextGenerationRepo(
        const HfModel(id: 'a/llm', tags: ['cmf', 'moe', 'quantized']),
      ),
      isTrue,
    );
  });

  test('quant chip reads the filename first, tags second', () {
    expect(quantLabelFor('bonsai-1.7b-q1.cmf', const []), 'Q1');
    expect(quantLabelFor('qwen-q4tp.cmf', const ['2-bit']), 'Q4TP');
    expect(quantLabelFor('escha-w2-q2tp.cmf', const []), 'Q2TP');
    // "q1" must match only as a delimited token, not inside a hash.
    expect(quantLabelFor('modelq123.cmf', const []), '');
    expect(quantLabelFor('model.cmf', const ['q4tp']), 'Q4TP');
    expect(quantLabelFor('model.cmf', const ['bitnet']), 'Q1');
    expect(quantLabelFor('model.cmf', const ['2-bit']), '2-BIT');
    expect(quantLabelFor(null, const []), '');
  });

  test('ready CMF variants are smallest-first with a stable tie break', () {
    final files = readyCmfFiles([
      const HfFileEntry(path: 'model-q8_2f.cmf', size: 1600),
      const HfFileEntry(path: 'model-q4tp.cmf', size: 900),
      const HfFileEntry(path: 'model-q2tp.cmf', size: 900),
      const HfFileEntry(path: 'README.md', size: 1),
      const HfFileEntry(path: 'empty.cmf', size: 0),
    ]);

    expect(files.map((file) => file.path), [
      'model-q2tp.cmf',
      'model-q4tp.cmf',
      'model-q8_2f.cmf',
    ]);
  });

  testWidgets(
    'ready CMF sheet defaults to the smallest file and downloads the selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final converter = _RecordingConverter();
      addTearDown(converter.dispose);
      await _pumpImportScreen(tester, converter);

      await tester.tap(find.text('From HF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ReadyCmfApi.model.id));
      await tester.pumpAndSettle();

      expect(find.text('demo-q4tp.cmf'), findsOneWidget);
      expect(find.text('900 B'), findsOneWidget);
      expect(find.text('demo-q8_2f.cmf'), findsOneWidget);
      expect(find.text('1.6 KB'), findsOneWidget);
      final selected = tester.widget<RadioListTile<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<String> &&
              widget.value == 'demo-q4tp.cmf',
        ),
      );
      // ignore: deprecated_member_use
      expect(selected.groupValue, 'demo-q4tp.cmf');

      await tester.tap(find.text('demo-q8_2f.cmf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download'));
      // A real job leaves an indeterminate progress indicator running, so
      // advance the sheet dismissal without waiting for every animation.
      await tester.pump(const Duration(milliseconds: 300));

      expect(converter.selectedCmfPath, 'demo-q8_2f.cmf');
      expect(tester.takeException(), isNull);
    },
  );

  test('the cmf tag marks a repo as ready-to-download', () {
    expect(
      looksLikeCmfRepo(
        const HfModel(id: 'infosave/x', tags: ['cortiq', 'cmf']),
      ),
      isTrue,
    );
    expect(looksLikeCmfRepo(const HfModel(id: 'a/b', tags: ['gguf'])), isFalse);
  });

  test('q4tp leads the quantization list as the recommended profile', () {
    expect(QuantType.values.first, QuantType.q4tp);
    expect(QuantType.q4tp.supportedOnDevice, isTrue);
    expect(QuantType.q2tp.supportedOnDevice, isTrue);
  });

  test('output estimates are ordered the way the bit widths say', () {
    const src = 2 * 1000 * 1000 * 1000; // 1B weights at bf16
    int est(QuantType q) => (src / 2 * q.bytesPerWeight).round();
    expect(est(QuantType.f16), greaterThan(est(QuantType.q8_2f)));
    expect(est(QuantType.q8_2f), greaterThan(est(QuantType.q4tp)));
    expect(est(QuantType.q4tp), greaterThan(est(QuantType.q2tp)));
    expect(est(QuantType.q2tp), greaterThan(est(QuantType.q1)));
  });
}
