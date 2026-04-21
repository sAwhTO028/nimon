import 'package:shared_preferences/shared_preferences.dart';

/// Which single language to use for learner-facing meanings (e.g. transcript gloss).
enum LearnExplanationLanguage {
  english,
  myanmar,
}

/// Persisted preference for Learn flows. Default: English.
abstract final class LearnExplanationLanguagePrefs {
  LearnExplanationLanguagePrefs._();

  static const _key = 'nimon_learn_explanation_language';

  static LearnExplanationLanguage decode(String? stored) {
    if (stored == 'my') return LearnExplanationLanguage.myanmar;
    return LearnExplanationLanguage.english;
  }

  static String encode(LearnExplanationLanguage v) =>
      v == LearnExplanationLanguage.myanmar ? 'my' : 'en';

  static Future<LearnExplanationLanguage> load() async {
    final p = await SharedPreferences.getInstance();
    return decode(p.getString(_key));
  }

  static Future<void> save(LearnExplanationLanguage v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, encode(v));
  }
}
