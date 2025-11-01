import 'package:flutter/material.dart';

enum PaperSheetState { loading, empty, filled, selected }

class PaperSheetWidget extends StatelessWidget {
  final String level;
  final String title;
  final String storyName;
  final String contextText;
  final String duration;
  final String? thumbnailUrl;
  final PaperSheetState state;
  final VoidCallback? onSelect;

  const PaperSheetWidget({
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
    
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        width: 250,
        height: 333, // 3:4 aspect ratio
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF3B82F6)
                : (isDark ? Colors.grey.shade700 : const Color(0x80222222)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              // Level badge (top-right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (level.isNotEmpty)
                    Text(
                            level,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF111111),
                          ),
                        ),
                    ],
                  ),
              const SizedBox(height: 4),
              
              // Title (centered)
              Text(
                      title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.26, // +2%
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF111111),
                      ),
                      textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Thumbnail
              Container(
                width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                      child: _buildThumbnail(isDark),
                    ),
              const SizedBox(height: 8),
                  
              // Story name
                  if (storyName.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      storyName,
                      style: const TextStyle(
                      fontSize: 12,
                        fontWeight: FontWeight.w600,
                      color: Color(0xFFD94C4C),
                    ),
                  ),
                ),
              if (storyName.isNotEmpty) const SizedBox(height: 8),
                  
              // Context
                  if (contextText.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Context: $contextText',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF444444),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (contextText.isNotEmpty) const SizedBox(height: 6),
              
              // Duration
              if (duration.isNotEmpty)
                  Align(
                  alignment: Alignment.centerLeft,
                    child: Text(
                    'Duration: $duration',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : const Color(0xFF666666),
                    ),
                  ),
                ),
              
              const Spacer(),
              
              // Footer label
              Text(
                'One-Short paper',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : const Color(0xFF6A6A6A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(bool isDark) {
    if (state == PaperSheetState.loading) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          thumbnailUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildCategoryPlaceholder();
          },
        ),
      );
    }

    return _buildCategoryPlaceholder();
  }

  Widget _buildCategoryPlaceholder() {
    // Map story name to category for placeholder
    String category = 'General';
    if (storyName.toLowerCase().contains('love') || 
        storyName.toLowerCase().contains('rainy') ||
        storyName.toLowerCase().contains('snow')) {
      category = 'Love';
    } else if (storyName.toLowerCase().contains('comedy')) {
      category = 'Comedy';
    } else if (storyName.toLowerCase().contains('horror')) {
      category = 'Horror';
    } else if (storyName.toLowerCase().contains('art')) {
      category = 'Art';
    } else if (storyName.toLowerCase().contains('history')) {
      category = 'History';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getCategoryColors(category),
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 32,
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
      case 'art':
        return [const Color(0xFF9370DB), const Color(0xFF4169E1)];
      case 'history':
        return [const Color(0xFF8B4513), const Color(0xFFD2691E)];
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
      case 'art':
        return Icons.palette;
      case 'history':
        return Icons.history_edu;
      default:
        return Icons.image;
    }
  }
}
