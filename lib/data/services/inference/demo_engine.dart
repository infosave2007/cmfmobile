import 'dart:async';
import 'dart:math';

import '../../models/chat.dart';
import '../../models/local_model.dart';
import 'inference_engine.dart';

/// Development fallback used when the native cortiq runtime is not bundled
/// (e.g. simulators). Streams a clearly-labeled simulated reply so the whole
/// UX — streaming, stats, server — can be exercised end to end. The UI shows
/// a "demo engine" badge whenever this engine is active.
class DemoEngine implements InferenceEngine {
  LocalModel? _loaded;
  bool _cancelled = false;

  @override
  bool get isAvailable => true;

  @override
  String get name => 'demo';

  @override
  LocalModel? get loadedModel => _loaded;

  @override
  void setGpu(bool enable) {}

  @override
  Future<void> loadModel(LocalModel model, {int threads = 4}) async {
    // Simulate mmap + warmup proportional to file size, capped.
    final ms = min(1200, 200 + model.sizeBytes ~/ (50 * 1024 * 1024));
    await Future<void>.delayed(Duration(milliseconds: ms));
    _loaded = model;
  }

  @override
  Future<void> unload() async => _loaded = null;

  /// Rough token estimate (~4 chars/token) used for demo usage stats.
  static int estimateTokens(String text) => max(1, text.length ~/ 4);

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) async* {
    final model = _loaded;
    if (model == null) throw StateError('no model loaded');
    _cancelled = false;

    final lastUser = request.messages.lastWhere(
      (m) => m.role == ChatRole.user,
      orElse: () => const ChatMessage(role: ChatRole.user, content: ''),
    );
    final attachmentNote = lastUser.attachments.isEmpty
        ? ''
        : '\n\nAttached: '
            '${lastUser.attachments.map((a) => a.name).join(', ')} — '
            'in a real run the document text is inlined into the prompt.';

    final reply = '**Demo engine** — the native cortiq runtime is not '
        'bundled in this build, so this is a simulated reply.\n\n'
        'Model: `${model.id}` '
        '(${model.meta?.archName ?? '?'}, ${model.meta?.quantType ?? '?'})\n'
        'Prompt: "${_ellipsize(lastUser.content, 120)}"\n\n'
        'To run real inference, build `libcortiq_ffi` from the cmfpublic '
        'workspace (see native/README.md) and reinstall the app.'
        '$attachmentNote';

    final started = DateTime.now();
    final promptTokens = request.messages
        .map((m) =>
            estimateTokens(m.content) +
            m.attachments
                .map((a) => estimateTokens(a.text))
                .fold<int>(0, (a, b) => a + b))
        .fold<int>(0, (a, b) => a + b);

    var completionTokens = 0;
    final rng = Random(reply.hashCode);
    final words = reply.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      if (_cancelled) break;
      final chunk = i == 0 ? words[i] : ' ${words[i]}';
      buffer.write(chunk);
      completionTokens += estimateTokens(chunk);
      yield GenerationEvent(delta: chunk);
      await Future<void>.delayed(
          Duration(milliseconds: 18 + rng.nextInt(40)));
      if (completionTokens >= request.maxTokens) break;
    }

    final elapsed = DateTime.now().difference(started);
    yield GenerationEvent(
      done: true,
      stats: GenerationStats(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        tokensPerSecond: elapsed.inMilliseconds > 0
            ? completionTokens * 1000 / elapsed.inMilliseconds
            : 0,
        latencyMs: elapsed.inMilliseconds,
        finishReason: _cancelled
            ? 'cancelled'
            : completionTokens >= request.maxTokens
                ? 'length'
                : 'stop',
        taskUsed: request.task,
      ),
    );
  }

  @override
  void cancel() => _cancelled = true;

  static String _ellipsize(String s, int max) {
    final t = s.trim().replaceAll('\n', ' ');
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }
}
