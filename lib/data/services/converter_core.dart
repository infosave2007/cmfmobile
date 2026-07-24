import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/conversion.dart';
import 'cmf_format.dart';
import 'safetensors.dart';

/// Pure-Dart core of the safetensors → CMF v2 converter — no Flutter
/// dependencies, so the exact same code runs in the app, in desktop tools
/// and in tests.
///
/// Every encoder mirrors the reference converter byte for byte
/// (cmfpublic crates/cortiq-cli/src/convert.rs): f16-rounded scales
/// (quantize against the SAME scale the reader dequantizes with),
/// round-half-to-even, reference clamps and layouts. Quantization runs on
/// an isolate pool sized by [ConvertInput.threads].

/// Smallest normal f16 — floor for degenerate rows (reference F16_TINY).
const double f16Tiny = 6.103515625e-5;

double f16Round(double x) => f16BitsToDouble(f32ToF16Bits(x));

/// Reference `f16_scale`: round to f16, floor at the smallest normal.
double f16ScaleOf(double raw) => math.max(f16Round(raw), f16Tiny);

/// Round half to even (numpy/np.round semantics, reference
/// `round_ties_even`).
double roundTiesEven(double x) {
  final floor = x.floorToDouble();
  final diff = x - floor;
  if (diff > 0.5) return floor + 1;
  if (diff < 0.5) return floor;
  return floor % 2 == 0 ? floor : floor + 1;
}

/// Canonicalize a source tensor name (reference `canon_name`): vision /
/// MTP towers are dropped, multimodal text wrappers unnest to `model.*`.
String? canonName(String raw) {
  if (raw.contains('.visual.') ||
      raw.startsWith('visual.') ||
      raw.startsWith('mtp.') ||
      raw.contains('.mtp.')) {
    return null;
  }
  for (final pfx in [
    'model.vision_embedder.',
    'model.embed_audio.',
    'model.embed_vision.',
  ]) {
    if (raw.startsWith(pfx)) return null;
  }
  for (final pfx in [
    'model.language_model.',
    'language_model.model.',
    'language_model.',
  ]) {
    if (raw.startsWith(pfx)) {
      return _lfm2Canon('model.${raw.substring(pfx.length)}');
    }
  }
  return _lfm2Canon(raw);
}

/// LFM2 checkpoints use a vendor-specific layout. These markers are unique
/// to LFM2 among the supported families, so ordinary Qwen/Gemma names pass
/// through byte-for-byte.
String _lfm2Canon(String name) {
  final isLfm2 =
      name == 'model.embedding_norm.weight' ||
      name.contains('.operator_norm') ||
      name.contains('.ffn_norm') ||
      name.contains('.feed_forward.') ||
      name.contains('.conv.') ||
      name.contains('.self_attn.out_proj') ||
      name.contains('.self_attn.q_layernorm') ||
      name.contains('.self_attn.k_layernorm');
  if (!isLfm2) return name;
  if (name == 'model.embedding_norm.weight') return 'model.norm.weight';
  return name
      .replaceAll('.operator_norm.', '.input_layernorm.')
      .replaceAll('.ffn_norm.', '.post_attention_layernorm.')
      .replaceAll('.self_attn.out_proj.', '.self_attn.o_proj.')
      .replaceAll('.self_attn.q_layernorm.', '.self_attn.q_norm.')
      .replaceAll('.self_attn.k_layernorm.', '.self_attn.k_norm.')
      .replaceAll('.conv.in_proj.', '.short_conv.in_proj.')
      .replaceAll('.conv.out_proj.', '.short_conv.out_proj.')
      .replaceAll('.conv.conv.', '.short_conv.conv.')
      .replaceAll('.feed_forward.gate.weight', '.mlp.gate.weight')
      .replaceAll('.feed_forward.expert_bias', '.mlp.expert_bias')
      .replaceAll('.feed_forward.experts.', '.mlp.experts.')
      .replaceAll('.feed_forward.', '.mlp.')
      .replaceAll('.w1.weight', '.gate_proj.weight')
      .replaceAll('.w3.weight', '.up_proj.weight')
      .replaceAll('.w2.weight', '.down_proj.weight');
}

/// Noise-sensitive projections the reference converter keeps at f16.
bool forceF16(String name) =>
    name.endsWith('linear_attn.in_proj_a.weight') ||
    name.endsWith('linear_attn.in_proj_b.weight') ||
    name.endsWith('mlp.gate.weight') ||
    name.endsWith('shared_expert_gate.weight');

/// Header quant_type label (reference: Q1 files carry VBIT — the enum has
/// no Q1 variant; per-tensor truth is in the directory).
String headerQuantLabel(QuantType quant) => switch (quant) {
  QuantType.q8Row => 'Q8_ROW',
  QuantType.q8_2f => 'Q8_2F',
  QuantType.q4Block => 'Q4_BLOCK',
  QuantType.vbit => 'VBIT',
  // The file-level QuantType enum has no Q1/Q1T variant — those files carry
  // VBIT here and the per-tensor directory holds the real dtype.
  QuantType.q1 => 'VBIT',
  QuantType.q1t => 'VBIT',
  QuantType.f16 => 'F16',
};

/// q1t outlier budget: fraction of each row kept exact (f16). The on-device
/// two-field mask reduces to top-|w| per row (no activation Hessian), so this
/// is picked per row and the file size stays deterministic.
const double q1tKeepFrac = 0.02;

/// Outliers kept per row for a q1t tensor of [cols] columns.
int q1tOutliersPerRow(int cols) => (cols * q1tKeepFrac).round();

