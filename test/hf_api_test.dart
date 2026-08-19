import 'dart:io';

import 'package:cmf_mobile/data/services/hf_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a starved range is finished sequentially, not thrown away', () async {
    // One worker stalls after a few bytes and burns its outage window while
    // the other completes. The transfer must survive that: the leftover is
    // fetched afterwards, resuming at the byte it stopped on rather than
    // rewriting the range from its start.
    final data = List<int>.generate(24, (i) => i);
    var starved = false;
    final ranges = <String>[];
    final api = HfApi(
      // Give up on the first stall instead of retrying for five minutes.
      outageWindow: Duration.zero,
      client: MockClient((request) async {
        final range = request.headers['range'];
        if (range == 'bytes=0-0') {
          return http.Response.bytes([data.first], 206);
        }
        ranges.add(range!);
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range);
        final start = int.parse(match!.group(1)!);
        final end = int.parse(match.group(2)!);
        if (start == 12 && !starved) {
          starved = true;
          // Three bytes, then the socket goes quiet.
          return http.Response.bytes(data.sublist(12, 15), 206);
        }
        return http.Response.bytes(data.sublist(start, end + 1), 206);
      }),
    );
    final dir = await Directory.systemTemp.createTemp('cmf-starved-test');
    final output = '${dir.path}/model.cmf';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel(
      'owner/repo',
      'model.cmf',
      output,
      totalSize: data.length,
      parallelism: 2,
    );

    expect(await File(output).readAsBytes(), data,
        reason: 'resumed bytes must land at the offset they stopped on');
    expect(ranges, contains('bytes=15-23'),
        reason: 'the leftover is resumed, not restarted from 12');
  });

  test('parallel download joins byte ranges in order', () async {
    final data = List<int>.generate(24, (i) => i);
    final ranges = <String>[];
    final api = HfApi(
      client: MockClient((request) async {
        final range = request.headers['range'];
        ranges.add(range ?? 'single');
        if (range == 'bytes=0-0') {
          return http.Response.bytes([data.first], 206);
        }
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range!);
        final start = int.parse(match!.group(1)!);
        final end = int.parse(match.group(2)!);
        return http.Response.bytes(data.sublist(start, end + 1), 206);
      }),
    );
    final dir = await Directory.systemTemp.createTemp('cmf-parallel-test');
    final output = '${dir.path}/model.cmf';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel(
      'owner/repo',
      'model.cmf',
      output,
      totalSize: data.length,
      parallelism: 4,
    );

    expect(await File(output).readAsBytes(), data);
    expect(
      ranges,
      containsAll(['bytes=0-5', 'bytes=6-11', 'bytes=12-17', 'bytes=18-23']),
    );
  });

  test('falls back to a single stream when ranges are unsupported', () async {
    final data = List<int>.generate(12, (i) => 20 + i);
    var requests = 0;
    final api = HfApi(
      client: MockClient((request) async {
        requests++;
        if (request.headers.containsKey('range')) {
          return http.Response.bytes(data, 200);
        }
        return http.Response.bytes(data, 200);
      }),
    );
    final dir = await Directory.systemTemp.createTemp('cmf-fallback-test');
    final output = '${dir.path}/model.cmf';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel(
      'owner/repo',
      'model.cmf',
      output,
      totalSize: data.length,
      parallelism: 4,
    );

    expect(await File(output).readAsBytes(), data);
    expect(requests, 2);
  });

  test('resumes an interrupted range from its last byte', () async {
    final data = List<int>.generate(12, (i) => 40 + i);
    final ranges = <String>[];
    var interrupted = false;
    final api = HfApi(
      client: MockClient((request) async {
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
      }),
    );
    final dir = await Directory.systemTemp.createTemp('cmf-resume-test');
    final output = '${dir.path}/model.safetensors';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel(
      'owner/repo',
      'model.safetensors',
      output,
      totalSize: data.length,
      parallelism: 2,
    );

    expect(await File(output).readAsBytes(), data);
    expect(ranges, contains('bytes=3-5'));
  });

  test('keeps retrying after progress despite repeated DNS failures', () async {
    final data = List<int>.generate(12, (i) => 70 + i);
    var dnsFailures = 0;
    final ranges = <String>[];
    final api = HfApi(
      client: MockClient((request) async {
        final range = request.headers['range']!;
        ranges.add(range);
        if (range == 'bytes=0-0') {
          return http.Response.bytes([data.first], 206);
        }
        if (range == 'bytes=0-5') {
          return http.Response.bytes(data.sublist(0, 3), 206);
        }
        if (range == 'bytes=3-5' && dnsFailures < 3) {
          dnsFailures++;
          throw const SocketException('temporary DNS failure');
        }
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
        final start = int.parse(match.group(1)!);
        final end = int.parse(match.group(2)!);
        return http.Response.bytes(data.sublist(start, end + 1), 206);
      }),
    );
    final dir = await Directory.systemTemp.createTemp('cmf-dns-retry-test');
    final output = '${dir.path}/model.safetensors';
    addTearDown(() => dir.delete(recursive: true));

    await api.downloadParallel(
      'owner/repo',
      'model.safetensors',
      output,
      totalSize: data.length,
      parallelism: 2,
    );

    expect(await File(output).readAsBytes(), data);
    expect(dnsFailures, 3);
    expect(ranges.where((r) => r == 'bytes=3-5'), hasLength(4));
  });
}
