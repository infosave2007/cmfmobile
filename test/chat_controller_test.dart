import 'dart:io';

import 'package:cmf_mobile/core/providers.dart';
import 'package:cmf_mobile/data/models/chat.dart';
import 'package:cmf_mobile/data/models/local_model.dart';
import 'package:cmf_mobile/data/services/inference/demo_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('chat_controller_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  Future<ProviderContainer> makeContainer() async {
    final engine = DemoEngine();
    await engine.loadModel(LocalModel(
      id: 'demo-model',
      filePath: '${tmp.path}/demo.cmf',
      sizeBytes: 1,
      modifiedAt: DateTime(2026, 1, 1),
    ));
    final container = ProviderContainer(
      overrides: [engineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    // ChatController._init() loads sessions asynchronously.
    container.read(chatControllerProvider);
    for (var i = 0; i < 200; i++) {
      if (container.read(chatControllerProvider).loaded) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(chatControllerProvider).loaded, isTrue);
    return container;
  }

  test('send() streams a reply into the session and persists it', () async {
    final container = await makeContainer();
    final controller = container.read(chatControllerProvider.notifier);

    await controller.send('hello there', const []);

    final state = container.read(chatControllerProvider);
    final messages = state.current!.messages;
    expect(messages, hasLength(2));
    expect(messages.first.role, ChatRole.user);
    expect(messages.last.role, ChatRole.assistant);
    expect(messages.last.content, contains('Demo engine'));
    expect(messages.last.stats, isNotNull);
    expect(state.generating, isFalse);
    // Per-token state is cleaned up after completion.
    expect(container.read(streamingReplyProvider), isNull);
    // The finished session is on disk.
    final files = Directory('${tmp.path}/chats')
        .listSync()
        .whereType<File>()
        .toList();
    expect(files, isNotEmpty);
  });

  test('newSession() reuses an existing empty session', () async {
    final container = await makeContainer();
    final controller = container.read(chatControllerProvider.notifier);

    final before = container.read(chatControllerProvider).sessions.length;
    controller.newSession();
    controller.newSession();
    final after = container.read(chatControllerProvider).sessions.length;
    expect(after, before); // blanks are not stacked
  });

  test('send() is ignored while a generation is already running', () async {
    final container = await makeContainer();
    final controller = container.read(chatControllerProvider.notifier);

    final first = controller.send('first', const []);
    // The demo engine streams for a while; a second send must be a no-op.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await controller.send('second', const []);
    await first;

    final messages =
        container.read(chatControllerProvider).current!.messages;
    expect(messages.where((m) => m.role == ChatRole.user), hasLength(1));
  });
}
