import 'package:flutter/material.dart';

/// Warm paper used only in **light** mode for learn hub / list screens.
const Color learnModuleLightPaperBackground = Color(0xFFF6F3EA);

/// Page scaffold background: warm paper in light, [ColorScheme.surface] in dark.
Color learnModuleListPageBackground(BuildContext context) {
  final t = Theme.of(context);
  return t.brightness == Brightness.dark
      ? t.colorScheme.surface
      : learnModuleLightPaperBackground;
}

/// Card / panel fill on list pages (vocab, grammar, learn hub tiles).
Color learnModuleListCardFill(BuildContext context) {
  final t = Theme.of(context);
  final cs = t.colorScheme;
  if (t.brightness == Brightness.dark) {
    return cs.surfaceContainerHigh;
  }
  return Colors.white.withValues(alpha: 0.86);
}

/// Hairline border for list cards and stat pills.
Color learnModuleListCardBorder(BuildContext context) {
  final t = Theme.of(context);
  final cs = t.colorScheme;
  return cs.outlineVariant.withValues(
    alpha: t.brightness == Brightness.dark ? 0.55 : 0.28,
  );
}
