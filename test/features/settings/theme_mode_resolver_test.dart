import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/settings/theme_mode_resolver.dart';

void main() {
  test('resolveThemeModeFromPreference: system default', () {
    expect(resolveThemeModeFromPreference('system'), ThemeMode.system);
    expect(resolveThemeModeFromPreference(''), ThemeMode.system);
    expect(resolveThemeModeFromPreference('unknown'), ThemeMode.system);
  });

  test('resolveThemeModeFromPreference: light/dark', () {
    expect(resolveThemeModeFromPreference('light'), ThemeMode.light);
    expect(resolveThemeModeFromPreference('dark'), ThemeMode.dark);
  });
}
