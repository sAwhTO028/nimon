/// Story type categories and their associated assets
class StoryCategories {
  // The 10 story type categories
  static const List<String> all = [
    'Love',
    'Comedy',
    'Horror',
    'Cultural',
    'Adventure',
    'Fantasy',
    'Drama',
    'Business',
    'Sci-Fi',
    'Mystery',
  ];

  /// Get the asset path for a category's thumbnail/icon
  /// Returns null if no asset exists yet
  static String? getCategoryImagePath(String category) {
    final categoryLower = category.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_');
    return 'assets/images/$categoryLower.png';
  }

  /// Get episode thumbnail path based on category and episode number
  /// Format: assets/images/{category}_{episodeNumber}.png
  static String? getEpisodeThumbnailPath(String category, int episodeNumber) {
    final categoryLower = category.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_');
    return 'assets/images/${categoryLower}_$episodeNumber.png';
  }

  /// Check if a category is valid
  static bool isValidCategory(String category) {
    return all.contains(category);
  }

  /// Get a fallback placeholder image path
  static String getPlaceholderPath() {
    return 'assets/images/writer.png'; // Use existing asset as placeholder
  }
}


