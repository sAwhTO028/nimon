// V1 language pair rules — community (`contentLocale`) vs learning target.

import 'package:nimon/core/settings/content_community.dart';

/// V1 learning-language wire codes (must match backend `V1_LEARNING_LANGUAGES`).
const Set<String> v1LearningLanguageWireCodes = {'ja', 'en'};

const String _defaultLearningLanguageWire = 'ja';

/// Normalizes stored/API learning language to `ja` or `en`; unknown → `ja`.
String safeLearningLanguageWireCode(String? raw) {
  final t = (raw ?? '').trim().toLowerCase();
  if (v1LearningLanguageWireCodes.contains(t)) return t;
  return _defaultLearningLanguageWire;
}

/// Whether Japanese-specific rules (furigana / kana reading) apply at publish time.
///
/// Only explicit `en` opts out. `null`, empty, `ja`, and unknown codes keep furigana
/// validation so legacy drafts without a stored tag behave as today.
bool isJapaneseLearningWireCode(String? raw) {
  final t = (raw ?? '').trim().toLowerCase();
  if (t == 'en') return false;
  return true;
}

/// Returns true when [contentLocale] and [learningLanguage] are both set and equal.
bool isSameLanguagePair({
  required String contentLocale,
  required String learningLanguage,
}) {
  final community =
      normalizeContentLocaleWireCode(contentLocale) ?? contentLocale.trim();
  final learning = learningLanguage.trim().toLowerCase();
  if (community.isEmpty || learning.isEmpty) return false;
  return community == learning;
}

/// User-visible message when Settings would create an invalid pair.
String languagePairBlockedMessage() =>
    'Content community and learning language must be different.';
