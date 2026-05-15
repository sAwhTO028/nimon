import 'package:flutter/material.dart';
import 'package:nimon/features/profile/public_profile_data.dart';
import 'package:nimon/ui/nimon_story_cover_image.dart';

/// Thumbnail + JLPT badge for public story rows.
class PublicStoryThumb extends StatelessWidget {
  const PublicStoryThumb({
    super.key,
    required this.thumbnailUrl,
    required this.jlptLevel,
    this.size = 72,
    this.borderRadius = 12,
  });

  final String? thumbnailUrl;
  final String jlptLevel;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NimonStoryCoverImage(
              coverImageUrl: thumbnailUrl,
              width: size,
              height: size,
              borderRadius: 0,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
            ),
            Positioned(
              top: 4,
              left: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    jlptLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide rectangular preview (~16:9) — shared by [CollectionListRow].
const double kCollectionListThumbWidth = 132;

const double kCollectionListThumbHeight = 74;

const double kCollectionListThumbRadius = 10;

/// Shared collection row: stacked wide thumb, title, story count, optional
/// description, optional trailing (e.g. overflow). Parent should wrap with
/// [InkWell] / [Material] for row tap (public profile, owner Published/Saved).
class CollectionListRow extends StatelessWidget {
  const CollectionListRow({
    super.key,
    required this.title,
    required this.countLabel,
    this.description,
    this.coverImageUrl,
    this.trailing,
  });

  final String title;
  final String countLabel;
  final String? description;
  final String? coverImageUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onVar = scheme.onSurfaceVariant;
    final desc = (description ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StackedCollectionThumb(
            coverUrl: coverImageUrl,
            width: kCollectionListThumbWidth,
            height: kCollectionListThumbHeight,
            borderRadius: kCollectionListThumbRadius,
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
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      trailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onVar.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onVar.withValues(alpha: 0.82),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Playlist-inspired collection row for [PublicFolder] — uses [CollectionListRow].
///
/// Parent should wrap with [InkWell] / [Material] for tap.
class PublicCollectionListRow extends StatelessWidget {
  const PublicCollectionListRow({
    super.key,
    required this.folder,
    this.onMenuTap,
  });

  final PublicFolder folder;

  /// When null, the overflow control is hidden.
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onVar = scheme.onSurfaceVariant;
    final desc = (folder.description ?? '').trim();
    final countLabel =
        '${folder.storyCount} stor${folder.storyCount == 1 ? 'y' : 'ies'}';

    return CollectionListRow(
      title: folder.name,
      countLabel: countLabel,
      description: desc.isEmpty ? null : desc,
      coverImageUrl: folder.coverImageUrl,
      trailing: onMenuTap == null
          ? null
          : IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 22,
                color: onVar.withValues(alpha: 0.72),
              ),
              onPressed: onMenuTap,
              tooltip: 'Collection actions',
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
    );
  }
}

/// Playlist-style stack: same-size plates offset so backing layers peek at the
/// bottom-right (grouped content), distinct from a flat mono thumbnail.
class _StackedCollectionThumb extends StatelessWidget {
  const _StackedCollectionThumb({
    required this.coverUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final String? coverUrl;
  final double width;
  final double height;
  final double borderRadius;

  static const double _ox2 = 8;
  static const double _oy2 = 9;
  static const double _ox1 = 4;
  static const double _oy1 = 5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget coverFace() {
      final has = (coverUrl ?? '').trim().isNotEmpty;
      if (has) {
        return Image.network(
          coverUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _collectionPlaceholder(scheme),
        );
      }
      return _collectionPlaceholder(scheme);
    }

    final r0 = borderRadius;
    final r1 = (borderRadius - 1).clamp(4.0, borderRadius);
    final r2 = (borderRadius - 2).clamp(4.0, borderRadius);

    return SizedBox(
      width: width + _ox2,
      height: height + _oy2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _ox2,
            top: _oy2,
            child: _backPlate(
              scheme,
              width,
              height,
              r2,
            ),
          ),
          Positioned(
            left: _ox1,
            top: _oy1,
            child: _backPlate(
              scheme,
              width,
              height,
              r1,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r0),
              child: SizedBox(
                width: width,
                height: height,
                child: coverFace(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backPlate(
    ColorScheme scheme,
    double w,
    double h,
    double r,
  ) {
    final edge = scheme.outlineVariant.withValues(alpha: 0.32);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: edge, width: 1),
      ),
    );
  }

  Widget _collectionPlaceholder(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.88),
      child: Center(
        child: Icon(
          Icons.playlist_play_rounded,
          size: 34,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}
