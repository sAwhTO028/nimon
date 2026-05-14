import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

ThemeData buildTheme() {
  final tokens = NimonColorTokens.light;
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: tokens.actionPrimary,
    onPrimary: tokens.appBackground,
    secondary: tokens.actionPrimary,
    onSecondary: tokens.appBackground,
    error: tokens.error,
    onError: tokens.appBackground,
    surface: tokens.surface,
    onSurface: tokens.textPrimary,
    // Keep deprecated fields aligned for older code paths.
    // ignore: deprecated_member_use
    background: tokens.appBackground,
    // ignore: deprecated_member_use
    onBackground: tokens.textPrimary,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.appBackground,
    dividerColor: tokens.border,
    cardColor: tokens.surface,
  );
  final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
      centerTitle: false,
      backgroundColor: tokens.appBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tokens.textPrimary,
      titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NimonRadii.standard.lg),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    drawerTheme: base.drawerTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NimonRadii.standard.xl),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: WidgetStatePropertyAll(
        (textTheme.labelMedium ?? const TextStyle()).copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
    ),
    extensions: <ThemeExtension<dynamic>>[
      NimonSpacing.standard,
      NimonRadii.standard,
      NimonTypography.standard,
      tokens,
    ],
  );
}

ThemeData buildDarkTheme() {
  final tokens = NimonColorTokens.dark;
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: tokens.actionPrimary,
    onPrimary: tokens.appBackground,
    secondary: tokens.actionPrimary,
    onSecondary: tokens.appBackground,
    error: tokens.error,
    onError: tokens.appBackground,
    surface: tokens.surface,
    onSurface: tokens.textPrimary,
    // ignore: deprecated_member_use
    background: tokens.appBackground,
    // ignore: deprecated_member_use
    onBackground: tokens.textPrimary,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.appBackground,
    dividerColor: tokens.border,
    cardColor: tokens.surface,
  );
  final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme);
  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: tokens.appBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tokens.textPrimary,
      titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
        color: tokens.textPrimary,
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
    ),
    extensions: <ThemeExtension<dynamic>>[
      NimonSpacing.standard,
      NimonRadii.standard,
      NimonTypography.standard,
      tokens,
    ],
  );
}
