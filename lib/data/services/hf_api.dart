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
