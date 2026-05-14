import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/learn_quiz_navigation.dart';
import 'package:nimon/features/learn/quiz_result_screen.dart';
import 'package:nimon/features/learn/quiz_session.dart';

void main() {
  const summary = QuizResultSummary(
    contentId: 't1',
    category: LearnQuizCategory.vocabulary,
    correct: 3,
    wrong: 1,
  );

  /// Same counts; [contentId] aligned with `/learn/t2/` deep-link fallback test.
  const summaryT2 = QuizResultSummary(
    contentId: 't2',
    category: LearnQuizCategory.vocabulary,
    correct: 3,
    wrong: 1,
  );

  testWidgets('Quiz result Back to Learn returns to hub on typical stack',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/learn/t1',
      routes: [
        GoRoute(
          path: '/learn/:id',
          builder: (context, s) {
            final id = s.pathParameters['id']!;
            return Scaffold(
              body: Center(child: Text('HUB$id')),
            );
          },
        ),
        GoRoute(
            path: '/learn/:id/quiz',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('QUIZSETUP')))),
        GoRoute(
          path: '/learn/:id/quiz/result',
          builder: (context, s) {
            final id = s.pathParameters['id']!;
            QuizResultSummary? su;
            final ex = s.extra;
            if (ex is QuizResultSummary) su = ex;
            return QuizResultScreen(contentId: id, summary: su);
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/learn/t1/quiz');
    await tester.pumpAndSettle();
    router.push('/learn/t1/quiz/result', extra: summary);
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    await tester.tap(find.text('Back to Learn'));
    await tester.pumpAndSettle();

    expect(find.text('HUBt1'), findsOneWidget);
    expect(router.state.uri.path, '/learn/t1');
  });

  testWidgets('Quiz result navigate helper go fallback single route',
      (tester) async {
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/other',
      routes: [
        GoRoute(
          path: '/other',
          builder: (_, __) => const Scaffold(body: Text('OTHER')),
        ),
        GoRoute(
          path: '/learn/:id',
          builder: (context, s) {
            final id = s.pathParameters['id']!;
            return Scaffold(
              body: Center(child: Text('HUB$id')),
            );
          },
        ),
        GoRoute(
          path: '/learn/:id/quiz/result',
          builder: (context, s) {
            final id = s.pathParameters['id']!;
            QuizResultSummary? su;
            final ex = s.extra;
            if (ex is QuizResultSummary) su = ex;
            return QuizResultScreen(contentId: id, summary: su);
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/learn/t2/quiz/result', extra: summaryT2);
    await tester.pumpAndSettle();

    expect(router.canPop(), isFalse);
    await navigateQuizResultBackToLearnHub(router, 't2');
    await tester.pumpAndSettle();

    expect(find.text('HUBt2'), findsOneWidget);
    expect(router.state.uri.path, '/learn/t2');
  });
}
