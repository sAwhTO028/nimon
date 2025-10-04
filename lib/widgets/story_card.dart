import 'package:flutter/material.dart';
import '../models/story.dart';

/// Reusable story card widget for consistent story display across the app
class StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback? onTap;
  final String? heroTag;
  final bool showStats;

  const StoryCard({
    super.key,
    required this.story,
    this.onTap,
    this.heroTag,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Story cover image
            _buildCoverImage(context),
            
            // Story details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    story.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Author and level
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Author Name', // TODO: Add author field to Story model
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // JLPT Level chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getLevelColor(story.jlptLevel, theme),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          story.jlptLevel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (showStats) ...[
                    const SizedBox(height: 12),
                    
                    // Stats row
                    Row(
                      children: [
                        // Likes
                        Icon(
                          Icons.favorite_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(story.likes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Episodes count
                        Icon(
                          Icons.library_books_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Episodes', // TODO: Add episode count to Story model
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            story.tags.isNotEmpty ? story.tags.first : 'General',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget imageWidget = Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
      ),
      child: story.coverUrl != null
          ? Image.network(
              story.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder(theme);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildPlaceholder(theme);
              },
            )
          : _buildPlaceholder(theme),
    );

    // Wrap with Hero if heroTag is provided
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.book,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  Color _getLevelColor(String level, ThemeData theme) {
    switch (level.toUpperCase()) {
      case 'N5':
        return Colors.green;
      case 'N4':
        return Colors.blue;
      case 'N3':
        return Colors.orange;
      case 'N2':
        return Colors.red;
      case 'N1':
        return Colors.purple;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
