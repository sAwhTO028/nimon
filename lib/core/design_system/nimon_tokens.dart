import 'package:flutter/material.dart';

/// Locked spacing scale: 4, 8, 12, 16, 20, 24, 32.
class NimonSpacing extends ThemeExtension<NimonSpacing> {
  final double x1;
  final double x2;
  final double x3;
  final double x4;
  final double x5;
  final double x6;
  final double x8;

  const NimonSpacing({
    this.x1 = 4,
    this.x2 = 8,
    this.x3 = 12,
    this.x4 = 16,
    this.x5 = 20,
    this.x6 = 24,
    this.x8 = 32,
  });

  static const NimonSpacing standard = NimonSpacing();

  @override
  NimonSpacing copyWith({
    double? x1,
    double? x2,
    double? x3,
    double? x4,
    double? x5,
    double? x6,
    double? x8,
  }) {
    return NimonSpacing(
      x1: x1 ?? this.x1,
      x2: x2 ?? this.x2,
      x3: x3 ?? this.x3,
      x4: x4 ?? this.x4,
      x5: x5 ?? this.x5,
      x6: x6 ?? this.x6,
      x8: x8 ?? this.x8,
    );
  }

  @override
  ThemeExtension<NimonSpacing> lerp(
    ThemeExtension<NimonSpacing>? other,
    double t,
  ) {
    if (other is! NimonSpacing) return this;
    return NimonSpacing(
      x1: lerpDouble(x1, other.x1, t),
      x2: lerpDouble(x2, other.x2, t),
      x3: lerpDouble(x3, other.x3, t),
      x4: lerpDouble(x4, other.x4, t),
      x5: lerpDouble(x5, other.x5, t),
      x6: lerpDouble(x6, other.x6, t),
      x8: lerpDouble(x8, other.x8, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Locked radius scale: 8, 12, 16, 20.
class NimonRadii extends ThemeExtension<NimonRadii> {
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const NimonRadii({
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 20,
  });

  static const NimonRadii standard = NimonRadii();

  BorderRadius radius(double v) => BorderRadius.circular(v);
  BorderRadius get radiusSm => radius(sm);
  BorderRadius get radiusMd => radius(md);
  BorderRadius get radiusLg => radius(lg);
  BorderRadius get radiusXl => radius(xl);

  @override
  NimonRadii copyWith({double? sm, double? md, double? lg, double? xl}) {
    return NimonRadii(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  ThemeExtension<NimonRadii> lerp(ThemeExtension<NimonRadii>? other, double t) {
    if (other is! NimonRadii) return this;
    return NimonRadii(
      sm: NimonSpacing.lerpDouble(sm, other.sm, t),
      md: NimonSpacing.lerpDouble(md, other.md, t),
      lg: NimonSpacing.lerpDouble(lg, other.lg, t),
      xl: NimonSpacing.lerpDouble(xl, other.xl, t),
    );
  }
}

extension NimonThemeTokensX on ThemeData {
  NimonSpacing get space => extension<NimonSpacing>() ?? NimonSpacing.standard;
  NimonRadii get radii => extension<NimonRadii>() ?? NimonRadii.standard;
}

