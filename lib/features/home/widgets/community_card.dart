import 'package:flutter/material.dart';
import '../../../models/story.dart';

/// A community card widget for the "From the Community" section
/// Shows a book cover, title, meta line, and 3 episode rows
class CommunityCard extends StatelessWidget {
  const CommunityCard({
    super.key,
    required this.community,
    this.onTap,
    this.onEpisodeTap,
  });

  final CommunityCollection community;
  final VoidCallback? onTap;
  final ValueChanged<Episode>? onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12), // tighter
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // HEADER (fixed height)
          SizedBox(
            height: 108, // fits on small phones
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    community.coverUrl,
                    width: 84,
                    height: 108,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 84,
                        height: 108,
                        color: theme.colorScheme.surfaceContainerLow,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 84,
                        height: 108,
                        color: theme.colorScheme.surfaceContainerLow,
                        child: const Center(
                          child: Icon(Icons.book, size: 24, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Title/desc/meta + Level pill
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Level
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              community.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'N2', // Static level tag
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Story Descriptions Story Descriptions Story Descriptions Story Descriptions Story Descriptions.....',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Story type – Love',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'Episodes 20',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // EPISODE ROWS (no inner scroll; exactly 3 rows)
          ...community.episodes.take(3).toList().asMap().entries.map((entry) {
            final episode = entry.value;
            return Container(
              height: 60, // compact row height
              margin: EdgeInsets.only(top: entry.key == 0 ? 0 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: InkWell(
                onTap: () => onEpisodeTap?.call(episode),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        episode.thumbnailUrl ?? 'https://picsum.photos/seed/${episode.id}/200/200',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 44,
                            height: 44,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 1),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 44,
                            height: 44,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: const Center(
                              child: Icon(Icons.play_circle_outline, size: 16, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Writer\'s Name', // Static writer name
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'EpisodeDescription EpisodeDescriptionEpisode Description EpisodeDescription.....',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Episode ${episode.index.toString().padLeft(2, '0')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }


  double _getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return (0.9 * screenWidth).clamp(0, 380).toDouble();
  }
}

/// Data model for community collections
class CommunityCollection {
  final String id;
  final String title;
  final String meta;
  final String coverUrl;
  final List<Episode> episodes;

  const CommunityCollection({
    required this.id,
    required this.title,
    required this.meta,
    required this.coverUrl,
    required this.episodes,
  });
}
