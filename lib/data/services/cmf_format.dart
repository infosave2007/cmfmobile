import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/cmf_metadata.dart';

/// CMF v2 binary format (see cmfpublic/docs/CMF_V2_SPEC.md).
///
/// Envelope: 128 bytes fixed.
///   0x00 magic "CMF\x01" | 0x04 u32 version=2 | 0x08 u32 flags
///   0x0C u32 required_features | then u64le pairs:
///   header(off,len) dir(off,len) data(off,len) masks(off,len)
///   vocab(off,len) index(off,len) | 0x70 header_hash64 | 0x78 dir_hash64
abstract final class Cmf {
  static const List<int> magic = [0x43, 0x4D, 0x46, 0x01]; // "CMF\x01"
  static const int version = 2;
  static const int envelopeLen = 128;
  static const int dirRecordLen = 56;
  static const int dataAlignment = 4096;
  static const int tensorAlignment = 64;

  static const int featureTensorDir = 1;

  // Tensor dtype ids.
  static const int dtF32 = 0;
  static const int dtF16 = 1;
  static const int dtBf16 = 2;
  static const int dtQ8Row = 3;
  static const int dtQ4Block = 4;
  static const int dtVbit = 8;
  static const int dtQ8_2f = 9;
  static const int dtVbitRo = 10;
  static const int dtQ4Tiled = 11;
  static const int dtQ1 = 12;

  static String dtypeName(int id) => switch (id) {
        dtF32 => 'f32',
        dtF16 => 'f16',
        dtBf16 => 'bf16',
        dtQ8Row => 'q8_row',
        dtQ4Block => 'q4_block',
        dtVbit => 'vbit',
        dtQ8_2f => 'q8_2f',
        dtVbitRo => 'vbit_ro',
        dtQ4Tiled => 'q4_tiled',
        dtQ1 => 'q1',
        _ => 'dtype#$id',
      };
}

/// Streaming murmur3-fmix64 hash over 64-bit LE words with positional salt:
///   m_i = fmix64(word_i ^ (i * 0x9E3779B97F4A7C15)); acc ^= m_i
///   digest = fmix64(acc ^ byteLength)
class CmfHash64 {
  int _acc = 0;
  int _wordIndex = 0;
  int _byteLen = 0;
  final Uint8List _carry = Uint8List(8);
  int _carryLen = 0;

  static int fmix64(int x) {
    x ^= x >>> 33;
    x *= 0xFF51AFD7ED558CCD;
    x ^= x >>> 33;
    x *= 0xC4CEB9FE1A85EC53;
    x ^= x >>> 33;
    return x;
  }

  void add(Uint8List bytes) {
    _byteLen += bytes.length;
    var pos = 0;
    if (_carryLen > 0) {
      final need = 8 - _carryLen;
      final take = need < bytes.length ? need : bytes.length;
      _carry.setRange(_carryLen, _carryLen + take, bytes);
      _carryLen += take;
      pos = take;
      if (_carryLen == 8) {
        _mixWord(ByteData.sublistView(_carry).getUint64(0, Endian.little));
        _carryLen = 0;
      }
    }
    final data = ByteData.sublistView(bytes);
    while (pos + 8 <= bytes.length) {
      _mixWord(data.getUint64(pos, Endian.little));
      pos += 8;
    }
    while (pos < bytes.length) {
      _carry[_carryLen++] = bytes[pos++];
    }
  }

  void _mixWord(int word) {
    _acc ^= CmfHash64.fmix64(word ^ (_wordIndex * 0x9E3779B97F4A7C15));
    _wordIndex++;
  }

  int digest() {
    if (_carryLen > 0) {
      for (var i = _carryLen; i < 8; i++) {
        _carry[i] = 0;
      }
      _mixWord(ByteData.sublistView(_carry).getUint64(0, Endian.little));
      _carryLen = 0;
    }
    return fmix64(_acc ^ _byteLen);
  }

  static int ofBytes(Uint8List bytes) {
    final h = CmfHash64()..add(bytes);
    return h.digest();
  }
}

class CmfEnvelope {
  const CmfEnvelope({
    required this.version,
    required this.flags,
    required this.requiredFeatures,
    required this.headerOff,
    required this.headerLen,
    required this.dirOff,
    required this.dirLen,
    required this.dataOff,
    required this.dataLen,
    required this.masksOff,
    required this.masksLen,
    required this.vocabOff,
    required this.vocabLen,
    required this.indexOff,
    required this.indexLen,
    required this.headerHash,
    required this.dirHash,
  });

