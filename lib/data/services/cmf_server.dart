import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../models/chat.dart';
import '../models/server.dart';
import 'inference/inference_engine.dart';

/// The CMF protocol server running on the phone.
///
/// Implements the same HTTP surface as `cortiq serve` (cmfpublic):
///   POST /v1/chat/completions   (JSON + SSE streaming)
///   POST /v1/completions
///   GET  /v1/models
///   GET  /v1/cortiq/status
///   GET  /v1/cortiq/masks
///   POST /v1/cortiq/switch
///   GET  /healthz
///
/// Mobile addition: optional Bearer-token auth (the desktop server is
/// local-first and unauthenticated; a phone on Wi-Fi should be able to
/// require a token).
class CmfServer {
  CmfServer({required this.engine});

  final InferenceEngine engine;

  HttpServer? _http;
  DateTime? _startedAt;
  String _activeTask = 'general';
  int _tokensGenerated = 0;

  // Decodes are serialized, like `cortiq serve --slots 1`.
  Future<void> _decodeQueue = Future.value();

  final ServerStats stats = ServerStats();
  final List<ServerRequestRecord> requestLog = [];
  final _logController = StreamController<ServerRequestRecord>.broadcast();

  Stream<ServerRequestRecord> get onRequest => _logController.stream;
  bool get isRunning => _http != null;
  int? get port => _http?.port;
  DateTime? get startedAt => _startedAt;

  String? authToken; // null/empty = no auth

  Future<void> start({required int port, String? token}) async {
    if (_http != null) return;
    authToken = (token == null || token.isEmpty) ? null : token;
    _http = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _startedAt = DateTime.now();
    _tokensGenerated = 0;
    _http!.listen(_dispatch, onError: (_) {});
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    _http = null;
    _startedAt = null;
  }

