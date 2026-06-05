import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/core/settings/language_pair.dart';

/// Compact learning-language segment for list badges (`JA`, `EN`, or `—`).
String learningLanguageBadgeShortLabel(String? learningLanguage) {
  final t = (learningLanguage ?? '').trim().toLowerCase();
  if (!v1LearningLanguageWireCodes.contains(t)) return '—';
  return t == 'en' ? 'EN' : 'JA';
}

/// Whether [learningLanguage] was absent/invalid before [safeLearningLanguageWireCode].
bool learningLanguageBadgeIsLegacyUnset(String? learningLanguage) {
  final t = (learningLanguage ?? '').trim().toLowerCase();
  return t.isEmpty || !v1LearningLanguageWireCodes.contains(t);
}

/// Dual badge text: `learning · community` (e.g. `EN · MY`, `JA · EN`).
String languagePairBadgeShortLabel({
  String? learningLanguage,
  String? contentLocale,
}) {
  final learn = learningLanguageBadgeShortLabel(learningLanguage);
  final community = contentCommunityBadgeShortLabel(contentLocale);
  if (learn == '—' && community == '—') return '—';
  return '$learn · $community';
}

/// Accessibility label for [LanguagePairBadge].
String languagePairBadgeSemanticsLabel({
  String? learningLanguage,
  String? contentLocale,
}) {
  final learnUnset = learningLanguageBadgeIsLegacyUnset(learningLanguage);
  final learnWire = safeLearningLanguageWireCode(learningLanguage);
  final learningPart = learnUnset
      ? 'Learning language unset'
      : switch (learnWire) {
          'ja' => 'Learning language Japanese',
          'en' => 'Learning language English',
          _ => 'Learning language unset',
        };

  final communityShort = contentCommunityBadgeShortLabel(contentLocale);
  final communityPart = communityShort == '—'
      ? 'Community language unset'
      : 'Community language ${contentCommunityDisplayLabel(contentLocale)}';

  return '$learningPart. $communityPart';
}

/// Discovery feed cards: show badge when at least one dimension is known (M23A-6D-3).
bool languagePairBadgeVisibleOnDiscoverySurfaces({
  String? learningLanguage,
  String? contentLocale,
}) {
  if (normalizeContentLocaleWireCode(contentLocale) != null) return true;
  final learn = (learningLanguage ?? '').trim().toLowerCase();
  return v1LearningLanguageWireCodes.contains(learn);
}
