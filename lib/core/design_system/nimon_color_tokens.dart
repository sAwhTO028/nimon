import 'package:flutter/material.dart';

/// Semantic app color tokens (`ThemeExtension`).
///
/// **M11k:** Premium muted blue‑gray palettes (light/dark).
class NimonColorTokens extends ThemeExtension<NimonColorTokens> {
  const NimonColorTokens({
    required this.appBackground,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.actionPrimary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.react,
    required this.disabled,
  });

  final Color appBackground;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color actionPrimary;
  final Color border;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color react;

  /// Disabled surface/text/border utility color (use with opacity as needed).
  final Color disabled;

  /// M11k light — soft blue‑gray editorial base.
  static const light = NimonColorTokens(
    appBackground: Color(0xFFF6F8FB),
    surface: Color(0xFFDFE6EE),
    textPrimary: Color(0xFF3B4450),
    textSecondary: Color(0xFF7A8796),
    actionPrimary: Color(0xFF3B4450),
    border: Color(0xFFB8C2CE),
    success: Color(0xFF6F9F8B),
    warning: Color(0xFFB89A5E),
    error: Color(0xFFB86B6B),
    info: Color(0xFF6F8FA8),
    react: Color(0xFFC76B6B),
    disabled: Color(0xFFB8C2CE),
  );

  /// M11k dark — calm blue‑gray chrome.
  static const dark = NimonColorTokens(
    appBackground: Color(0xFF1F2630),
    surface: Color(0xFF2A3440),
    textPrimary: Color(0xFFE8EDF3),
    textSecondary: Color(0xFFA8B4C2),
    actionPrimary: Color(0xFFE8EDF3),
    border: Color(0xFF4D5A69),
    success: Color(0xFF8FBFA5),
    warning: Color(0xFFC7AE7A),
    error: Color(0xFFC98484),
    info: Color(0xFF8FAFCB),
    react: Color(0xFFC98484),
    disabled: Color(0xFF4D5A69),
  );

  @override
  NimonColorTokens copyWith({
    Color? appBackground,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? actionPrimary,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? react,
    Color? disabled,
  }) {
    return NimonColorTokens(
      appBackground: appBackground ?? this.appBackground,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      actionPrimary: actionPrimary ?? this.actionPrimary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      react: react ?? this.react,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  ThemeExtension<NimonColorTokens> lerp(
    ThemeExtension<NimonColorTokens>? other,
    double t,
  ) {
    if (other is! NimonColorTokens) return this;
    return NimonColorTokens(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      actionPrimary: Color.lerp(actionPrimary, other.actionPrimary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      react: Color.lerp(react, other.react, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

extension NimonThemeColorTokensX on ThemeData {
  NimonColorTokens get colors =>
      extension<NimonColorTokens>() ?? NimonColorTokens.light;
}