/// Tensors kept at q8_2f instead of q1t — the reference skip list. The
/// embedding, LM head and the sensitive down-projection lose too much at
/// ternary, so they stay 8-bit even in a q1t file.
bool _q1tKeepDense(String name) =>
    name.endsWith('embed_tokens.weight') ||
    name.endsWith('lm_head.weight') ||
    name.endsWith('down_proj.weight');

/// Per-tensor target dtype (reference dispatch): 2-D tensors with ≥32
/// elements quantize; q1 needs in_dim % 32 == 0, otherwise that tensor
/// falls back to q8_2f. Everything else stores f16.
int targetDtype(QuantType quant, String name, List<int> shape, int numel) {
  final twoD = shape.length == 2 && numel >= 32 && !forceF16(name);
  if (!twoD) return Cmf.dtF16;
  switch (quant) {
    case QuantType.q8Row:
      return Cmf.dtQ8Row;
    case QuantType.q8_2f:
      return Cmf.dtQ8_2f;
    case QuantType.q1:
      return shape[1] % 32 == 0 ? Cmf.dtQ1 : Cmf.dtQ8_2f;
    case QuantType.q1t:
      // Ternary needs in_dim % 32 == 0 and a within-row column index that
      // fits u16 (the overlay). Skip-list tensors and misfits stay q8_2f.
      return (shape[1] % 32 == 0 && shape[1] <= 65536 && !_q1tKeepDense(name))
          ? Cmf.dtQ1T
          : Cmf.dtQ8_2f;
    case QuantType.f16:
      return Cmf.dtF16;
    case QuantType.q4Block:
      return shape[1] % 32 == 0 ? Cmf.dtQ4Block : Cmf.dtQ8_2f;
    default:
      return Cmf.dtF16; // vbit needs the desktop toolchain
  }
}

int nbytesFor(int dtype, List<int> shape, int numel) => switch (dtype) {
  Cmf.dtQ8Row => shape[0] * shape[1] + shape[0] * 2,
  Cmf.dtQ8_2f => shape[0] * shape[1] + shape[0] * 2 + shape[1] * 2,
  Cmf.dtQ1 => (shape[0] * shape[1]) ~/ 32 * 6,
  Cmf.dtQ4Block => (shape[0] * shape[1]) ~/ 32 * 18,
  // [9B/32-group base][u32 row_ptr[rows+1]][(u16 col, f16 val) × rows·k]
  Cmf.dtQ1T =>
    (shape[0] * shape[1]) ~/ 32 * 9 +
        (shape[0] + 1) * 4 +
        shape[0] * q1tOutliersPerRow(shape[1]) * 4,
  _ => numel * 2,
};

/// Returns the language-model config used by the reference converter.
/// Multimodal wrappers keep the actual text geometry under `text_config`,
/// while the outer model_type remains the CMF architecture family name.
Map<String, dynamic> textModelConfig(Map<String, dynamic> config) {
  final nested = config['text_config'];
  if (nested is! Map) return config;

  // Recent multimodal configs (notably Qwen3.5) keep the real language
  // architecture here. Preserve outer tokenizer ids that may be omitted by
  // text_config, then let the nested architecture override wrapper fields.
  return <String, dynamic>{
    ...config,
    ...nested.cast<String, dynamic>(),
    'model_type': config['model_type'] ?? nested['model_type'],
  };
}

/// Inserts a separately-published chat_template.jinja into the tokenizer
/// config consumed by the CMF writer. Existing tokenizer fields are kept.
String mergeTokenizerChatTemplate(
  String? tokenizerConfigText,
  String template,
) {
  final config = tokenizerConfigText == null
      ? <String, dynamic>{}
      : (jsonDecode(tokenizerConfigText) as Map<String, dynamic>);
  config['chat_template'] = template;
  return jsonEncode(config);
}

/// Reject only architectures whose tensor layout is not implemented by the
/// Dart converter. Standard Qwen MoE and LFM2-MoE use the same canonical
/// expert layout as the runtime and are supported 1:1.
void ensureSupportedArch(Map<String, dynamic> config) {
  config = textModelConfig(config);
  final modelType = (config['model_type'] as String? ?? '').toLowerCase();
  final isGemma4 = modelType.contains('gemma4');
  final layerTypes =
      (config['layer_types'] as List?)?.cast<String>() ?? const [];
  final numExperts = config['num_experts'] as int? ?? 0;
  if (config.containsKey('num_local_experts') && numExperts == 0) {
    throw StateError(
      '${config['model_type']}: num_local_experts tensor '
      'layout is not supported; expected canonical num_experts MoE',
    );
  }
  if (numExperts > 0) {
    if ((config['num_experts_per_tok'] as int? ?? 0) <= 0 ||
        (config['moe_intermediate_size'] as int? ?? 0) <= 0) {
      throw StateError(
        '${config['model_type']}: MoE config is missing '
        'num_experts_per_tok or moe_intermediate_size',
      );
    }
  }
  if (config['attn_logit_softcapping'] is num ||
      (!isGemma4 && config['final_logit_softcapping'] is num)) {
    throw StateError(
      '$modelType attention/logit soft-capping is not '
      'supported by the runtime (Gemma 2 cannot be converted safely)',
    );
  }
  if (isGemma4) {
    if (config['enable_moe_block'] == true) {
      throw StateError('Gemma 4 MoE blocks are not supported yet');
    }
    if ((config['hidden_size_per_layer_input'] as int? ?? 0) > 0) {
      throw StateError('Gemma 4 E-series per-layer inputs are not supported');
    }
    if ((config['num_kv_shared_layers'] as int? ?? 0) > 0) {
      throw StateError('Gemma 4 KV-shared layers are not supported');
    }
    _gemma4SlidingPattern(config);
  }
  final activation = config['hidden_activation'] ?? config['hidden_act'];
  if (activation != null &&
      !const [
        'silu',
        'swish',
        'gelu_pytorch_tanh',
        'gelu_tanh',
        'gelu_new',
      ].contains(activation)) {
    throw StateError('unsupported hidden activation $activation');
  }
  final hasLinear = layerTypes.contains('linear_attention');
  if (hasLinear) {
    final layers = config['num_hidden_layers'] as int? ?? 0;
    if (layerTypes.length != layers) {
      throw StateError(
        'hybrid architecture has ${layerTypes.length} '
        'layer_types for $layers layers',
      );
    }
    for (final key in [
      'linear_conv_kernel_dim',
      'linear_num_key_heads',
      'linear_num_value_heads',
      'linear_key_head_dim',
      'linear_value_head_dim',
    ]) {
      if ((config[key] as int? ?? 0) <= 0) {
        throw StateError('hybrid architecture is missing $key');
      }
    }
  }
  final hasShortConv = layerTypes.any((t) => t == 'conv' || t == 'short_conv');
  if (hasShortConv) {
    final layers = config['num_hidden_layers'] as int? ?? 0;
    if (layerTypes.length != layers) {
      throw StateError(
        'ShortConv architecture has ${layerTypes.length} '
        'layer_types for $layers layers',
      );
    }
    if ((config['conv_L_cache'] as int? ??
            config['linear_conv_kernel_dim'] as int? ??
            0) <=
        0) {
      throw StateError('ShortConv architecture is missing conv_L_cache');
    }
    final invalid = layerTypes.where(
      (t) => t != 'conv' && t != 'short_conv' && t != 'full_attention',
    );
    if (invalid.isNotEmpty) {
      throw StateError('unsupported LFM2 layer type ${invalid.first}');
    }
  }
}

