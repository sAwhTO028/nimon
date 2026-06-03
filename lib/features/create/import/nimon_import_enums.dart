// -----------------------------------------------------------------------------
// AI JSON import contract — enums (not [CreatorStoryV1] wire types).
//
// Parsed AI files use human-oriented labels in metadata (e.g. "Japanese",
// "Burmese"). A future validator maps these to app settings; a future mapper
// builds [CreatorStoryV1]. Never call [CreatorStoryV1.fromJson] on raw AI JSON.
// -----------------------------------------------------------------------------

/// Target publish mode declared in import metadata.
enum NimonImportKind {
  readOnly,
  fullLearn,
  unknown,
}

/// Learning language declared in import metadata.
///
/// The app currently supports Japanese learning only; [english] exists for
/// forward compatibility and will be rejected by the import validator later.
enum NimonLearningLanguage {
  japanese,
  english,
  unknown,
}

/// Content community declared in import metadata (JSON field: `contentCommunity`).
///
/// This is **not** the same as [UserPreferences.contentLocale], but values map
/// 1:1 after normalization:
/// - [burmese] → `my`
/// - [english] → `en` (International / English community in Settings)
/// - [japanese] → `ja`
enum NimonContentCommunity {
  /// Canonical: Myanmar community (legacy alias: "Burmese").
  ///
  /// Note: enum name kept for wire stability; JSON should prefer "Myanmar".
  burmese,
  english,
  japanese,
  unknown,
}

/// Generator tab / mode hint from import metadata (`promptDataTab`).
enum NimonPromptDataTab {
  manualMode,
  aiMode,
  unknown,
}

/// Severity for [NimonImportIssue] (import pipeline only).
enum NimonImportIssueSeverity {
  info,
  warning,
  blocking,
}

// -----------------------------------------------------------------------------
// String normalization + enum parsing (model-level only; no business validation)
// -----------------------------------------------------------------------------

String nimonImportNormalizeToken(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '';
  return t
      .toLowerCase()
      .replaceAll('/', '_')
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

NimonImportKind nimonImportKindFromString(String? raw) {
  final k = nimonImportNormalizeToken(raw);
  if (k.isEmpty) return NimonImportKind.unknown;
  if (k == 'read_only_v1' ||
      k == 'read_only' ||
      k == 'reading_only' ||
      k == 'readonly' ||
      k == 'read_only_publish') {
    return NimonImportKind.readOnly;
  }
  if (k == 'full_learn_v1' ||
      k == 'full_learn' ||
      k == 'fulllearn' ||
      k == 'full_learn_publish') {
    return NimonImportKind.fullLearn;
  }
  return NimonImportKind.unknown;
}

NimonLearningLanguage nimonLearningLanguageFromString(String? raw) {
  final k = nimonImportNormalizeToken(raw);
  if (k.isEmpty) return NimonLearningLanguage.unknown;
  if (k == 'japanese' || k == 'ja' || k == 'jp') {
    return NimonLearningLanguage.japanese;
  }
  if (k == 'english' || k == 'en') {
    return NimonLearningLanguage.english;
  }
  return NimonLearningLanguage.unknown;
}

NimonContentCommunity nimonContentCommunityFromString(String? raw) {
  final k = nimonImportNormalizeToken(raw);
  if (k.isEmpty) return NimonContentCommunity.unknown;
  // Canonical: Myanmar (legacy alias: Burmese).
  if (k == 'myanmar' || k == 'burmese' || k == 'my') {
    return NimonContentCommunity.burmese;
  }
  if (k == 'english' ||
      k == 'en' ||
      k == 'international' ||
      k == 'international_english' ||
      (k.contains('international') && k.contains('english'))) {
    return NimonContentCommunity.english;
  }
  if (k == 'japanese' || k == 'ja' || k == 'jp') {
    return NimonContentCommunity.japanese;
  }
  return NimonContentCommunity.unknown;
}

NimonPromptDataTab nimonPromptDataTabFromString(String? raw) {
  final k = nimonImportNormalizeToken(raw);
  if (k.isEmpty) return NimonPromptDataTab.unknown;
  if (k == 'manual_mode' || k == 'manual' || k == 'manualmode') {
    return NimonPromptDataTab.manualMode;
  }
  if (k == 'ai_mode' || k == 'ai' || k == 'aimode') {
    return NimonPromptDataTab.aiMode;
  }
  return NimonPromptDataTab.unknown;
}

// -----------------------------------------------------------------------------
// Debug / wire labels
// -----------------------------------------------------------------------------

extension NimonImportKindLabels on NimonImportKind {
  /// Backend-style publish kind string when known.
  String? get wirePublishKind => switch (this) {
        NimonImportKind.readOnly => 'read_only_v1',
        NimonImportKind.fullLearn => 'full_learn_v1',
        NimonImportKind.unknown => null,
      };

  String get debugLabel => switch (this) {
        NimonImportKind.readOnly => 'readOnly',
        NimonImportKind.fullLearn => 'fullLearn',
        NimonImportKind.unknown => 'unknown',
      };
}

extension NimonLearningLanguageLabels on NimonLearningLanguage {
  /// App [UserPreferences.learningLanguage] wire code when known (`ja` today).
  String? get preferencesWireCode => switch (this) {
        NimonLearningLanguage.japanese => 'ja',
        NimonLearningLanguage.english => 'en',
        NimonLearningLanguage.unknown => null,
      };

  String get debugLabel => switch (this) {
        NimonLearningLanguage.japanese => 'japanese',
        NimonLearningLanguage.english => 'english',
        NimonLearningLanguage.unknown => 'unknown',
      };
}

extension NimonContentCommunityLabels on NimonContentCommunity {
  /// Maps JSON `contentCommunity` to Settings [UserPreferences.contentLocale].
  String? get contentLocaleWireCode => switch (this) {
        NimonContentCommunity.burmese => 'my',
        NimonContentCommunity.english => 'en',
        NimonContentCommunity.japanese => 'ja',
        NimonContentCommunity.unknown => null,
      };

  String get debugLabel => switch (this) {
        NimonContentCommunity.burmese => 'burmese',
        NimonContentCommunity.english => 'english',
        NimonContentCommunity.japanese => 'japanese',
        NimonContentCommunity.unknown => 'unknown',
      };
}

extension NimonPromptDataTabLabels on NimonPromptDataTab {
  String get debugLabel => switch (this) {
        NimonPromptDataTab.manualMode => 'manualMode',
        NimonPromptDataTab.aiMode => 'aiMode',
        NimonPromptDataTab.unknown => 'unknown',
      };
}
