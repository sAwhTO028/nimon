import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/features/settings/theme_mode_resolver.dart';

/// Avoid [buildDarkTheme] / google_fonts network loads in unit/widget tests.
ThemeData _darkThemeWithTokenExtension() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: NimonColorTokens.dark.appBackground,
    extensions: const <ThemeExtension<dynamic>>[
      NimonColorTokens.dark,
    ],
  );
}

void main() {
  group('M11j tokens', () {
    test('NimonColorTokens.dark uses dark surfaces and light primary text', () {
      const d = NimonColorTokens.dark;
      expect(d.appBackground.computeLuminance(), lessThan(0.25));
      expect(d.surface.computeLuminance(), lessThan(0.35));
      expect(d.textPrimary.computeLuminance(), greaterThan(0.7));
      expect(d.border, isNot(equals(d.surface)));
    });

    test('dark ThemeData + NimonColorTokens extension matches dark palette',
        () {
      final theme = _darkThemeWithTokenExtension();
      expect(
          theme.scaffoldBackgroundColor, NimonColorTokens.dark.appBackground);
      expect(theme.colors.appBackground, NimonColorTokens.dark.appBackground);
      expect(theme.colors.surface, NimonColorTokens.dark.surface);
      expect(theme.colors.textPrimary, NimonColorTokens.dark.textPrimary);
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('modal surface token is dark in dark theme app',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkThemeWithTokenExtension(),
          home: Builder(
            builder: (context) {
              return ColoredBox(
                key: const ValueKey<Object>('m11j_surface_probe'),
                color: Theme.of(context).colors.surface,
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      final box = tester.widget<ColoredBox>(
        find.byKey(const ValueKey<Object>('m11j_surface_probe')),
      );
      expect(box.color.computeLuminance(), lessThan(0.4));
    });

    test('preference dark resolves to ThemeMode.dark', () {
      expect(resolveThemeModeFromPreference('dark'), ThemeMode.dark);
    });
  });

  group('M11j action rail inactive ink (mirrors mono reader rail)', () {
    test('inactive rail icons use textPrimary — light on dark backgrounds', () {
      expect(
        NimonColorTokens.dark.textPrimary.computeLuminance(),
        greaterThan(0.65),
      );
    });
  });
}