int? _gemma4SlidingPattern(Map<String, dynamic> config) {
  final modelType = (config['model_type'] as String? ?? '').toLowerCase();
  if (!modelType.contains('gemma4')) return null;
  final types = (config['layer_types'] as List?)?.cast<String>() ?? const [];
  final layers = config['num_hidden_layers'] as int? ?? types.length;
  final full = <int>[
    for (var i = 0; i < types.length; i++)
      if (types[i] == 'full_attention') i,
  ];
  final pattern = full.isEmpty ? 0 : full.first + 1;
  if (pattern == 0 ||
      full.asMap().entries.any((e) => e.value != pattern * (e.key + 1) - 1) ||
      layers ~/ pattern != full.length) {
    throw StateError('Gemma 4 has an irregular full/sliding layer schedule');
  }
  return pattern;
}

class ConvertInput {
  const ConvertInput({
    required this.shardPaths,
    required this.config,
    required this.vocabPath,
    required this.outputPath,
    required this.quant,
    required this.sourceRepo,
    this.tokenizerConfigText,
    this.threads = 4,
  });

  final List<String> shardPaths;
  final Map<String, dynamic> config;
  final String? tokenizerConfigText;
  final String vocabPath;
  final String outputPath;
  final QuantType quant;
  final String sourceRepo;
  final int threads;
}

