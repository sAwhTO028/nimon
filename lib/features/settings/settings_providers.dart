import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/settings/app_settings_prefs.dart';

final themeModeSettingProvider =
    StateNotifierProvider<ThemeModeSettingNotifier, ThemeMode>((ref) {
  return ThemeModeSettingNotifier();
});

class ThemeModeSettingNotifier extends StateNotifier<ThemeMode> {
  ThemeModeSettingNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    state = await AppSettingsPrefs.loadThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await AppSettingsPrefs.saveThemeMode(mode);
    state = mode;
  }
}

final appLocaleSettingProvider =
    StateNotifierProvider<AppLocaleSettingNotifier, Locale?>((ref) {
  return AppLocaleSettingNotifier();
});

class AppLocaleSettingNotifier extends StateNotifier<Locale?> {
  AppLocaleSettingNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await AppSettingsPrefs.loadAppLocale();
  }

  /// `null` = system default.
  Future<void> setLocale(Locale? locale) async {
    await AppSettingsPrefs.saveAppLocale(locale);
    state = locale;
  }
}

final readingTextScaleSettingProvider =
    StateNotifierProvider<ReadingTextScaleNotifier, double>((ref) {
  return ReadingTextScaleNotifier();
});

class ReadingTextScaleNotifier extends StateNotifier<double> {
  ReadingTextScaleNotifier() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    state = await AppSettingsPrefs.loadReadingTextScale();
  }

  Future<void> setFromSizeId(String id) async {
    await AppSettingsPrefs.saveReadingTextSizeId(id);
    state = switch (id) {
      'large' => 1.12,
      'small' => 0.92,
      _ => 1.0,
    };
  }

  String get currentSizeId {
    if (state <= 0.94) return 'small';
    if (state >= 1.08) return 'large';
    return 'standard';
  }
}

final notificationsEnabledSettingProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  return NotificationsEnabledNotifier();
});

class NotificationsEnabledNotifier extends StateNotifier<bool> {
  NotificationsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await AppSettingsPrefs.loadNotificationsEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await AppSettingsPrefs.saveNotificationsEnabled(enabled);
    state = enabled;
  }
}

final monoExplanationEnabledSettingProvider =
    StateNotifierProvider<MonoExplanationEnabledNotifier, bool>((ref) {
  return MonoExplanationEnabledNotifier();
});

class MonoExplanationEnabledNotifier extends StateNotifier<bool> {
  MonoExplanationEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await AppSettingsPrefs.loadMonoExplanationEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await AppSettingsPrefs.saveMonoExplanationEnabled(enabled);
    state = enabled;
  }
}
