import 'dart:io';
import 'dart:typed_data';

import 'package:cmf_mobile/data/services/cmf_format.dart';
import 'package:cmf_mobile/data/services/safetensors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('skill declaration in the header', () {
    test('a skill header names its skills', () {
      // Shape taken from infosave/Nanbeige4.2-3Bcmf, experiments/
      // nanbeige42-code.skill.cmf — the file the catalog used to offer as if
      // it were a model.
      final header = <String, dynamic>{
        'version': 2,
        'format': 'cmf',
        'arch': {'arch_name': 'nanbeige', 'num_layers': 22},
        'skills': [
          {
            'id': 'code',
            'name': 'Coding specialist (Python/JS/systems)',
            'base_arch': 'nanbeige',
            'task': 'specialist',
          }
        ],
      };
      expect(cmfHeaderSkills(header), ['Coding specialist (Python/JS/systems)']);
    });

    test('a model header declares none', () {
      // A skill carries the base model's full arch, so arch cannot separate
      // them; only the declaration can.
      final header = <String, dynamic>{
        'version': 2,
        'format': 'cmf',
        'arch': {'arch_name': 'nanbeige', 'num_layers': 22},
        'quant_type': 'q4tp',
      };
      expect(cmfHeaderSkills(header), isEmpty);
    });

    test('falls back to the id when a skill has no name', () {
      final header = <String, dynamic>{
        'skills': [
          {'id': 'gfx'}
        ],
      };
      expect(cmfHeaderSkills(header), ['gfx']);
    });

    test('a malformed skills value is not a skill', () {
      expect(cmfHeaderSkills(<String, dynamic>{'skills': 'code'}), isEmpty);
      expect(cmfHeaderSkills(<String, dynamic>{'skills': []}), isEmpty);
      expect(cmfHeaderSkills(<String, dynamic>{}), isEmpty);
    });
  });

  group('f16 conversion', () {
    test('round-trips common values', () {
      for (final v in [0.0, 1.0, -1.0, 0.5, 2.75, -100.25, 65504.0]) {
        final bits = f32ToF16Bits(v);
        expect(f16BitsToDouble(bits), closeTo(v, v.abs() * 1e-3 + 1e-6));
      }
    });

    test('overflows to infinity', () {
      expect(f16BitsToDouble(f32ToF16Bits(1e6)), double.infinity);
      expect(f16BitsToDouble(f32ToF16Bits(-1e6)), double.negativeInfinity);
    });
  });

  group('CmfHash64', () {
    test('is deterministic and length-sensitive', () {
      final a = CmfHash64.ofBytes(Uint8List.fromList([1, 2, 3, 4]));
      final b = CmfHash64.ofBytes(Uint8List.fromList([1, 2, 3, 4]));
      final c = CmfHash64.ofBytes(Uint8List.fromList([1, 2, 3, 4, 0]));
      expect(a, b);
      expect(a, isNot(c));
    });

    test('streams identically to one-shot', () {
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 251));
      final oneShot = CmfHash64.ofBytes(data);
      final streamed = CmfHash64()
        ..add(data.sublist(0, 3))
        ..add(data.sublist(3, 700))
        ..add(data.sublist(700));
      expect(streamed.digest(), oneShot);
    });
  });

  group('CMF write/read round-trip', () {
    test('envelope, header and directory survive a round-trip', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_test');
      final path = '${dir.path}/test.cmf';

      final spec = CmfTensorSpec(
        name: 'model.layers.0.self_attn.q_proj.weight',
        dtype: Cmf.dtF16,
        shape: [4, 8],
        nbytes: 4 * 8 * 2,
      );
      final writer = CmfWriter(
        outputPath: path,
        headerJson: {
          'format': 'cmf',
          'version': 2,
          'arch': {
            'arch_name': 'qwen2',
            'hidden_size': 8,
            'num_layers': 1,
            'num_kv_heads': 2,
            'head_dim': 4,
            'vocab_size': 100,
            'max_position_embeddings': 4096,
          },
          'quant_type': 'F16',
          'tokenizer_config': {
            'chat_template': '{{messages}}',
            'eos_token_ids': [2],
          },
        },
        tensors: [spec],
        vocabBytes: Uint8List.fromList('{"version":"1.0"}'.codeUnits),
      );
      await writer.begin();
      await writer.nextTensor();
      await writer.writeTensorChunk(Uint8List(4 * 8 * 2));
      await writer.finish();

      final meta = await CmfReader.readMetadata(path);
      expect(meta.version, 2);
      expect(meta.archName, 'qwen2');
      expect(meta.quantType, 'F16');
      expect(meta.numLayers, 1);
      expect(meta.numKvHeads, 2);
      expect(meta.headDim, 4);
      expect(meta.contextLength, 4096);
      expect(meta.tensorCount, 1);
      expect(meta.hasVocab, isTrue);
      expect(meta.hasChatTemplate, isTrue);
      expect(meta.eosTokenIds, [2]);
      expect(meta.supportsAttachments, isTrue);

      // Envelope invariants from the spec.
      final bytes = await File(path).openRead(0, 128).first;
      expect(bytes.sublist(0, 4), [0x43, 0x4D, 0x46, 0x01]);
      final env = CmfEnvelope.parse(Uint8List.fromList(bytes));
      expect(env.dataOff % 4096, 0);

      await dir.delete(recursive: true);
    });

    test('rejects non-CMF files', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_test');
      final path = '${dir.path}/bogus.cmf';
      await File(path).writeAsBytes(List.filled(256, 0x42));
      expect(() => CmfReader.readMetadata(path), throwsFormatException);
      await dir.delete(recursive: true);
    });

    test('validator accepts v0.3.12 ShortConv tensor layout', () async {
      final dir = await Directory.systemTemp.createTemp('cmf_short_conv');
      final path = '${dir.path}/short-conv.cmf';
      addTearDown(() => dir.delete(recursive: true));

      final tensors =
          [
                'model.embed_tokens.weight',
                'model.layers.0.short_conv.in_proj.weight',
                'model.layers.0.short_conv.conv.weight',
                'model.layers.0.short_conv.out_proj.weight',
              ]
              .map(
                (name) => CmfTensorSpec(
                  name: name,
                  dtype: Cmf.dtF16,
                  shape: [1],
                  nbytes: 2,
                ),
              )
              .toList();
      final writer = CmfWriter(
        outputPath: path,
        headerJson: {
          'format': 'cmf',
          'version': 2,
          'arch': {
            'arch_name': 'lfm2_moe',
            'hidden_size': 1,
            'num_layers': 1,
            'vocab_size': 1,
            'layer_types': ['ShortConv'],
            'linear_conv_kernel_dim': 3,
            'tie_word_embeddings': true,
          },
          'quant_type': 'F16',
        },
        tensors: tensors,
      );
      await writer.begin();
      for (var i = 0; i < tensors.length; i++) {
        await writer.nextTensor();
        await writer.writeTensorChunk(Uint8List(2));
      }
      await writer.finish();

      expect(await CmfValidator.validate(path), isEmpty);
    });
  });

  group('safetensors', () {
    test('parses header and offsets', () async {
      final dir = await Directory.systemTemp.createTemp('st_test');
      final path = '${dir.path}/test.safetensors';
      const headerJson =
          '{"w":{"dtype":"F32","shape":[2,2],"data_offsets":[0,16]}}';
      final header = headerJson.codeUnits;
      final bytes = BytesBuilder()
        ..add(
          (ByteData(
            8,
          )..setUint64(0, header.length, Endian.little)).buffer.asUint8List(),
        )
        ..add(header)
        ..add(List.filled(16, 0));
      await File(path).writeAsBytes(bytes.takeBytes());

      final st = await SafetensorsFile.open(path);
      expect(st.tensors, hasLength(1));
      expect(st.tensors.first.name, 'w');
      expect(st.tensors.first.numel, 4);
      expect(st.tensors.first.nbytes, 16);
      expect(st.dataStart, 8 + header.length);
      await dir.delete(recursive: true);
    });
  });
}
