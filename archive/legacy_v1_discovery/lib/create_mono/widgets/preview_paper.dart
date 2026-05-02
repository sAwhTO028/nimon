import 'package:flutter/material.dart';

class PreviewPaper extends StatelessWidget {
  final String jlpt;
  final String? category;
  final String? promptId;
  final String title;

  const PreviewPaper({
    super.key,
    required this.jlpt,
    this.category,
    this.promptId,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top-right badge
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (jlpt.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'N$jlpt',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Image and content
          Row(
            children: [
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildCategoryImage(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'DEMO TITLE NAME' : title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (promptId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getPromptTitle(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Context: ${_getContextText()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Duration: ${_getDuration()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'One-Short paper',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryImage() {
    if (category == null) {
      return const Icon(Icons.image, color: Colors.grey, size: 32);
    }

    // Map categories to image assets
    final imageMap = {
      'Love': 'assets/images/one_short/love.png',
      'Comedy': 'assets/images/one_short/comedy.png',
      'Horror': 'assets/images/one_short/horror.png',
      'Art': 'assets/images/one_short/art.png',
      'History': 'assets/images/one_short/history.png',
    };

    final imagePath = imageMap[category];
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          width: 80,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.image, color: Colors.grey, size: 32);
          },
        ),
      );
    }

    return const Icon(Icons.image, color: Colors.grey, size: 32);
  }

  String _getPromptTitle() {
    switch (promptId) {
      case 'rainy_day_promise':
        return 'Theme – RAINY DAY PROMISE';
      case 'first_snow_train':
        return 'Theme – FIRST SNOW, LAST TRAIN';
      default:
        return '';
    }
  }

  String _getContextText() {
    switch (promptId) {
      case 'rainy_day_promise':
        return 'Two old friends meet again at a bus stop on a rainy afternoon in Tokyo.';
      case 'first_snow_train':
        return 'Two people miss the last train home and walk together through the first snow of the season.';
      default:
        return 'Select a prompt to see the story context here.';
    }
  }

  String _getDuration() {
    switch (promptId) {
      case 'rainy_day_promise':
        return '4–6 minutes';
      case 'first_snow_train':
        return '6–8 minutes';
      default:
        return 'Duration will appear here';
    }
  }
}
