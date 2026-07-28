import 'dart:convert';
import 'dart:io';

import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/models/cmf_metadata.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/cmf_server.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeEngine engine;
  late CmfServer server;
  late HttpClient client;

  setUp(() async {
    engine = _FakeEngine();
    server = CmfServer(engine: engine);
    await server.start(port: 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<_Response> request(String method, String path, {String? body}) async {
    final req = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(body));
    }
    final res = await req.close();
    return _Response(res.statusCode, res.headers, await utf8.decodeStream(res));
  }

  test('chat completion validates model and reports length', () async {
    final res = await request(
      'POST',
      '/v1/chat/completions',
      body: jsonEncode({
        'model': 'test-model',
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'max_tokens': 2,
      }),
    );

    expect(res.status, 200);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    expect(json['model'], 'test-model');
    expect(json['choices'][0]['message']['content'], 'OK');
    expect(json['choices'][0]['finish_reason'], 'length');
    expect(json['usage']['completion_tokens'], 2);
  });

  test('malformed JSON is a safe 400 and is counted in stats', () async {
    final res = await request('POST', '/v1/chat/completions', body: '{bad');

    expect(res.status, 400);
    final error = (jsonDecode(res.body) as Map)['error'] as Map;
    expect(error['code'], 'invalid_json');
    expect(error['message'], 'Invalid JSON in request body');
    expect(res.body, isNot(contains('FormatException')));
    expect(server.stats.errors, 1);
    expect(server.requestLog.single.statusCode, 400);
  });

  test('empty messages is a safe 400', () async {
    final res = await request(
      'POST',
      '/v1/chat/completions',
      body: jsonEncode({'model': 'test-model', 'messages': []}),
    );

    expect(res.status, 400);
    final error = (jsonDecode(res.body) as Map)['error'] as Map;
    expect(error['code'], 'invalid_messages');
    expect(error['param'], 'messages');
    expect(res.body, isNot(contains('Bad state')));
  });

  test('unknown model and task are rejected before generation', () async {
    final wrongModel = await request(
      'POST',
      '/v1/completions',
      body: jsonEncode({'model': 'missing', 'prompt': 'hello'}),
    );
    expect(wrongModel.status, 404);
    expect(
      (jsonDecode(wrongModel.body) as Map)['error']['code'],
      'model_not_found',
    );

    final wrongTask = await request(
      'POST',
      '/v1/cortiq/switch',
      body: jsonEncode({'task': 'missing'}),
    );
    expect(wrongTask.status, 400);
    expect(
      (jsonDecode(wrongTask.body) as Map)['error']['code'],
      'task_not_found',
    );
    expect(engine.calls, 0);
  });

  test('CORS preflight advertises supported methods', () async {
    final res = await request('OPTIONS', '/v1/chat/completions');

    expect(res.status, 204);
    expect(res.headers.value('access-control-allow-methods'), contains('POST'));
  });

  test('stop sequence trims output, cancels engine, finish_reason=stop',
      () async {
    engine.script = [
      'Hello ',
      'wor',
      'ld EN',
      'D tail that must not appear',
    ];
    final res = await request(
      'POST',
      '/v1/chat/completions',
      body: jsonEncode({
        'messages': [
          {'role': 'user', 'content': 'hi'},
        ],
        'stop': ['END'],
      }),
    );

    expect(res.status, 200);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    expect(json['choices'][0]['message']['content'], 'Hello world ');
    expect(json['choices'][0]['finish_reason'], 'stop');
    expect(engine.cancels, 1);
  });

  test('without a stop match the held-back tail is flushed', () async {
    engine.script = ['Hello ', 'world'];
    final res = await request(
      'POST',
      '/v1/chat/completions',
      body: jsonEncode({
        'messages': [
          {'role': 'user', 'content': 'hi'},
        ],
        'stop': 'NEVERMATCHES',
      }),
    );

    expect(res.status, 200);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    expect(json['choices'][0]['message']['content'], 'Hello world');
  });

  test('invalid stop parameter is a safe 400', () async {
    final res = await request(
      'POST',
      '/v1/chat/completions',
      body: jsonEncode({
        'messages': [
          {'role': 'user', 'content': 'hi'},
        ],
        'stop': 123,
      }),
    );

    expect(res.status, 400);
    final error = (jsonDecode(res.body) as Map)['error'] as Map;
    expect(error['param'], 'stop');
    expect(engine.calls, 0);
  });

  test(
    'internal generation errors do not leak implementation details',
    () async {
      engine.fail = true;
      final res = await request(
        'POST',
        '/v1/completions',
        body: jsonEncode({'model': 'test-model', 'prompt': 'hello'}),
      );

      expect(res.status, 500);
      final error = (jsonDecode(res.body) as Map)['error'] as Map;
      expect(error['code'], 'internal_error');
      expect(error['message'], 'Internal server error');
      expect(res.body, isNot(contains('native secret')));
    },
  );
}

class _Response {
  const _Response(this.status, this.headers, this.body);

  final int status;
  final HttpHeaders headers;
  final String body;
}

class _FakeEngine implements InferenceEngine {
  bool fail = false;
  int calls = 0;
  int cancels = 0;

  /// Deltas emitted per generation (tests override for multi-token output).
  List<String> script = const ['OK'];

  @override
  void setGpu(bool enable) {}

  @override
  bool get isAvailable => true;

  @override
  String get name => 'fake';

  @override
  LocalModel? get loadedModel => LocalModel(
    id: 'test-model',
    filePath: '/tmp/test.cmf',
    sizeBytes: 1,
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
    meta: const CmfMetadata(
      version: 2,
      archName: 'test',
      quantType: 'F16',
      numLayers: 1,
      hiddenSize: 4,
      vocabSize: 4,
      contextLength: 128,
      tensorCount: 1,
      hasVocab: true,
      hasChatTemplate: true,
      eosTokenIds: [0],
      tasks: ['code'],
      requiredFeatures: 1,
    ),
  );

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) async* {
    calls++;
    if (fail) throw StateError('native secret');
    for (final delta in script) {
      yield GenerationEvent(delta: delta);
    }
    yield const GenerationEvent(
      done: true,
      stats: GenerationStats(
        promptTokens: 1,
        completionTokens: 2,
        tokensPerSecond: 10,
        latencyMs: 1,
        finishReason: 'stop',
        taskUsed: 'general',
      ),
    );
  }

  @override
  bool? get gpuBackendAvailable => null;

  @override
  Future<void> loadModel(
    LocalModel model, {
    int threads = 0,
    String engineFlags = '',
  }) async {}

  @override
  Future<void> unload() async {}

  @override
  void cancel() => cancels++;
}
