import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NpuStatus.fromJson', () {
    test('reads a runtime report where the NPU won the prompt trial', () {
      final s = NpuStatus.fromJson({
        'supported': true,
        'requested': true,
        'available': true,
        'prompt_verdict': 'npu',
        'prompt_npu': 11233,
        'prompt_cpu': 28085,
        'decode_verdict': 'untested',
        'lanes': 48,
        'weights_mb': 420,
        'calls': 96,
        'fallbacks': 1,
        'error': '',
      });
      expect(s.requested, isTrue);
      expect(s.available, isTrue);
      expect(s.promptVerdict, NpuVerdict.npu);
      expect(s.promptSpeedup, closeTo(2.5, 0.01));
      expect(s.lanes, 48);
      expect(s.weightsMb, 420);
      expect(s.calls, 96);
      expect(s.fallbacks, 1);
      expect(s.error, isEmpty);
    });

    test('a CPU win and an untested lane map to their verdicts', () {
      expect(NpuStatus.fromJson({'prompt_verdict': 'cpu'}).promptVerdict,
          NpuVerdict.cpu);
      expect(NpuStatus.fromJson({'prompt_verdict': 'untested'}).promptVerdict,
          NpuVerdict.untested);
    });

    test('missing or unknown fields fall back to safe defaults', () {
      final s = NpuStatus.fromJson({'prompt_verdict': 'something-new'});
      expect(s.requested, isFalse);
      expect(s.available, isFalse);
      expect(s.promptVerdict, NpuVerdict.untested);
      expect(s.promptSpeedup, 0);
      expect(s.weightsMb, 0);
      expect(s.error, isEmpty);
    });

    test('keeps the reason when the module did not come up', () {
      final s = NpuStatus.fromJson({
        'requested': true,
        'available': false,
        'error': 'cannot load libcortiq_npu.so',
      });
      expect(s.available, isFalse);
      expect(s.error, 'cannot load libcortiq_npu.so');
    });
  });
}
