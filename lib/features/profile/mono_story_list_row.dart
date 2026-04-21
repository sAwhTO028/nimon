import 'package:flutter/material.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';

/// Thumbnail size for [MonoStoryListRow] (profile, public profile, collections, etc.).
const double kMonoStoryListThumbSize = 76;

/// Corner radius for the thumbnail in [MonoStoryListRow].
const double kMonoStoryListThumbRadius = 12;

/// Shared lightweight mono story row: thumb + JLPT badge, title + description, optional overflow menu.
///
/// No chevron, no bottom metadata footer. Parent owns tap (e.g. [InkWell] wrapper).
class MonoStoryListRow extends StatelessWidget {
  const MonoStoryListRow({
    super.key,
    required this.title,
    required this.description,
    required this.jlptLevel,
    this.thumbnailUrl,
    this.onMenuTap,
  });

  final String title;
  final String description;
  final String jlptLevel;
  final String? thumbnailUrl;

  /// When null, the overflow control is hidden (e.g. read-only public lists).
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onVar = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PublicStoryThumb(
            thumbnailUrl: thumbnailUrl,
            jlptLevel: jlptLevel,
            size: kMonoStoryListThumbSize,
            borderRadius: kMonoStoryListThumbRadius,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (onMenuTap != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 22,
                          color: onVar.withValues(alpha: 0.72),
                        ),
                        onPressed: onMenuTap,
                        tooltip: 'More',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onVar.withValues(alpha: 0.88),
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
