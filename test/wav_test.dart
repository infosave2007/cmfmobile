import 'dart:typed_data';

import 'package:cmf_mobile/core/util/wav.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List pcm16(int frames, {int rate = 16000, int channels = 1}) {
  final dataLen = frames * 2 * channels;
  final out = Uint8List(44 + dataLen);
  final d = ByteData.sublistView(out);
  out.setRange(0, 4, 'RIFF'.codeUnits);
  d.setUint32(4, 36 + dataLen, Endian.little);
  out.setRange(8, 12, 'WAVE'.codeUnits);
  out.setRange(12, 16, 'fmt '.codeUnits);
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, channels, Endian.little);
  d.setUint32(24, rate, Endian.little);
  d.setUint32(28, rate * 2 * channels, Endian.little);
  d.setUint16(32, 2 * channels, Endian.little);
  d.setUint16(34, 16, Endian.little);
  out.setRange(36, 40, 'data'.codeUnits);
  d.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < frames * channels; i++) {
    d.setInt16(44 + i * 2, (i % 200) * 100 - 10000, Endian.little);
  }
  return out;
}

void main() {
  group('parseWav', () {
    test('reads a 16 kHz mono PCM16 header', () {
      final info = parseWav(pcm16(32000))!;
      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.frames, 32000);
      expect(info.seconds, 2.0);
      expect(info.dataOffset, 44);
    });

    test('rejects what is not a WAV', () {
      expect(parseWav(Uint8List(10)), isNull);
      expect(parseWav(Uint8List.fromList(List.filled(64, 65))), isNull);
    });

    test('skips chunks before data and tolerates a short data chunk', () {
      final base = pcm16(100);
      // Insert a LIST chunk between fmt and data.
      final list = Uint8List.fromList([
        ...'LIST'.codeUnits, 4, 0, 0, 0, 1, 2, 3, 4,
      ]);
      final withList = Uint8List.fromList([
        ...base.sublist(0, 36), ...list, ...base.sublist(36),
      ]);
      final info = parseWav(withList)!;
      expect(info.frames, 100);
      expect(info.dataOffset, 36 + 12 + 8);
      // Truncated file: the data chunk claims more than is there.
      final cut = base.sublist(0, 44 + 50);
      expect(parseWav(cut)!.frames, 25);
    });
  });

  group('padWavToSeconds', () {
    test('appends silence up to the minimum and rewrites the header', () {
      final short = pcm16(16000); // 1 s
      final padded = padWavToSeconds(short, 10);
      final info = parseWav(padded)!;
      expect(info.seconds, 10.0);
      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      // Original samples first, then zeros.
      expect(padded.sublist(44, 44 + 32000), short.sublist(44));
      expect(padded.sublist(44 + 32000).every((b) => b == 0), isTrue);
      expect(padded.length, 44 + 10 * 16000 * 2);
    });

    test('leaves a long enough clip untouched', () {
      final long = pcm16(16000 * 12);
      expect(identical(padWavToSeconds(long, 10), long), isTrue);
    });

    test('leaves other encodings alone', () {
      final stereo24 = pcm16(100, channels: 2);
      // Patch bits per sample to 24 so the padder declines.
      ByteData.sublistView(stereo24).setUint16(34, 24, Endian.little);
      expect(identical(padWavToSeconds(stereo24, 10), stereo24), isTrue);
    });
  });

  group('trimWavSilence', () {
    Uint8List withSpeech(int lead, int speech, int tail) {
      final frames = lead + speech + tail;
      final out = pcm16(frames);
      final d = ByteData.sublistView(out);
      for (var i = 0; i < frames; i++) {
        final inSpeech = i >= lead && i < lead + speech;
        // Speech: a loud square wave; silence: faint noise.
        final v = inSpeech ? ((i ~/ 40).isEven ? 9000 : -9000) : (i % 7) - 3;
        d.setInt16(44 + i * 2, v, Endian.little);
      }
      return out;
    }

    test('cuts the silence around speech, keeping a margin', () {
      // 3 s silence, 2 s speech, 6 s silence at 16 kHz.
      final src = withSpeech(48000, 32000, 96000);
      final out = trimWavSilence(src, marginSeconds: 0.4);
      final info = parseWav(out)!;
      // 2 s of speech plus 0.4 s on each side, give or take a 20 ms frame.
      expect(info.seconds, closeTo(2.8, 0.05));
      expect(out.length, 44 + info.frames * 2);
    });

    test('returns the input when there is nothing to cut', () {
      final src = withSpeech(0, 32000, 0);
      expect(identical(trimWavSilence(src), src), isTrue);
    });

    test('returns the input when it is all silence', () {
      final src = withSpeech(16000, 0, 16000);
      expect(identical(trimWavSilence(src), src), isTrue);
    });

    test('leaves float and non-16-bit files alone', () {
      final src = pcm16(1600);
      ByteData.sublistView(src).setUint16(34, 8, Endian.little);
      ByteData.sublistView(src).setUint16(32, 1, Endian.little);
      expect(identical(trimWavSilence(src), src), isTrue);
    });
  });
}
