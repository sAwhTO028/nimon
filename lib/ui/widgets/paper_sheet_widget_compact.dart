import 'package:flutter/material.dart';
import 'paper_sheet_widget.dart';

class PaperSheetWidgetCompact extends StatelessWidget {
  final String level;
  final String title;
  final String storyName;
  final String contextText;
  final String duration;
  final String? thumbnailUrl;
  final PaperSheetState state;
  final VoidCallback? onSelect;

  const PaperSheetWidgetCompact({
    super.key,
    this.level = '',
    this.title = 'DEMO TITLE NAME',
    this.storyName = '',
    this.contextText = '',
    this.duration = '',
    this.thumbnailUrl,
    this.state = PaperSheetState.empty,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = state == PaperSheetState.selected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Target sizing: 50% of parent content width, max 200dp, min 150dp (smaller size)
    final contentWidth = screenWidth - 32; // Account for 16dp padding on each side
    final cardWidth = (contentWidth * 0.5).clamp(150.0, 200.0);
    // Book cover aspect ratio: more square-ish like a typical book cover (3:4)
    final cardHeight = (cardWidth * 1.33).clamp(150.0, 200.0);
    
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF3B82F6)
                : (isDark ? Colors.grey.shade700 : const Color(0xCC222222)), // 80% opacity
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Level badge (top-right)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (level.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 6),
                      child: Text(
                        level,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF111111),
                        ),
                      ),
                    ),
                ],
              ),
              
              // Title (centered)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF111111),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                child: _buildThumbnail(isDark),
              ),
              const SizedBox(height: 6),
              
              // Story name
              if (storyName.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      storyName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD94C4C),
                      ),
                    ),
                  ),
                ),
              
              // Context
              if (contextText.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Context: $contextText',
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.2,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF444444),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              // Duration
              if (duration.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Duration: $duration',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.grey.shade500 : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              
              const Spacer(),
              
              // Footer label
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'One-Short paper',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.grey.shade500 : const Color(0xFF777777),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(bool isDark) {
    if (state == PaperSheetState.loading) {
      return _buildShimmerSkeleton();
    }

    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          thumbnailUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildCategoryPlaceholder();
          },
        ),
      );
    }

    return _buildCategoryPlaceholder();
  }

  Widget _buildShimmerSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildCategoryPlaceholder() {
    // Map story name to category for placeholder (matching home page categories)
    String category = 'General';
    if (storyName.toLowerCase().contains('love') || 
        storyName.toLowerCase().contains('rainy') ||
        storyName.toLowerCase().contains('snow')) {
      category = 'Love';
    } else if (storyName.toLowerCase().contains('comedy')) {
      category = 'Comedy';
    } else if (storyName.toLowerCase().contains('horror')) {
      category = 'Horror';
    } else if (storyName.toLowerCase().contains('cultural')) {
      category = 'Cultural';
    } else if (storyName.toLowerCase().contains('adventure')) {
      category = 'Adventure';
    } else if (storyName.toLowerCase().contains('fantasy')) {
      category = 'Fantasy';
    } else if (storyName.toLowerCase().contains('drama')) {
      category = 'Drama';
    } else if (storyName.toLowerCase().contains('business')) {
      category = 'Business';
    } else if (storyName.toLowerCase().contains('sci-fi') || storyName.toLowerCase().contains('scifi')) {
      category = 'Sci-Fi';
    } else if (storyName.toLowerCase().contains('mystery')) {
      category = 'Mystery';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getCategoryColors(category),
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  List<Color> _getCategoryColors(String category) {
    switch (category.toLowerCase()) {
      case 'love':
        return [const Color(0xFFFF69B4), const Color(0xFF9370DB)];
      case 'comedy':
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
      case 'horror':
        return [const Color(0xFF8B0000), const Color(0xFF2F2F2F)];
      case 'cultural':
        return [const Color(0xFF9370DB), const Color(0xFF4169E1)];
      case 'adventure':
        return [const Color(0xFF228B22), const Color(0xFF32CD32)];
      case 'fantasy':
        return [const Color(0xFF9932CC), const Color(0xFFDA70D6)];
      case 'drama':
        return [const Color(0xFF8B4513), const Color(0xFFD2691E)];
      case 'business':
        return [const Color(0xFF4169E1), const Color(0xFF87CEEB)];
      case 'sci-fi':
        return [const Color(0xFF00CED1), const Color(0xFF20B2AA)];
      case 'mystery':
        return [const Color(0xFF2F4F4F), const Color(0xFF708090)];
      default:
        return [const Color(0xFF6A6A6A), const Color(0xFF8A8A8A)];
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'love':
        return Icons.favorite;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      case 'horror':
        return Icons.warning;
      case 'cultural':
        return Icons.palette;
      case 'adventure':
        return Icons.explore;
      case 'fantasy':
        return Icons.auto_awesome;
      case 'drama':
        return Icons.theater_comedy;
      case 'business':
        return Icons.business;
      case 'sci-fi':
        return Icons.rocket_launch;
      case 'mystery':
        return Icons.psychology;
      default:
        return Icons.image;
    }
  }
}
