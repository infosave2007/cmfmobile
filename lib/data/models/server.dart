/// One handled request in the on-device server log.
class ServerRequestRecord {
  const ServerRequestRecord({
    required this.timestamp,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.latencyMs,
    this.remote = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
  });

  final DateTime timestamp;
  final String method;
  final String path;
  final int statusCode;
  final int latencyMs;
  final String remote;
  final int promptTokens;
  final int completionTokens;

  bool get ok => statusCode < 400;
}

/// Aggregate counters for the current server run.
class ServerStats {
  int requests = 0;
  int errors = 0;
  int promptTokens = 0;
  int completionTokens = 0;
  double tokensPerSecondEma = 0;

  void recordGeneration(int prompt, int completion, double tps) {
    promptTokens += prompt;
    completionTokens += completion;
    if (tps > 0) {
      tokensPerSecondEma =
          tokensPerSecondEma == 0 ? tps : tokensPerSecondEma * 0.7 + tps * 0.3;
    }
  }
}
