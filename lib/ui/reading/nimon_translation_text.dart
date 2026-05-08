import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

class NimonTranslationText extends StatelessWidget {
  final String text;
  final int? maxLines;

  const NimonTranslationText({
    super.key,
    required this.text,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wc = NimonBreakpoints.of(context);
    final s = theme.space;
    final type = theme.type;

    final style = type.translation(theme, wc).copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
        );

    return Padding(
      padding: EdgeInsets.only(top: s.x1),
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow:
            maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
      ),
    );
  }
}
