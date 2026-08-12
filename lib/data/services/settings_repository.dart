import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/companion.dart';
import '../models/settings.dart';

class SettingsRepository {
  static const _kTheme = 'themeMode';
  static const _kLocale = 'localeCode';
  static const _kTemperature = 'temperature';
  static const _kTopP = 'topP';
  static const _kMaxTokens = 'maxTokens';
  static const _kThreads = 'threads';
  static const _kEngineFlags = 'engineFlags';
  static const _kSchema = 'settingsSchema';
  static const _kDisableThinking = 'disableThinking';
  static const _kServerPort = 'serverPort';
  static const _kServerAuth = 'serverAuthEnabled';
  static const _kServerToken = 'serverToken';
  static const _kHfToken = 'hfToken';
  static const _kUseGpu = 'useGpu';
  static const _kCompanionRole = 'companionRole';
  static const _kCompanionAddress = 'companionAddress';
  static const _kCompanionToken = 'companionToken';
  static const _kCompanionPort = 'companionWorkerPort';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    var token = p.getString(_kServerToken) ?? '';
    if (token.isEmpty) {
      token = _generateToken();
      await p.setString(_kServerToken, token);
    }
    // Schema 1 made the thread count auto-sized (0). Installs carrying the
    // old hardcoded default get the new one; a value the user actually
    // picked stays put.
    if ((p.getInt(_kSchema) ?? 0) < 1) {
      if (p.getInt(_kThreads) == 4) await p.setInt(_kThreads, 0);
      await p.setInt(_kSchema, 1);
    }
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[p.getString(_kTheme)] ??
          ThemeMode.system,
      localeCode: p.getString(_kLocale),
      temperature: p.getDouble(_kTemperature) ?? 0.7,
      topP: p.getDouble(_kTopP) ?? 0.95,
      maxTokens: p.getInt(_kMaxTokens) ?? 1024,
      threads: p.getInt(_kThreads) ?? 0,
      engineFlags: p.getString(_kEngineFlags) ?? '',
      disableThinking: p.getBool(_kDisableThinking) ?? false,
      serverPort: p.getInt(_kServerPort) ?? 8080,
      serverAuthEnabled: p.getBool(_kServerAuth) ?? false,
      serverToken: token,
      hfToken: p.getString(_kHfToken) ?? '',
      useGpu: p.getBool(_kUseGpu) ?? false,
      // A peer is never restored as active: the address was reachable when it
      // was saved, and a phone that silently dials a desktop it can no longer
      // see would look like a broken model rather than a missing cable. The
      // screen restores the role, the user presses Connect.
      companionRole: CompanionRole.values
              .asNameMap()[p.getString(_kCompanionRole)] ??
          CompanionRole.local,
      companionAddress: p.getString(_kCompanionAddress) ?? '',
      companionToken: p.getString(_kCompanionToken) ?? '',
      companionWorkerPort: p.getInt(_kCompanionPort) ?? 9911,
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
    await p.setString(_kEngineFlags, s.engineFlags);
    await p.setBool(_kDisableThinking, s.disableThinking);
    await p.setInt(_kServerPort, s.serverPort);
    await p.setBool(_kServerAuth, s.serverAuthEnabled);
    await p.setString(_kServerToken, s.serverToken);
    await p.setString(_kHfToken, s.hfToken);
    await p.setBool(_kUseGpu, s.useGpu);
    await p.setString(_kCompanionRole, s.companionRole.name);
    await p.setString(_kCompanionAddress, s.companionAddress);
    await p.setString(_kCompanionToken, s.companionToken);
    await p.setInt(_kCompanionPort, s.companionWorkerPort);
  }

  static String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final body =
        List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'cmf-$body';
  }
}
