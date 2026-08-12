import 'package:flutter/material.dart';

import 'companion.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.localeCode,
    this.temperature = 0.7,
    this.topP = 0.95,
    this.maxTokens = 1024,
    this.threads = 0,
    this.engineFlags = '',
    this.disableThinking = false,
    this.serverPort = 8080,
    this.serverAuthEnabled = false,
    this.serverToken = '',
    this.hfToken = '',
    this.useGpu = false,
    this.companionRole = CompanionRole.local,
    this.companionAddress = '',
    this.companionToken = '',
    this.companionWorkerPort = 9911,
  });

  final ThemeMode themeMode;

  /// null = follow system locale.
  final String? localeCode;
  final double temperature;
  final double topP;
  final int maxTokens;

  /// Worker threads for inference and for the converter's isolate pool.
  /// 0 = auto: the device's big-core cluster (see `EngineTuning`).
  final int threads;

  /// Advanced `CMF_KEY=value` overrides (one per line) pushed into the
  /// engine's environment at model load — the runtime's tuning knobs
  /// (`CMF_REPACK`, `CMF_PREFILL_CHUNK`, `CMF_MLOCK`, …) have no UI of their
  /// own, and the right value is device-specific.
  final String engineFlags;

  /// Disable the model's reasoning/thinking pass (Qwen3/3.5): answer directly
  /// instead of emitting a `<think>` block. Applied to every generation.
  final bool disableThinking;
  final int serverPort;
  final bool serverAuthEnabled;
  final String serverToken;
  final String hfToken;
  final bool useGpu;

  /// Which side computes. Persisted so a phone set up as a worker comes back
  /// as one, but never auto-applied over the network: see [CompanionConfig].
  final CompanionRole companionRole;

  /// `host:port` of the desktop's worker.
  final String companionAddress;

  /// Shared secret, the same string on both devices. Sent in clear text, so
  /// it belongs on a cable or a network the user trusts.
  final String companionToken;

  /// Port this device listens on when it serves its layers.
  final int companionWorkerPort;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    bool clearLocale = false,
    double? temperature,
    double? topP,
    int? maxTokens,
    int? threads,
    String? engineFlags,
    bool? disableThinking,
    int? serverPort,
    bool? serverAuthEnabled,
    String? serverToken,
    String? hfToken,
    bool? useGpu,
    CompanionRole? companionRole,
    String? companionAddress,
    String? companionToken,
    int? companionWorkerPort,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        maxTokens: maxTokens ?? this.maxTokens,
        threads: threads ?? this.threads,
        engineFlags: engineFlags ?? this.engineFlags,
        disableThinking: disableThinking ?? this.disableThinking,
        serverPort: serverPort ?? this.serverPort,
        serverAuthEnabled: serverAuthEnabled ?? this.serverAuthEnabled,
        serverToken: serverToken ?? this.serverToken,
        hfToken: hfToken ?? this.hfToken,
        useGpu: useGpu ?? this.useGpu,
        companionRole: companionRole ?? this.companionRole,
        companionAddress: companionAddress ?? this.companionAddress,
        companionToken: companionToken ?? this.companionToken,
        companionWorkerPort:
            companionWorkerPort ?? this.companionWorkerPort,
      );
}
