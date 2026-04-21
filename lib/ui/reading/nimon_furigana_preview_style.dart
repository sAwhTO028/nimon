import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

/// App-wide furigana **design language**: base text is primary; ruby is smaller,
/// lighter, and must not dominate. Used by [NimonJapaneseSentenceLine] and
/// aligned with reading surfaces that use [NimonFuriganaPreviewContext.reading].
enum NimonFuriganaPreviewContext {
  /// Creator sentence cards, furigana sheet — default density.
  storytelling,

  /// Vocabulary / Semantics example previews — same metrics as [storytelling].
  details,

  /// Long-form reader (mono / future reading UI) — uses [NimonTypography]
  /// reading scale with the same hierarchy rules; slightly more wrap breathing room.
  reading,
}

/// Locked numeric tokens for furigana line layout (wrap + ruby column).
///
/// Do not duplicate these values on individual screens — use
/// [resolveNimonFuriganaLineStyle].
abstract final class NimonFuriganaPreviewTokens {
  NimonFuriganaPreviewTokens._();

  /// Creator contexts: base size when [TextTheme.bodyLarge] has no font size.
  static const double creatorBaseFontSizeFallback = 16.0;

  /// Default ink for creator Japanese sentence lines (matches prior cards).
  static const Color creatorJapaneseInk = Color(0xFF1A1917);

  /// Line height for creator base text.
  static const double creatorBaseLineHeight = 1.35;

  /// Ruby font size as a fraction of resolved base [TextStyle.fontSize].
  static const double rubySizeRatioFromBase = 11 / 16;

  static const double wrapTokenSpacing = 2.0;

  /// Vertical gap between [Wrap] runs (token rows).
  static const double wrapRunSpacingCreator = 6.0;
  static const double wrapRunSpacingReading = 7.0;

  /// Gap between ruby line and base glyph column in stacked ruby units.
  static const double rubyToBaseColumnGap = 2.0;

  /// Ruby uses [ColorScheme.onSurfaceVariant] at this opacity (creator).
  static const double rubyForegroundAlphaCreator = 0.72;

  /// Ruby above base in reading uses [ColorScheme.onSurface] (see typography).
  static const double rubyForegroundAlphaReading = 0.78;
}

/// Resolved typography + spacing for one furigana-capable sentence line.
@immutable
class NimonFuriganaLineStyle {
  const NimonFuriganaLineStyle({
    required this.baseStyle,
    required this.rubyStyle,
    required this.wrapSpacing,
    required this.wrapRunSpacing,
    required this.rubyBaseGap,
  });

  final TextStyle baseStyle;
  final TextStyle rubyStyle;

  /// Horizontal spacing between adjacent wrap children (plain tokens / ruby units).
  final double wrapSpacing;

  /// Vertical spacing between wrap runs.
  final double wrapRunSpacing;

  /// Vertical gap between ruby text and base text inside a stacked unit.
  final double rubyBaseGap;
}

/// Single source of truth for furigana **hierarchy** and **layout constants**
/// across Storytelling, Vocabulary details, and reading views.
NimonFuriganaLineStyle resolveNimonFuriganaLineStyle(
  BuildContext context,
  ThemeData theme,
  NimonFuriganaPreviewContext previewContext,
) {
  final cs = theme.colorScheme;
  final wc = NimonBreakpoints.of(context);
  final type = theme.type;

  switch (previewContext) {
    case NimonFuriganaPreviewContext.storytelling:
    case NimonFuriganaPreviewContext.details:
      final baseSize = theme.textTheme.bodyLarge?.fontSize ??
          NimonFuriganaPreviewTokens.creatorBaseFontSizeFallback;
      final rubySize =
          (baseSize * NimonFuriganaPreviewTokens.rubySizeRatioFromBase)
              .clamp(9.0, 12.0)
              .toDouble();

      final base = theme.textTheme.bodyLarge?.copyWith(
            color: NimonFuriganaPreviewTokens.creatorJapaneseInk,
            height: NimonFuriganaPreviewTokens.creatorBaseLineHeight,
            fontWeight: FontWeight.w600,
          ) ??
          TextStyle(
            fontSize: baseSize,
            height: NimonFuriganaPreviewTokens.creatorBaseLineHeight,
            fontWeight: FontWeight.w600,
            color: NimonFuriganaPreviewTokens.creatorJapaneseInk,
          );

      final ruby = (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontSize: rubySize,
        height: 1.05,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.02,
        color: cs.onSurfaceVariant
            .withValues(alpha: NimonFuriganaPreviewTokens.rubyForegroundAlphaCreator),
      );

      return NimonFuriganaLineStyle(
        baseStyle: base,
        rubyStyle: ruby,
        wrapSpacing: NimonFuriganaPreviewTokens.wrapTokenSpacing,
        wrapRunSpacing: NimonFuriganaPreviewTokens.wrapRunSpacingCreator,
        rubyBaseGap: NimonFuriganaPreviewTokens.rubyToBaseColumnGap,
      );

    case NimonFuriganaPreviewContext.reading:
      final base = type.readingJa(theme, wc).copyWith(
        color: cs.onSurface,
      );
      final ruby = type.furigana(theme, wc).copyWith(
        color: cs.onSurface
            .withValues(alpha: NimonFuriganaPreviewTokens.rubyForegroundAlphaReading),
        fontWeight: FontWeight.w500,
        height: 1.02,
        letterSpacing: 0.05,
      );

      return NimonFuriganaLineStyle(
        baseStyle: base,
        rubyStyle: ruby,
        wrapSpacing: NimonFuriganaPreviewTokens.wrapTokenSpacing,
        wrapRunSpacing: NimonFuriganaPreviewTokens.wrapRunSpacingReading,
        rubyBaseGap: NimonFuriganaPreviewTokens.rubyToBaseColumnGap,
      );
  }
}
