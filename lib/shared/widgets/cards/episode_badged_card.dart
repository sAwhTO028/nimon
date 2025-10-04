import 'package:flutter/material.dart';
import '../../../models/story.dart';
import '../../../models/episode_meta.dart';

/// Badged card widget for Episode content with top-left badge and top-right JLPT chip
class EpisodeBadgedCard extends StatelessWidget {
  const EpisodeBadgedCard({
    super.key,
    required this.episode,
    required this.story,
    this.onTap,
    this.width = 160,
  });

  final Episode episode;
  final Story story;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image area with overlays
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    // Cover image
                    ClipRRect(
                      child: AspectRatio(
                        aspectRatio: 4 / 5,
                        child: story.coverUrl != null
                            ? Image.network(
                                story.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholder(context),
                              )
                            : _buildPlaceholder(context),
                      ),
                    ),
                    
                    // Top-left badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildTypeBadge(context, 'Story Type'),
                    ),
                    
                    // Top-right JLPT chip
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildJLPTChip(context, story.jlptLevel),
                    ),
                    
                    // Bottom title band
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildTitleBand(context, episode, story),
                    ),
                  ],
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                ),
                child: Row(
                  children: [
                    // Writer avatar (using a default writer name for now)
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        'WRITER NAME'.isNotEmpty 
                            ? 'WRITER NAME'[0].toUpperCase()
                            : 'W',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Writer info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WRITER NAME',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Episode - ${episode.index}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Likes
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: colorScheme.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatLikes(story.likes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
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
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJLPTChip(BuildContext context, String jlpt) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          jlpt,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBand(BuildContext context, Episode episode, Story story) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
      ),
      child: Text(
        'Episode ${episode.index} ${story.title}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  String _formatLikes(int likes) {
    if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    }
    return likes.toString();
  }
}
