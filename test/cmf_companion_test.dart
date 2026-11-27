import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file names that mark a companion, from the infosave repos', () {
    for (final path in [
      'qwen38-flash-next-q2tp-v2.mtp.cmf',
      'qwen38-flash-next-q2tp-hot.mtp.cmf',
      'MiMo-V2.6-Flash-RL-q4tp.mtp.cmf',
      'MiMo-V2.6-Flash-RL-q4tp.mm.cmf',
      'MNN-Pocket-0.3B-q4tp.dflash.cmf',
      'ripple-65b-q4tp.dflash.cmf',
      '1c-query.skill.cmf',
      'experiments/nanbeige42-code.skill.cmf',
      'experiments/nanbeige42-gfx-pervisit-skill-v2.cmf',
      'experiments/nanbeige42-gfx-pervisit-skill.cmf',
    ]) {
      expect(cmfPathIsCompanion(path), isTrue, reason: path);
    }
  });

  test('model file names are not companions', () {
    for (final path in [
      'lfm2.5-2.6b-q4tp.cmf',
      'lfm2.5-230m-q4tp.cmf',
      'qwen38-flash-next-q2tp-v2.cmf',
      'MiMo-V2.6-Flash-RL-q4tp.cmf',
      'MNN-Pocket-0.3B-q4tp.cmf',
      'nanbeige42-3b-q4t.cmf',
      'mmh3-turbo-q4tp.cmf', // "mm" inside a word, not a projector
      'minimax-m3.1-flash-q4tp.cmf',
      'MiniCPM-V-4.7-1B-q4tp.cmf',
      'cortiq-decision.cmf',
      'whisper-large-v3-turbo-q4tp-mixed.cmf',
      'Spark-X2.5-1.7B-q4mix.cmf',
      'README.md',
    ]) {
      expect(cmfPathIsCompanion(path), isFalse, reason: path);
    }
  });

  test('headers that declare a companion', () {
    // DFlash sidecar (MNN-Pocket-0.3B-q4tp.dflash.cmf).
    expect(
      cmfHeaderIsCompanion({
        'arch': {'arch_name': 'dflash2_sidecar', 'num_layers': 3},
        'provenance': {
          'kind': 'dflash2_sidecar',
          'base_binding': {'filename': 'MNN-Pocket-0.3B-q4tp.cmf'},
        },
      }),
      isTrue,
    );
    // MiMo projector towers (MiMo-V2.6-Flash-RL-q4tp.mm.cmf).
    expect(
      cmfHeaderIsCompanion({
        'arch': {'arch_name': 'mimo_v2_mm', 'num_layers': 0},
        'provenance': {
          'mimo_mm': {'base_arch': 'mimo_v2'},
        },
      }),
      isTrue,
    );
    // A standalone skill (1c-query.skill.cmf).
    expect(
      cmfHeaderIsCompanion({
        'arch': {'arch_name': 'qwen3_5'},
        'skills': [
          {'id': '1c-query', 'base_dir_hash': '9f22ab', 'base_arch': 'qwen3_5'},
        ],
      }),
      isTrue,
    );
  });

  test('model headers are not companions, Embryo carried skills included', () {
    expect(
      cmfHeaderIsCompanion({
        'arch': {'arch_name': 'lfm2', 'num_layers': 16},
        'provenance': {'tool': 'cortiq convert'},
      }),
      isFalse,
    );
    expect(
      cmfHeaderIsCompanion({
        'arch': {'arch_name': 'embryo'},
        'skills': [
          {
            'id': 'herbs',
            'kind': 'lookup',
            'bound': {'genome_id': 'g1'},
          },
        ],
      }),
      isFalse,
    );
  });
}
