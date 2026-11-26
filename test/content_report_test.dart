import 'dart:convert';
import 'dart:io';

import 'package:cmf_mobile/core/content_report_config.dart';
import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/models/content_report.dart';
import 'package:cmf_mobile/data/services/content_report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ContentReport _report(String id) => ContentReport(
      id: id,
      createdAt: DateTime.utc(2026, 11, 26, 12),
      reason: ReportReason.hateful,
      reply: 'bad reply $id',
      prompt: 'the question',
      comment: 'why',
      model: 'lfm3-1.7b-q4tp.cmf',
      appVersion: '1.3.11',
      platform: 'android',
    );

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('reports'));
  tearDown(() => tmp.deleteSync(recursive: true));
  Future<File> file() async => File('${tmp.path}/content_reports.json');

  test('a report survives JSON, unknown reasons fall back to other', () {
    final r = _report('a');
    final back = ContentReport.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(ContentReport.fromJson({'reason': 'new-kind'}).reason, ReportReason.other);
    expect(ContentReport.clip('x' * 10, 4), 'xxxx…');
  });

  test('a reported chat message keeps the flag through JSON', () {
    const m = ChatMessage(role: ChatRole.assistant, content: 'hi');
    expect(ChatMessage.fromJson(m.toJson()).reported, isFalse);
    final r = m.copyWith(reported: true);
    expect(ChatMessage.fromJson(r.toJson()).reported, isTrue);
    expect(r.copyWith(content: 'x').reported, isTrue);
  });

  test('offline: the report is kept, and goes out on the next retry', () async {
    var online = false;
    final got = <String>[];
    final svc = ContentReportService(
      file: file,
      sender: (r) async {
        if (!online) return false;
        got.add(r.id);
        return true;
      },
    );
    expect(await svc.submit(_report('a')), isFalse);
    expect((await svc.load()).single.sent, isFalse);
    online = true;
    expect(await svc.retryPending(), 1);
    expect(got, ['a']);
    expect((await svc.load()).single.sent, isTrue);
    // A second report goes out at once and the first is not sent twice.
    expect(await svc.submit(_report('b')), isTrue);
    expect(got, ['a', 'b']);
  });

  test('a failing receiver stops the flush; order is kept', () async {
    var calls = 0;
    final svc = ContentReportService(
      file: file,
      sender: (r) async {
        calls++;
        if (r.id == 'b') throw const SocketException('down');
        return true;
      },
    );
    await svc.submit(_report('b'));
    await svc.submit(_report('c')); // b still fails, c waits behind it
    final all = await svc.load();
    expect(all.map((r) => r.id), ['b', 'c']);
    expect(all.every((r) => !r.sent), isTrue);
    expect(calls, 2);
  });

  test('the outbox keeps the newest reports only', () async {
    final svc = ContentReportService(file: file, sender: (_) async => true);
    for (var i = 0; i < ContentReportService.keep + 5; i++) {
      await svc.submit(_report('$i'));
    }
    final all = await svc.load();
    expect(all.length, ContentReportService.keep);
    expect(all.first.id, '5');
  });

  test('the Google Form sender posts one entry per mapped field', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response('ok', 200);
    });
    const endpoint = ContentReportEndpoint(
      formUrl: 'https://docs.google.com/forms/d/e/FORM/formResponse',
      fields: {
        'reason': 'entry.1',
        'reply': 'entry.2',
        'prompt': 'entry.3',
        'model': 'entry.4',
        'app': 'entry.5',
      },
    );
    final ok = await googleFormSender(endpoint, client: client)(_report('a'));
    expect(ok, isTrue);
    expect(seen.method, 'POST');
    expect(seen.url.toString(), endpoint.formUrl);
    final body = Uri.splitQueryString(seen.body);
    expect(body['entry.1'], 'hateful');
    expect(body['entry.2'], 'bad reply a');
    expect(body['entry.3'], 'the question');
    expect(body['entry.4'], 'lfm3-1.7b-q4tp.cmf');
    expect(body['entry.5'], '1.3.11 android');
    expect(body.length, 5);
  });

  test('the shipped endpoint maps every report field to its own entry', () {
    const e = contentReportEndpoint;
    expect(e.configured, isTrue);
    expect(e.formUrl, endsWith('/formResponse'));
    expect(e.fields.keys.toSet(),
        {'id', 'createdAt', 'reason', 'reply', 'prompt', 'comment', 'model', 'app'});
    expect(e.fields.values.toSet().length, e.fields.length);
    expect(e.fields.values.every((v) => RegExp(r'^entry\.\d+$').hasMatch(v)), isTrue);
  });

  test('an unconfigured endpoint sends nothing', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('', 200);
    });
    const none = ContentReportEndpoint(formUrl: '', fields: {});
    expect(await googleFormSender(none, client: client)(_report('a')), isFalse);
    expect(called, isFalse);
    expect(jsonEncode(_report('a').toJson()), contains('"sent":false'));
  });
}
