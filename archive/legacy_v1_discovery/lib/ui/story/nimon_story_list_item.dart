import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';
import 'package:nimon/ui/widgets/nimon_metadata_row.dart';

class NimonStoryListItem extends StatelessWidget {
  final String title;
  final String? summary;
  final String? levelLabel;
  final String? readingTimeLabel;
  final String? typeLabel;
  final double? progress; // 0..1
  final ImageProvider? thumbnail;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const NimonStoryListItem({
    super.key,
    required this.title,
    this.summary,
    this.levelLabel,
    this.readingTimeLabel,
    this.typeLabel,
    this.progress,
    this.thumbnail,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wc = NimonBreakpoints.of(context);
    final s = theme.space;
    final r = theme.radii;
    final type = theme.type;

    final titleStyle = type.storyCardTitle(theme, wc).copyWith(
          color: theme.colorScheme.onSurface,
        );
    final summaryStyle = type.storyCardSummary(theme, wc).copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
        );

    final thumbW = wc == NimonWidthClass.compact ? 108.0 : 124.0;
    final thumbH = wc == NimonWidthClass.compact ? 72.0 : 82.0;

    final child = Padding(
      padding: EdgeInsets.all(s.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: r.radiusLg,
            child: Container(
              width: thumbW,
              height: thumbH,
              color: theme.colorScheme.surfaceContainerHighest,
              child: thumbnail != null
                  ? Image(
                      image: thumbnail!,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.menu_book_outlined,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      size: 28,
                    ),
            ),
          ),
          SizedBox(width: s.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onMore != null)
                      IconButton(
                        onPressed: onMore,
                        icon: const Icon(Icons.more_vert),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'More',
                      ),
                  ],
                ),
                if ((summary ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: s.x1),
                  Text(
                    summary!.trim(),
                    style: summaryStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: s.x2),
                NimonMetadataRow(
                  levelLabel: levelLabel,
                  readingTimeLabel: readingTimeLabel,
                  typeLabel: typeLabel,
                ),
                if (progress != null) ...[
                  SizedBox(height: s.x2),
                  ClipRRect(
                    borderRadius: r.radiusSm,
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: r.radiusXl,
        child: child,
      ),
    );
  }
}
