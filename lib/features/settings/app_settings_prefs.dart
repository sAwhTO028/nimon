import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app-wide settings (theme, locale, reader text scale, notifications).
abstract final class AppSettingsPrefs {
  AppSettingsPrefs._();

  static const _themeKey = 'nimon_theme_mode';
  static const _localeKey = 'nimon_app_locale';
  static const _readingKey = 'nimon_reading_text_size';
  static const _notificationsEnabledKey = 'nimon_app_notifications_enabled';
  static const _monoExplanationEnabledKey = 'nimon_mono_explanation_enabled';

  static Future<ThemeMode> loadThemeMode() async {
    final p = await SharedPreferences.getInstance();
    switch (p.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final p = await SharedPreferences.getInstance();
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await p.setString(_themeKey, v);
  }

  /// `null` = follow device locale.
  static Future<Locale?> loadAppLocale() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_localeKey);
    if (raw == null || raw == 'system' || raw.isEmpty) return null;
    if (raw == 'ja') return const Locale('ja');
    return const Locale('en');
  }

  static Future<void> saveAppLocale(Locale? locale) async {
    final p = await SharedPreferences.getInstance();
    if (locale == null) {
      await p.setString(_localeKey, 'system');
      return;
    }
    await p.setString(_localeKey, locale.languageCode);
  }

  static Future<double> loadReadingTextScale() async {
    final p = await SharedPreferences.getInstance();
    switch (p.getString(_readingKey)) {
      case 'large':
        return 1.12;
      case 'small':
        return 0.92;
      default:
        return 1.0;
    }
  }

  static Future<void> saveReadingTextSizeId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_readingKey, id);
  }

  /// App-level notifications preference (V1). Does not request OS permission.
  /// Default: on (`true`) when unset.
  static Future<bool> loadNotificationsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_notificationsEnabledKey) ?? true;
  }

  static Future<void> saveNotificationsEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notificationsEnabledKey, enabled);
  }

  /// Mono reader: show per-line explanation sentences (V1).
  /// Default: on (`true`) when unset.
  static Future<bool> loadMonoExplanationEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_monoExplanationEnabledKey) ?? true;
  }

  static Future<void> saveMonoExplanationEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_monoExplanationEnabledKey, enabled);
  }
}
