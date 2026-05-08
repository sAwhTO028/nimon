import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/quiz_mcq.dart';
import 'package:nimon/features/learn/quiz_session.dart';

void main() {
  group('pickPublishedQuizQuestionsForSession', () {
    test('returns empty when category has no items in pool', () {
      const pool = [
        QuizMcqItem(
          id: 'g1',
          category: LearnQuizCategory.grammar,
          prompt: 'p',
          options: ['a', 'b', 'c', 'd'],
          correctIndex: 0,
        ),
      ];
      final out = pickPublishedQuizQuestionsForSession(
        category: LearnQuizCategory.vocabulary,
        questionCount: 5,
        pool: pool,
      );
      expect(out, isEmpty);
    });

    test('filters by category and respects questionCount cycling', () {
      const pool = [
        QuizMcqItem(
          id: 'v1',
          category: LearnQuizCategory.vocabulary,
          prompt: 'A',
          options: ['a', 'b', 'c', 'd'],
          correctIndex: 0,
        ),
        QuizMcqItem(
          id: 'v2',
          category: LearnQuizCategory.vocabulary,
          prompt: 'B',
          options: ['a', 'b', 'c', 'd'],
          correctIndex: 1,
        ),
      ];
      final out = pickPublishedQuizQuestionsForSession(
        category: LearnQuizCategory.vocabulary,
        questionCount: 3,
        pool: pool,
      );
      expect(out, hasLength(3));
      expect(
          out.every((q) => q.category == LearnQuizCategory.vocabulary), isTrue);
      expect(out.map((q) => q.prompt).toSet(), equals({'A', 'B'}));
    });
  });
}
