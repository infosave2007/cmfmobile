/// Roles this device can take in a network split, and what the peer reports
/// about itself while it holds one.
///
/// The engine's own measurements (docs/MOBILE_SPLIT.ru.md in the cmf repo)
/// decide which of these are worth offering. A token travels through the
/// layers in order, so splitting a model that already fits buys nothing — it
/// measured *slower* than the faster side alone. What a split buys is a model
/// the phone could not otherwise run, so the app offers roles, not a load
/// percentage.
///
/// Two of the four roles in that document are deliberately absent here:
/// offloading only the prefill needs KV state to cross the wire, which the
/// runtime cannot do yet, and serving a whole request is the Server screen,
/// which already exists.
library;

enum CompanionRole {
  /// Everything runs on this device. The honest default, and the only
  /// sensible one over Wi-Fi until the runtime can batch tokens per round.
  local,

  /// The desktop holds the model and the head; this phone keeps the
  /// tokenizer and draws. What makes a 34.7B model usable on a phone with
  /// 2 GB free.
  desktop,

  /// This phone serves its layers to somebody else's coordinator, so the
  /// desktop can run a model larger than its own memory.
  worker,
}

/// A refusal that comes from the app, not the runtime.
///
/// The controller reports one of these instead of a message, because the
/// message has to be localized and the controller has no localizations —
/// that is the screen's job. Text coming back from the engine itself
/// (`wire version 4 ≠ 5`, `address in use`) travels as-is: it is a
/// diagnostic, and translating it would only make it harder to search for.
enum CompanionFault {
  /// The address is not `host:port`. Caught here so it fails where it was
  /// typed rather than on the first generation.
  addressInvalid,

  /// No model is loaded. The file is read locally for the tokenizer and the
  /// chat template even when the desktop does the computing, and it is what
  /// the worker role serves.
  modelNotLoaded,
}

/// Why a generation through the peer failed.
///
/// The runtime says it precisely and in English — `connect 127.0.0.1:9911:
/// Connection refused (os error 111)` — which is the right text for a log and
/// the wrong one for a chat bubble. These cases exist so the UI can say what
/// happened in the user's language and offer the remedy that fits.
enum PeerFailure {
  /// The desktop is not answering: stopped, unplugged, or never started.
  /// Covers both directions of that — refused on the dial, broken pipe when
  /// it dies mid-session.
  unreachable,

  /// The two sides are on different engine versions. The handshake compares
  /// a wire version and says so rather than producing garbage.
  wireVersion,

  /// The desktop holds a different `.cmf`. Checked by `dir_hash`, so a
  /// mismatched pair is refused instead of assembling a chimera.
  modelMismatch,

  /// Something else came back from the peer path.
  other,
}

/// Reads the runtime's text and names the cause, or null when the failure has
/// nothing to do with a peer.
///
/// Matching on message text is not lovely, but the C ABI returns a string and
/// the alternative — treating every failure during a split as a peer failure —
/// would blame the desktop for a bad model file.
PeerFailure? classifyPeerFailure(String raw) {
  final text = raw.toLowerCase();
  if (!text.contains('peer')) return null;
  if (text.contains('wire version')) return PeerFailure.wireVersion;
  if (text.contains('dir_hash') ||
      text.contains('dir hash') ||
      text.contains('different model')) {
    return PeerFailure.modelMismatch;
  }
  const unreachable = [
    'connection refused',
    'broken pipe',
    'connection reset',
    // The runtime's own words when the far side closes mid-generation, which
    // is the common case: somebody stopped the worker or unplugged the cable.
    'hung up',
    'disconnected',
    'closed',
    'timed out',
    'timeout',
    'no route to host',
    'network is unreachable',
    'not connected',
    'eof',
  ];
  for (final marker in unreachable) {
    if (text.contains(marker)) return PeerFailure.unreachable;
  }
  return PeerFailure.other;
}

