import 'package:flutter/material.dart';

/// Width classes are the primary responsive rule across the app.
enum NimonWidthClass { compact, medium, expanded }

class NimonBreakpoints {
  /// COMPACT: width < 600
  static const double compactMax = 600;

  /// MEDIUM: 600 <= width < 840
  static const double mediumMax = 840;

  /// EXPANDED: width >= 840

  static NimonWidthClass ofWidth(double width) {
    if (width < compactMax) return NimonWidthClass.compact;
    if (width < mediumMax) return NimonWidthClass.medium;
    return NimonWidthClass.expanded;
  }

  static NimonWidthClass of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);
}
