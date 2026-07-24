import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal safetensors reader: 8-byte LE header length, JSON header with
/// {name: {dtype, shape, data_offsets: [begin, end]}}, then raw data.
class SafetensorsFile {
  SafetensorsFile._(this.path, this.tensors, this.dataStart);

  final String path;
  final List<SafetensorEntry> tensors;
  final int dataStart;

  static Future<SafetensorsFile> open(String path) async {
    final raf = await File(path).open();
    try {
      final head = Uint8List.fromList(await raf.read(8));
      final headerLen =
          ByteData.sublistView(head).getUint64(0, Endian.little);
      if (headerLen <= 0 || headerLen > 256 * 1024 * 1024) {
        throw const FormatException('bad safetensors header length');
      }
      final headerJson = utf8.decode(await raf.read(headerLen));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      final tensors = <SafetensorEntry>[];
      header.forEach((name, value) {
        if (name == '__metadata__') return;
        final m = value as Map<String, dynamic>;
        final offsets = (m['data_offsets'] as List).cast<int>();
        tensors.add(SafetensorEntry(
          name: name,
          dtype: m['dtype'] as String,
          shape: (m['shape'] as List).cast<int>(),
          begin: offsets[0],
          end: offsets[1],
        ));
      });
      tensors.sort((a, b) => a.begin.compareTo(b.begin));

      // Integrity: a resumed/interrupted download can produce a file whose
      // header parses fine but whose data section is short. Catch it here,
      // before hours of quantization run on garbage.
      final dataLen = await raf.length() - (8 + headerLen);
      var maxEnd = 0;
      for (final t in tensors) {
        if (t.begin < 0 || t.end < t.begin) {
          throw FormatException(
              'tensor ${t.name}: invalid data_offsets [${t.begin}, ${t.end}]');
        }
        if (t.isFloat && t.nbytes != t.numel * t.bytesPerElement) {
          throw FormatException(
              'tensor ${t.name}: ${t.nbytes} bytes does not match '
              'shape ${t.shape} × ${t.bytesPerElement}B (${t.dtype})');
        }
        if (t.end > maxEnd) maxEnd = t.end;
      }
      if (maxEnd > dataLen) {
        throw FormatException(
            'truncated safetensors: tensors need $maxEnd data bytes, '
            'file has $dataLen — re-download the shard');
      }
      return SafetensorsFile._(path, tensors, 8 + headerLen);
    } finally {
      await raf.close();
    }
  }
}

class SafetensorEntry {
  const SafetensorEntry({
    required this.name,
    required this.dtype,
    required this.shape,
    required this.begin,
    required this.end,
  });

  final String name;
  final String dtype; // "F32" | "F16" | "BF16" | ...
  final List<int> shape;
  final int begin, end; // relative to data start

  int get nbytes => end - begin;
  int get numel => shape.isEmpty ? 1 : shape.reduce((a, b) => a * b);
  bool get isFloat => dtype == 'F32' || dtype == 'F16' || dtype == 'BF16';
  int get bytesPerElement => switch (dtype) {
        'F32' || 'I32' || 'U32' => 4,
        'F16' || 'BF16' || 'I16' || 'U16' => 2,
        'F64' || 'I64' || 'U64' => 8,
        _ => 1,
      };
}

/// IEEE 754 half bits -> double.
double f16BitsToDouble(int h) {
  final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
  final exp = (h >>> 10) & 0x1F;
  final mant = h & 0x3FF;
  if (exp == 0) {
    return sign * mant * 5.960464477539063e-8; // 2^-24
  }
  if (exp == 0x1F) {
    return mant == 0 ? sign * double.infinity : double.nan;
  }
  final d = ByteData(4)
    ..setUint32(
        0,
        ((h & 0x8000) << 16) |
            (((exp - 15 + 127) & 0xFF) << 23) |
            (mant << 13),
        Endian.little);
  return d.getFloat32(0, Endian.little);
}

/// Decodes a slab of raw safetensors floats into f32 values.
Float32List decodeFloats(Uint8List raw, String dtype) {
  switch (dtype) {
    case 'F32':
      return Float32List.sublistView(raw);
    case 'F16':
      {
        final u16 = Uint16List.sublistView(raw);
        final out = Float32List(u16.length);
        for (var i = 0; i < u16.length; i++) {
          out[i] = f16BitsToDouble(u16[i]);
        }
        return out;
      }
    case 'BF16':
      {
        final u16 = Uint16List.sublistView(raw);
        final out = Float32List(u16.length);
        final scratch = ByteData(4);
        for (var i = 0; i < u16.length; i++) {
          scratch.setUint32(0, u16[i] << 16, Endian.little);
          out[i] = scratch.getFloat32(0, Endian.little);
        }
        return out;
      }
    default:
      throw FormatException('unsupported dtype $dtype');
  }
}
