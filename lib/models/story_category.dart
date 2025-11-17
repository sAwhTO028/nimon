/// Centralized story category enum - single source of truth for all 10 categories
enum StoryCategory {
  love('Love'),
  comedy('Comedy'),
  horror('Horror'),
  cultural('Cultural'),
  adventure('Adventure'),
  fantasy('Fantasy'),
  drama('Drama'),
  business('Business'),
  sciFi('Sci-Fi'),
  mystery('Mystery');

  final String displayName;
  const StoryCategory(this.displayName);

  /// Convert from backend API string (snake_case or kebab-case)
  static StoryCategory? fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'love':
        return StoryCategory.love;
      case 'comedy':
        return StoryCategory.comedy;
      case 'horror':
        return StoryCategory.horror;
      case 'cultural':
        return StoryCategory.cultural;
      case 'adventure':
        return StoryCategory.adventure;
      case 'fantasy':
        return StoryCategory.fantasy;
      case 'drama':
        return StoryCategory.drama;
      case 'business':
        return StoryCategory.business;
      case 'sci_fi':
      case 'scifi':
        return StoryCategory.sciFi;
      case 'mystery':
        return StoryCategory.mystery;
      default:
        return null;
    }
  }

  /// Convert to backend API format (snake_case)
  String toApiString() {
    switch (this) {
      case StoryCategory.sciFi:
        return 'sci_fi';
      default:
        return name;
    }
  }

  /// Get all categories as display names (for UI lists)
  static List<String> get allDisplayNames =>
      StoryCategory.values.map((c) => c.displayName).toList();

  /// Get category from display name
  static StoryCategory? fromDisplayName(String displayName) {
    try {
      return StoryCategory.values.firstWhere(
        (c) => c.displayName == displayName,
      );
    } catch (e) {
      return null;
    }
  }
}

