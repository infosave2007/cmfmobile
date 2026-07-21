import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsRepository {
  static const _kTheme = 'themeMode';
  static const _kLocale = 'localeCode';
  static const _kTemperature = 'temperature';
  static const _kTopP = 'topP';
  static const _kMaxTokens = 'maxTokens';
  static const _kThreads = 'threads';
  static const _kDisableThinking = 'disableThinking';
  static const _kServerPort = 'serverPort';
  static const _kServerAuth = 'serverAuthEnabled';
  static const _kServerToken = 'serverToken';
  static const _kHfToken = 'hfToken';
  static const _kUseGpu = 'useGpu';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    var token = p.getString(_kServerToken) ?? '';
    if (token.isEmpty) {
      token = _generateToken();
      await p.setString(_kServerToken, token);
    }
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[p.getString(_kTheme)] ??
          ThemeMode.system,
      localeCode: p.getString(_kLocale),
      temperature: p.getDouble(_kTemperature) ?? 0.7,
      topP: p.getDouble(_kTopP) ?? 0.95,
      maxTokens: p.getInt(_kMaxTokens) ?? 1024,
      threads: p.getInt(_kThreads) ?? 4,
      disableThinking: p.getBool(_kDisableThinking) ?? false,
      serverPort: p.getInt(_kServerPort) ?? 8080,
      serverAuthEnabled: p.getBool(_kServerAuth) ?? false,
      serverToken: token,
      hfToken: p.getString(_kHfToken) ?? '',
      useGpu: p.getBool(_kUseGpu) ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, s.themeMode.name);
    if (s.localeCode == null) {
      await p.remove(_kLocale);
    } else {
      await p.setString(_kLocale, s.localeCode!);
    }
    await p.setDouble(_kTemperature, s.temperature);
    await p.setDouble(_kTopP, s.topP);
    await p.setInt(_kMaxTokens, s.maxTokens);
    await p.setInt(_kThreads, s.threads);
    await p.setBool(_kDisableThinking, s.disableThinking);
    await p.setInt(_kServerPort, s.serverPort);
    await p.setBool(_kServerAuth, s.serverAuthEnabled);
    await p.setString(_kServerToken, s.serverToken);
    await p.setString(_kHfToken, s.hfToken);
    await p.setBool(_kUseGpu, s.useGpu);
  }

  static String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final body =
        List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'cmf-$body';
  }
}
