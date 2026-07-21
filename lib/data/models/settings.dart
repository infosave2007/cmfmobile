import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.localeCode,
    this.temperature = 0.7,
    this.topP = 0.95,
    this.maxTokens = 1024,
    this.threads = 4,
    this.disableThinking = false,
    this.serverPort = 8080,
    this.serverAuthEnabled = false,
    this.serverToken = '',
    this.hfToken = '',
    this.useGpu = false,
  });

  final ThemeMode themeMode;

  /// null = follow system locale.
  final String? localeCode;
  final double temperature;
  final double topP;
  final int maxTokens;
  final int threads;

  /// Disable the model's reasoning/thinking pass (Qwen3/3.5): answer directly
  /// instead of emitting a `<think>` block. Applied to every generation.
  final bool disableThinking;
  final int serverPort;
  final bool serverAuthEnabled;
  final String serverToken;
  final String hfToken;
  final bool useGpu;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    bool clearLocale = false,
    double? temperature,
    double? topP,
    int? maxTokens,
    int? threads,
    bool? disableThinking,
    int? serverPort,
    bool? serverAuthEnabled,
    String? serverToken,
    String? hfToken,
    bool? useGpu,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        maxTokens: maxTokens ?? this.maxTokens,
        threads: threads ?? this.threads,
        disableThinking: disableThinking ?? this.disableThinking,
        serverPort: serverPort ?? this.serverPort,
        serverAuthEnabled: serverAuthEnabled ?? this.serverAuthEnabled,
        serverToken: serverToken ?? this.serverToken,
        hfToken: hfToken ?? this.hfToken,
        useGpu: useGpu ?? this.useGpu,
      );
}
