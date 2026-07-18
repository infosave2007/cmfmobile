import 'dart:io';

import 'package:cmf_mobile/data/services/hf_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parallel download joins byte ranges in order', () async {
    final data = List<int>.generate(24, (i) => i);
    final ranges = <String>[];
    final api = HfApi(client: MockClient((request) async {
      final range = request.headers['range'];
      ranges.add(range ?? 'single');
      if (range == 'bytes=0-0') {
        return http.Response.bytes([data.first], 206);
      }
      final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range!);
      final start = int.parse(match!.group(1)!);
      final end = int.parse(match.group(2)!);
      return http.Response.bytes(data.sublist(start, end + 1), 206);
    }));
    final dir = await Directory.systemTemp.createTemp('cmf-parallel-test');
    final output = '${dir.path}/model.cmf';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel('owner/repo', 'model.cmf', output,
        totalSize: data.length, parallelism: 4);

    expect(await File(output).readAsBytes(), data);
    expect(ranges, containsAll([
      'bytes=0-5',
      'bytes=6-11',
      'bytes=12-17',
      'bytes=18-23',
    ]));
  });

  test('falls back to a single stream when ranges are unsupported', () async {
    final data = List<int>.generate(12, (i) => 20 + i);
    var requests = 0;
    final api = HfApi(client: MockClient((request) async {
      requests++;
      if (request.headers.containsKey('range')) {
        return http.Response.bytes(data, 200);
      }
      return http.Response.bytes(data, 200);
    }));
    final dir = await Directory.systemTemp.createTemp('cmf-fallback-test');
    final output = '${dir.path}/model.cmf';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel('owner/repo', 'model.cmf', output,
        totalSize: data.length, parallelism: 4);

    expect(await File(output).readAsBytes(), data);
    expect(requests, 2);
  });

  test('resumes an interrupted range from its last byte', () async {
    final data = List<int>.generate(12, (i) => 40 + i);
    final ranges = <String>[];
    var interrupted = false;
    final api = HfApi(client: MockClient((request) async {
      final range = request.headers['range']!;
      ranges.add(range);
      if (range == 'bytes=0-0') {
        return http.Response.bytes([data.first], 206);
      }
      final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
      final start = int.parse(match.group(1)!);
      final end = int.parse(match.group(2)!);
      if (range == 'bytes=0-5' && !interrupted) {
        interrupted = true;
        return http.Response.bytes(data.sublist(0, 3), 206);
      }
      return http.Response.bytes(data.sublist(start, end + 1), 206);
    }));
    final dir = await Directory.systemTemp.createTemp('cmf-resume-test');
    final output = '${dir.path}/model.safetensors';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel('owner/repo', 'model.safetensors', output,
        totalSize: data.length, parallelism: 2);

    expect(await File(output).readAsBytes(), data);
    expect(ranges, contains('bytes=3-5'));
  });
}
