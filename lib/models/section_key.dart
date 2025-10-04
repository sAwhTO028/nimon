/// Enum to identify different sections for navigation and data loading
enum SectionKey {
  continueReading,
  recommendStories,
  trendingForYou,
  fromTheCommunity,
  popularMonoCollections,
  newWritersSpotlight,
  topCharts,
  readingChallenges,
}

extension SectionKeyExtension on SectionKey {
  /// Get the display title for each section
  String get title {
    switch (this) {
      case SectionKey.continueReading:
        return 'Continue Reading';
      case SectionKey.recommendStories:
        return 'Recommend Stories';
      case SectionKey.trendingForYou:
        return 'Trending For You';
      case SectionKey.fromTheCommunity:
        return 'From the Community';
      case SectionKey.popularMonoCollections:
        return "Popular Mono Writer's Collections";
      case SectionKey.newWritersSpotlight:
        return 'New Writers Spotlight';
      case SectionKey.topCharts:
        return 'Top Charts';
      case SectionKey.readingChallenges:
        return 'Reading Challenges';
    }
  }

  /// Get the API/data identifier for each section
  String get identifier {
    switch (this) {
      case SectionKey.continueReading:
        return 'continue_reading';
      case SectionKey.recommendStories:
        return 'recommend_stories';
      case SectionKey.trendingForYou:
        return 'trending_for_you';
      case SectionKey.fromTheCommunity:
        return 'from_the_community';
      case SectionKey.popularMonoCollections:
        return 'popular_mono_collections';
      case SectionKey.newWritersSpotlight:
        return 'new_writers_spotlight';
      case SectionKey.topCharts:
        return 'top_charts';
      case SectionKey.readingChallenges:
        return 'reading_challenges';
    }
  }

  /// Check if section supports "See More" functionality
  bool get supportsSeeMore {
    switch (this) {
      case SectionKey.continueReading:
        return true;
      case SectionKey.recommendStories:
        return true;
      case SectionKey.trendingForYou:
        return true;
      case SectionKey.fromTheCommunity:
        return true;
      case SectionKey.popularMonoCollections:
        return false; // No see more as per requirements
      case SectionKey.newWritersSpotlight:
        return false; // No see more as per requirements
      case SectionKey.topCharts:
        return true;
      case SectionKey.readingChallenges:
        return false; // No see more as per requirements
    }
  }
}

