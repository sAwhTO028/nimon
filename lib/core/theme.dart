import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5b86e5)),
  );
  final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
      centerTitle: false,
      titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
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
    extensions: <ThemeExtension<dynamic>>[
      NimonSpacing.standard,
      NimonRadii.standard,
      NimonTypography.standard,
    ],
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff5b86e5),
      brightness: Brightness.dark,
    ),
  );
  final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme);
  return base.copyWith(
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      NimonSpacing.standard,
      NimonRadii.standard,
      NimonTypography.standard,
    ],
  );
}
