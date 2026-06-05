import 'package:flutter/material.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';
import 'package:nimon/ui/widgets/community_badge.dart';
import 'package:nimon/ui/widgets/language_pair_badge.dart';

/// Which compact locale chip [MonoStoryListRow] shows in the chip row.
enum MonoStoryListBadgeMode {
  none,
  community,
  languagePair,
}

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
    this.categoryText,
    this.durationText,
    this.publishBadgeText,
    this.badgeMode = MonoStoryListBadgeMode.none,
    this.showCommunityBadge = false,
    this.contentLocale,
    this.learningLanguage,
  });

  final String title;
  final String description;
  final String jlptLevel;
  final String? thumbnailUrl;

  /// When null, the overflow control is hidden (e.g. read-only public lists).
  final VoidCallback? onMenuTap;

  /// e.g. genre — shown under title for Published API rows.
  final String? categoryText;

  /// e.g. `3–5 min` when the backend provides it.
  final String? durationText;

  /// e.g. `Read only` / `Full learn` (Published Mono contract v1).
  final String? publishBadgeText;

  /// Preferred badge mode; [showCommunityBadge] maps to [MonoStoryListBadgeMode.community] when this is [MonoStoryListBadgeMode.none].
  final MonoStoryListBadgeMode badgeMode;

  /// Legacy flag — prefer [badgeMode]. Collection cards and older call sites.
  final bool showCommunityBadge;

  /// `en` | `my` | `ja`; used by community or language-pair badges.
  final String? contentLocale;

  /// `ja` | `en`; used when [badgeMode] is [MonoStoryListBadgeMode.languagePair].
  final String? learningLanguage;

  MonoStoryListBadgeMode get _effectiveBadgeMode {
    if (badgeMode != MonoStoryListBadgeMode.none) return badgeMode;
    if (showCommunityBadge) return MonoStoryListBadgeMode.community;
    return MonoStoryListBadgeMode.none;
  }

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
                if (_effectiveBadgeMode != MonoStoryListBadgeMode.none ||
                    (publishBadgeText != null &&
                        publishBadgeText!.trim().isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_effectiveBadgeMode ==
                          MonoStoryListBadgeMode.community)
                        CommunityBadge(contentLocale: contentLocale),
                      if (_effectiveBadgeMode ==
                          MonoStoryListBadgeMode.languagePair)
                        LanguagePairBadge(
                          learningLanguage: learningLanguage,
                          contentLocale: contentLocale,
                        ),
                      if (publishBadgeText != null &&
                          publishBadgeText!.trim().isNotEmpty)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: onVar.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              publishBadgeText!.trim(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: onVar.withValues(alpha: 0.85),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if ((categoryText != null && categoryText!.trim().isNotEmpty) ||
                    (durationText != null &&
                        durationText!.trim().isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (categoryText != null &&
                          categoryText!.trim().isNotEmpty)
                        categoryText!.trim(),
                      if (durationText != null &&
                          durationText!.trim().isNotEmpty)
                        durationText!.trim(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onVar.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