  final int version;
  final int flags;
  final int requiredFeatures;
  final int headerOff, headerLen;
  final int dirOff, dirLen;
  final int dataOff, dataLen;
  final int masksOff, masksLen;
  final int vocabOff, vocabLen;
  final int indexOff, indexLen;
  final int headerHash, dirHash;

  static CmfEnvelope parse(Uint8List bytes) {
    if (bytes.length < Cmf.envelopeLen) {
      throw const FormatException('file shorter than CMF envelope');
    }
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != Cmf.magic[i]) {
        throw const FormatException('bad magic (not a CMF file)');
      }
    }
    final d = ByteData.sublistView(bytes);
    final version = d.getUint32(0x04, Endian.little);
    if (version != Cmf.version) {
      throw FormatException('unsupported CMF version $version');
    }
    return CmfEnvelope(
      version: version,
      flags: d.getUint32(0x08, Endian.little),
      requiredFeatures: d.getUint32(0x0C, Endian.little),
      headerOff: d.getUint64(0x10, Endian.little),
      headerLen: d.getUint64(0x18, Endian.little),
      dirOff: d.getUint64(0x20, Endian.little),
      dirLen: d.getUint64(0x28, Endian.little),
      dataOff: d.getUint64(0x30, Endian.little),
      dataLen: d.getUint64(0x38, Endian.little),
      masksOff: d.getUint64(0x40, Endian.little),
      masksLen: d.getUint64(0x48, Endian.little),
      vocabOff: d.getUint64(0x50, Endian.little),
      vocabLen: d.getUint64(0x58, Endian.little),
      indexOff: d.getUint64(0x60, Endian.little),
      indexLen: d.getUint64(0x68, Endian.little),
      headerHash: d.getUint64(0x70, Endian.little),
      dirHash: d.getUint64(0x78, Endian.little),
    );
  }
}

/// Reads CMF metadata without loading tensor data (header + counts only).
class CmfReader {
  static Future<CmfMetadata> readMetadata(String path) async {
    final raf = await File(path).open();
    try {
      final envBytes = await raf.read(Cmf.envelopeLen);
      final env = CmfEnvelope.parse(Uint8List.fromList(envBytes));

      await raf.setPosition(env.headerOff);
      final headerBytes = await raf.read(env.headerLen);
      final header =
          jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;

      // Directory: tensor count + the ACTUAL quantization. The header's
      // quant_type is informational (q1 files legitimately carry VBIT
      // there); the per-tensor truth lives in the directory, so report
      // the dtype that owns the most bytes.
      var tensorCount = 0;
      String? dominantQuant;
      if (env.dirLen >= 16) {
        await raf.setPosition(env.dirOff);
        final dir = Uint8List.fromList(
            await raf.read(env.dirLen.clamp(16, 8 * 1024 * 1024)));
        final d = ByteData.sublistView(dir);
        tensorCount = d.getUint64(0, Endian.little);
        final bytesPerDtype = <int, int>{};
        for (var i = 0; i < tensorCount; i++) {
          final rec = 16 + i * Cmf.dirRecordLen;
          if (rec + Cmf.dirRecordLen > dir.length) break;
          final dtype = d.getUint8(rec + 6);
          final nbytes = d.getUint64(rec + 40, Endian.little);
          bytesPerDtype[dtype] = (bytesPerDtype[dtype] ?? 0) + nbytes;
        }
        // Quantized dtypes take priority over the f16/f32 remainder
        // (norms and embeddings are often f16 even in quantized files).
        final quantized = Map.of(bytesPerDtype)
          ..removeWhere((k, _) =>
              k == Cmf.dtF32 || k == Cmf.dtF16 || k == Cmf.dtBf16);
        final pool = quantized.isNotEmpty ? quantized : bytesPerDtype;
        if (pool.isNotEmpty) {
          final top = pool.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
          dominantQuant = Cmf.dtypeName(top).toUpperCase();
        }
      }

      // Task-mask names from the masks section meta JSON.
      final tasks = <String>[];
      if (env.masksOff != 0 && env.masksLen > 8) {
        await raf.setPosition(env.masksOff);
        final head = Uint8List.fromList(await raf.read(8));
        final metaLen =
            ByteData.sublistView(head).getUint32(4, Endian.little);
        if (metaLen > 0 && metaLen < 4 * 1024 * 1024) {
          final metaBytes = await raf.read(metaLen);
          try {
            final meta =
                jsonDecode(utf8.decode(metaBytes)) as Map<String, dynamic>;
            for (final m in (meta['masks'] as List? ?? const [])) {
              final name = (m as Map)['name'];
              if (name is String) tasks.add(name);
            }
          } catch (_) {
            // Masks meta is informational; ignore parse issues.
          }
        }
      }

      final arch = header['arch'] as Map<String, dynamic>? ?? const {};
      final tok =
          header['tokenizer_config'] as Map<String, dynamic>? ?? const {};
      final eosRaw = tok['eos_token_ids'];
      final eos = eosRaw is List
          ? eosRaw.whereType<int>().toList()
          : eosRaw is int
              ? [eosRaw]
              : <int>[];

      return CmfMetadata(
        version: env.version,
        archName: arch['arch_name'] as String? ?? '?',
        quantType:
            dominantQuant ?? header['quant_type'] as String? ?? '?',
        numLayers: arch['num_layers'] as int? ?? 0,
        hiddenSize: arch['hidden_size'] as int? ?? 0,
        numKvHeads: arch['num_kv_heads'] as int? ?? 0,
        headDim: arch['head_dim'] as int? ?? 0,
        vocabSize: arch['vocab_size'] as int? ?? 0,
        contextLength: arch['max_position_embeddings'] as int? ?? 0,
        tensorCount: tensorCount,
        hasVocab: env.vocabOff != 0 && env.vocabLen > 0,
        hasChatTemplate: (tok['chat_template'] as String?)?.isNotEmpty == true,
        eosTokenIds: eos,
        tasks: tasks,
        requiredFeatures: env.requiredFeatures,
      );
    } finally {
      await raf.close();
    }
  }
}

