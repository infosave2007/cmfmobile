import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/conversion.dart';

/// HuggingFace Hub API client (same endpoints as cortiq-gateway's importer).
class HfApi {
  HfApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://huggingface.co';

  Map<String, String> _headers(String? token) => {
        'User-Agent': 'cmf-mobile',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  /// GET /api/models?search=...&sort=trendingScore|downloads&direction=-1
  Future<List<HfModel>> search(String query,
      {int limit = 24, String? token}) async {
    final sort = query.trim().isEmpty ? 'trendingScore' : 'downloads';
    final uri = Uri.parse('$_base/api/models').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'sort': sort,
      'direction': '-1',
      'limit': '${limit.clamp(1, 50)}',
      'full': 'false',
    });
    final res = await _client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('HF search failed: HTTP ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((m) => HfModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/models/{repo} → one model card (used for featured models).
  Future<HfModel> fetchModel(String repo, {String? token}) async {
    final uri = Uri.parse('$_base/api/models/$repo');
    final res = await _client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('HF model failed: HTTP ${res.statusCode}');
    }
    return HfModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET /api/models/{repo}/tree/main?recursive=true → [{path, size, type}]
  Future<List<HfFileEntry>> listFiles(String repo, {String? token}) async {
    final uri = Uri.parse('$_base/api/models/$repo/tree/main?recursive=true');
    final res = await _client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('HF tree failed: HTTP ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .where((e) => e['type'] == 'file')
        .map((e) => HfFileEntry(
              path: e['path'] as String,
              size: e['size'] as int? ?? 0,
            ))
        .toList();
  }

  /// Streams {repo}/resolve/main/{path} to [destPath].
  /// [onBytes] receives cumulative received / total (total may be 0).
  Future<void> download(
    String repo,
    String path,
    String destPath, {
    String? token,
    void Function(int received, int total)? onBytes,
    bool Function()? isCancelled,
  }) async {
    final uri = Uri.parse('$_base/$repo/resolve/main/$path');
    final req = http.Request('GET', uri)..headers.addAll(_headers(token));
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw HttpException('download $path: HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? 0;
    final file = File(destPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        if (isCancelled?.call() == true) {
          throw const CancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        onBytes?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
      if (isCancelled?.call() == true) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// Downloads a large immutable Hub file through concurrent HTTP ranges.
  /// Falls back to [download] when the origin does not advertise byte ranges.
  Future<void> downloadParallel(
    String repo,
    String path,
    String destPath, {
    required int totalSize,
    int parallelism = 4,
    String? token,
    void Function(int received, int total)? onBytes,
    bool Function()? isCancelled,
  }) async {
    final requestedWorkers = parallelism.clamp(2, 8);
    final workers = totalSize < requestedWorkers ? totalSize : requestedWorkers;
    if (workers < 2 ||
        !await _supportsRanges(repo, path, token: token)) {
      return download(repo, path, destPath,
          token: token,
          onBytes: onBytes,
          isCancelled: isCancelled);
    }

    final file = File(destPath);
    await file.parent.create(recursive: true);
    final out = await file.open(mode: FileMode.write);
    await out.truncate(totalSize);

    final received = List<int>.filled(workers, 0);
    var aborted = false;
    Object? firstError;
    var writeTail = Future<void>.value();

    Future<void> fetchPart(int index) async {
      final start = totalSize * index ~/ workers;
      final end = totalSize * (index + 1) ~/ workers - 1;
      final expected = end - start + 1;
      final uri = Uri.parse('$_base/$repo/resolve/main/$path');
      var writeOffset = start;
      try {
        Object? lastError;
        for (var attempt = 1; attempt <= 3; attempt++) {
          if (aborted || isCancelled?.call() == true) {
            throw const CancelledException();
          }
          final rangeStart = start + received[index];
          if (rangeStart > end) break;
          final req = http.Request('GET', uri)
            ..headers.addAll(_headers(token))
            ..headers['Range'] = 'bytes=$rangeStart-$end';
          try {
            final res = await _client.send(req);
            if (res.statusCode != 206) {
              throw HttpException(
                  'parallel download $path: expected HTTP 206, got '
                  '${res.statusCode}');
            }
            await for (final chunk in res.stream) {
              if (aborted || isCancelled?.call() == true) {
                throw const CancelledException();
              }
              final offset = writeOffset;
              writeOffset += chunk.length;
              // RandomAccessFile has one shared cursor. Serialize only the
              // short disk writes; HTTP streams remain concurrent.
              writeTail = writeTail.then((_) async {
                await out.setPosition(offset);
                await out.writeFrom(chunk);
              });
              await writeTail;
              received[index] += chunk.length;
              onBytes?.call(
                  received.fold(0, (a, b) => a + b), totalSize);
            }
            if (received[index] == expected) break;
            throw HttpException('range $rangeStart-$end ended early');
          } catch (e) {
            if (e is CancelledException) rethrow;
            lastError = e;
            if (attempt < 3) {
              await Future<void>.delayed(
                  Duration(milliseconds: 400 * attempt));
            }
          }
        }
        if (received[index] != expected) {
          throw HttpException('parallel download $path: range $start-$end '
              'returned ${received[index]} bytes, expected $expected '
              '(last error: $lastError)');
        }
      } catch (e) {
        aborted = true;
        firstError ??= e;
      }
    }

    try {
      await Future.wait(List.generate(workers, fetchPart));
      await writeTail;
    } finally {
      await out.close();
    }
    if (firstError != null) throw firstError!;
    if (isCancelled?.call() == true) throw const CancelledException();
  }

  Future<bool> _supportsRanges(String repo, String path,
      {String? token}) async {
    final uri = Uri.parse('$_base/$repo/resolve/main/$path');
    final req = http.Request('GET', uri)
      ..headers.addAll(_headers(token))
      ..headers['Range'] = 'bytes=0-0';
    try {
      final res = await _client.send(req);
      // Do not drain a server that ignored Range: for a multi-GB CMF that
      // would accidentally perform the entire download as the capability
      // probe. Cancelling here also frees the probe connection immediately.
      final subscription = res.stream.listen(null);
      await subscription.cancel();
      return res.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  /// Fetches a small text file (config.json etc.) as a string.
  Future<String> fetchText(String repo, String path, {String? token}) async {
    final uri = Uri.parse('$_base/$repo/resolve/main/$path');
    final res = await _client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('fetch $path: HTTP ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes);
  }
}

class HfFileEntry {
  const HfFileEntry({required this.path, required this.size});
  final String path;
  final int size;
}

class CancelledException implements Exception {
  const CancelledException();
  @override
  String toString() => 'cancelled';
}
