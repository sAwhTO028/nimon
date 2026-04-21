import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';

/// Reading-column standard used by text-heavy pages.
class NimonReadingColumn {
  /// Phone: full available width minus 20–24 padding.
  /// Medium: max reading width around 680–760.
  /// Expanded: max reading width around 760–860.
  static double maxWidthForClass(NimonWidthClass wc) {
    switch (wc) {
      case NimonWidthClass.compact:
        return double.infinity;
      case NimonWidthClass.medium:
        return 740;
      case NimonWidthClass.expanded:
        return 840;
    }
  }

  static EdgeInsets pagePadding(NimonWidthClass wc) {
    switch (wc) {
      case NimonWidthClass.compact:
        return const EdgeInsets.symmetric(horizontal: 20);
      case NimonWidthClass.medium:
        return const EdgeInsets.symmetric(horizontal: 24);
      case NimonWidthClass.expanded:
        return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  /// Wraps [child] into a centered, max-width reading column.
  static Widget wrap(BuildContext context, Widget child) {
    final wc = NimonBreakpoints.of(context);
    final pad = pagePadding(wc);
    final maxW = maxWidthForClass(wc);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: child,
        ),
      ),
    );
  }
}

