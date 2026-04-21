/// Single-category quiz types (V1: no mixed mode).
enum LearnQuizCategory {
  vocabulary,
  kanji,
  grammar,
  sampleSentence,
}

extension LearnQuizCategoryLabel on LearnQuizCategory {
  String get displayLabel => switch (this) {
        LearnQuizCategory.vocabulary => 'Vocabulary',
        LearnQuizCategory.kanji => 'Kanji',
        LearnQuizCategory.grammar => 'Grammar',
        LearnQuizCategory.sampleSentence => 'Sample Sentence',
      };
}

/// Passed to the quiz play route when the user taps Start Quiz on setup.
class QuizSessionStartArgs {
  const QuizSessionStartArgs({
    required this.contentId,
    required this.category,
    required this.questionCount,
  });

  final String contentId;
  final LearnQuizCategory category;
  final int questionCount;
}

/// Passed to the quiz result route after the last question.
class QuizResultSummary {
  const QuizResultSummary({
    required this.contentId,
    required this.category,
    required this.correct,
    required this.wrong,
  });

  final String contentId;
  final LearnQuizCategory category;
  final int correct;
  final int wrong;

  int get total => correct + wrong;

  /// 0–100
  int get scorePercent =>
      total == 0 ? 0 : ((correct * 100) / total).round();
}
