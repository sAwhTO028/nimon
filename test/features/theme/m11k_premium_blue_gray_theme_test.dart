import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/features/settings/theme_mode_resolver.dart';

ThemeData _themeWithTokens(NimonColorTokens tokens) {
  return ThemeData(
    brightness:
        tokens == NimonColorTokens.dark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: tokens.appBackground,
    colorScheme: ColorScheme(
      brightness:
          tokens == NimonColorTokens.dark ? Brightness.dark : Brightness.light,
      primary: tokens.actionPrimary,
      onPrimary: tokens.appBackground,
      secondary: tokens.actionPrimary,
      onSecondary: tokens.appBackground,
      error: tokens.error,
      onError: tokens.appBackground,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
    ),
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
}

void main() {
  group('M11k official light tokens', () {
    test('hex values match product spec', () {
      const l = NimonColorTokens.light;
      expect(l.appBackground, const Color(0xFFF6F8FB));
      expect(l.surface, const Color(0xFFDFE6EE));
      expect(l.border, const Color(0xFFB8C2CE));
      expect(l.textSecondary, const Color(0xFF7A8796));
      expect(l.textPrimary, const Color(0xFF3B4450));
    });
  });

  group('M11k official dark tokens', () {
    test('hex values match product spec', () {
      const d = NimonColorTokens.dark;
      expect(d.appBackground, const Color(0xFF1F2630));
      expect(d.surface, const Color(0xFF2A3440));
      expect(d.border, const Color(0xFF4D5A69));
      expect(d.textSecondary, const Color(0xFFA8B4C2));
      expect(d.textPrimary, const Color(0xFFE8EDF3));
    });
  });

  group('M11k ThemeMode mapping', () {
    test('system / light / dark from preferences', () {
      expect(resolveThemeModeFromPreference('system'), ThemeMode.system);
      expect(resolveThemeModeFromPreference('light'), ThemeMode.light);
      expect(resolveThemeModeFromPreference('dark'), ThemeMode.dark);
    });
  });

  group('M11k surface smoke', () {
    testWidgets('light theme builds probe with appBackground + surface',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _themeWithTokens(NimonColorTokens.light),
          home: Builder(
            builder: (context) {
              final t = Theme.of(context);
              return Column(
                children: [
                  Expanded(
                    child: ColoredBox(
                      key: const ValueKey<Object>('m11k_bg'),
                      color: t.colors.appBackground,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ColoredBox(
                      key: const ValueKey<Object>('m11k_surface'),
                      color: t.colors.surface,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey<Object>('m11k_bg')))
            .color,
        NimonColorTokens.light.appBackground,
      );
      expect(
        tester
            .widget<ColoredBox>(
                find.byKey(const ValueKey<Object>('m11k_surface')))
            .color,
        NimonColorTokens.light.surface,
      );
    });

    testWidgets('dark theme builds probe with appBackground + surface',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _themeWithTokens(NimonColorTokens.dark),
          home: Builder(
            builder: (context) {
              final t = Theme.of(context);
              return Column(
                children: [
                  Expanded(
                    child: ColoredBox(
                      key: const ValueKey<Object>('m11k_bg_d'),
                      color: t.colors.appBackground,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ColoredBox(
                      key: const ValueKey<Object>('m11k_surface_d'),
                      color: t.colors.surface,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey<Object>('m11k_bg_d')))
            .color,
        NimonColorTokens.dark.appBackground,
      );
      expect(
        tester
            .widget<ColoredBox>(
                find.byKey(const ValueKey<Object>('m11k_surface_d')))
            .color,
        NimonColorTokens.dark.surface,
      );
    });
  });

  test('onPrimary pairing uses appBackground per M11k theme.dart', () {
    const l = NimonColorTokens.light;
    const d = NimonColorTokens.dark;
    expect(l.actionPrimary, l.textPrimary);
    expect(d.actionPrimary, d.textPrimary);
    expect(l.appBackground, const Color(0xFFF6F8FB));
    expect(d.appBackground, const Color(0xFF1F2630));
  });
}