/// Structural pre-flight for a .cmf file: catches inconsistent files
/// (e.g. hybrid models converted by tools that mislabel layer_types) with
/// a clear Dart-side error instead of a native crash at generate time.
abstract final class CmfValidator {
  static Future<List<String>> validate(String path) async {
    final problems = <String>[];
    final raf = await File(path).open();
    try {
      final env = CmfEnvelope.parse(
          Uint8List.fromList(await raf.read(Cmf.envelopeLen)));

      await raf.setPosition(env.headerOff);
      final header = jsonDecode(utf8.decode(await raf.read(env.headerLen)))
          as Map<String, dynamic>;
      final arch = header['arch'] as Map<String, dynamic>? ?? const {};
      final layerTypes =
          (arch['layer_types'] as List?)?.cast<String>() ?? const [];
      final tied = arch['tie_word_embeddings'] == true;

      // Tensor names from the directory pool.
      if (env.dirLen < 16 || env.dirLen > 64 * 1024 * 1024) {
        return ['directory section has implausible size ${env.dirLen}'];
      }
      await raf.setPosition(env.dirOff);
      final dir = Uint8List.fromList(await raf.read(env.dirLen));
      final d = ByteData.sublistView(dir);
      final count = d.getUint64(0, Endian.little);
      final poolOff = d.getUint64(8, Endian.little);
      final names = <String>{};
      for (var i = 0; i < count; i++) {
        final rec = 16 + i * Cmf.dirRecordLen;
        if (rec + Cmf.dirRecordLen > dir.length) break;
        final nameOff = d.getUint32(rec, Endian.little);
        final nameLen = d.getUint16(rec + 4, Endian.little);
        final start = poolOff + nameOff;
        if (start + nameLen <= dir.length) {
          names.add(utf8.decode(dir.sublist(start, start + nameLen),
              allowMalformed: true));
        }
      }

      if (!names.contains('model.embed_tokens.weight')) {
        problems.add('missing model.embed_tokens.weight');
      }
      if (!tied && !names.contains('lm_head.weight')) {
        problems.add(
            'missing lm_head.weight (and tie_word_embeddings is false)');
      }
      for (var i = 0; i < layerTypes.length; i++) {
        if (layerTypes[i] == 'FullAttention') {
          final missing = ['q_proj', 'k_proj', 'v_proj', 'o_proj']
              .where((n) => !names
                  .contains('model.layers.$i.self_attn.$n.weight'))
              .toList();
          if (missing.isNotEmpty) {
            problems.add('layer $i is FullAttention but is missing '
                'self_attn.${missing.join('/')} weights');
            break; // one clear message beats sixty
          }
        } else {
          final prefix = 'model.layers.$i.linear_attn.';
          final required = [
            'in_proj_qkv.weight',
            'in_proj_z.weight',
            'in_proj_a.weight',
            'in_proj_b.weight',
            'conv1d.weight',
            'A_log',
            'dt_bias',
            'norm.weight',
            'out_proj.weight',
          ];
          final missing = required
              .where((n) => !names.contains('$prefix$n'))
              .toList();
          if (missing.isNotEmpty) {
            problems.add('layer $i is ${layerTypes[i]} but is missing '
                'linear_attn.${missing.join(', linear_attn.')}');
            break;
          }
        }
      }
    } catch (e) {
      problems.add('unreadable CMF structure: $e');
    } finally {
      await raf.close();
    }
    return problems;
  }
}

