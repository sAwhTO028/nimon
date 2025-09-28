import 'dart:math';
import 'package:flutter/material.dart';

class CommunityEpisode {
  final String title;
  final int episodeNumber;
  final String thumbnailUrl;

  CommunityEpisode({
    required this.title,
    required this.episodeNumber,
    required this.thumbnailUrl,
  });
}

class CommunityCollectionCard extends StatelessWidget {
  final String title; // e.g., "Myanmar Hits"
  final String authorLine; // e.g., "by Community Writers"
  final String description; // short blurb
  final String coverUrl; // book cover
  final String jlptLevel; // e.g., "N2"
  final int totalEpisodes; // e.g., 20
  final String storyType; // e.g., "Cultural", "Adventure"
  final List<CommunityEpisode> episodes;

  const CommunityCollectionCard({
    super.key,
    required this.title,
    required this.authorLine,
    required this.description,
    required this.coverUrl,
    required this.jlptLevel,
    required this.totalEpisodes,
    required this.storyType,
    required this.episodes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Material(
      color: color.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          // Handle card tap
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $title collection')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 260, // Fixed height to prevent overflow
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with cover image and JLPT badge
              Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          coverUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 70,
                              height: 70,
                              color: color.surfaceContainerLow,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 70,
                              height: 70,
                              color: color.surfaceContainerLow,
                              child: const Center(
                                child: Icon(Icons.book, size: 24, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title and description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authorLine,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                color: color.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // JLPT badge
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        jlptLevel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Story type and episodes count
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Story type – $storyType',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$totalEpisodes episodes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Latest Episodes section
              Text(
                'Latest Episodes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              // Episodes list (max 2 episodes to prevent overflow)
              Expanded(
                child: Column(
                  children: episodes.take(2).map((episode) => _EpisodeRow(episode: episode)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final CommunityEpisode episode;

  const _EpisodeRow({required this.episode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Container(
      height: 50, // Fixed height for episode row
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle episode tap
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Playing ${episode.title}')),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Episode thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    episode.thumbnailUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 36,
                        height: 36,
                        color: color.surfaceContainerLow,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 1),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 36,
                        height: 36,
                        color: color.surfaceContainerLow,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 14, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Episode title
                Expanded(
                  child: Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Episode number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Ep ${episode.episodeNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
