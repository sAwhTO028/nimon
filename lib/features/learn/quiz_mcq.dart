import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/features/learn/quiz_session.dart';

/// One multiple-choice question for the shared V1 quiz engine.
class QuizMcqItem {
  const QuizMcqItem({
    required this.id,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.explanationMy,
    this.sourceStoryId,
  }) : assert(correctIndex >= 0 && correctIndex < 4);

  final String id;
  final LearnQuizCategory category;
  final String prompt;

  /// Four choices; [correctIndex] is the only correct one.
  final List<String> options;
  final int correctIndex;

  final String? explanation;

  /// Optional Myanmar explanation (English uses [explanation] when present).
  final String? explanationMy;

  final String? sourceStoryId;

  String? explanationForLearner(LearnExplanationLanguage lang) {
    return pickSupportText(lang, en: explanation, my: explanationMy);
  }
}
