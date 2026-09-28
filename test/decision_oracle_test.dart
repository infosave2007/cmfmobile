import 'dart:convert';
import 'package:cmf_mobile/data/services/decision_oracle.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const settings = OracleSettings(enabled:true, apiKey:'unit-test-not-a-real-key');
  const skill = {'labels':['a','b'], 'rubric':{'instructions':'Choose an option','criteria':{'a':'A','b':'B'}}};
  test('oracle disabled by default, settings require HTTPS', () {
    expect(const OracleSettings().enabled, false);
    expect(() => const OracleSettings(baseUrl:'http://example.com').validate(), throwsFormatException);
    expect(() => const OracleSettings(baseUrl:'https://user:pass@example.com').validate(), throwsFormatException);
    expect(() => const OracleSettings(baseUrl:'https://example.com?key=x').validate(), throwsFormatException);
    expect(() => const OracleSettings(enabled:true).validate(), throwsFormatException);
  });
  test('settings round trip through secure storage and delete removes key', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = OracleSettingsStore();
    expect((await store.read()).enabled,false);
    await store.save(settings);
    expect((await store.read()).apiKey,settings.apiKey);
    await store.clear();
    expect((await store.read()).apiKey,isEmpty);
  });
  test('uses rubric/schema, no redirect, validated oracle result with provenance', () async {
    var calls = 0;
    final oracle = DecisionOracle(clientFactory: () => MockClient((req) async {
      calls++;
      expect(req.url.toString(),'https://openrouter.ai/api/v1/chat/completions');
      expect(req.followRedirects,false);
      expect(req.headers['Authorization'],'Bearer ${settings.apiKey}');
      final body = jsonDecode(req.body);
      expect(body['model'],'xiaomi/mimo-v2.6-flash');
      expect(body['max_tokens'],256);
      expect(body['response_format']['json_schema']['strict'],true);
      return http.Response(jsonEncode({'choices':[{'finish_reason':'stop','message':{'content':'{"label":"a"}'}}],
        'usage':{'total_tokens':123,'cost':0.001}}),200);
    }));
    final result = await oracle.ask(settings,skill,'Some request');
    expect(calls,1);
    expect(result['label'],'a'); expect(result['source'],'oracle');
    expect(result['cost_usd'],0.001);
    expect(jsonEncode(result),isNot(contains(settings.apiKey)));
  });
  test('unknown label and truncated output are refused', () async {
    for (final (label, reason) in [('invented','stop'),('a','length')]) {
      final oracle = DecisionOracle(clientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices':[{'finish_reason':reason,'message':{'content':jsonEncode({'label':label})}}]}),200)));
      await expectLater(oracle.ask(settings,skill,'x'),throwsStateError);
    }
  });
  test('upstream bodies and credentials never appear in errors; no retries', () async {
    var calls=0;
    final oracle = DecisionOracle(clientFactory: () => MockClient((_) async { calls++; return http.Response(settings.apiKey,302); }));
    try { await oracle.ask(settings,skill,'x'); fail('redirect was accepted'); }
    catch(e) { expect('$e',isNot(contains(settings.apiKey))); expect('$e',contains('302')); }
    expect(calls,1);
  });
  test('disabled oracle makes zero network calls', () async {
    final oracle = DecisionOracle(clientFactory: () => throw StateError('must not create client'));
    await expectLater(oracle.ask(const OracleSettings(),skill,'x'),throwsStateError);
  });
}
