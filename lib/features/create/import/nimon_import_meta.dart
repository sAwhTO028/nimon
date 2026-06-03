import 'package:nimon/features/create/import/nimon_import_enums.dart';

// -----------------------------------------------------------------------------
// `nimonImportMeta` — AI generator metadata (import contract only).
//
// This object lives on AI-exported JSON. It is validated against app context
// (learning language, content community, signed-in user email) before mapping.
// It is not stored as-is on [CreatorStoryV1].
// -----------------------------------------------------------------------------

/// Metadata block at `nimonImportMeta` in AI-generated import JSON.
class NimonImportMeta {
  const NimonImportMeta({
    this.schemaVersion,
    this.generatorVersion,
    this.learningLanguage = NimonLearningLanguage.unknown,
    this.contentCommunity = NimonContentCommunity.unknown,
    this.promptDataTab = NimonPromptDataTab.unknown,
    this.importKind = NimonImportKind.unknown,
    this.createdForEmail,
    this.learningLanguageRaw,
    this.contentCommunityRaw,
    this.promptDataTabRaw,
    this.publishKindRaw,
  });

  final int? schemaVersion;
  final String? generatorVersion;

  /// Parsed from JSON `learningLanguage` (e.g. `"Japanese"`).
  final NimonLearningLanguage learningLanguage;

  /// Parsed from JSON `contentCommunity` (e.g. `"Myanmar"`; legacy `"Burmese"`).
  ///
  /// Compare to [UserPreferences.contentLocale] via [NimonContentCommunityLabels.contentLocaleWireCode].
  final NimonContentCommunity contentCommunity;

  final NimonPromptDataTab promptDataTab;

  /// Parsed from JSON `publishKind` (e.g. `read_only_v1`, `full_learn_v1`).
  final NimonImportKind importKind;

  /// Local UX safety check only; backend ownership uses authenticated JWT.
  final String? createdForEmail;

  /// Original strings when present (debug / error messages).
  final String? learningLanguageRaw;
  final String? contentCommunityRaw;
  final String? promptDataTabRaw;
  final String? publishKindRaw;

  /// Whether required meta fields are present enough for downstream validation.
  bool get hasRecognizedImportKind => importKind != NimonImportKind.unknown;

  bool get hasCreatedForEmail => (createdForEmail ?? '').trim().isNotEmpty;

  /// Best-effort parse from a JSON object map. Does not validate business rules.
  factory NimonImportMeta.fromJsonMap(Map<String, Object?> json) {
    final learningRaw = _optStr(json['learningLanguage']);
    final communityRaw = _optStr(json['contentCommunity']);
    final tabRaw = _optStr(json['promptDataTab']);
    final publishRaw = _optStr(json['publishKind']);

    return NimonImportMeta(
      schemaVersion: _optInt(json['schemaVersion']),
      generatorVersion: _optStr(json['generatorVersion']),
      learningLanguage: nimonLearningLanguageFromString(learningRaw),
      contentCommunity: nimonContentCommunityFromString(communityRaw),
      promptDataTab: nimonPromptDataTabFromString(tabRaw),
      importKind: nimonImportKindFromString(publishRaw),
      createdForEmail: _normalizeEmail(_optStr(json['createdForEmail'])),
      learningLanguageRaw: learningRaw.isEmpty ? null : learningRaw,
      contentCommunityRaw: communityRaw.isEmpty ? null : communityRaw,
      promptDataTabRaw: tabRaw.isEmpty ? null : tabRaw,
      publishKindRaw: publishRaw.isEmpty ? null : publishRaw,
    );
  }

  @override
  String toString() =>
      'NimonImportMeta(schemaVersion=$schemaVersion, '
      'importKind=${importKind.debugLabel}, '
      'learningLanguage=${learningLanguage.debugLabel}, '
      'contentCommunity=${contentCommunity.debugLabel} → '
      'contentLocale=${contentCommunity.contentLocaleWireCode}, '
      'promptDataTab=${promptDataTab.debugLabel}, '
      'createdForEmail=${createdForEmail == null ? 'null' : '<redacted>'})';
}

String _optStr(Object? v) {
  if (v == null) return '';
  return v.toString().trim();
}

int? _optInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

String? _normalizeEmail(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return t.toLowerCase();
}
