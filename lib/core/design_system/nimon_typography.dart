import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';

/// Locked typography tokens and responsive rules.
///
/// This is the single source of truth for sizes/weights across text-heavy screens.
class NimonTypography extends ThemeExtension<NimonTypography> {
  const NimonTypography();

  static const NimonTypography standard = NimonTypography();

  /// APP BAR / PAGE TITLE: 20–22, weight 600–700.
  TextStyle pageTitle(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 20.0,
      NimonWidthClass.medium => 21.0,
      NimonWidthClass.expanded => 22.0,
    };
    return (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
  }

  /// SECTION TITLE: 18–20, weight 600.
  TextStyle sectionTitle(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 18.0,
      NimonWidthClass.medium => 19.0,
      NimonWidthClass.expanded => 20.0,
    };
    return (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
  }

  /// STORY CARD TITLE: 18–20, weight 600–700.
  TextStyle storyCardTitle(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 18.0,
      NimonWidthClass.medium => 19.0,
      NimonWidthClass.expanded => 20.0,
    };
    return (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
  }

  /// STORY CARD SUMMARY: 13–15, weight 400.
  TextStyle storyCardSummary(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 13.5,
      NimonWidthClass.medium => 14.0,
      NimonWidthClass.expanded => 15.0,
    };
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
  }

  /// METADATA / SECONDARY: 12–13, weight 400–500.
  TextStyle metadata(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 12.0,
      NimonWidthClass.medium => 12.5,
      NimonWidthClass.expanded => 13.0,
    };
    return (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
  }

  /// MAIN JAPANESE READING TEXT.
  ///
  /// - Compact default: size ~22, height ~1.35–1.45
  /// - Compact dense: size ~21–22
  /// - Small mode: 24–26 (used when constraints demand)
  /// - Medium/expanded: do not scale up aggressively; keep calm density
  TextStyle readingJa(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 24.0,
      NimonWidthClass.medium => 24.5,
      NimonWidthClass.expanded => 25.0,
    };
    return (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w500,
      height: wc == NimonWidthClass.compact ? 1.40 : 1.42,
      letterSpacing: 0.02,
    );
  }

  TextStyle readingJaDense(ThemeData theme, NimonWidthClass wc) =>
      readingJa(theme, wc).copyWith(
        fontSize: wc == NimonWidthClass.compact ? 23.0 : 24.0,
        height: wc == NimonWidthClass.compact ? 1.38 : 1.40,
      );

  TextStyle readingJaSmall(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 25.0,
      NimonWidthClass.medium => 26.0,
      NimonWidthClass.expanded => 26.0,
    };
    return readingJa(theme, wc).copyWith(fontSize: size);
  }

  /// FURIGANA: 10–12, readable, secondary.
  TextStyle furigana(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 9.6,
      NimonWidthClass.medium => 10.0,
      NimonWidthClass.expanded => 10.0,
    };
    return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w500,
      height: 1.02,
      letterSpacing: 0.05,
    );
  }

  /// TRANSLATION TEXT: 14–16, medium contrast.
  TextStyle translation(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 14.5,
      NimonWidthClass.medium => 15.0,
      NimonWidthClass.expanded => 15.0,
    };
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.40,
      letterSpacing: 0.02,
    );
  }

  /// BUTTON / CHIP / LABEL: 11–14, weight 500.
  TextStyle uiLabel(ThemeData theme, NimonWidthClass wc) {
    final size = switch (wc) {
      NimonWidthClass.compact => 12.0,
      NimonWidthClass.medium => 13.0,
      NimonWidthClass.expanded => 14.0,
    };
    return (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
  }

  @override
  NimonTypography copyWith() => this;

  @override
  ThemeExtension<NimonTypography> lerp(
    ThemeExtension<NimonTypography>? other,
    double t,
  ) {
    return this;
  }
}

extension NimonTypographyX on ThemeData {
  NimonTypography get type =>
      extension<NimonTypography>() ?? NimonTypography.standard;
}

extension NimonTypographyContextX on BuildContext {
  NimonWidthClass get widthClass => NimonBreakpoints.of(this);
}