/// One tensor scheduled for writing.
class CmfTensorSpec {
  CmfTensorSpec({
    required this.name,
    required this.dtype,
    required this.shape,
    required this.nbytes,
  });

  final String name;
  final int dtype;
  final List<int> shape; // up to 6 dims
  final int nbytes;

  int offset = 0; // relative to data_off, assigned by the writer
  int hash = 0;
}

/// Streams a spec-compliant CMF v2 file to disk.
///
/// Usage: construct with header/specs/vocab, call [begin], then for each
/// tensor (in the same order as [tensors]) call [writeTensorChunk] one or
/// more times, then [finish].
class CmfWriter {
  CmfWriter({
    required this.outputPath,
    required Map<String, dynamic> headerJson,
    required this.tensors,
    this.vocabBytes,
  }) : _headerBytes = utf8.encode(jsonEncode(headerJson));

  final String outputPath;
  final List<CmfTensorSpec> tensors;
  final Uint8List? vocabBytes;
  final Uint8List _headerBytes;

  late RandomAccessFile _raf;
  late int _dirOff;
  late int _dirLen;
  late int _dataOff;
  late int _dataLen;

  int _tensorIndex = -1;
  int _written = 0; // bytes written of current tensor
  CmfHash64 _tensorHash = CmfHash64();

  static int _align(int v, int a) => (v + a - 1) ~/ a * a;

  /// Absolute file offset of the data blob (valid after [begin]).
  int get dataOffset => _dataOff;

  Future<void> begin() async {
    // Plan layout.
    final namePool = BytesBuilder(copy: false);
    final nameOffsets = <int>[];
    for (final t in tensors) {
      nameOffsets.add(namePool.length);
      namePool.add(utf8.encode(t.name));
    }
    _dirOff = Cmf.envelopeLen + _headerBytes.length;
    _dirLen = 16 + tensors.length * Cmf.dirRecordLen + namePool.length;
    _dataOff = _align(_dirOff + _dirLen, Cmf.dataAlignment);

    var cursor = 0;
    for (final t in tensors) {
      cursor = _align(cursor, Cmf.tensorAlignment);
      t.offset = cursor;
      cursor += t.nbytes;
    }
    _dataLen = cursor;

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    _raf = await file.open(mode: FileMode.write);
    await _raf.truncate(0);

    // Envelope + directory are rewritten with hashes in finish();
    // reserve their bytes now so tensor data can stream sequentially.
    await _raf.writeFrom(Uint8List(Cmf.envelopeLen));
    await _raf.writeFrom(_headerBytes);
    await _raf.writeFrom(Uint8List(_dataOff - _dirOff));
  }

  Future<void> nextTensor() async {
    _tensorIndex++;
    _written = 0;
    _tensorHash = CmfHash64();
    final t = tensors[_tensorIndex];
    await _raf.setPosition(_dataOff + t.offset);
  }

  Future<void> writeTensorChunk(Uint8List chunk) async {
    _tensorHash.add(chunk);
    await _raf.writeFrom(chunk);
    _written += chunk.length;
    final t = tensors[_tensorIndex];
    if (_written > t.nbytes) {
      throw StateError('tensor ${t.name}: wrote $_written > ${t.nbytes}');
    }
    if (_written == t.nbytes) {
      t.hash = _tensorHash.digest();
    }
  }