Map<String, dynamic> buildCmfHeader(
  Map<String, dynamic> config,
  String? tokCfgText,
  QuantType quant, {
  required String sourceRepo,
  required int numQuantTensors,
}) {
  config = textModelConfig(config);
  final modelType = config['model_type'] as String? ?? 'llama';
  final hidden = config['hidden_size'] as int? ?? 0;
  final heads = config['num_attention_heads'] as int? ?? 1;
  final layers = config['num_hidden_layers'] as int? ?? 0;
  final rawLayerTypes =
      (config['layer_types'] as List?)?.cast<String>() ?? const [];
  final layerTypes = [
    for (var i = 0; i < layers; i++)
      if (i < rawLayerTypes.length && rawLayerTypes[i] == 'linear_attention')
        'LinearAttention'
      else if (i < rawLayerTypes.length &&
          (rawLayerTypes[i] == 'conv' || rawLayerTypes[i] == 'short_conv'))
        'ShortConv'
      else
        'FullAttention',
  ];
  final hasLinear = layerTypes.contains('LinearAttention');
  final rope = config['rope_parameters'] is Map
      ? (config['rope_parameters'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final modelTypeLower = modelType.toLowerCase();
  final numExperts = config['num_experts'] as int? ?? 0;
  final isMoe = numExperts > 0;
  final isGemma = modelTypeLower.contains('gemma');
  final isGemma4 = modelTypeLower.contains('gemma4');
  final g4Pattern = isGemma4 ? _gemma4SlidingPattern(config) : null;
  final g4FullRope = rope['full_attention'] is Map
      ? (rope['full_attention'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final g4SlidingRope = rope['sliding_attention'] is Map
      ? (rope['sliding_attention'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final activation = config['hidden_activation'] ?? config['hidden_act'];
  final hiddenAct =
      const ['gelu_pytorch_tanh', 'gelu_tanh', 'gelu_new'].contains(activation)
      ? 'gelu_tanh'
      : 'silu';
  final slidingPattern = config['sliding_window_pattern'] ?? g4Pattern;
  final eosRaw = config['eos_token_id'];
  final eos = eosRaw is List
      ? eosRaw.whereType<int>().toList()
      : eosRaw is int
      ? [eosRaw]
      : <int>[];

  String? chatTemplate;
  if (tokCfgText != null) {
    try {
      final tokCfg = jsonDecode(tokCfgText) as Map<String, dynamic>;
      final ct = tokCfg['chat_template'];
      if (ct is String) chatTemplate = ct;
    } catch (_) {}
  }

  return {
    'format': 'cmf',
    'version': Cmf.version,
    'arch': {
      'arch_name': modelType,
      'hidden_size': hidden,
      'intermediate_size':
          config['intermediate_size'] ?? config['moe_intermediate_size'] ?? 0,
      'num_layers': layers,
      'num_attention_heads': heads,
      'num_kv_heads': config['num_key_value_heads'] ?? heads,
      'head_dim': config['head_dim'] ?? (heads > 0 ? hidden ~/ heads : 0),
      'vocab_size': config['vocab_size'] ?? 0,
      'layer_types': layerTypes,
      'rms_norm_eps': config['rms_norm_eps'] ?? config['norm_eps'] ?? 1e-6,
      'norm_style':
          modelTypeLower.startsWith('qwen3_5') ||
              modelTypeLower.contains('qwen3_next') ||
              (modelTypeLower.contains('gemma') &&
                  !modelTypeLower.contains('gemma4'))
          ? 'gemma'
          : 'qwen',
      'rope_theta': isGemma4
          ? g4FullRope['rope_theta'] ?? 10000.0
          : config['rope_theta'] ?? rope['rope_theta'] ?? 10000.0,
      'tie_word_embeddings': config['tie_word_embeddings'] ?? isGemma,
      'partial_rotary_factor':
          config['partial_rotary_factor'] ??
          rope['partial_rotary_factor'] ??
          1.0,
      'hidden_act': hiddenAct,
      'embed_multiplier': isGemma ? math.sqrt(hidden.toDouble()) : 1.0,
      'query_pre_attn_scalar':
          config['query_pre_attn_scalar'] ?? (isGemma4 ? 1.0 : null),
      'sliding_window': slidingPattern != null
          ? config['sliding_window']
          : null,
      'sliding_window_pattern': slidingPattern,
      'rope_local_base_freq':
          config['rope_local_base_freq'] ?? g4SlidingRope['rope_theta'],
      'global_head_dim': isGemma4 ? config['global_head_dim'] : null,
      'num_global_kv_heads': isGemma4
          ? config['num_global_key_value_heads']
          : null,
      'global_partial_rotary_factor': isGemma4
          ? g4FullRope['partial_rotary_factor']
          : null,
      'final_logit_softcapping': isGemma4
          ? config['final_logit_softcapping']
          : null,
      'attn_v_norm': isGemma4,
      if (hasLinear)
        'linear_core': {
          'kind': 'gated_delta_net',
          'num_heads': config['linear_num_value_heads'],
          'value_head_dim': config['linear_value_head_dim'],
        },
      if (isMoe)
        'moe': {
          'num_experts': numExperts,
          'top_k': config['num_experts_per_tok'] ?? 2,
          'moe_intermediate_size': config['moe_intermediate_size'] ?? 0,
          'norm_topk_prob':
              config['norm_topk_prob'] ??
              (modelTypeLower.startsWith('qwen3_5') ||
                  modelTypeLower.contains('qwen3_next')),
          'shared_expert_intermediate_size':
              config['shared_expert_intermediate_size'],
          'router_sigmoid': modelTypeLower.startsWith('lfm2'),
          'routed_scaling_factor': switch (config['routed_scaling_factor']) {
            final num value when (value.toDouble() - 1.0).abs() > 1e-9 =>
              value.toDouble(),
            _ => null,
          },
        },
      'max_position_embeddings': config['max_position_embeddings'] ?? 0,
      'linear_conv_kernel_dim':
          config['linear_conv_kernel_dim'] ?? config['conv_L_cache'],
      'linear_num_key_heads': config['linear_num_key_heads'],
      'linear_num_value_heads': config['linear_num_value_heads'],
      'linear_key_head_dim': config['linear_key_head_dim'],
      'linear_value_head_dim': config['linear_value_head_dim'],
    },
    'quant_type': headerQuantLabel(quant),
    'tokenizer_config': {
      'chat_template': ?chatTemplate,
      'eos_token_ids': eos,
      'bos_token_id': config['bos_token_id'],
      'pad_token_id': config['pad_token_id'] is int
          ? config['pad_token_id']
          : null,
    },
    'provenance': {
      'tool': 'cmf-mobile 1.0',
      'source_model': sourceRepo,
      'quantized_tensors': numQuantTensors,
    },
  };
}

/// Converts downloaded safetensors shards into a CMF v2 file, quantizing
/// on [ConvertInput.threads] parallel isolates.
Future<void> convertSafetensorsToCmf(
  ConvertInput input, {
  void Function(int doneBytes, int totalBytes)? onProgress,
  void Function(String line)? onLog,
  bool Function()? isCancelled,
}) async {
  ensureSupportedArch(input.config);
  // Plan: every float tensor gets a canonical name, a target dtype and a
  // pre-assigned slot in the output file.
  final tasks = <TensorTask>[];
  final specs = <CmfTensorSpec>[];
  for (final path in input.shardPaths) {
    final shard = await SafetensorsFile.open(path);
    for (final t in shard.tensors) {
      final name = canonName(t.name);
      if (name == null) {
        onLog?.call('skip ${t.name} (multimodal/MTP tower)');
        continue;
      }
      if (!t.isFloat) {
        onLog?.call('skip ${t.name} (${t.dtype})');
        continue;
      }
      final dtype = targetDtype(input.quant, name, t.shape, t.numel);
      final spec = CmfTensorSpec(
        name: name,
        dtype: dtype,
        shape: t.shape,
        nbytes: nbytesFor(dtype, t.shape, t.numel),
      );
      specs.add(spec);
      tasks.add(
        TensorTask(
          shardPath: path,
          shardDataStart: shard.dataStart,
          srcDtype: t.dtype,
          srcBegin: t.begin,
          srcNbytes: t.nbytes,
          shape: t.shape,
          name: name,
          outDtype: dtype,
          outNbytes: spec.nbytes,
          outOffset: 0, // assigned after begin()
        ),
      );
    }
  }

  // Gemma 4 global attention uses K as V and does not publish v_proj.
  // Materialize the small duplicate so the runtime keeps a uniform Q/K/V/O
  // contract, matching the reference converter exactly.
  final config = textModelConfig(input.config);
  final modelType = (config['model_type'] as String? ?? '').toLowerCase();
  if (modelType.contains('gemma4') && config['global_head_dim'] != null) {
    final sourceTasks = List<TensorTask>.of(tasks);
    final names = specs.map((s) => s.name).toSet();
    final layerTypes =
        (config['layer_types'] as List?)?.cast<String>() ?? const [];
    for (final task in sourceTasks) {
      final match = RegExp(
        r'^model\.layers\.(\d+)\.self_attn\.k_proj\.weight$',
      ).firstMatch(task.name);
      if (match == null) continue;
      final layer = int.parse(match.group(1)!);
      if (layer >= layerTypes.length || layerTypes[layer] != 'full_attention') {
        continue;
      }
      final vName = task.name.replaceFirst('k_proj', 'v_proj');
      if (names.contains(vName)) continue;
      final spec = CmfTensorSpec(
        name: vName,
        dtype: task.outDtype,
        shape: task.shape,
        nbytes: task.outNbytes,
      );
      specs.add(spec);
      tasks.add(
        TensorTask(
          shardPath: task.shardPath,
          shardDataStart: task.shardDataStart,
          srcDtype: task.srcDtype,
          srcBegin: task.srcBegin,
          srcNbytes: task.srcNbytes,
          shape: task.shape,
          name: vName,
          outDtype: task.outDtype,
          outNbytes: task.outNbytes,
          outOffset: 0,
        ),
      );
      names.add(vName);
    }
  }
  if (specs.isEmpty) throw StateError('no float tensors found');

  final quantCount = specs.where((s) => s.dtype != Cmf.dtF16).length;
  final header = buildCmfHeader(
    input.config,
    input.tokenizerConfigText,
    input.quant,
    sourceRepo: input.sourceRepo,
    numQuantTensors: quantCount,
  );

  final writer = CmfWriter(
    outputPath: input.outputPath,
    headerJson: header,
    tensors: specs,
    vocabBytes: await File(input.vocabPath).readAsBytes(),
  );
  await writer.begin();
  for (var i = 0; i < tasks.length; i++) {
    tasks[i] = tasks[i].withOutOffset(writer.dataOffset + specs[i].offset);
  }

  // Balance tensors across workers by size (largest first, round-robin).
  final workers = math.max(1, math.min(input.threads, tasks.length));
  final order = List<int>.generate(tasks.length, (i) => i)
    ..sort((a, b) => tasks[b].srcNbytes.compareTo(tasks[a].srcNbytes));
  final partitions = List.generate(workers, (_) => <TensorTask>[]);
  final partitionBytes = List.filled(workers, 0);
  for (final i in order) {
    var target = 0;
    for (var w = 1; w < workers; w++) {
      if (partitionBytes[w] < partitionBytes[target]) target = w;
    }
    partitions[target].add(tasks[i]);
    partitionBytes[target] += tasks[i].srcNbytes;
  }

  final totalBytes = tasks.fold<int>(0, (s, t) => s + t.srcNbytes);
  var doneBytes = 0;
  final hashes = <String, int>{};
  final errors = <String>[];
  final isolates = <Isolate>[];
  final active = partitions.where((p) => p.isNotEmpty).toList();
  var runningWorkers = active.length;
  final allDone = Completer<void>();

  try {
    for (final partition in active) {
      final port = ReceivePort();
      void workerFinished() {
        port.close();
        runningWorkers--;
        if (runningWorkers == 0 && !allDone.isCompleted) allDone.complete();
      }

      port.listen((message) {
        switch (message) {
          case ('p', final int bytes):
            doneBytes += bytes;
            onProgress?.call(doneBytes, totalBytes);
          case ('h', final String name, final int hash):
            hashes[name] = hash;
          case ('d', null):
            workerFinished();
          case ('e', final String error):
            errors.add(error);
            workerFinished();
          case final List<dynamic> isolateError:
            errors.add('${isolateError.firstOrNull}');
            workerFinished();
        }
      });
      isolates.add(
        await Isolate.spawn(
          quantizeWorker,
          WorkerArgs(
            tasks: partition,
            outputPath: writer.stagingPath,
            sendPort: port.sendPort,
          ),
          onError: port.sendPort,
          errorsAreFatal: true,
        ),
      );
    }

    // Wait for the pool; poll so cancellation stays responsive.
    while (!allDone.isCompleted) {
      await Future.any([
        allDone.future,
        Future<void>.delayed(const Duration(milliseconds: 300)),
      ]);
      if (isCancelled?.call() == true && !allDone.isCompleted) {
        for (final iso in isolates) {
          iso.kill(priority: Isolate.immediate);
        }
        await writer.abort();
        throw const ConvertCancelled();
      }
    }

    if (errors.isNotEmpty) {
      await writer.abort();
      throw StateError(errors.first);
    }
    for (final spec in specs) {
      spec.hash = hashes[spec.name] ?? 0;
    }
    await writer.finish();
  } catch (_) {
    for (final iso in isolates) {
      iso.kill(priority: Isolate.immediate);
    }
    rethrow;
  }
}

class ConvertCancelled implements Exception {
  const ConvertCancelled();
  @override
  String toString() => 'cancelled';
}

class TensorTask {
  const TensorTask({
    required this.shardPath,
    required this.shardDataStart,
    required this.srcDtype,
    required this.srcBegin,
    required this.srcNbytes,
    required this.shape,
    required this.name,
    required this.outDtype,
    required this.outNbytes,
    required this.outOffset,
  });

  final String shardPath;
  final int shardDataStart;
  final String srcDtype;
  final int srcBegin;
  final int srcNbytes;
  final List<int> shape;
  final String name;
  final int outDtype;
  final int outNbytes;
  final int outOffset;

  TensorTask withOutOffset(int offset) => TensorTask(
    shardPath: shardPath,
    shardDataStart: shardDataStart,
    srcDtype: srcDtype,
    srcBegin: srcBegin,
    srcNbytes: srcNbytes,
    shape: shape,
    name: name,
    outDtype: outDtype,
    outNbytes: outNbytes,
    outOffset: offset,
  );
}

class WorkerArgs {
  const WorkerArgs({
    required this.tasks,
    required this.outputPath,
    required this.sendPort,
  });

  final List<TensorTask> tasks;
  final String outputPath;
  final SendPort sendPort;
}

/// Isolate entry: quantizes its share of tensors, writing each at its
/// pre-assigned absolute offset (positioned writes, no coordination).
Future<void> quantizeWorker(WorkerArgs args) async {
  final port = args.sendPort;
  RandomAccessFile? out;
  final shardFiles = <String, RandomAccessFile>{};
  try {
    out = await File(args.outputPath).open(mode: FileMode.append);
    for (final task in args.tasks) {
      final shard = shardFiles[task.shardPath] ??= await File(
        task.shardPath,
      ).open();
      final hash = await _processTensor(
        task,
        shard,
        out,
        onBytes: (n) => port.send(('p', n)),
      );
      port.send(('h', task.name, hash));
    }
    port.send(('d', null));
  } catch (e) {
    port.send(('e', '${args.tasks.firstOrNull?.name}: $e'));
  } finally {
    await out?.close();
    for (final f in shardFiles.values) {
      await f.close();
    }
  }
}

Future<int> _processTensor(
  TensorTask task,
  RandomAccessFile shard,
  RandomAccessFile out, {
  required void Function(int bytes) onBytes,
}) async {
  final hash = CmfHash64();
  var writePos = task.outOffset;
  Future<void> emit(Uint8List bytes) async {
    hash.add(bytes);
    await out.setPosition(writePos);
    await out.writeFrom(bytes);
    writePos += bytes.length;
  }

  final srcStart = task.shardDataStart + task.srcBegin;
  final rows = task.shape.isNotEmpty ? task.shape[0] : 1;
  final cols = task.shape.length == 2 ? task.shape[1] : 0;
  final bpe = switch (task.srcDtype) {
    'F32' => 4,
    _ => 2, // F16 / BF16
  };

  switch (task.outDtype) {
    case Cmf.dtQ8Row:
      // [int8 q: rows×cols][f16 scales: rows]
      final scales = Uint8List(rows * 2);
      final scaleData = ByteData.sublistView(scales);
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = await shard.read(n * cols * bpe);
        final values = decodeFloats(raw, task.srcDtype);
        final q = Uint8List(n * cols);
        for (var r = 0; r < n; r++) {
          var absMax = 0.0;
          for (var c = 0; c < cols; c++) {
            final a = values[r * cols + c].abs();
            if (a > absMax) absMax = a;
          }
          final scale = f16ScaleOf(absMax / 127.0);
          scaleData.setUint16((r0 + r) * 2, f32ToF16Bits(scale), Endian.little);
          for (var c = 0; c < cols; c++) {
            q[r * cols + c] = roundTiesEven(
              values[r * cols + c] / scale,
            ).clamp(-128.0, 127.0).toInt().toUnsigned(8);
          }
        }
        await emit(q);
        onBytes(raw.length);
      }
      await emit(scales);

    case Cmf.dtQ8_2f:
      // Pass 1 — column field: f16(RMS over rows), floored at F16_TINY.
      final colSumSq = Float64List(cols);
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = await shard.read(n * cols * bpe);
        final values = decodeFloats(raw, task.srcDtype);
        for (var r = 0; r < n; r++) {
          for (var c = 0; c < cols; c++) {
            final v = values[r * cols + c];
            colSumSq[c] += v * v;
          }
        }
      }
      final col = Float32List(cols);
      final colBytes = Uint8List(cols * 2);
      final colData = ByteData.sublistView(colBytes);
      for (var c = 0; c < cols; c++) {
        final rms = math.max(math.sqrt(colSumSq[c] / rows), 1e-12);
        col[c] = math.max(f16Round(rms), f16Tiny);
        colData.setUint16(c * 2, f32ToF16Bits(col[c]), Endian.little);
      }
      // Pass 2 — per-row residual against the column field.
      final scales = Uint8List(rows * 2);
      final scaleData = ByteData.sublistView(scales);
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = await shard.read(n * cols * bpe);
        final values = decodeFloats(raw, task.srcDtype);
        final q = Uint8List(n * cols);
        for (var r = 0; r < n; r++) {
          var absMax = 0.0;
          for (var c = 0; c < cols; c++) {
            final a = (values[r * cols + c] / col[c]).abs();
            if (a > absMax) absMax = a;
          }
          final scale = f16ScaleOf(math.max(absMax, 1e-12) / 127.0);
          scaleData.setUint16((r0 + r) * 2, f32ToF16Bits(scale), Endian.little);
          for (var c = 0; c < cols; c++) {
            final wn = values[r * cols + c] / col[c];
            q[r * cols + c] = roundTiesEven(
              wn / scale,
            ).clamp(-127.0, 127.0).toInt().toUnsigned(8);
          }
        }
        await emit(q);
        onBytes(raw.length);
      }
      await emit(scales);
      await emit(colBytes);

    case Cmf.dtQ1:
      // Flat 32-groups (in_dim % 32 == 0): [f16 mean|w|][4B signs, LSB
      // first, bit = w >= 0].
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      final groupsPerRow = cols ~/ 32;
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = await shard.read(n * cols * bpe);
        final values = decodeFloats(raw, task.srcDtype);
        final tiles = Uint8List(n * groupsPerRow * 6);
        final tileData = ByteData.sublistView(tiles);
        for (var r = 0; r < n; r++) {
          for (var g = 0; g < groupsPerRow; g++) {
            final base = r * cols + g * 32;
            var sumAbs = 0.0;
            for (var i = 0; i < 32; i++) {
              sumAbs += values[base + i].abs();
            }
            final scale = f16ScaleOf(sumAbs / 32.0);
            final tile = (r * groupsPerRow + g) * 6;
            tileData.setUint16(tile, f32ToF16Bits(scale), Endian.little);
            for (var j = 0; j < 4; j++) {
              var byte = 0;
              for (var k = 0; k < 8; k++) {
                if (values[base + j * 8 + k] >= 0.0) byte |= 1 << k;
              }
              tiles[tile + 2 + j] = byte;
            }
          }
        }
        await emit(tiles);
        onBytes(raw.length);
      }

    case Cmf.dtQ4Block:
      // Q4Block: per 32-group [packed nibbles: 16B][f16 scale: 2B].
      // Each byte stores 2 nibbles: low = even index, high = odd index.
      // Value = (nibble - 8) * scale, range [-8, 7].
      final groupsPerRow = cols ~/ 32;
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      final allPacked = BytesBuilder(copy: false);
      final allScales = BytesBuilder(copy: false);
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = await shard.read(n * cols * bpe);
        final values = decodeFloats(raw, task.srcDtype);
        final packed = Uint8List(n * groupsPerRow * 16);
        final scales = Uint8List(n * groupsPerRow * 2);
        final scaleData = ByteData.sublistView(scales);
        for (var r = 0; r < n; r++) {
          for (var g = 0; g < groupsPerRow; g++) {
            final base = r * cols + g * 32;
            var absMax = 0.0;
            for (var i = 0; i < 32; i++) {
              final a = values[base + i].abs();
              if (a > absMax) absMax = a;
            }
            final scale = f16ScaleOf(absMax / 7.0);
            final tileBase = (r * groupsPerRow + g) * 16;
            for (var k = 0; k < 16; k++) {
              final q0 = roundTiesEven(values[base + k * 2] / scale)
                  .clamp(-8.0, 7.0).toInt() + 8;
              final q1 = roundTiesEven(values[base + k * 2 + 1] / scale)
                  .clamp(-8.0, 7.0).toInt() + 8;
              packed[tileBase + k] = (q0 & 0x0F) | (q1 << 4);
            }
            scaleData.setUint16(
                (r * groupsPerRow + g) * 2, f32ToF16Bits(scale), Endian.little);
          }
        }
        allPacked.add(packed);
        allScales.add(scales);
        onBytes(raw.length);
      }
      await emit(allPacked.toBytes());
      await emit(allScales.toBytes());

    case Cmf.dtQ1T:
      // Training-free ternary {−s,0,+s}: per 32-group `[f16 scale][7B base-3
      // codes]` (0→0, 1→+s, 2→−s), then a per-row sparse f16 outlier overlay
      // `[u32 row_ptr[rows+1]][(u16 col, f16 val)]`. Outliers are the top-|w|
      // per row (the two-field mask without activation stats); a per-row α
      // rescale (докрутка, d=1) folds into the group scales. Byte-identical to
      // the reference q1t reader; the base and overlay regions are emitted in
      // file order so the tensor hash matches.
      const pow3 = [1, 3, 9, 27, 81];
      final groupsPerRow = cols ~/ 32;
      final kPerRow = q1tOutliersPerRow(cols);
      final outPerRow = kPerRow.clamp(0, cols);
      final rowPtr = Uint8List((rows + 1) * 4);
      final rowPtrData = ByteData.sublistView(rowPtr);
      final overlay = BytesBuilder(copy: false);
      var outlierCursor = 0;
      // Scratch reused across rows — the hot loop must not allocate.
      final idxScratch = Int32List(cols);
      final isOut = Uint8List(cols);
      final scale = Float32List(groupsPerRow);
      final codes = Uint8List(groupsPerRow * 7);
      final rowsPerSlab = math.max(1, 8 * 1024 * 1024 ~/ (cols * bpe));
      await shard.setPosition(srcStart);
      for (var r0 = 0; r0 < rows; r0 += rowsPerSlab) {
        final n = math.min(rowsPerSlab, rows - r0);
        final raw = await shard.read(n * cols * bpe);
        final values = decodeFloats(raw, task.srcDtype);
        final tiles = Uint8List(n * groupsPerRow * 9);
        final tileData = ByteData.sublistView(tiles);
        // (u16 col, f16 val) pairs for the whole slab in one buffer.
        final slabOverlay = Uint8List(n * outPerRow * 4);
        final slabOverlayData = ByteData.sublistView(slabOverlay);
        var op = 0;
        for (var r = 0; r < n; r++) {
          final rowBase = r * cols;
          _topKAbsMaskInto(values, rowBase, cols, kPerRow, idxScratch, isOut);
          codes.fillRange(0, codes.length, 0);
          // Per-group abs-mean scale over the non-outlier weights.
          for (var g = 0; g < groupsPerRow; g++) {
            final base = rowBase + g * 32;
            var sum = 0.0;
            var cnt = 0;
            for (var k = 0; k < 32; k++) {
              if (isOut[g * 32 + k] == 0) {
                sum += values[base + k].abs();
                cnt++;
              }
            }
            final s = math.max(
              f16Round(cnt > 0 ? sum / cnt : 0.0),
              f16Tiny,
            );
            scale[g] = s;
            for (var k = 0; k < 32; k++) {
              int code;
              if (isOut[g * 32 + k] != 0) {
                code = 0; // KERNEL INVARIANT: base contributes 0 at outliers
              } else {
                final rr = values[base + k] / s;
                code = rr >= 0.5 ? 1 : (rr <= -0.5 ? 2 : 0);
              }
              codes[g * 7 + k ~/ 5] += code * pow3[k % 5];
            }
          }
          // Per-row α that minimizes ‖α·Q − W‖² over non-outliers.
          var num = 0.0, den = 0.0;
          for (var g = 0; g < groupsPerRow; g++) {
            final base = rowBase + g * 32;
            final s = scale[g];
            for (var k = 0; k < 32; k++) {
              if (isOut[g * 32 + k] != 0) continue;
              final code = (codes[g * 7 + k ~/ 5] ~/ pow3[k % 5]) % 3;
              final q = code == 1 ? s : (code == 2 ? -s : 0.0);
              if (q == 0.0) continue;
              num += q * values[base + k];
              den += q * q;
            }
          }
          final alpha = den > 1e-20 ? (num / den).clamp(0.5, 2.0) : 1.0;
          for (var g = 0; g < groupsPerRow; g++) {
            final tile = (r * groupsPerRow + g) * 9;
            tileData.setUint16(
              tile,
              f32ToF16Bits(scale[g] * alpha),
              Endian.little,
            );
            for (var b = 0; b < 7; b++) {
              tiles[tile + 2 + b] = codes[g * 7 + b];
            }
          }
          // Overlay entries for this row, ascending column order.
          for (var j = 0; j < cols; j++) {
            if (isOut[j] != 0) {
              slabOverlayData.setUint16(op, j, Endian.little);
              slabOverlayData.setUint16(
                op + 2,
                f32ToF16Bits(values[rowBase + j]),
                Endian.little,
              );
              op += 4;
              outlierCursor++;
            }
          }
          rowPtrData.setUint32((r0 + r + 1) * 4, outlierCursor, Endian.little);
        }
        overlay.add(
          op == slabOverlay.length
              ? slabOverlay
              : Uint8List.sublistView(slabOverlay, 0, op),
        );
        await emit(tiles);
        onBytes(raw.length);
      }
      await emit(rowPtr);
      await emit(overlay.takeBytes());

    default: // f16
      final numel = task.shape.isEmpty ? 1 : task.shape.reduce((a, b) => a * b);
      await shard.setPosition(srcStart);
      if (task.srcDtype == 'F16') {
        var remaining = numel * 2;
        while (remaining > 0) {
          final take = math.min(remaining, 8 * 1024 * 1024);
          final chunk = await shard.read(take);
          await emit(chunk);
          onBytes(chunk.length);
          remaining -= chunk.length;
        }
      } else {
        final elemsPerSlab = math.max(1, 4 * 1024 * 1024 ~/ bpe);
        var remaining = numel;
        while (remaining > 0) {
          final n = math.min(remaining, elemsPerSlab);
          final raw = await shard.read(n * bpe);
          final values = decodeFloats(raw, task.srcDtype);
          final outBytes = Uint8List(n * 2);
          final outData = ByteData.sublistView(outBytes);
          for (var i = 0; i < n; i++) {
            outData.setUint16(i * 2, f32ToF16Bits(values[i]), Endian.little);
          }
          await emit(outBytes);
          onBytes(raw.length);
          remaining -= n;
        }
      }
  }

  if (writePos - task.outOffset != task.outNbytes) {
    throw StateError(
      '${task.name}: wrote ${writePos - task.outOffset}, '
      'expected ${task.outNbytes}',
    );
  }
  return hash.digest();
}

/// Fills [mask] (0/1 per column) marking the [k] largest-magnitude weights
/// in the row `values[base .. base+cols)`. Exactly `min(k, cols)` entries
/// are set — the q1t overlay size depends on this count, so it must be
/// exact. Quickselect with a fixed-seed pivot keeps it O(cols) per row and
/// deterministic across runs. [idx] and [mask] are caller-owned scratch
/// (length >= cols), reused across rows so the hot loop does not allocate.
void _topKAbsMaskInto(
  List<double> values,
  int base,
  int cols,
  int k,
  Int32List idx,
  Uint8List mask,
) {
  mask.fillRange(0, cols, 0);
  if (k <= 0) return;
  if (k >= cols) {
    mask.fillRange(0, cols, 1);
    return;
  }
  for (var j = 0; j < cols; j++) {
    idx[j] = j;
  }
  double mag(int t) => values[base + idx[t]].abs();
  void swap(int a, int b) {
    final t = idx[a];
    idx[a] = idx[b];
    idx[b] = t;
  }

  // Descending Lomuto partition around a random pivot: strictly-larger
  // magnitudes move left; returns the pivot's final index.
  int partition(int lo, int hi, int pivotPos) {
    final pv = mag(pivotPos);
    swap(pivotPos, hi);
    var store = lo;
    for (var i = lo; i < hi; i++) {
      if (mag(i) > pv) {
        swap(i, store);
        store++;
      }
    }
    swap(store, hi);
    return store;
  }

  // Textbook quickselect for rank k-1 (descending): on exit idx[0 .. k) are
  // the k largest magnitudes, so the mask has exactly k trues.
  final rng = math.Random(0);
  final target = k - 1;
  var lo = 0, hi = cols - 1;
  while (lo < hi) {
    final p = partition(lo, hi, lo + rng.nextInt(hi - lo + 1));
    if (p == target) {
      break;
    } else if (p < target) {
      lo = p + 1;
    } else {
      hi = p - 1;
    }
  }
  for (var t = 0; t < k; t++) {
    mask[idx[t]] = 1;
  }
}