  /// LAN URLs clients can use (Wi-Fi IP first, then any other interface).
  Future<List<String>> serverUrls() async {
    final p = port;
    if (p == null) return const [];
    final urls = <String>[];
    final wifi = await NetworkInfo().getWifiIP();
    if (wifi != null && wifi.isNotEmpty) urls.add('http://$wifi:$p');
    for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false)) {
      for (final addr in iface.addresses) {
        final url = 'http://${addr.address}:$p';
        if (!urls.contains(url)) urls.add(url);
      }
    }
    return urls;
  }

  Future<void> _dispatch(HttpRequest req) async {
    final sw = Stopwatch()..start();
    var status = HttpStatus.ok;
    var promptTokens = 0, completionTokens = 0;
    try {
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      req.response.headers
          .set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      if (req.method == 'OPTIONS') {
        req.response.statusCode = HttpStatus.noContent;
        await req.response.close();
        return;
      }

      final path = req.uri.path;
      if (authToken != null && path != '/healthz') {
        final auth = req.headers.value(HttpHeaders.authorizationHeader);
        if (auth != 'Bearer $authToken') {
          status = HttpStatus.unauthorized;
          await _json(req, status, {
            'error': {'message': 'invalid or missing bearer token'}
          });
          return;
        }
      }

      switch ((req.method, path)) {
        case ('GET', '/healthz'):
          await _json(req, 200, {'status': 'ok'});
        case ('GET', '/v1/models'):
          await _handleModels(req);
        case ('GET', '/v1/cortiq/status'):
          await _handleStatus(req);
        case ('GET', '/v1/cortiq/masks'):
          await _handleMasks(req);
        case ('POST', '/v1/cortiq/switch'):
          await _handleSwitch(req);
        case ('POST', '/v1/chat/completions'):
          final usage = await _handleChat(req, chatMode: true);
          promptTokens = usage.$1;
          completionTokens = usage.$2;
        case ('POST', '/v1/completions'):
          final usage = await _handleChat(req, chatMode: false);
          promptTokens = usage.$1;
          completionTokens = usage.$2;
        default:
          status = HttpStatus.notFound;
          await _json(req, status, {
            'error': {'message': 'not found: ${req.method} $path'}
          });
      }
    } catch (e) {
      status = HttpStatus.internalServerError;
      try {
        await _json(req, status, {
          'error': {'message': e.toString()}
        });
      } catch (_) {}
    } finally {
      sw.stop();
      stats.requests++;
      if (status >= 400) stats.errors++;
      final record = ServerRequestRecord(
        timestamp: DateTime.now(),
        method: req.method,
        path: req.uri.path,
        statusCode: status,
        latencyMs: sw.elapsedMilliseconds,
        remote: req.connectionInfo?.remoteAddress.address ?? '',
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
      requestLog.insert(0, record);
      if (requestLog.length > 100) requestLog.removeLast();
      _logController.add(record);
    }
  }

  Future<void> _json(HttpRequest req, int status, Object body) async {
    req.response.statusCode = status;
    req.response.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> _handleModels(HttpRequest req) async {
    final model = engine.loadedModel;
    await _json(req, 200, {
      'object': 'list',
      'data': [
        if (model != null)
          {
            'id': model.id,
            'object': 'model',
            'created': model.modifiedAt.millisecondsSinceEpoch ~/ 1000,
            'owned_by': 'cortiq',
          }
      ],
    });
  }

  Future<void> _handleStatus(HttpRequest req) async {
    final uptime = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    await _json(req, 200, {
      'active_task': _activeTask,
      'active_sparsity': 0.0,
      'active_layers': engine.loadedModel?.meta?.numLayers ?? 0,
      'execution_mode': 'Mobile { engine: ${engine.name} }',
      'tokens_generated': _tokensGenerated,
      'avg_tokens_per_sec':
          double.parse(stats.tokensPerSecondEma.toStringAsFixed(1)),
      'uptime_seconds': uptime,
    });
  }

  Future<void> _handleMasks(HttpRequest req) async {
    final meta = engine.loadedModel?.meta;
    final tasks = meta?.tasks ?? const <String>[];
    await _json(req, 200, {
      'masks': [
        {
          'task_id': 0,
          'name': 'general',
          'sparsity': 0.0,
          'quality_score': null,
          'quality_metric': null,
          'active_layers': meta?.numLayers ?? 0,
          'active_neurons_avg': 0.0,
          'has_hot_pack': false,
        },
        for (var i = 0; i < tasks.length; i++)
          if (tasks[i] != 'general')
            {
              'task_id': i + 1,
              'name': tasks[i],
              'sparsity': null,
              'quality_score': null,
              'quality_metric': null,
              'active_layers': meta?.numLayers ?? 0,
              'active_neurons_avg': null,
              'has_hot_pack': false,
            },
      ],
    });
  }

  Future<void> _handleSwitch(HttpRequest req) async {
    final body = jsonDecode(await utf8.decodeStream(req)) as Map;
    final task = body['task'] as String?;
    if (task == null || task.isEmpty) {
      await _json(req, 400, {
        'error': {'message': 'missing "task"'}
      });
      return;
    }
    _activeTask = task;
    await _json(req, 200, {'ok': true, 'task': task});
  }

  /// Returns (promptTokens, completionTokens) for the request log.
  Future<(int, int)> _handleChat(HttpRequest req,
      {required bool chatMode}) async {
    final model = engine.loadedModel;
    if (model == null) {
      await _json(req, 503, {
        'error': {'message': 'no model loaded on device'}
      });
      return (0, 0);
    }
    final body =
        jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;

    final messages = <ChatMessage>[];
    if (chatMode) {
      for (final raw in (body['messages'] as List? ?? const [])) {
        final m = raw as Map<String, dynamic>;
        final content = m['content'];
        messages.add(ChatMessage(
          role: ChatRole.values.asNameMap()[m['role']] ?? ChatRole.user,
          content: content is String
              ? content
              : (content as List?)
                      ?.whereType<Map>()
                      .map((p) => p['text'] as String? ?? '')
                      .join('\n') ??
                  '',
        ));
      }
    } else {
      messages.add(ChatMessage(
        role: ChatRole.user,
        content: body['prompt'] as String? ?? '',
      ));
    }

    final task = (body['cortiq'] as Map?)?['task'] as String? ?? _activeTask;
    final request = GenerationRequest(
      messages: messages,
      temperature: (body['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (body['top_p'] as num?)?.toDouble() ?? 0.95,
      maxTokens: body['max_tokens'] as int? ?? 1024,
      task: task == 'general' ? null : task,
    );
    final stream = body['stream'] as bool? ?? false;
    final id = 'cmf-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Serialize decodes: chain onto the queue and await our own turn.
    final completer = Completer<(int, int)>();
    _decodeQueue = _decodeQueue.then((_) async {
      try {
        completer.complete(stream
            ? await _streamResponse(req, request, id, created, chatMode)
            : await _fullResponse(req, request, id, created, chatMode));
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<(int, int)> _fullResponse(HttpRequest req, GenerationRequest request,
      String id, int created, bool chatMode) async {
    final buffer = StringBuffer();
    GenerationStats? stats0;
    await for (final ev in engine.generate(request)) {
      buffer.write(ev.delta);
      if (ev.done) stats0 = ev.stats;
    }
    final s = stats0 ??
        const GenerationStats(
            promptTokens: 0,
            completionTokens: 0,
            tokensPerSecond: 0,
            latencyMs: 0);
    _recordUsage(s);
    await _json(req, 200, {
      'id': id,
      'object': chatMode ? 'chat.completion' : 'text_completion',
      'created': created,
      'model': engine.loadedModel?.id ?? 'cmf',
      'choices': [
        {
          'index': 0,
          if (chatMode)
            'message': {'role': 'assistant', 'content': buffer.toString()}
          else
            'text': buffer.toString(),
          'finish_reason': s.finishReason ?? 'stop',
        }
      ],
      'usage': {
        'prompt_tokens': s.promptTokens,
        'completion_tokens': s.completionTokens,
        'total_tokens': s.totalTokens,
      },
      'cortiq': {
        'task_used': s.taskUsed ?? 'general',
        'execution_mode': 'Mobile { engine: ${engine.name} }',
        'tokens_per_second': double.parse(s.tokensPerSecond.toStringAsFixed(1)),
      },
    });
    return (s.promptTokens, s.completionTokens);
  }

  Future<(int, int)> _streamResponse(HttpRequest req,
      GenerationRequest request, String id, int created, bool chatMode) async {
    req.response.headers.contentType =
        ContentType('text', 'event-stream', charset: 'utf-8');
    req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    req.response.headers.set('Connection', 'keep-alive');

    void sse(Map<String, dynamic> chunk) {
      req.response.write('data: ${jsonEncode(chunk)}\n\n');
    }

    Map<String, dynamic> chunk(Map<String, dynamic> delta, String? finish) => {
          'id': id,
          'object': chatMode ? 'chat.completion.chunk' : 'text_completion',
          'created': created,
          'model': engine.loadedModel?.id ?? 'cmf',
          'choices': [
            {
              'index': 0,
              if (chatMode) 'delta': delta else 'text': delta['content'] ?? '',
              'finish_reason': finish,
            }
          ],
        };

    if (chatMode) sse(chunk({'role': 'assistant'}, null));
    GenerationStats? stats0;
    await for (final ev in engine.generate(request)) {
      if (ev.done) {
        stats0 = ev.stats;
        break;
      }
      if (ev.delta.isNotEmpty) {
        sse(chunk({'content': ev.delta}, null));
        await req.response.flush();
      }
    }
    final s = stats0 ??
        const GenerationStats(
            promptTokens: 0,
            completionTokens: 0,
            tokensPerSecond: 0,
            latencyMs: 0);
    _recordUsage(s);
    final finalChunk = chunk({'content': null}, s.finishReason ?? 'stop');
    finalChunk['usage'] = {
      'prompt_tokens': s.promptTokens,
      'completion_tokens': s.completionTokens,
      'total_tokens': s.totalTokens,
    };
    sse(finalChunk);
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
    return (s.promptTokens, s.completionTokens);
  }

  void _recordUsage(GenerationStats s) {
    _tokensGenerated += s.completionTokens;
    stats.recordGeneration(
        s.promptTokens, s.completionTokens, s.tokensPerSecond);
  }

  void dispose() {
    stop();
    _logController.close();
  }
}
