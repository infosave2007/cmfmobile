import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

    test('uses nested text_config for multimodal model headers', () {
      final h = buildCmfHeader(
        {
          'model_type': 'multimodal_wrapper',
          'eos_token_id': 9,
          'text_config': {
            'model_type': 'dense_text',
            'hidden_size': 96,
            'num_hidden_layers': 3,
            'num_attention_heads': 4,
            'vocab_size': 128,
          },
        },
        null,
        QuantType.q8Row,
        sourceRepo: 'test/nested',
        numQuantTensors: 1,
      );
      final arch = h['arch'] as Map<String, dynamic>;
      expect(arch['arch_name'], 'multimodal_wrapper');
      expect(arch['hidden_size'], 96);
      expect(arch['num_layers'], 3);
      expect((h['tokenizer_config'] as Map)['eos_token_ids'], [9]);
    });
  });

  group('architecture guard', () {
    test('accepts Qwen3.5 hybrid fields nested under text_config', () {
      expect(
        () => ensureSupportedArch({
          'model_type': 'qwen3_5',
          'text_config': {
            'num_hidden_layers': 2,
            'layer_types': ['linear_attention', 'full_attention'],
            'linear_conv_kernel_dim': 4,
            'linear_num_key_heads': 16,
            'linear_num_value_heads': 16,
            'linear_key_head_dim': 128,
            'linear_value_head_dim': 128,
          },
        }),
        returnsNormally,
      );
    });

    test('writes the complete Qwen3.5 GatedDeltaNet descriptor', () {
      final h = buildCmfHeader(
        {
          'model_type': 'qwen3_5',
          'tie_word_embeddings': true,
          'text_config': {
            'hidden_size': 1024,
            'intermediate_size': 3584,
            'num_hidden_layers': 2,
            'num_attention_heads': 8,
            'num_key_value_heads': 2,
            'head_dim': 256,
            'vocab_size': 248320,
            'layer_types': ['linear_attention', 'full_attention'],
            'linear_conv_kernel_dim': 4,
            'linear_num_key_heads': 16,
            'linear_num_value_heads': 16,
            'linear_key_head_dim': 128,
            'linear_value_head_dim': 128,
            'max_position_embeddings': 262144,
            'rope_parameters': {
              'rope_theta': 10000000.0,
              'partial_rotary_factor': 0.25,
            },
          },
        },
        null,
        QuantType.q8_2f,
        sourceRepo: 'Qwen/Qwen3.5-0.8B',
        numQuantTensors: 1,
      );
      final arch = h['arch'] as Map<String, dynamic>;
      expect(arch['arch_name'], 'qwen3_5');
      expect(arch['layer_types'], ['LinearAttention', 'FullAttention']);
      expect(arch['norm_style'], 'gemma');
      expect(arch['rope_theta'], 10000000.0);
      expect(arch['partial_rotary_factor'], 0.25);
      expect(arch['linear_core'], {
        'kind': 'gated_delta_net',
        'num_heads': 16,
        'value_head_dim': 128,
      });
      expect(arch['linear_conv_kernel_dim'], 4);
      expect(arch['linear_num_key_heads'], 16);
      expect(arch['linear_num_value_heads'], 16);
      expect(arch['linear_key_head_dim'], 128);
      expect(arch['linear_value_head_dim'], 128);
      expect(arch['tie_word_embeddings'], isTrue);
    });

    test('rejects nested MoE configs', () {
      expect(
        () => ensureSupportedArch({
          'model_type': 'wrapper',
          'text_config': {
            'model_type': 'moe_text',
            'num_local_experts': 64,
          },
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('allows nested dense attention configs', () {
      expect(
        () => ensureSupportedArch({
          'model_type': 'wrapper',
          'text_config': {
            'model_type': 'dense_text',
            'layer_types': ['full_attention'],
          },
        }),
        returnsNormally,
      );
    });

    test('converts a hybrid tensor layout into a valid CMF', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_hybrid_test');
      addTearDown(() => dir.delete(recursive: true));
      final shard = '${dir.path}/model.safetensors';
      final vocab = '${dir.path}/tokenizer.json';
      final output = '${dir.path}/model.cmf';
      final tensors = <String, List<int>>{
        'model.language_model.embed_tokens.weight': [4, 4],
        for (final name in [
          'in_proj_qkv.weight',
          'in_proj_z.weight',
          'in_proj_a.weight',
          'in_proj_b.weight',
          'conv1d.weight',
          'A_log',
          'dt_bias',
          'norm.weight',
          'out_proj.weight',
        ])
          'model.language_model.layers.0.linear_attn.$name': [4],
        for (final name in ['q_proj', 'k_proj', 'v_proj', 'o_proj'])
          'model.language_model.layers.1.self_attn.$name.weight': [4, 4],
      };
      await _writeF32Safetensors(shard, tensors);
      await File(vocab).writeAsString('{}');
      final config = <String, dynamic>{
        'model_type': 'qwen3_5',
        'tie_word_embeddings': true,
        'text_config': {
          'hidden_size': 4,
          'intermediate_size': 8,
          'num_hidden_layers': 2,
          'num_attention_heads': 1,
          'num_key_value_heads': 1,
          'head_dim': 4,
          'vocab_size': 4,
          'layer_types': ['linear_attention', 'full_attention'],
          'linear_conv_kernel_dim': 4,
          'linear_num_key_heads': 1,
          'linear_num_value_heads': 1,
          'linear_key_head_dim': 4,
          'linear_value_head_dim': 4,
        },
      };
      ensureSupportedArch(config);

      await convertSafetensorsToCmf(
        ConvertInput(
          shardPaths: [shard],
          config: config,
          vocabPath: vocab,
          outputPath: output,
          quant: QuantType.f16,
          sourceRepo: 'test/qwen3.5',
          threads: 2,
        ),
      );

      expect(await CmfValidator.validate(output), isEmpty);
      final meta = await CmfReader.readMetadata(output);
      expect(meta.archName, 'qwen3_5');
      expect(meta.numLayers, 2);
    });

    test('writes Gemma 3 scaling, activation and sliding-window fields', () {
      final h = buildCmfHeader(
        {
          'model_type': 'gemma3_text',
          'hidden_size': 9,
          'intermediate_size': 16,
          'num_hidden_layers': 2,
          'num_attention_heads': 1,
          'vocab_size': 32,
          'hidden_activation': 'gelu_pytorch_tanh',
          'sliding_window': 1024,
          'sliding_window_pattern': 2,
          'rope_local_base_freq': 10000.0,
          'query_pre_attn_scalar': 256.0,
        },
        null,
        QuantType.q8Row,
        sourceRepo: 'google/gemma-3-test',
        numQuantTensors: 1,
      );
      final arch = h['arch'] as Map<String, dynamic>;
      expect(arch['norm_style'], 'gemma');
      expect(arch['hidden_act'], 'gelu_tanh');
      expect(arch['embed_multiplier'], 3.0);
      expect(arch['query_pre_attn_scalar'], 256.0);
      expect(arch['sliding_window'], 1024);
      expect(arch['sliding_window_pattern'], 2);
      expect(arch['rope_local_base_freq'], 10000.0);
      expect(arch['tie_word_embeddings'], isTrue);
    });

    test('rejects Gemma 2 soft-capping instead of emitting bad output', () {
      expect(
        () => ensureSupportedArch({
          'model_type': 'gemma2',
          'attn_logit_softcapping': 50.0,
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('writes Gemma 4 dual-attention geometry', () {
      final h = buildCmfHeader(
        {
          'model_type': 'gemma4',
          'text_config': {
            'hidden_size': 3840,
            'intermediate_size': 15360,
            'num_hidden_layers': 6,
            'num_attention_heads': 16,
            'num_key_value_heads': 4,
            'num_global_key_value_heads': 1,
            'head_dim': 256,
            'global_head_dim': 512,
            'vocab_size': 262144,
            'layer_types': [
              'sliding_attention',
              'sliding_attention',
              'sliding_attention',
              'sliding_attention',
              'sliding_attention',
              'full_attention',
            ],
            'hidden_activation': 'gelu_pytorch_tanh',
            'sliding_window': 1024,
            'final_logit_softcapping': 30.0,
            'rope_parameters': {
              'full_attention': {
                'rope_theta': 1000000.0,
                'partial_rotary_factor': 0.25,
              },
              'sliding_attention': {'rope_theta': 10000.0},
            },
          },
        },
        null,
        QuantType.q8Row,
        sourceRepo: 'google/gemma-4-12B',
        numQuantTensors: 1,
      );
      final arch = h['arch'] as Map<String, dynamic>;
      expect(arch['norm_style'], 'qwen');
      expect(arch['embed_multiplier'], closeTo(math.sqrt(3840), 1e-12));
      expect(arch['rope_theta'], 1000000.0);
      expect(arch['rope_local_base_freq'], 10000.0);
      expect(arch['sliding_window_pattern'], 6);
      expect(arch['global_head_dim'], 512);
      expect(arch['num_global_kv_heads'], 1);
      expect(arch['global_partial_rotary_factor'], 0.25);
      expect(arch['final_logit_softcapping'], 30.0);
      expect(arch['attn_v_norm'], isTrue);
    });

    test('Gemma 4 materializes missing global v_proj from k_proj', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_gemma4_test');
      addTearDown(() => dir.delete(recursive: true));
      final shard = '${dir.path}/model.safetensors';
      final vocab = '${dir.path}/tokenizer.json';
      final output = '${dir.path}/model.cmf';
      await _writeF32Safetensors(shard, {
        'model.language_model.embed_tokens.weight': [4, 4],
        'model.language_model.layers.0.self_attn.q_proj.weight': [4, 4],
        'model.language_model.layers.0.self_attn.k_proj.weight': [4, 4],
        'model.language_model.layers.0.self_attn.o_proj.weight': [4, 4],
      });
      await File(vocab).writeAsString('{}');
      final config = <String, dynamic>{
        'model_type': 'gemma4',
        'tie_word_embeddings': true,
        'text_config': {
          'hidden_size': 4,
          'intermediate_size': 8,
          'num_hidden_layers': 1,
          'num_attention_heads': 1,
          'num_key_value_heads': 1,
          'num_global_key_value_heads': 1,
          'head_dim': 4,
          'global_head_dim': 4,
          'vocab_size': 4,
          'layer_types': ['full_attention'],
          'sliding_window': 8,
          'rope_parameters': {
            'full_attention': {
              'rope_theta': 1000.0,
              'partial_rotary_factor': 0.5,
            },
            'sliding_attention': {'rope_theta': 100.0},
          },
        },
      };

      await convertSafetensorsToCmf(
        ConvertInput(
          shardPaths: [shard],
          config: config,
          vocabPath: vocab,
          outputPath: output,
          quant: QuantType.f16,
          sourceRepo: 'test/gemma4',
          threads: 2,
        ),
      );

      expect(await CmfValidator.validate(output), isEmpty);
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

Future<void> _writeF32Safetensors(
    String path, Map<String, List<int>> tensors) async {
  var offset = 0;
  final header = <String, dynamic>{};
  for (final entry in tensors.entries) {
    final count = entry.value.fold<int>(1, (a, b) => a * b);
    header[entry.key] = {
      'dtype': 'F32',
      'shape': entry.value,
      'data_offsets': [offset, offset + count * 4],
    };
    offset += count * 4;
  }
  final headerBytes = utf8.encode(jsonEncode(header));
  final bytes = BytesBuilder(copy: false)
    ..add((ByteData(8)..setUint64(0, headerBytes.length, Endian.little))
        .buffer
        .asUint8List())
    ..add(headerBytes)
    ..add(Uint8List(offset));
  await File(path).writeAsBytes(bytes.takeBytes());
}
