import 'package:nimon/features/learn/learn_explanation_language.dart';

/// Picks a single learner-facing support line: one language only, with simple fallback.
///
/// [en] / [my] are explicit; [additional] uses BCP-47-ish keys (`en`, `my`, …).
/// Preference: chosen language → the other primary → first non-empty in [additional] → null.
String? pickSupportText(
  LearnExplanationLanguage language, {
  String? en,
  String? my,
  Map<String, String>? additional,
}) {
  String? t(String? s) {
    final x = s?.trim();
    return (x == null || x.isEmpty) ? null : x;
  }

  final map = <String, String>{
    if (t(en) != null) 'en': en!.trim(),
    if (t(my) != null) 'my': my!.trim(),
    if (additional != null)
      for (final e in additional.entries)
        if (t(e.value) != null) e.key: e.value.trim(),
  };

  final primaryKey =
      language == LearnExplanationLanguage.myanmar ? 'my' : 'en';
  final secondaryKey =
      language == LearnExplanationLanguage.myanmar ? 'en' : 'my';

  if (map[primaryKey] != null && map[primaryKey]!.isNotEmpty) {
    return map[primaryKey];
  }
  if (map[secondaryKey] != null && map[secondaryKey]!.isNotEmpty) {
    return map[secondaryKey];
  }
  for (final v in map.values) {
    if (v.isNotEmpty) return v;
  }
  return null;
}
