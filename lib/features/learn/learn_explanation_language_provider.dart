import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';

/// In-memory source of truth for learner explanation/support language (backed by prefs).
class LearnExplanationLanguageNotifier
    extends StateNotifier<LearnExplanationLanguage> {
  LearnExplanationLanguageNotifier() : super(LearnExplanationLanguage.english) {
    _load();
  }

  Future<void> _load() async {
    final v = await LearnExplanationLanguagePrefs.load();
    state = v;
  }

  /// Refresh from SharedPreferences (e.g. Learn hub entry).
  Future<void> reloadFromPrefs() async {
    state = await LearnExplanationLanguagePrefs.load();
  }

  Future<void> setLanguage(LearnExplanationLanguage v) async {
    await LearnExplanationLanguagePrefs.save(v);
    state = v;
  }

  /// Apply without persisting (e.g. already read from prefs elsewhere).
  void hydrate(LearnExplanationLanguage v) {
    state = v;
  }
}

final learnExplanationLanguageProvider = StateNotifierProvider<
    LearnExplanationLanguageNotifier, LearnExplanationLanguage>((ref) {
  return LearnExplanationLanguageNotifier();
});
