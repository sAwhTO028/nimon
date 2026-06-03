// -----------------------------------------------------------------------------
// Story Basics category dropdown values (display label == stored value).
// -----------------------------------------------------------------------------

/// Canonical category strings for [CreateStoryBasicsForm] and [StoryBasics.category].
const List<String> kStoryBasicsCategoryOptions = [
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

/// Generator / import labels → canonical [kStoryBasicsCategoryOptions] value.
const Map<String, String> kImportedStoryBasicsCategoryAliases = {
  'daily life': 'Cultural',
  'daily_life': 'Cultural',
  'daily-life': 'Cultural',
  'school': 'Cultural',
  'work': 'Business',
  'travel': 'Adventure',
  'food': 'Cultural',
  'friendship': 'Love',
  'family': 'Drama',
};

String _normalizeCategoryLookupKey(String raw) {
  return raw.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
}

/// Returns a canonical option when [raw] matches exactly or case-insensitively.
String? _canonicalStoryBasicsCategory(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (kStoryBasicsCategoryOptions.contains(trimmed)) return trimmed;
  final lower = trimmed.toLowerCase();
  for (final option in kStoryBasicsCategoryOptions) {
    if (option.toLowerCase() == lower) return option;
  }
  return null;
}

/// Maps imported AI/generator category text to a stored dropdown value, or `''` if unknown.
String normalizeImportedStoryBasicsCategory(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return '';

  final canonical = _canonicalStoryBasicsCategory(trimmed);
  if (canonical != null) return canonical;

  final aliasKey = _normalizeCategoryLookupKey(trimmed);
  final mapped = kImportedStoryBasicsCategoryAliases[aliasKey];
  if (mapped != null && kStoryBasicsCategoryOptions.contains(mapped)) {
    return mapped;
  }

  return '';
}

/// Value safe for [DropdownButtonFormField] — `null` when not in [kStoryBasicsCategoryOptions].
String? storyBasicsCategoryDropdownValue(String? stored) {
  final trimmed = (stored ?? '').trim();
  if (trimmed.isEmpty) return null;
  return _canonicalStoryBasicsCategory(trimmed);
}
