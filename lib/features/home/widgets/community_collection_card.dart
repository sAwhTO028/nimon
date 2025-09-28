import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        // Add haptic feedback
        HapticFeedback.lightImpact();
        
        // Navigate to story details
        Navigator.pushNamed(
          context,
          '/story-details',
          arguments: {
            'title': title,
            'description': description,
            'coverUrl': coverUrl,
            'jlptLevel': jlptLevel,
            'totalEpisodes': totalEpisodes,
            'storyType': storyType,
            'episodes': episodes,
          },
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.none,
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 380, // Reduced height to prevent overflow
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with thumbnail and JLPT badge
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
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 72,
                                height: 72,
                                color: color.surfaceContainerLow,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 72,
                                height: 72,
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
                                style: theme.textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authorLine,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: color.onSurface.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // JLPT badge
                    Align(
                      alignment: Alignment.topRight,
                      child: _JlptBadge(level: jlptLevel),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Meta row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Story type – $storyType',
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      '$totalEpisodes episodes',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              // Latest Episodes section with progress indicator
              Row(
                children: [
                  Text(
                    'Latest Episodes',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  // Progress indicator showing completion
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${episodes.length}/$totalEpisodes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
                // Episodes list - use Flexible to prevent overflow
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: episodes.take(3).map((episode) => _EpisodeTile(
                      episode: episode,
                      storyTitle: title,
                      jlptLevel: jlptLevel,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 4), // Minimal bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JlptBadge extends StatelessWidget {
  final String level;

  const _JlptBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final CommunityEpisode episode;
  final String storyTitle;
  final String jlptLevel;

  const _EpisodeTile({
    required this.episode,
    required this.storyTitle,
    required this.jlptLevel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return InkWell(
      onTap: () {
        // Add haptic feedback
        HapticFeedback.selectionClick();
        
        // Navigate to reader view
        Navigator.pushNamed(
          context,
          '/reader',
          arguments: {
            'episodeTitle': episode.title,
            'episodeNumber': episode.episodeNumber,
            'thumbnailUrl': episode.thumbnailUrl,
            'storyTitle': storyTitle, // Pass the parent story title
            'jlptLevel': jlptLevel, // Pass JLPT level for context
          },
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: color.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.outline.withOpacity(0.2)),
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
            const SizedBox(width: 8),
            // Episode title
            Expanded(
              child: Text(
                episode.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // Episode number with progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: episode.episodeNumber <= 3 
                    ? color.primaryContainer 
                    : color.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: episode.episodeNumber <= 3 
                    ? null 
                    : Border.all(color: color.outline.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (episode.episodeNumber <= 3)
                    Icon(
                      Icons.play_circle_outline,
                      size: 8,
                      color: color.onPrimaryContainer,
                    ),
                  const SizedBox(width: 2),
                  Text(
                    'Ep ${episode.episodeNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: episode.episodeNumber <= 3 
                          ? color.onPrimaryContainer 
                          : color.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
