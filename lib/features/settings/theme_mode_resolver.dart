import 'package:flutter/material.dart';

/// M11f: resolve stored `themeMode` preference to Flutter ThemeMode.
ThemeMode resolveThemeModeFromPreference(String code) {
  final t = code.trim().toLowerCase();
  return switch (t) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
