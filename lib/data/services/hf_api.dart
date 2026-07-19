import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/conversion.dart';

/// HuggingFace Hub API client (same endpoints as cortiq-gateway's importer).
class HfApi {
  HfApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://huggingface.co';

  Map<String, String> _headers(String? token) => {
    'User-Agent': 'cmf-mobile',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // Mobile networks drop constantly (Wi-Fi↔cellular handoff, tunnels, sleep).
  // A multi-GB download must survive minutes of DNS/socket failure and a dead
  // socket that never closes — so every transfer retries transient errors
  // within an outage window, resuming from the last byte, and bails out of a
  // silent stall via an idle timeout rather than hanging forever.

  /// No bytes for this long on a live stream ⇒ the socket is dead; retry.
  static const _idleTimeout = Duration(seconds: 30);

  /// Establishing the connection (DNS + TLS + response headers) may hang.
  static const _connectTimeout = Duration(seconds: 30);

  /// Keep retrying transient failures until this much time has passed with
  /// *no* forward progress. Any received byte resets the clock, so a slow but
  /// alive link never trips it; a genuine outage longer than this gives up.
  static const _outageWindow = Duration(minutes: 5);

  /// Permanent failures — retrying cannot help, so surface them immediately.
  /// Everything else (host lookup, connection reset, TLS, timeout, early EOF,
  /// 5xx, 429) is treated as transient and retried.
  static bool _isFatal(Object e) {
    if (e is! HttpException) return false;
    final m = e.message;
    for (final code in const ['401', '403', '404', '410', '451']) {
      if (m.contains('HTTP $code') || m.contains('got $code')) return true;
    }
    return false;
  }

  /// Exponential backoff capped at 20 s: 0.5, 1, 2, 4, 8, 16, 20, 20 …
  static Duration _backoff(int attempt) => Duration(
    milliseconds: (500 * math.pow(2, attempt.clamp(0, 6)))
        .clamp(500, 20000)
        .toInt(),
  );

  Future<http.StreamedResponse> _send(http.Request req) =>
      _client.send(req).timeout(_connectTimeout);

  /// GET /api/models?search=...&sort=trendingScore|downloads&direction=-1
  Future<List<HfModel>> search(
    String query, {
    int limit = 24,
    String? token,
  }) async {
    final sort = query.trim().isEmpty ? 'trendingScore' : 'downloads';
    final uri = Uri.parse('$_base/api/models').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
        'sort': sort,
        'direction': '-1',
        'limit': '${limit.clamp(1, 50)}',
        'full': 'false',
      },
    );
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
    return HfModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
        .map(
          (e) => HfFileEntry(
            path: e['path'] as String,
            size: e['size'] as int? ?? 0,
          ),
        )
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
    final file = File(destPath);
    await file.parent.create(recursive: true);
    final out = await file.open(mode: FileMode.write);
    var received = 0;
    var total = 0;
    var lastProgress = DateTime.now();
    var attempt = 0;
    try {
      while (true) {
        if (isCancelled?.call() == true) throw const CancelledException();
        try {
          final req = http.Request('GET', uri)
            ..headers.addAll(_headers(token));
          // Resume where we stopped; a fresh start needs no Range.
          if (received > 0) req.headers['Range'] = 'bytes=$received-';
          final res = await _send(req);
          if (received > 0 && res.statusCode == 200) {
            // Server ignored the Range — restart from the top.
            received = 0;
            await out.setPosition(0);
            await out.truncate(0);
          } else if (received > 0 && res.statusCode != 206) {
            throw HttpException('download $path: HTTP ${res.statusCode}');
          } else if (received == 0 && res.statusCode != 200) {
            throw HttpException('download $path: HTTP ${res.statusCode}');
          }
          final body = res.contentLength ?? 0;
          total =
              math.max(total, res.statusCode == 206 ? received + body : body);
          await out.setPosition(received);
          await for (final chunk in res.stream.timeout(_idleTimeout)) {
            if (isCancelled?.call() == true) throw const CancelledException();
            await out.writeFrom(chunk);
            received += chunk.length;
            lastProgress = DateTime.now();
            onBytes?.call(received, total);
          }
          await out.flush();
          return;
        } catch (e) {
          if (e is CancelledException) rethrow;
          if (_isFatal(e) ||
              DateTime.now().difference(lastProgress) > _outageWindow) {
            throw HttpException('download $path failed: $e');
          }
          await Future<void>.delayed(_backoff(attempt++));
        }
      }
    } finally {
      await out.close();
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
    if (workers < 2 || !await _supportsRanges(repo, path, token: token)) {
      return download(
        repo,
        path,
        destPath,
        token: token,
        onBytes: onBytes,
        isCancelled: isCancelled,
      );
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
        var lastProgress = DateTime.now();
        var attempt = 0;
        while (received[index] < expected) {
          if (aborted || isCancelled?.call() == true) {
            throw const CancelledException();
          }
          final rangeStart = start + received[index];
          if (rangeStart > end) break;
          final req = http.Request('GET', uri)
            ..headers.addAll(_headers(token))
            ..headers['Range'] = 'bytes=$rangeStart-$end';
          try {
            final res = await _send(req);
            if (res.statusCode != 206) {
              throw HttpException(
                'parallel download $path: expected HTTP 206, got '
                '${res.statusCode}',
              );
            }
            final contentRange = res.headers['content-range'];
            if (contentRange != null) {
              final match = RegExp(
                r'^bytes (\d+)-(\d+)/(?:\d+|\*)$',
              ).firstMatch(contentRange);
              final responseStart = match == null
                  ? null
                  : int.tryParse(match.group(1)!);
              final responseEnd = match == null
                  ? null
                  : int.tryParse(match.group(2)!);
              if (responseStart != rangeStart ||
                  responseEnd == null ||
                  responseEnd < responseStart! ||
                  responseEnd > end) {
                throw HttpException(
                  'parallel download $path: invalid Content-Range '
                  '$contentRange for bytes=$rangeStart-$end',
                );
              }
            }
            await for (final chunk in res.stream.timeout(_idleTimeout)) {
              if (aborted || isCancelled?.call() == true) {
                throw const CancelledException();
              }
              final remaining = expected - received[index];
              if (remaining <= 0) break;
              final bytes = chunk.length <= remaining
                  ? chunk
                  : chunk.sublist(0, remaining);
              final offset = writeOffset;
              writeOffset += bytes.length;
              // RandomAccessFile has one shared cursor. Serialize only the
              // short disk writes; HTTP streams remain concurrent.
              writeTail = writeTail.then((_) async {
                await out.setPosition(offset);
                await out.writeFrom(bytes);
              });
              await writeTail;
              received[index] += bytes.length;
              // Any received byte proves the link is alive: reset the outage
              // clock and the backoff so recovery is instant.
              lastProgress = DateTime.now();
              attempt = 0;
              onBytes?.call(received.fold(0, (a, b) => a + b), totalSize);
              if (received[index] == expected) break;
            }
            if (received[index] == expected) break;
            throw HttpException('range $rangeStart-$end ended early');
          } catch (e) {
            if (e is CancelledException) rethrow;
            lastError = e;
            // A multi-GB range may need many connections across minutes of
            // flaky signal. Keep resuming from the next byte until an outage
            // outlasts the window, or the error is permanent.
            if (_isFatal(e) ||
                DateTime.now().difference(lastProgress) > _outageWindow) {
              break;
            }
            await Future<void>.delayed(_backoff(attempt++));
            if (aborted || isCancelled?.call() == true) {
              throw const CancelledException();
            }
          }
        }
        if (received[index] != expected) {
          throw HttpException(
            'parallel download $path: range $start-$end '
            'returned ${received[index]} bytes, expected $expected '
            '(last error: $lastError)',
          );
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

  Future<bool> _supportsRanges(
    String repo,
    String path, {
    String? token,
  }) async {
    final uri = Uri.parse('$_base/$repo/resolve/main/$path');
    // A transient DNS/socket blip during the probe must not silently demote
    // the transfer to a single connection — retry the probe a few times.
    for (var attempt = 0; ; attempt++) {
      final req = http.Request('GET', uri)
        ..headers.addAll(_headers(token))
        ..headers['Range'] = 'bytes=0-0';
      try {
        final res = await _send(req);
        // Do not drain a server that ignored Range: for a multi-GB CMF that
        // would accidentally perform the entire download as the capability
        // probe. Cancelling here also frees the probe connection immediately.
        final subscription = res.stream.listen(null);
        await subscription.cancel();
        return res.statusCode == 206;
      } catch (_) {
        if (attempt >= 3) return false;
        await Future<void>.delayed(_backoff(attempt));
      }
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
