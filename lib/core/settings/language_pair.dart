// V1 language pair rules — community (`contentLocale`) vs learning target.

import 'package:nimon/core/settings/content_community.dart';

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
