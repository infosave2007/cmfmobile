import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NpuStatus.fromJson', () {
    test('reads a runtime report where the CPU won the trial', () {
      final s = NpuStatus.fromJson({
        'supported': true,
        'requested': true,
        'available': true,
        'verdict': 'cpu',
        'npu_us': 2080,
        'cpu_us': 1490,
        'lanes': 1,
        'weights_mb': 15,
        'calls': 24,
        'fallbacks': 1,
        'error': '',
      });
      expect(s.requested, isTrue);
      expect(s.available, isTrue);
      expect(s.verdict, NpuVerdict.cpu);
      expect(s.npuMicros, 2080);
      expect(s.cpuMicros, 1490);
      expect(s.lanes, 1);
      expect(s.calls, 24);
      expect(s.fallbacks, 1);
      expect(s.error, isEmpty);
    });

    test('an NPU win and an untested lane map to their verdicts', () {
      expect(NpuStatus.fromJson({'verdict': 'npu'}).verdict, NpuVerdict.npu);
      expect(NpuStatus.fromJson({'verdict': 'untested'}).verdict,
          NpuVerdict.untested);
    });

    test('missing or unknown fields fall back to safe defaults', () {
      final s = NpuStatus.fromJson({'verdict': 'something-new'});
      expect(s.requested, isFalse);
      expect(s.available, isFalse);
      expect(s.verdict, NpuVerdict.untested);
      expect(s.npuMicros, 0);
      expect(s.cpuMicros, 0);
      expect(s.error, isEmpty);
    });

    test('keeps the reason when the backend did not come up', () {
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