  Future<void> finish() async {
    // Vocab section (verbatim tokenizer.json).
    var vocabOff = 0, vocabLen = 0;
    if (vocabBytes != null && vocabBytes!.isNotEmpty) {
      vocabOff = _align(_dataOff + _dataLen, 8);
      await _raf.setPosition(_dataOff + _dataLen);
      await _raf.writeFrom(Uint8List(vocabOff - (_dataOff + _dataLen)));
      await _raf.writeFrom(vocabBytes!);
      vocabLen = vocabBytes!.length;
    }

    // Directory: [count u64][pool_off u64][records...][name pool]
    final namePool = BytesBuilder(copy: false);
    final dir = ByteData(16 + tensors.length * Cmf.dirRecordLen);
    dir.setUint64(0, tensors.length, Endian.little);
    dir.setUint64(8, 16 + tensors.length * Cmf.dirRecordLen, Endian.little);
    var rec = 16;
    for (final t in tensors) {
      final nameBytes = utf8.encode(t.name);
      dir.setUint32(rec + 0, namePool.length, Endian.little);
      dir.setUint16(rec + 4, nameBytes.length, Endian.little);
      dir.setUint8(rec + 6, t.dtype);
      dir.setUint8(rec + 7, t.shape.length);
      for (var i = 0; i < 6; i++) {
        dir.setUint32(
            rec + 8 + i * 4, i < t.shape.length ? t.shape[i] : 0, Endian.little);
      }
      dir.setUint64(rec + 32, t.offset, Endian.little);
      dir.setUint64(rec + 40, t.nbytes, Endian.little);
      dir.setUint64(rec + 48, t.hash, Endian.little);
      namePool.add(nameBytes);
      rec += Cmf.dirRecordLen;
    }
    final dirBytes = BytesBuilder(copy: false)
      ..add(dir.buffer.asUint8List())
      ..add(namePool.takeBytes());
    final dirAll = dirBytes.takeBytes();
    await _raf.setPosition(_dirOff);
    await _raf.writeFrom(dirAll);

    // Envelope.
    final env = ByteData(Cmf.envelopeLen);
    for (var i = 0; i < 4; i++) {
      env.setUint8(i, Cmf.magic[i]);
    }
    env.setUint32(0x04, Cmf.version, Endian.little);
    env.setUint32(0x08, 0, Endian.little);
    // QUANT_2F (bit 2) is required when q8_2f/vbit tensors are present —
    // matches the reference writer in cortiq-core/src/format.rs.
    final hasQuant2f = tensors
        .any((t) => t.dtype == Cmf.dtQ8_2f || t.dtype == Cmf.dtVbit);
    env.setUint32(0x0C,
        Cmf.featureTensorDir | (hasQuant2f ? 4 : 0), Endian.little);
    env.setUint64(0x10, Cmf.envelopeLen, Endian.little);
    env.setUint64(0x18, _headerBytes.length, Endian.little);
    env.setUint64(0x20, _dirOff, Endian.little);
    env.setUint64(0x28, dirAll.length, Endian.little);
    env.setUint64(0x30, _dataOff, Endian.little);
    env.setUint64(0x38, _dataLen, Endian.little);
    env.setUint64(0x40, 0, Endian.little); // masks
    env.setUint64(0x48, 0, Endian.little);
    env.setUint64(0x50, vocabOff, Endian.little);
    env.setUint64(0x58, vocabLen, Endian.little);
    env.setUint64(0x60, 0, Endian.little); // sparse index
    env.setUint64(0x68, 0, Endian.little);
    env.setUint64(
        0x70, CmfHash64.ofBytes(Uint8List.fromList(_headerBytes)), Endian.little);
    env.setUint64(0x78, CmfHash64.ofBytes(dirAll), Endian.little);
    await _raf.setPosition(0);
    await _raf.writeFrom(env.buffer.asUint8List());
    await _raf.close();
  }

  Future<void> abort() async {
    try {
      await _raf.close();
    } catch (_) {}
    try {
      await File(outputPath).delete();
    } catch (_) {}
  }
}

/// float32 -> IEEE 754 half, round-to-nearest-even, with overflow to inf.
int f32ToF16Bits(double value) {
  final f32 = ByteData(4)..setFloat32(0, value, Endian.little);
  final x = f32.getUint32(0, Endian.little);
  final sign = (x >>> 16) & 0x8000;
  var exp = (x >>> 23) & 0xFF;
  var mant = x & 0x7FFFFF;
  if (exp == 0xFF) return sign | 0x7C00 | (mant != 0 ? 0x200 : 0); // inf/nan
  final e = exp - 127 + 15;
  if (e >= 0x1F) return sign | 0x7C00; // overflow -> inf
  if (e <= 0) {
    if (e < -10) return sign; // underflow -> 0
    mant |= 0x800000;
    final shift = 14 - e;
    final half = mant >>> shift;
    final rem = mant & ((1 << shift) - 1);
    final round = (rem > (1 << (shift - 1))) ||
        (rem == (1 << (shift - 1)) && (half & 1) == 1);
    return sign | (half + (round ? 1 : 0));
  }
  final half = (e << 10) | (mant >>> 13);
  final rem = mant & 0x1FFF;
  final round = rem > 0x1000 || (rem == 0x1000 && (half & 1) == 1);
  return sign | (half + (round ? 1 : 0));
}
