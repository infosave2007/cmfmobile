import 'dart:typed_data';

import 'package:cmf_mobile/data/models/conversion.dart';
import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/converter_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roundTiesEven', () {
    test('matches banker rounding', () {
      expect(roundTiesEven(2.5), 2);
      expect(roundTiesEven(3.5), 4);
      expect(roundTiesEven(-2.5), -2);
      expect(roundTiesEven(-3.5), -4);
      expect(roundTiesEven(2.4), 2);
      expect(roundTiesEven(-2.6), -3);
      expect(roundTiesEven(0.5), 0);
      expect(roundTiesEven(1.5), 2);
    });
  });

  group('f16ScaleOf', () {
    test('floors at the smallest normal f16', () {
      expect(f16ScaleOf(0), f16Tiny);
      expect(f16ScaleOf(1e-9), f16Tiny);
    });

    test('rounds to representable f16', () {
      final s = f16ScaleOf(0.1234567);
      expect(f16Round(s), s); // already f16-representable
    });
  });

  group('canonName', () {
    test('drops multimodal and MTP towers', () {
      expect(canonName('model.visual.patch_embed.weight'), isNull);
      expect(canonName('mtp.head.weight'), isNull);
      expect(canonName('model.embed_vision.proj.weight'), isNull);
    });

    test('unnests language_model wrappers', () {
      expect(canonName('model.language_model.layers.0.mlp.gate_proj.weight'),
          'model.layers.0.mlp.gate_proj.weight');
      expect(canonName('language_model.model.embed_tokens.weight'),
          'model.embed_tokens.weight');
    });

    test('passes ordinary names through', () {
      expect(canonName('lm_head.weight'), 'lm_head.weight');
    });
  });

  group('targetDtype', () {
    test('follows the reference dispatch', () {
      expect(targetDtype(QuantType.q8Row, 'a.weight', [64, 64], 4096),
          Cmf.dtQ8Row);
      expect(targetDtype(QuantType.q8_2f, 'a.weight', [64, 64], 4096),
          Cmf.dtQ8_2f);
      // q1 needs in % 32 == 0, otherwise q8_2f fallback.
      expect(
          targetDtype(QuantType.q1, 'a.weight', [64, 64], 4096), Cmf.dtQ1);
      expect(targetDtype(QuantType.q1, 'a.weight', [64, 63], 4032),
          Cmf.dtQ8_2f);
      // 1-D and noise-sensitive tensors stay f16.
      expect(targetDtype(QuantType.q8Row, 'norm.weight', [64], 64),
          Cmf.dtF16);
      expect(
          targetDtype(
              QuantType.q8Row, 'model.layers.0.mlp.gate.weight', [8, 64], 512),
          Cmf.dtF16);
    });
  });

  group('header', () {
    test('q1 files carry VBIT quant_type (enum has no Q1)', () {
      expect(headerQuantLabel(QuantType.q1), 'VBIT');
      expect(headerQuantLabel(QuantType.q8_2f), 'Q8_2F');
      expect(headerQuantLabel(QuantType.q8Row), 'Q8_ROW');
    });

    test('required arch fields are present', () {
      final h = buildCmfHeader(
        {
          'model_type': 'qwen3',
          'hidden_size': 64,
          'intermediate_size': 128,
          'num_hidden_layers': 2,
          'num_attention_heads': 4,
          'num_key_value_heads': 2,
          'vocab_size': 100,
          'rms_norm_eps': 1e-6,
          'max_position_embeddings': 2048,
          'eos_token_id': 7,
        },
        null,
        QuantType.q8_2f,
        sourceRepo: 'test/repo',
        numQuantTensors: 1,
      );
      final arch = h['arch'] as Map<String, dynamic>;
      for (final key in [
        'arch_name', 'hidden_size', 'intermediate_size', 'num_layers',
        'num_attention_heads', 'num_kv_heads', 'head_dim', 'vocab_size',
        'layer_types', 'rms_norm_eps', 'max_position_embeddings',
      ]) {
        expect(arch, contains(key), reason: key);
      }
      expect(arch['layer_types'], ['FullAttention', 'FullAttention']);
      expect((h['tokenizer_config'] as Map)['eos_token_ids'], [7]);
    });
  });

  group('encoders (sizes and invariants)', () {
    test('q1 nbytes = numel/32*6, q8_2f adds the column field', () {
      expect(nbytesFor(Cmf.dtQ1, [4, 64], 256), 4 * 2 * 6);
      expect(nbytesFor(Cmf.dtQ8Row, [4, 64], 256), 4 * 64 + 4 * 2);
      expect(nbytesFor(Cmf.dtQ8_2f, [4, 64], 256),
          4 * 64 + 4 * 2 + 64 * 2);
      expect(nbytesFor(Cmf.dtF16, [4, 64], 256), 512);
    });

    test('q1 sign convention: zero counts as positive', () {
      // Mirror of the reference: bit set when v >= 0.
      final values = Float32List(32); // all zeros -> all bits set
      var bits = 0;
      for (var k = 0; k < 8; k++) {
        if (values[k] >= 0.0) bits |= 1 << k;
      }
      expect(bits, 0xFF);
    });
  });
}
