import 'package:cmf_mobile/data/models/cmf_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

CmfMetadata _meta({int requiredFeatures = 1, List<String> skills = const []}) =>
    CmfMetadata(
      version: 2,
      archName: 'cortiq_embryo',
      quantType: 'Q8_2F',
      numLayers: 8,
      hiddenSize: 384,
      vocabSize: 32768,
      contextLength: 131072,
      tensorCount: 345,
      hasVocab: true,
      hasChatTemplate: true,
      eosTokenIds: const [32760],
      tasks: const [],
      requiredFeatures: requiredFeatures,
      skills: skills,
    );

void main() {
  group('CmfMetadata.isSkill', () {
    test('Embryo-56M is a chat model: carried skills, bit 6 clear', () {
      // required_features of the published file: bits 0, 2, 9, 10, 12, 13.
      final m = _meta(requiredFeatures: 0x3605);
      expect(m.isSkill, isFalse);
      expect(m.isDecision, isFalse);
    });

    test('a standalone skill is one by its feature bit alone', () {
      expect(_meta(requiredFeatures: 0x63).isSkill, isTrue);
    });

    test('a standalone skill is one by its declaration alone', () {
      expect(_meta(skills: const ['code']).isSkill, isTrue);
    });

    test('a decision file is never a skill', () {
      expect(_meta(requiredFeatures: 0x800 | 0x40).isSkill, isFalse);
      expect(_meta(requiredFeatures: 0x800 | 0x40).isDecision, isTrue);
    });

    test('round-trips through json', () {
      final m = CmfMetadata.fromJson(_meta(requiredFeatures: 0x3605).toJson());
      expect(m.requiredFeatures, 0x3605);
      expect(m.isSkill, isFalse);
    });
  });
}
