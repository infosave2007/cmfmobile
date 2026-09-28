import 'dart:convert';
import 'dart:io';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/cmf_server.dart';
import 'package:cmf_mobile/data/services/inference/inference_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _DecisionEngine extends InferenceEngine {
  bool decision = true;
  final calls = <String>[];
  @override bool get isAvailable => true;
  @override String get name => 'decision-test';
  @override LocalModel? get loadedModel => null;
  @override bool get isDecisionModel => decision;
  @override Future<void> loadModel(LocalModel m, {int threads=0, String engineFlags=''}) async {}
  @override Future<void> unload() async {}
  @override void cancel() {}
  @override Stream<GenerationEvent> generate(GenerationRequest r) => throw StateError('must not generate');
  @override Future<Map<String,dynamic>> decisionRequest(String method,String path,[Map<String,dynamic> body=const {}]) async {
    calls.add('$method $path');
    return {'status':path.endsWith('/missing')?404:200,'body':{'oracle':false,'choice':'test','skills':[]}};
  }
}
void main() {
  late _DecisionEngine engine;
  late CmfServer server;
  late HttpClient client;
  setUp(() async { engine=_DecisionEngine(); server=CmfServer(engine:engine); await server.start(port:0, token:'phone-test'); client=HttpClient(); });
  tearDown(() async { client.close(force:true); await server.stop(); });
  Future<int> request(String method,String path,{String body='{}',String? token='phone-test'}) async {
    final req=await client.openUrl(method,Uri.parse('http://127.0.0.1:${server.port}$path'));
    if(token!=null) req.headers.set('Authorization','Bearer $token');
    if(method=='POST') {req.headers.contentType=ContentType.json;req.write(body);}
    final res=await req.close(); await res.drain<void>(); return res.statusCode;
  }
  test('decision endpoints obey authentication, do not generate', () async {
    expect(await request('POST','/v1/decide',token:null),401);
    expect(engine.calls,isEmpty);
    for(final p in ['/v1/decide','/v1/decisions','/api/alpha/decisions']) {
      expect(await request('POST',p,body:jsonEncode({'text':'test','skill':'s'})),200);
    }
    expect(await request('GET','/v1/skills'),200);
    expect(await request('GET','/v1/skills/missing'),404);
    expect(await request('POST','/v1/chat/completions'),409);
  });
  test('malformed input and wrong loaded model fail clearly', () async {
    expect(await request('POST','/v1/decide',body:'[]'),400);
    expect(await request('POST','/v1/decide',body:'{'),400);
    expect(engine.calls,isEmpty);
    engine.decision=false;
    expect(await request('POST','/v1/decide'),409);
  });
}
