import 'dart:math' as math;
import 'dart:typed_data';

/// What a RIFF/WAVE header says about its samples.
class WavInfo {
  const WavInfo({
    required this.format,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });

  /// 1 = PCM, 3 = IEEE float (after WAVE_FORMAT_EXTENSIBLE unwrapping).
  final int format;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;

  int get frameBytes => channels * (bitsPerSample ~/ 8);
  int get frames => frameBytes == 0 ? 0 : dataLength ~/ frameBytes;
  double get seconds => sampleRate == 0 ? 0 : frames / sampleRate;
}

/// Parses the fmt and data chunks of a WAV file; null when it is not one or
/// carries an encoding the engine does not read (PCM 8/16/24/32 and float
/// 32/64 are accepted, like the runtime's own reader).
WavInfo? parseWav(Uint8List bytes) {
  if (bytes.length < 44) return null;
  final d = ByteData.sublistView(bytes);
  if (String.fromCharCodes(bytes, 0, 4) != 'RIFF' ||
      String.fromCharCodes(bytes, 8, 12) != 'WAVE') {
    return null;
  }
  int format = 0, channels = 0, rate = 0, bits = 0;
  var i = 12;
  while (i + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, i, i + 4);
    final len = d.getUint32(i + 4, Endian.little);
    final start = i + 8;
    final end = (start + len).clamp(start, bytes.length);
    if (id == 'fmt ' && end >= start + 16) {
      format = d.getUint16(start, Endian.little);
      channels = d.getUint16(start + 2, Endian.little);
      rate = d.getUint32(start + 4, Endian.little);
      bits = d.getUint16(start + 14, Endian.little);
      if (format == 0xfffe && end >= start + 26) {
        format = d.getUint16(start + 24, Endian.little);
      }
    } else if (id == 'data') {
      if (channels == 0 || rate == 0) return null;
      final ok = (format == 1 && const [8, 16, 24, 32].contains(bits)) ||
          (format == 3 && const [32, 64].contains(bits));
      if (!ok) return null;
      return WavInfo(
        format: format,
        channels: channels,
        sampleRate: rate,
        bitsPerSample: bits,
        dataOffset: start,
        dataLength: end - start,
      );
    }
    i = start + len + (len & 1);
  }
  return null;
}

/// The same audio followed by digital silence up to [minSeconds] (unchanged
/// when it is already that long). A 16 kHz mono PCM16 file is rewritten
/// with a canonical 44-byte header; other layouts are left as they are.
///
/// Why: with the encoder trimmed to the audio prefix, Whisper hallucinates
/// on clips of a few seconds (it was trained on 30 s windows), and a full
/// window costs about 80 s on a phone. Speech followed by silence is what
/// the full window sees too, so this keeps the short-clip quality at a
/// fraction of the time.
Uint8List padWavToSeconds(Uint8List bytes, double minSeconds) {
  final info = parseWav(bytes);
  if (info == null || info.seconds >= minSeconds) return bytes;
  if (info.format != 1 || info.bitsPerSample != 16) return bytes;
  final wanted = (minSeconds * info.sampleRate).ceil();
  final padFrames = wanted - info.frames;
  if (padFrames <= 0) return bytes;
  // The rest of the data chunk is left zero: silence.
  return _canonicalPcm16(
    info,
    bytes,
    info.dataOffset,
    info.dataLength,
    info.dataLength + padFrames * info.frameBytes,
  );
}

/// The same audio without the silence before and after the speech, with
/// [marginSeconds] of it kept on each side. A 16-bit PCM file comes back
/// with a canonical header; other layouts, a file with no sound in it, and
/// one with nothing to cut are returned as they are.
///
/// Why: a dictation starts with the tap and ends with the next one, so a
/// note of 7 s of speech can carry 6 s of room noise after it, and on that
/// tail Whisper invents sentences and repeats them until the token bound.
/// The threshold is relative to the loudest 20 ms frame, with a floor so a
/// recording of pure noise is not cut to a single frame.
Uint8List trimWavSilence(Uint8List bytes, {double marginSeconds = 0.4}) {
  final info = parseWav(bytes);
  if (info == null || info.format != 1 || info.bitsPerSample != 16) {
    return bytes;
  }
  final d = ByteData.sublistView(bytes);
  final frames = info.frames;
  final channels = info.channels;
  final window = (info.sampleRate ~/ 50).clamp(1, frames); // 20 ms
  final windows = (frames / window).ceil();
  if (windows == 0) return bytes;
  final rms = List<double>.filled(windows, 0);
  for (var w = 0; w < windows; w++) {
    final from = w * window;
    final to = ((w + 1) * window).clamp(0, frames);
    var sum = 0.0;
    for (var f = from; f < to; f++) {
      for (var c = 0; c < channels; c++) {
        final v = d
            .getInt16(info.dataOffset + (f * channels + c) * 2, Endian.little)
            .toDouble();
        sum += v * v;
      }
    }
    final n = (to - from) * channels;
    rms[w] = n == 0 ? 0 : math.sqrt(sum / n);
  }
  final peak = rms.reduce(math.max);
  final threshold = math.max(peak * 0.06, 160.0);
  var first = rms.indexWhere((v) => v > threshold);
  var last = rms.lastIndexWhere((v) => v > threshold);
  if (first < 0 || last < 0) return bytes;
  final margin = (marginSeconds * info.sampleRate).round();
  final start = math.max(0, first * window - margin);
  final end = math.min(frames, (last + 1) * window + margin);
  if (start == 0 && end == frames) return bytes;
  final keep = (end - start) * info.frameBytes;
  return _canonicalPcm16(
    info,
    bytes,
    info.dataOffset + start * info.frameBytes,
    keep,
    keep,
  );
}

/// A canonical 44-byte PCM16 header over [dataLen] bytes, the first
/// [copyLen] of them copied from [source] at [copyFrom].
Uint8List _canonicalPcm16(
  WavInfo info,
  Uint8List source,
  int copyFrom,
  int copyLen,
  int dataLen,
) {
  final out = Uint8List(44 + dataLen);
  final d = ByteData.sublistView(out);
  void tag(int at, String s) {
    for (var k = 0; k < 4; k++) {
      out[at + k] = s.codeUnitAt(k);
    }
  }

  tag(0, 'RIFF');
  d.setUint32(4, 36 + dataLen, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, info.channels, Endian.little);
  d.setUint32(24, info.sampleRate, Endian.little);
  d.setUint32(28, info.sampleRate * info.frameBytes, Endian.little);
  d.setUint16(32, info.frameBytes, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, dataLen, Endian.little);
  out.setRange(44, 44 + copyLen, source, copyFrom);
  return out;
}
