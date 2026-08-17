import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cmf_mobile/data/models/conversion.dart';
import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/converter_core.dart';
import 'package:cmf_mobile/data/services/safetensors.dart' show f16BitsToDouble;
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
      expect(
        canonName('model.language_model.layers.0.mlp.gate_proj.weight'),
        'model.layers.0.mlp.gate_proj.weight',
      );
      expect(
        canonName('language_model.model.embed_tokens.weight'),
        'model.embed_tokens.weight',
      );
    });

    test('passes ordinary names through', () {
      expect(canonName('lm_head.weight'), 'lm_head.weight');
    });

    test('maps LFM2 vendor tensors without touching Qwen names', () {
      expect(canonName('model.embedding_norm.weight'), 'model.norm.weight');
      expect(
        canonName('model.layers.0.conv.in_proj.weight'),
        'model.layers.0.short_conv.in_proj.weight',
      );
      expect(
        canonName('model.layers.0.feed_forward.experts.7.w1.weight'),
        'model.layers.0.mlp.experts.7.gate_proj.weight',
      );
      expect(
        canonName('model.layers.0.feed_forward.experts.7.w3.weight'),
        'model.layers.0.mlp.experts.7.up_proj.weight',
      );
      expect(
        canonName('model.layers.0.feed_forward.experts.7.w2.weight'),
        'model.layers.0.mlp.experts.7.down_proj.weight',
      );
      expect(
        canonName('model.layers.0.self_attn.out_proj.weight'),
        'model.layers.0.self_attn.o_proj.weight',
      );
      expect(
        canonName('model.layers.0.mlp.experts.7.gate_proj.weight'),
        'model.layers.0.mlp.experts.7.gate_proj.weight',
      );
    });
  });

  group('targetDtype', () {
    test('follows the reference dispatch', () {
      expect(
        targetDtype(QuantType.q8Row, 'a.weight', [64, 64], 4096),
        Cmf.dtQ8Row,
      );
      expect(
        targetDtype(QuantType.q8_2f, 'a.weight', [64, 64], 4096),
        Cmf.dtQ8_2f,
      );
      // q1 needs in % 32 == 0, otherwise q8_2f fallback.
      expect(targetDtype(QuantType.q1, 'a.weight', [64, 64], 4096), Cmf.dtQ1);
      expect(
        targetDtype(QuantType.q1, 'a.weight', [64, 63], 4032),
        Cmf.dtQ8_2f,
      );
      // 1-D and noise-sensitive tensors stay f16.
      expect(targetDtype(QuantType.q8Row, 'norm.weight', [64], 64), Cmf.dtF16);
      expect(
        targetDtype(QuantType.q8Row, 'model.layers.0.mlp.gate.weight', [
          8,
          64,
        ], 512),
        Cmf.dtF16,
      );
    });
  });

  group('q4tp / q2tp', () {
    test('targetDtype follows the reference dispatch and the 2/4 profile', () {
      expect(
        targetDtype(QuantType.q4tp, 'a.weight', [64, 64], 4096),
        Cmf.dtQ4TiledP,
      );
      // cols % 32 misfits fall back to the two-field q8_2f.
      expect(
        targetDtype(QuantType.q4tp, 'a.weight', [64, 63], 4032),
        Cmf.dtQ8_2f,
      );
      // The q2tp PROFILE: 2-bit only for gate/up experts; down experts and
      // the skeleton stay q4tp. A dense model degenerates to plain q4tp.
      expect(
        targetDtype(
          QuantType.q2tp,
          'model.layers.0.mlp.experts.3.gate_proj.weight',
          [64, 64],
          4096,
        ),
        Cmf.dtQ2TiledP,
      );
      expect(
        targetDtype(
          QuantType.q2tp,
          'model.layers.0.mlp.experts.3.up_proj.weight',
          [64, 64],
          4096,
        ),
        Cmf.dtQ2TiledP,
      );
      expect(
        targetDtype(
          QuantType.q2tp,
          'model.layers.0.mlp.experts.3.down_proj.weight',
          [64, 64],
          4096,
        ),
        Cmf.dtQ4TiledP,
      );
      expect(
        targetDtype(
          QuantType.q2tp,
          'model.layers.0.self_attn.q_proj.weight',
          [64, 64],
          4096,
        ),
        Cmf.dtQ4TiledP,
      );
    });

    test('nbytesFor matches the three-plane layout', () {
      // 64×64: 128 groups ×16B + 64 rows ×4B params + 64 × ceil(2·5/8) codes.
      expect(nbytesFor(Cmf.dtQ4TiledP, [64, 64], 4096), 2048 + 256 + 128);
      expect(nbytesFor(Cmf.dtQ2TiledP, [64, 64], 4096), 1024 + 256 + 128);
    });

    test('encoded q4tp reconstructs within format error, zeros exact',
        () async {
      final dir = await Directory.systemTemp.createTemp('cmf_q4tp_test');
      addTearDown(() => dir.delete(recursive: true));
      const rows = 8, cols = 64;
      final values = _patternTensor(rows, cols);
      final shard = '${dir.path}/model.safetensors';
      final output = '${dir.path}/model.cmf';
      await _writeF32SafetensorsData(shard, {
        'model.layers.0.self_attn.q_proj.weight': ([rows, cols], values),
        ..._denseScaffold(cols),
      });
      await File('${dir.path}/tokenizer.json').writeAsString('{}');
      await convertSafetensorsToCmf(
        ConvertInput(
          shardPaths: [shard],
          config: _denseConfig(cols),
          vocabPath: '${dir.path}/tokenizer.json',
          outputPath: output,
          quant: QuantType.q4tp,
          sourceRepo: 'test/q4tp',
          threads: 2,
        ),
      );
      expect(await CmfValidator.validate(output), isEmpty);

      final (dtype, shape, bytes) = await _readCmfTensorBytes(
        output,
        'model.layers.0.self_attn.q_proj.weight',
      );
      expect(dtype, Cmf.dtQ4TiledP);
      expect(shape, [rows, cols]);
      expect(bytes.length, nbytesFor(Cmf.dtQ4TiledP, [rows, cols], rows * cols));

      final decoded = _dequantQ4tp(bytes, rows, cols);
      for (var r = 0; r < rows; r++) {
        for (var g = 0; g < cols ~/ 32; g++) {
          var absMax = 0.0, err = 0.0;
          for (var i = 0; i < 32; i++) {
            final v = values[r * cols + g * 32 + i];
            final d = decoded[r * cols + g * 32 + i];
            if (v.abs() > absMax) absMax = v.abs();
            err = math.max(err, (v - d).abs());
          }
          if (absMax == 0.0) {
            // A dead group must reconstruct to exact zeros.
            expect(err, 0.0, reason: 'row $r group $g');
          } else {
            // Within a step of the 16-level grid on this group's scale, with
            // headroom for the shared-ladder rounding of the scale itself.
            expect(err, lessThan(absMax / 7.0 * 1.2),
                reason: 'row $r group $g absMax=$absMax err=$err');
          }
        }
      }
    });

    test('q2tp profile: experts 2-bit with exact-zero groups, skeleton q4tp',
        () async {
      final dir = await Directory.systemTemp.createTemp('cmf_q2tp_test');
      addTearDown(() => dir.delete(recursive: true));
      const hidden = 32, inter = 64;
      final gateValues = _patternTensor(inter, hidden);
      final shard = '${dir.path}/model.safetensors';
      final output = '${dir.path}/model.cmf';
      await _writeF32SafetensorsData(shard, {
        'model.embed_tokens.weight': (
          [4, hidden],
          _patternTensor(4, hidden),
        ),
        'model.norm.weight': ([hidden], Float32List(hidden)),
        'model.layers.0.input_layernorm.weight': (
          [hidden],
          Float32List(hidden),
        ),
        'model.layers.0.post_attention_layernorm.weight': (
          [hidden],
          Float32List(hidden),
        ),
        for (final p in ['q_proj', 'k_proj', 'v_proj', 'o_proj'])
          'model.layers.0.self_attn.$p.weight': (
            [hidden, hidden],
            _patternTensor(hidden, hidden),
          ),
        'model.layers.0.mlp.gate.weight': ([2, hidden], Float32List(2 * hidden)),
        for (var e = 0; e < 2; e++) ...{
          'model.layers.0.mlp.experts.$e.gate_proj.weight': (
            [inter, hidden],
            gateValues,
          ),
          'model.layers.0.mlp.experts.$e.up_proj.weight': (
            [inter, hidden],
            _patternTensor(inter, hidden),
          ),
          'model.layers.0.mlp.experts.$e.down_proj.weight': (
            [hidden, inter],
            _patternTensor(hidden, inter),
          ),
        },
      });
      await File('${dir.path}/tokenizer.json').writeAsString('{}');
      await convertSafetensorsToCmf(
        ConvertInput(
          shardPaths: [shard],
          config: <String, dynamic>{
            'model_type': 'qwen3_moe',
            'hidden_size': hidden,
            'intermediate_size': inter,
            'num_hidden_layers': 1,
            'num_attention_heads': 1,
            'num_key_value_heads': 1,
            'vocab_size': 4,
            'num_experts': 2,
            'num_experts_per_tok': 1,
            'moe_intermediate_size': inter,
            'norm_topk_prob': true,
            'tie_word_embeddings': true,
          },
          vocabPath: '${dir.path}/tokenizer.json',
          outputPath: output,
          quant: QuantType.q2tp,
          sourceRepo: 'test/q2tp',
          threads: 2,
        ),
      );
      expect(await CmfValidator.validate(output), isEmpty);

      final (gDtype, _, gBytes) = await _readCmfTensorBytes(
        output,
        'model.layers.0.mlp.experts.0.gate_proj.weight',
      );
      expect(gDtype, Cmf.dtQ2TiledP);
      final (dDtype, _, _) = await _readCmfTensorBytes(
        output,
        'model.layers.0.mlp.experts.0.down_proj.weight',
      );
      expect(dDtype, Cmf.dtQ4TiledP);
      final (aDtype, _, _) = await _readCmfTensorBytes(
        output,
        'model.layers.0.self_attn.q_proj.weight',
      );
      expect(aDtype, Cmf.dtQ4TiledP);

      final decoded = _dequantQ2tp(gBytes, inter, hidden);
      for (var r = 0; r < inter; r++) {
        for (var g = 0; g < hidden ~/ 32; g++) {
          var absMax = 0.0, err = 0.0;
          for (var i = 0; i < 32; i++) {
            final v = gateValues[r * hidden + g * 32 + i];
            final d = decoded[r * hidden + g * 32 + i];
            if (v.abs() > absMax) absMax = v.abs();
            err = math.max(err, (v - d).abs());
          }
          if (absMax == 0.0) {
            // Rung 0 exists exactly so a pruned group cannot come back as
            // noise — the four-level grid alone cannot spell zero.
            expect(err, 0.0, reason: 'row $r group $g');
          } else {
            // Four levels: worst case half a step on the group's scale, with
            // ladder-quantization headroom on top.
            expect(err, lessThan(absMax * 0.8),
                reason: 'row $r group $g absMax=$absMax err=$err');
          }
        }
      }
    });
  });

  group('header', () {
    test('merges sidecar chat template and keeps tokenizer fields', () {
      final merged =
          jsonDecode(
                mergeTokenizerChatTemplate(
                  '{"bos_token":"<s>","chat_template":"old"}',
                  'new {{ messages }}',
                ),
              )
              as Map;
      expect(merged['bos_token'], '<s>');
      expect(merged['chat_template'], 'new {{ messages }}');
    });

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
        'arch_name',
        'hidden_size',
        'intermediate_size',
        'num_layers',
        'num_attention_heads',
        'num_kv_heads',
        'head_dim',
        'vocab_size',
        'layer_types',
        'rms_norm_eps',
        'max_position_embeddings',
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
    test('accepts the official LiquidAI LFM2.5-8B-A1B config', () {
      final config = <String, dynamic>{
        'model_type': 'lfm2_moe',
        'hidden_size': 2048,
        'intermediate_size': 7168,
        'num_hidden_layers': 24,
        'num_attention_heads': 32,
        'num_key_value_heads': 8,
        'vocab_size': 128000,
        'layer_types': [
          'conv',
          'conv',
          'full_attention',
          'conv',
          'conv',
          'conv',
          'full_attention',
          'conv',
          'conv',
          'conv',
          'full_attention',
          'conv',
          'conv',
          'conv',
          'full_attention',
          'conv',
          'conv',
          'conv',
          'full_attention',
          'conv',
          'conv',
          'full_attention',
          'conv',
          'conv',
        ],
        'conv_L_cache': 3,
        'norm_eps': 1e-5,
        'num_experts': 32,
        'num_experts_per_tok': 4,
        'moe_intermediate_size': 1792,
        'norm_topk_prob': true,
        'routed_scaling_factor': 1.0,
        'tie_word_embeddings': true,
        'max_position_embeddings': 128000,
        'rope_parameters': {'rope_theta': 5000000.0},
      };
      expect(() => ensureSupportedArch(config), returnsNormally);

      final h = buildCmfHeader(
        config,
        null,
        QuantType.q8_2f,
        sourceRepo: 'LiquidAI/LFM2.5-8B-A1B',
        numQuantTensors: 1,
      );
      final arch = h['arch'] as Map;
      expect(
        (arch['layer_types'] as List).where((t) => t == 'ShortConv'),
        hasLength(18),
      );
      expect(
        (arch['layer_types'] as List).where((t) => t == 'FullAttention'),
        hasLength(6),
      );
      expect(arch['head_dim'], 64);
      expect(arch['rms_norm_eps'], 1e-5);
      expect(arch['rope_theta'], 5000000.0);
      expect(arch['linear_conv_kernel_dim'], 3);
      expect((arch['moe'] as Map)['router_sigmoid'], isTrue);
    });

    test('keeps canonical Qwen MoE conversion enabled', () {
      final config = <String, dynamic>{
        'model_type': 'qwen3_moe',
        'hidden_size': 64,
        'intermediate_size': 128,
        'num_hidden_layers': 2,
        'num_attention_heads': 4,
        'num_key_value_heads': 2,
        'vocab_size': 100,
        'num_experts': 8,
        'num_experts_per_tok': 2,
        'moe_intermediate_size': 32,
        'norm_topk_prob': true,
      };
      expect(() => ensureSupportedArch(config), returnsNormally);

      final h = buildCmfHeader(
        config,
        null,
        QuantType.q8_2f,
        sourceRepo: 'Qwen/Qwen3-MoE',
        numQuantTensors: 1,
      );
      final moe = (h['arch'] as Map)['moe'] as Map;
      expect(moe['num_experts'], 8);
      expect(moe['top_k'], 2);
      expect(moe['moe_intermediate_size'], 32);
      expect(moe['norm_topk_prob'], isTrue);
      expect(moe['router_sigmoid'], isFalse);
    });

    test('converts canonical Qwen MoE experts into a valid CMF', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_qwen_moe_test');
      addTearDown(() => dir.delete(recursive: true));
      final shard = '${dir.path}/model.safetensors';
      final vocab = '${dir.path}/tokenizer.json';
      final output = '${dir.path}/model.cmf';
      await _writeF32Safetensors(shard, {
        'model.embed_tokens.weight': [4, 4],
        'model.norm.weight': [4],
        'model.layers.0.input_layernorm.weight': [4],
        'model.layers.0.post_attention_layernorm.weight': [4],
        for (final projection in ['q_proj', 'k_proj', 'v_proj', 'o_proj'])
          'model.layers.0.self_attn.$projection.weight': [4, 4],
        'model.layers.0.mlp.gate.weight': [2, 4],
        for (var expert = 0; expert < 2; expert++) ...{
          'model.layers.0.mlp.experts.$expert.gate_proj.weight': [8, 4],
          'model.layers.0.mlp.experts.$expert.up_proj.weight': [8, 4],
          'model.layers.0.mlp.experts.$expert.down_proj.weight': [4, 8],
        },
      });
      await File(vocab).writeAsString('{}');
      final config = <String, dynamic>{
        'model_type': 'qwen3_moe',
        'hidden_size': 4,
        'intermediate_size': 8,
        'num_hidden_layers': 1,
        'num_attention_heads': 1,
        'num_key_value_heads': 1,
        'vocab_size': 4,
        'num_experts': 2,
        'num_experts_per_tok': 1,
        'moe_intermediate_size': 8,
        'norm_topk_prob': true,
        'tie_word_embeddings': true,
      };

      await convertSafetensorsToCmf(
        ConvertInput(
          shardPaths: [shard],
          config: config,
          vocabPath: vocab,
          outputPath: output,
          quant: QuantType.f16,
          sourceRepo: 'Qwen/Qwen3-MoE-test',
          threads: 2,
        ),
      );

      expect(await CmfValidator.validate(output), isEmpty);
      expect((await CmfReader.readMetadata(output)).archName, 'qwen3_moe');
    });

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

    test('still rejects unsupported num_local_experts layouts', () {
      expect(
        () => ensureSupportedArch({
          'model_type': 'wrapper',
          'text_config': {'model_type': 'moe_text', 'num_local_experts': 64},
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

    test('converts LFM2 ShortConv plus sigmoid MoE into a valid CMF', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_lfm2_moe_test');
      addTearDown(() => dir.delete(recursive: true));
      final shard = '${dir.path}/model.safetensors';
      final vocab = '${dir.path}/tokenizer.json';
      final output = '${dir.path}/model.cmf';
      final tensors = <String, List<int>>{
        'model.embed_tokens.weight': [4, 4],
        'model.embedding_norm.weight': [4],
        'model.layers.0.operator_norm.weight': [4],
        'model.layers.0.ffn_norm.weight': [4],
        'model.layers.0.conv.in_proj.weight': [12, 4],
        'model.layers.0.conv.conv.weight': [4, 1, 3],
        'model.layers.0.conv.out_proj.weight': [4, 4],
        'model.layers.0.feed_forward.gate.weight': [2, 4],
        'model.layers.0.feed_forward.expert_bias': [2],
        for (var expert = 0; expert < 2; expert++) ...{
          'model.layers.0.feed_forward.experts.$expert.w1.weight': [8, 4],
          'model.layers.0.feed_forward.experts.$expert.w3.weight': [8, 4],
          'model.layers.0.feed_forward.experts.$expert.w2.weight': [4, 8],
        },
      };
      await _writeF32Safetensors(shard, tensors);
      await File(vocab).writeAsString('{}');
      final config = <String, dynamic>{
        'model_type': 'lfm2_moe',
        'hidden_size': 4,
        'intermediate_size': 8,
        'num_hidden_layers': 1,
        'num_attention_heads': 1,
        'num_key_value_heads': 1,
        'vocab_size': 4,
        'layer_types': ['conv'],
        'conv_L_cache': 3,
        'norm_eps': 1e-5,
        'num_experts': 2,
        'num_experts_per_tok': 1,
        'moe_intermediate_size': 8,
        'norm_topk_prob': true,
        'use_expert_bias': true,
        'routed_scaling_factor': 1.0,
        'tie_word_embeddings': true,
        'rope_parameters': {'rope_theta': 5000000.0},
      };

      await convertSafetensorsToCmf(
        ConvertInput(
          shardPaths: [shard],
          config: config,
          vocabPath: vocab,
          outputPath: output,
          quant: QuantType.f16,
          sourceRepo: 'LiquidAI/LFM2-test',
          threads: 2,
        ),
      );

      expect(await CmfValidator.validate(output), isEmpty);
      final meta = await CmfReader.readMetadata(output);
      expect(meta.archName, 'lfm2_moe');
      final raf = await File(output).open();
      addTearDown(raf.close);
      final envelope = CmfEnvelope.parse(
        Uint8List.fromList(await raf.read(Cmf.envelopeLen)),
      );
      await raf.setPosition(envelope.headerOff);
      final header =
          jsonDecode(utf8.decode(await raf.read(envelope.headerLen))) as Map;
      final arch = header['arch'] as Map;
      expect(arch['layer_types'], ['ShortConv']);
      expect(arch['linear_conv_kernel_dim'], 3);
      expect(arch['rms_norm_eps'], 1e-5);
      expect(arch['moe'], {
        'num_experts': 2,
        'top_k': 1,
        'moe_intermediate_size': 8,
        'norm_topk_prob': true,
        'shared_expert_intermediate_size': null,
        'router_sigmoid': true,
        'routed_scaling_factor': null,
      });
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
      expect(nbytesFor(Cmf.dtQ8_2f, [4, 64], 256), 4 * 64 + 4 * 2 + 64 * 2);
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

  group('q1t encoder', () {
    test('nbytes = base tiles + row_ptr + outlier overlay', () {
      final k = q1tOutliersPerRow(64); // round(64 * 0.02) = 1
      // 8 groups × 9B base + (rows+1)×4 row_ptr + rows×k×4 overlay entries.
      expect(nbytesFor(Cmf.dtQ1T, [4, 64], 256), 8 * 9 + 5 * 4 + 4 * k * 4);
    });

    test('round-trips ternary base + f16 outlier overlay via the reader format',
        () async {
      final dir = await Directory.systemTemp.createTemp('cmf_q1t_test');
      addTearDown(() => dir.delete(recursive: true));
      final shard = '${dir.path}/model.safetensors';
      final vocab = '${dir.path}/tokenizer.json';
      final output = '${dir.path}/model.cmf';

      const rows = 64, cols = 64;
      final q = Float32List(rows * cols);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          q[r * cols + c] = ((c % 3) - 1) * 0.05; // -0.05 / 0 / +0.05 ternary
        }
        q[r * cols + (r % cols)] = 5.0 + r * 0.01; // one large outlier per row
      }
      await _writeF32SafetensorsData(shard, {
        'model.embed_tokens.weight': (const [32, 64], Float32List(32 * 64)),
        'model.norm.weight': (const [64], Float32List(64)),
        'model.layers.0.input_layernorm.weight': (const [64], Float32List(64)),
        'model.layers.0.post_attention_layernorm.weight':
            (const [64], Float32List(64)),
        'model.layers.0.self_attn.q_proj.weight': (const [64, 64], q),
        'model.layers.0.self_attn.k_proj.weight':
            (const [64, 64], Float32List(64 * 64)),
        'model.layers.0.self_attn.v_proj.weight':
            (const [64, 64], Float32List(64 * 64)),
        'model.layers.0.self_attn.o_proj.weight':
            (const [64, 64], Float32List(64 * 64)),
        'model.layers.0.mlp.gate_proj.weight':
            (const [128, 64], Float32List(128 * 64)),
        'model.layers.0.mlp.up_proj.weight':
            (const [128, 64], Float32List(128 * 64)),
        'model.layers.0.mlp.down_proj.weight':
            (const [64, 128], Float32List(64 * 128)),
      });
      await File(vocab).writeAsString('{}');
      final config = <String, dynamic>{
        'model_type': 'qwen3',
        'hidden_size': 64,
        'intermediate_size': 128,
        'num_hidden_layers': 1,
        'num_attention_heads': 1,
        'num_key_value_heads': 1,
        'vocab_size': 32,
        'tie_word_embeddings': true,
      };

      await convertSafetensorsToCmf(ConvertInput(
        shardPaths: [shard],
        config: config,
        vocabPath: vocab,
        outputPath: output,
        quant: QuantType.q1t,
        sourceRepo: 'test/q1t',
        threads: 1,
      ));

      // Every tensor hash and section length is internally consistent.
      expect(await CmfValidator.validate(output), isEmpty);

      final (dtype, shape, bytes) = await _readCmfTensorBytes(
        output,
        'model.layers.0.self_attn.q_proj.weight',
      );
      expect(dtype, Cmf.dtQ1T, reason: 'q_proj should be ternary');
      expect(shape, [rows, cols]);
      expect(bytes.length, nbytesFor(Cmf.dtQ1T, [rows, cols], rows * cols));

      final decoded = _dequantQ1t(bytes, rows, cols);
      // The row outlier reconstructs (f16) at exactly its (row, col) — this is
      // the whole overlay layout: row_ptr region, entry region, col/val order.
      for (var r = 0; r < rows; r++) {
        expect(decoded[r * cols + (r % cols)], closeTo(5.0 + r * 0.01, 0.05),
            reason: 'row $r outlier');
      }
      // Non-outlier weights are ternary: |value| ∈ {0, s} per 32-group.
      for (var r = 0; r < rows; r++) {
        for (var g = 0; g < cols ~/ 32; g++) {
          final mags = <double>{};
          for (var k = 0; k < 32; k++) {
            final c = g * 32 + k;
            if (c == r % cols) continue; // skip the outlier column
            mags.add(decoded[r * cols + c].abs());
          }
          expect(mags.length, lessThanOrEqualTo(2),
              reason: 'row $r group $g is not ternary: $mags');
        }
      }
    });
  });
}

Future<void> _writeF32Safetensors(
  String path,
  Map<String, List<int>> tensors,
) async {
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
    ..add(
      (ByteData(
        8,
      )..setUint64(0, headerBytes.length, Endian.little)).buffer.asUint8List(),
    )
    ..add(headerBytes)
    ..add(Uint8List(offset));
  await File(path).writeAsBytes(bytes.takeBytes());
}

/// Deterministic values that exercise the tiled-predicted encoders' edges:
/// group 0 of every row is all zeros (the dead-group path), the last group
/// carries a 40× outlier (stretches the row ladder), the rest is a mixed-sign
/// wave with magnitudes spanning two decades.
Float32List _patternTensor(int rows, int cols) {
  final values = Float32List(rows * cols);
  for (var r = 0; r < rows; r++) {
    for (var c = 32; c < cols; c++) {
      final t = (r * 31 + c * 17) % 97;
      final magnitude = 0.001 + 0.05 * (t % 10) + 0.002 * (t % 7);
      values[r * cols + c] = (t.isEven ? 1 : -1) * magnitude;
    }
    if (cols >= 64) {
      values[r * cols + cols - 1] = r.isEven ? 2.0 : -2.0; // the outlier
    }
  }
  return values;
}

/// Dense scaffold tensors so the tiny test config converts end to end.
Map<String, (List<int>, Float32List)> _denseScaffold(int hidden) => {
      'model.embed_tokens.weight': ([4, hidden], _patternTensor(4, hidden)),
      'model.norm.weight': ([hidden], Float32List(hidden)),
      'model.layers.0.input_layernorm.weight': ([hidden], Float32List(hidden)),
      'model.layers.0.post_attention_layernorm.weight': (
        [hidden],
        Float32List(hidden),
      ),
      for (final p in ['k_proj', 'v_proj', 'o_proj'])
        'model.layers.0.self_attn.$p.weight': (
          [hidden, hidden],
          _patternTensor(hidden, hidden),
        ),
      'model.layers.0.mlp.gate_proj.weight': (
        [hidden, hidden],
        _patternTensor(hidden, hidden),
      ),
      'model.layers.0.mlp.up_proj.weight': (
        [hidden, hidden],
        _patternTensor(hidden, hidden),
      ),
      'model.layers.0.mlp.down_proj.weight': (
        [hidden, hidden],
        _patternTensor(hidden, hidden),
      ),
    };

Map<String, dynamic> _denseConfig(int hidden) => <String, dynamic>{
      'model_type': 'qwen3',
      'hidden_size': hidden,
      'intermediate_size': hidden,
      'num_hidden_layers': 1,
      'num_attention_heads': 1,
      'num_key_value_heads': 1,
      'vocab_size': 4,
      'tie_word_embeddings': true,
    };

/// Reference q4tp dequantizer, written from the format definition
/// (cortiq-core quant.rs): ladder s[c] = 2^(lo + c·step) as exp2 plus
/// multiplies, nibbles low-then-high, value (n − 8)·s.
Float32List _dequantQ4tp(Uint8List bytes, int rows, int cols) {
  final gpr = cols ~/ 32;
  final stride = q4tpCodeStride(gpr);
  final paramsOff = rows * gpr * 16;
  final codesOff = paramsOff + rows * 4;
  final data = ByteData.sublistView(bytes);
  final out = Float32List(rows * cols);
  for (var r = 0; r < rows; r++) {
    final lo = f16BitsToDouble(data.getUint16(paramsOff + r * 4, Endian.little));
    final st =
        f16BitsToDouble(data.getUint16(paramsOff + r * 4 + 2, Endian.little));
    final tab = Float64List(32);
    final ratio = math.pow(2.0, st).toDouble();
    tab[0] = math.pow(2.0, lo).toDouble();
    for (var c = 1; c < 32; c++) {
      tab[c] = tab[c - 1] * ratio;
    }
    for (var g = 0; g < gpr; g++) {
      final bit = g * 5;
      final b = codesOff + r * stride + bit ~/ 8;
      final sh = bit % 8;
      var code = bytes[b] >> sh;
      if (sh > 3) code |= bytes[b + 1] << (8 - sh);
      final s = tab[code & 0x1F];
      for (var k = 0; k < 16; k++) {
        final byte = bytes[(r * gpr + g) * 16 + k];
        out[r * cols + g * 32 + k * 2] = ((byte & 0x0F) - 8) * s;
        out[r * cols + g * 32 + k * 2 + 1] = (((byte >> 4) & 0x0F) - 8) * s;
      }
    }
  }
  return out;
}

/// Reference q2tp dequantizer: the q4tp ladder shifted one rung (rung 0 is
/// the exact zero), 2-bit fields LSB-first, value (c − 1.5)·s.
Float32List _dequantQ2tp(Uint8List bytes, int rows, int cols) {
  final gpr = cols ~/ 32;
  final stride = q4tpCodeStride(gpr);
  final paramsOff = rows * gpr * 8;
  final codesOff = paramsOff + rows * 4;
  final data = ByteData.sublistView(bytes);
  final out = Float32List(rows * cols);
  for (var r = 0; r < rows; r++) {
    final lo = f16BitsToDouble(data.getUint16(paramsOff + r * 4, Endian.little));
    final st =
        f16BitsToDouble(data.getUint16(paramsOff + r * 4 + 2, Endian.little));
    final tab = Float64List(32);
    final ratio = math.pow(2.0, st).toDouble();
    var v = math.pow(2.0, lo).toDouble();
    tab[0] = 0.0;
    for (var c = 1; c < 32; c++) {
      tab[c] = v;
      v *= ratio;
    }
    for (var g = 0; g < gpr; g++) {
      final bit = g * 5;
      final b = codesOff + r * stride + bit ~/ 8;
      final sh = bit % 8;
      var code = bytes[b] >> sh;
      if (sh > 3) code |= bytes[b + 1] << (8 - sh);
      final s = tab[code & 0x1F];
      for (var k = 0; k < 8; k++) {
        final byte = bytes[(r * gpr + g) * 8 + k];
        for (var j = 0; j < 4; j++) {
          final q = (byte >> (2 * j)) & 0x3;
          out[r * cols + g * 32 + k * 4 + j] = (q - 1.5) * s;
        }
      }
    }
  }
  return out;
}

/// Like [_writeF32Safetensors] but writes real tensor data (not zeros), so
/// value-level round-trip tests can exercise the encoders.
Future<void> _writeF32SafetensorsData(
  String path,
  Map<String, (List<int>, Float32List)> tensors,
) async {
  var offset = 0;
  final header = <String, dynamic>{};
  final blobs = <Float32List>[];
  for (final entry in tensors.entries) {
    final (shape, data) = entry.value;
    final count = shape.fold<int>(1, (a, b) => a * b);
    header[entry.key] = {
      'dtype': 'F32',
      'shape': shape,
      'data_offsets': [offset, offset + count * 4],
    };
    offset += count * 4;
    blobs.add(data);
  }
  final headerBytes = utf8.encode(jsonEncode(header));
  final bb = BytesBuilder(copy: false)
    ..add(
      (ByteData(8)..setUint64(0, headerBytes.length, Endian.little))
          .buffer
          .asUint8List(),
    )
    ..add(headerBytes);
  for (final b in blobs) {
    bb.add(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
  }
  await File(path).writeAsBytes(bb.takeBytes());
}

/// Reads one tensor's (dtype, shape, raw bytes) from a finished .cmf file by
/// walking the envelope + directory — independent of the writer internals.
Future<(int, List<int>, Uint8List)> _readCmfTensorBytes(
  String path,
  String name,
) async {
  final raf = await File(path).open();
  try {
    final env = ByteData.sublistView(Uint8List.fromList(await raf.read(128)));
    final dirOff = env.getUint64(0x20, Endian.little);
    final dirLen = env.getUint64(0x28, Endian.little);
    final dataOff = env.getUint64(0x30, Endian.little);
    await raf.setPosition(dirOff);
    final dir = Uint8List.fromList(await raf.read(dirLen));
    final d = ByteData.sublistView(dir);
    final count = d.getUint64(0, Endian.little);
    final poolOff = d.getUint64(8, Endian.little);
    for (var i = 0; i < count; i++) {
      final rec = 16 + i * 56;
      final nameOff = d.getUint32(rec, Endian.little);
      final nameLen = d.getUint16(rec + 4, Endian.little);
      final tname = utf8.decode(
        dir.sublist(poolOff + nameOff, poolOff + nameOff + nameLen),
      );
      if (tname != name) continue;
      final dtype = d.getUint8(rec + 6);
      final ndim = d.getUint8(rec + 7);
      final shape = [
        for (var s = 0; s < ndim; s++)
          d.getUint32(rec + 8 + s * 4, Endian.little),
      ];
      final off = d.getUint64(rec + 32, Endian.little);
      final nbytes = d.getUint64(rec + 40, Endian.little);
      await raf.setPosition(dataOff + off);
      return (dtype, shape, Uint8List.fromList(await raf.read(nbytes)));
    }
    throw StateError('tensor $name not found');
  } finally {
    await raf.close();
  }
}

/// Dart port of the reference `dequant_q1t` — the byte contract the runtime
/// reads. If the on-device encoder drifts from it, this decode disagrees.
Float64List _dequantQ1t(Uint8List bytes, int rows, int cols) {
  const groupSize = 32, tile = 9;
  const pow3 = [1, 3, 9, 27, 81];
  final n = rows * cols;
  final dst = Float64List(n);
  final bd = ByteData.sublistView(bytes);
  final nGroups = (n + groupSize - 1) ~/ groupSize;
  final baseLen = nGroups * tile;
  for (var g = 0; g < nGroups; g++) {
    final off = g * tile;
    final s = f16BitsToDouble(bd.getUint16(off, Endian.little));
    for (var k = 0; k < groupSize; k++) {
      final i = g * groupSize + k;
      if (i >= n) break;
      final code = (bytes[off + 2 + k ~/ 5] ~/ pow3[k % 5]) % 3;
      dst[i] = code == 1 ? s : (code == 2 ? -s : 0.0);
    }
  }
  final entries = baseLen + (rows + 1) * 4;
  int rp(int r) => bd.getUint32(baseLen + r * 4, Endian.little);
  for (var r = 0; r < rows; r++) {
    for (var p = rp(r); p < rp(r + 1); p++) {
      final e = entries + p * 4;
      final col = bd.getUint16(e, Endian.little);
      final val = f16BitsToDouble(bd.getUint16(e + 2, Endian.little));
      dst[r * cols + col] = val;
    }
  }
  return dst;
}
