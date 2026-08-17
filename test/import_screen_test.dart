import 'package:cmf_mobile/data/models/conversion.dart';
import 'package:cmf_mobile/features/models/import_screen.dart';
import 'package:flutter_test/flutter_test.dart';

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
          const HfModel(id: 'a/video', tags: ['cmf', 'text-to-video'])),
      isFalse,
    );
    expect(
      isTextGenerationRepo(
          const HfModel(id: 'a/music', tags: ['cmf', 'music', 'audio'])),
      isFalse,
    );
    expect(
      isTextGenerationRepo(
          const HfModel(id: 'a/img', tags: ['cmf', 'diffusion'])),
      isFalse,
    );
    expect(
      isTextGenerationRepo(
          const HfModel(id: 'a/llm', tags: ['cmf', 'moe', 'quantized'])),
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

  test('the cmf tag marks a repo as ready-to-download', () {
    expect(
      looksLikeCmfRepo(const HfModel(id: 'infosave/x', tags: ['cortiq', 'cmf'])),
      isTrue,
    );
    expect(
      looksLikeCmfRepo(const HfModel(id: 'a/b', tags: ['gguf'])),
      isFalse,
    );
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
