import '../../models/chat.dart';
import '../../models/local_model.dart';

/// Sampling / routing parameters for one generation call.
class GenerationRequest {
  const GenerationRequest({
    required this.messages,
    this.temperature = 0.7,
    this.topP = 0.95,
    this.maxTokens = 1024,
    this.task,
    this.disableThinking = false,
  });

  final List<ChatMessage> messages;
  final double temperature;
  final double topP;
  final int maxTokens;

  /// CMF task-mask name (routes through the `cortiq.task` extension).
  final String? task;

  /// Turn off reasoning-model thinking (Qwen3/3.5): render the chat template
  /// with `enable_thinking=false` so the model answers directly with no
  /// `<think>` block. Honored by the native engine ≥ 0.4.1.
  final bool disableThinking;
}

/// A streamed generation event. [delta] carries new text; the last event
/// has [done] = true and non-null [stats].
class GenerationEvent {
  const GenerationEvent({this.delta = '', this.done = false, this.stats});

  final String delta;
  final bool done;
  final GenerationStats? stats;
}

/// Abstraction over the local inference runtime.
///
/// [NativeCortiqEngine] binds to the cortiq-engine Rust runtime over FFI
/// when the native library is bundled; [DemoEngine] is a clearly-labeled
/// simulator so the full UI works on simulators and in development.
abstract class InferenceEngine {
  /// True when this engine can actually run models on this device.
  bool get isAvailable;

  /// Engine identifier shown in the UI ("cortiq-native", "demo").
  String get name;

  LocalModel? get loadedModel;

  Future<void> loadModel(LocalModel model, {int threads = 4});

  Future<void> unload();

  /// Streams generated text. Implementations must emit a final event with
  /// done=true and stats filled in (also after cancellation).
  Stream<GenerationEvent> generate(GenerationRequest request);

  /// Cooperatively stops the current generation.
  void cancel();
}
