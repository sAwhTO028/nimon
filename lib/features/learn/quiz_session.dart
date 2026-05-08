import 'dart:math';

import 'package:nimon/features/learn/quiz_mcq.dart';

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

/// Picks [questionCount] questions for [category] from [pool], shuffled; cycles if count > pool size.
///
/// Used when [QuizSessionStartArgs.publishedQuizPool] drives the session instead of [QuizMockBank].
List<QuizMcqItem> pickPublishedQuizQuestionsForSession({
  required LearnQuizCategory category,
  required int questionCount,
  required List<QuizMcqItem> pool,
}) {
  final filtered =
      pool.where((q) => q.category == category).toList(growable: false);
  if (filtered.isEmpty) return [];
  final n = questionCount.clamp(1, 999);
  final shuffled = List<QuizMcqItem>.from(filtered)..shuffle(Random());
  final out = <QuizMcqItem>[];
  for (var i = 0; i < n; i++) {
    out.add(shuffled[i % shuffled.length]);
  }
  return out;
}

/// Passed to the quiz play route when the user taps Start Quiz on setup.
class QuizSessionStartArgs {
  const QuizSessionStartArgs({
    required this.contentId,
    required this.category,
    required this.questionCount,
    this.publishedQuizPool,
  });

  final String contentId;
  final LearnQuizCategory category;
  final int questionCount;

  /// When non-null and non-empty, [QuizPlayScreen] builds the deck from published snapshot rows.
  ///
  /// **Null** means use [QuizMockBank] only when [learnDemoMocksAllowed] applies; catalog UUIDs must not fall back to mocks.
  final List<QuizMcqItem>? publishedQuizPool;
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
  int get scorePercent => total == 0 ? 0 : ((correct * 100) / total).round();
}