/// The runtime's message without Dart's and the ABI's plumbing.
///
/// `Bad state: generate: peer generate: connect …` is three layers of wrapper
/// around the one clause that matters. Shown as-is it reads like a crash.
String cleanEngineError(String raw) {
  var text = raw.trim();
  const noise = ['Bad state: ', 'StateError: ', 'Exception: '];
  for (final prefix in noise) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length).trim();
  }
  // The ABI nests its own context, one layer per hop it passed through:
  // "generate: peer generate: <the cause>". Peel every one of them.
  while (true) {
    final match = RegExp(r'^[a-z_]*\s*generate:\s*').firstMatch(text);
    if (match == null || match.end == 0) break;
    text = text.substring(match.end).trim();
  }
  return text.isEmpty ? raw : text;
}

/// Where the peer lives, and how the phone talks to it.
class CompanionConfig {
  const CompanionConfig({
    this.role = CompanionRole.local,
    this.address = '',
    this.token = '',
    this.workerPort = 9911,
  });

  final CompanionRole role;

  /// `host:port` of the desktop's worker. A loopback address means the two
  /// are on a cable (USB tethering, or `adb reverse`), which is the transport
  /// this feature is actually good on.
  final String address;

  /// Shared secret. The runtime refuses to listen without one on anything but
  /// loopback. It is not encrypted — trusted network or cable only.
  final String token;

  /// Port this device listens on in [CompanionRole.worker].
  final int workerPort;

  bool get overCable => isLoopback(address);

  /// A cable is `127.0.0.1` because that is what `adb reverse` and USB
  /// tethering give you; anything else is a network, with a network's tail.
  static bool isLoopback(String address) {
    final host = address.split(':').first.trim().toLowerCase();
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  /// `host:port`, or null with the reason when it is not usable.
  static String? validate(String address) {
    final text = address.trim();
    if (text.isEmpty) return null;
    final colon = text.lastIndexOf(':');
    if (colon <= 0 || colon == text.length - 1) return null;
    final port = int.tryParse(text.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) return null;
    return text;
  }

  CompanionConfig copyWith({
    CompanionRole? role,
    String? address,
    String? token,
    int? workerPort,
  }) =>
      CompanionConfig(
        role: role ?? this.role,
        address: address ?? this.address,
        token: token ?? this.token,
        workerPort: workerPort ?? this.workerPort,
      );
}

/// What the peer costs right now, from `cortiq_peer_stats`.
///
/// Every field is nullable on purpose: the runtime distinguishes "this
/// platform does not expose it" from a real zero, and so must anything that
/// reads it. A scheduler that reads a missing clock as 0 MHz parks a node
/// that is perfectly healthy.
class PeerStats {
  const PeerStats({
    this.thermalMilliC,
    this.powered,
    this.cpuKhzCurrent,
    this.cpuKhzMax,
    this.memAvailableKb,
    this.threads,
    this.platform,
  });

  final int? thermalMilliC;
  final bool? powered;
  final int? cpuKhzCurrent;
  final int? cpuKhzMax;
  final int? memAvailableKb;
  final int? threads;
  final String? platform;

  static const empty = PeerStats();

  bool get isEmpty =>
      thermalMilliC == null &&
      cpuKhzCurrent == null &&
      memAvailableKb == null &&
      threads == null &&
      platform == null;

  double? get temperatureC =>
      thermalMilliC == null ? null : thermalMilliC! / 1000;

  /// How much of its clock range the peer is actually using. Below ~0.5 on an
  /// active decode means the governor never woke up for a task that computes
  /// for a few milliseconds and then blocks on a socket — which costs about
  /// half the throughput, and is what the foreground service is for.
  double? get clockFraction {
    final cur = cpuKhzCurrent;
    final max = cpuKhzMax;
    if (cur == null || max == null || max <= 0) return null;
    return cur / max;
  }

  factory PeerStats.fromJson(Map<String, dynamic> json) {
    int? asInt(String key) => json[key] is num ? (json[key] as num).round() : null;
    return PeerStats(
      thermalMilliC: asInt('thermal_mc'),
      powered: json['powered'] is bool ? json['powered'] as bool : null,
      cpuKhzCurrent: asInt('cpu_khz_cur'),
      cpuKhzMax: asInt('cpu_khz_max'),
      memAvailableKb: asInt('mem_avail_kb'),
      threads: asInt('threads'),
      platform: json['platform'] is String ? json['platform'] as String : null,
    );
  }
}
