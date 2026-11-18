/// Per-device choices: light or dark look, and the app language.
/// Saved on the device, so they stay after closing the app.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';

abstract final class AppPrefs {
  /// Système (follows the phone), Clair or Sombre.
  static final theme = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// 'fr' (default) or 'en'.
  static final language = ValueNotifier<String>('fr');

  static const _themeKey = 'prefs.theme';
  static const _langKey = 'prefs.language';

  /// Reads the saved choices. Never fails: storage can be missing (private
  /// browsing, tests), and the defaults are fine.
  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      theme.value = switch (p.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _apply(p.getString(_langKey) == 'en' ? 'en' : 'fr');
    } catch (_) {
      _apply('fr');
    }
  }

  static Future<void> setTheme(ThemeMode m) async {
    theme.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_themeKey, m.name);
    } catch (_) {}
  }

  static Future<void> setLanguage(String code) async {
    _apply(code);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_langKey, code);
    } catch (_) {}
  }

  static void _apply(String code) {
    L.setLanguage(code);
    Intl.defaultLocale = code == 'en' ? 'en_GB' : 'fr_FR';
    language.value = code;
  }
}
