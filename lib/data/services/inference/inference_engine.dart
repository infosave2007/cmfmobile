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

  void setGpu(bool enable) {}

  /// Whether this runtime was built with a GPU backend: true/false when it
  /// can say, null when it offers no way to ask (every build up to and
  /// including v0.5.28 — `cortiq_set_gpu` is accepted there whether or not
  /// anything acts on it). See native/TUNING.md.
  bool? get gpuBackendAvailable => null;

  /// [threads] sizes the native worker pool (0 = size it to the device's big
  /// cluster); [engineFlags] carries advanced `CMF_*=value` overrides. Both
  /// reach the runtime through the process environment — see
  /// [EngineTuning] — because the C ABI takes neither.
  Future<void> loadModel(
    LocalModel model, {
    int threads = 0,
    String engineFlags = '',
  });

  Future<void> unload();

  /// Streams generated text. Implementations must emit a final event with
  /// done=true and stats filled in (also after cancellation).
  Stream<GenerationEvent> generate(GenerationRequest request);

  /// Cooperatively stops the current generation.
  void cancel();
}
