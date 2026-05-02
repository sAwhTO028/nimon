import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

class NimonMetadataRow extends StatelessWidget {
  final String? levelLabel;
  final String? readingTimeLabel;
  final String? typeLabel;
  final Widget? trailing;

  const NimonMetadataRow({
    super.key,
    this.levelLabel,
    this.readingTimeLabel,
    this.typeLabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wc = NimonBreakpoints.of(context);
    final s = theme.space;
    final r = theme.radii;
    final type = theme.type;

    final metaStyle = type.metadata(theme, wc).copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
    );

    Widget pill(String text) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: s.x2, vertical: s.x1),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: r.radiusSm,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final parts = <Widget>[];
    if ((levelLabel ?? '').trim().isNotEmpty) parts.add(pill(levelLabel!.trim()));
    if ((readingTimeLabel ?? '').trim().isNotEmpty) {
      parts.add(Text(readingTimeLabel!.trim(), style: metaStyle));
    }
    if ((typeLabel ?? '').trim().isNotEmpty) {
      parts.add(Text(typeLabel!.trim(), style: metaStyle));
    }

    return Row(
      children: [
        Flexible(
          child: Wrap(
            spacing: s.x2,
            runSpacing: s.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: parts,
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: s.x2),
          trailing!,
        ],
      ],
    );
  }
}

