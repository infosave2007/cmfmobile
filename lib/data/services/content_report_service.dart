import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/content_report_config.dart';
import '../models/content_report.dart';

/// Sends one report; true when the receiver accepted it.
typedef ReportSender = Future<bool> Function(ContentReport report);

/// The outbox of reports about AI replies.
///
/// A report is written to disk first and then sent, so one made offline, or
/// while the receiver is down, goes out on the next attempt (each new report
/// and every app start retry what is pending). Delivered reports stay in the
/// file, marked sent, as the user's own record; the newest 200 are kept.
class ContentReportService {
  ContentReportService({
    ReportSender? sender,
    Future<File> Function()? file,
  })  : _sender = sender ?? googleFormSender(contentReportEndpoint),
        _file = file ?? _defaultFile;

  final ReportSender _sender;
  final Future<File> Function() _file;
  Future<void> _chain = Future.value();

  static const keep = 200;

  static Future<File> _defaultFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/content_reports.json');
  }

  Future<List<ContentReport>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) => ContentReport.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _store(List<ContentReport> reports) async {
    final f = await _file();
    final tail = reports.length > keep
        ? reports.sublist(reports.length - keep)
        : reports;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(tail.map((r) => r.toJson()).toList()));
    await tmp.rename(f.path);
  }

  /// Saves [report] and tries to deliver it with anything still pending.
  /// Returns whether [report] itself was delivered.
  Future<bool> submit(ContentReport report) {
    final done = _chain.then((_) async {
      final all = await load();
      all.add(report);
      await _store(all);
      final sent = await _flush(all);
      return sent.contains(report.id);
    });
    _chain = done.then((_) {}, onError: (_) {});
    return done;
  }

  /// Retries pending reports (on app start). Returns how many went out.
  Future<int> retryPending() {
    final done = _chain.then((_) async => (await _flush(await load())).length);
    _chain = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<Set<String>> _flush(List<ContentReport> all) async {
    final sent = <String>{};
    for (var i = 0; i < all.length; i++) {
      if (all[i].sent) continue;
      bool ok;
      try {
        ok = await _sender(all[i]);
      } catch (_) {
        ok = false;
      }
      if (!ok) break; // offline or the receiver is down: try again later
      all[i] = all[i].markSent();
      sent.add(all[i].id);
    }
    if (sent.isNotEmpty) await _store(all);
    return sent;
  }
}

/// Posts a report to a Google Form's `formResponse` endpoint, one `entry.N`
/// field per report field. Not configured: nothing is sent (false).
ReportSender googleFormSender(ContentReportEndpoint endpoint,
    {http.Client? client}) {
  return (report) async {
    if (!endpoint.configured) return false;
    final values = <String, String>{
      'id': report.id,
      'createdAt': report.createdAt.toUtc().toIso8601String(),
      'reason': report.reason.name,
      'reply': report.reply,
      'prompt': report.prompt ?? '',
      'comment': report.comment,
      'model': report.model,
      'app': '${report.appVersion} ${report.platform}'.trim(),
    };
    final body = <String, String>{
      for (final e in endpoint.fields.entries)
        if (values.containsKey(e.key)) e.value: values[e.key]!,
    };
    final c = client ?? http.Client();
    try {
      final r = await c
          .post(Uri.parse(endpoint.formUrl), body: body)
          .timeout(const Duration(seconds: 20));
      // Google answers 200 with its "response recorded" page.
      return r.statusCode >= 200 && r.statusCode < 400;
    } finally {
      if (client == null) c.close();
    }
  };
}
