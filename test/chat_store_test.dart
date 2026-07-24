import 'dart:convert';
import 'dart:io';

import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/services/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('chat_store_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  ChatSession session(String id, {List<ChatMessage>? messages}) => ChatSession(
        id: id,
        createdAt: DateTime(2026, 1, 1),
        messages: messages,
      );

  test('save / loadAll / delete round-trip', () async {
    final store = ChatStore();
    final s = session('a1', messages: [
      const ChatMessage(role: ChatRole.user, content: 'привет'),
      const ChatMessage(
        role: ChatRole.assistant,
        content: 'ответ',
        stats: GenerationStats(
          promptTokens: 3,
          completionTokens: 5,
          tokensPerSecond: 12.5,
          latencyMs: 400,
          finishReason: 'stop',
        ),
      ),
    ]);
    await store.save(s);

    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'a1');
    expect(loaded.single.messages, hasLength(2));
    expect(loaded.single.messages.last.stats?.completionTokens, 5);

    await store.delete('a1');
    expect(await store.loadAll(), isEmpty);
  });

  test('corrupt session files are skipped, valid ones survive', () async {
    final store = ChatStore();
    await store.save(session('good'));
    File('${tmp.path}/chats/bad.json').writeAsStringSync('{not json');

    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'good');
  });

  test('overlapping saves of one session serialize into valid JSON',
      () async {
    final store = ChatStore();
    final s = session('busy');
    final saves = <Future<void>>[];
    for (var i = 0; i < 20; i++) {
      s.messages.add(ChatMessage(role: ChatRole.user, content: 'msg $i'));
      saves.add(store.save(s));
    }
    await Future.wait(saves);

    final raw = File('${tmp.path}/chats/busy.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect((decoded['messages'] as List).length, 20);
  });
}
