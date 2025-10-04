/// Model to represent filter state for story lists
class FilterState {
  final String? selectedLevel; // N5, N4, N3, N2, N1, or null for ALL
  final String? selectedCategory; // Love, Comedy, Horror, etc., or null for ALL
  final SortBy sortBy;

  const FilterState({
    this.selectedLevel,
    this.selectedCategory,
    this.sortBy = SortBy.newest,
  });

  /// Create a copy with updated values
  FilterState copyWith({
    String? selectedLevel,
    String? selectedCategory,
    SortBy? sortBy,
  }) {
    return FilterState(
      selectedLevel: selectedLevel,
      selectedCategory: selectedCategory,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Clear all filters
  FilterState clear() {
    return const FilterState();
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return selectedLevel != null || selectedCategory != null || sortBy != SortBy.newest;
  }

  /// Get filter count for UI display
  int get activeFilterCount {
    int count = 0;
    if (selectedLevel != null) count++;
    if (selectedCategory != null) count++;
    if (sortBy != SortBy.newest) count++;
    return count;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterState &&
        other.selectedLevel == selectedLevel &&
        other.selectedCategory == selectedCategory &&
        other.sortBy == sortBy;
  }

  @override
  int get hashCode {
    return selectedLevel.hashCode ^
        selectedCategory.hashCode ^
        sortBy.hashCode;
  }

  @override
  String toString() {
    return 'FilterState(level: $selectedLevel, category: $selectedCategory, sortBy: $sortBy)';
  }
}

/// Enum for sorting options
enum SortBy {
  newest,
  oldest,
  mostPopular,
  mostLiked,
  alphabetical,
}

extension SortByExtension on SortBy {
  String get displayName {
    switch (this) {
      case SortBy.newest:
        return 'Newest First';
      case SortBy.oldest:
        return 'Oldest First';
      case SortBy.mostPopular:
        return 'Most Popular';
      case SortBy.mostLiked:
        return 'Most Liked';
      case SortBy.alphabetical:
        return 'A-Z';
    }
  }

  String get identifier {
    switch (this) {
      case SortBy.newest:
        return 'newest';
      case SortBy.oldest:
        return 'oldest';
      case SortBy.mostPopular:
        return 'most_popular';
      case SortBy.mostLiked:
        return 'most_liked';
      case SortBy.alphabetical:
        return 'alphabetical';
    }
  }
}

