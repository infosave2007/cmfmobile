import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat.dart';

/// Persists chat sessions (topics) to disk so conversations and their
/// context survive restarts — one JSON file per session under
/// documents/chats/.
class ChatStore {
  Directory? _dir;

  Future<Directory> _chatsDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/chats');
    await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<List<ChatSession>> loadAll() async {
    final dir = await _chatsDir();
    final sessions = <ChatSession>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        sessions.add(ChatSession.fromJson(json));
      } catch (_) {
        // Skip corrupt session files rather than failing the whole list.
      }
    }
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<void> save(ChatSession session) async {
    final dir = await _chatsDir();
    final file = File('${dir.path}/${session.id}.json');
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<void> delete(String sessionId) async {
    final dir = await _chatsDir();
    final file = File('${dir.path}/$sessionId.json');
    if (await file.exists()) await file.delete();
  }
}
