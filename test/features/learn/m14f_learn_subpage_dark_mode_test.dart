import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/grammar_pattern_list_screen.dart';
import 'package:nimon/features/learn/learn_module_surface_tokens.dart';
import 'package:nimon/features/learn/listening_pronunciation_screen.dart';
import 'package:nimon/features/learn/quiz_setup_screen.dart';
import 'package:nimon/features/learn/vocab_kanji_list_screen.dart';

ThemeData _darkTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
  );
}

ThemeData _lightTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
  );
}

Widget _pumpLearnSubpage({
  required ThemeData theme,
  required Widget child,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => child,
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      theme: theme,
      routerConfig: router,
    ),
  );
}

void _expectScaffoldUsesModuleBackground(WidgetTester tester, ThemeData theme) {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  final expected = learnModuleListPageBackground(
    tester.element(find.byType(Scaffold)),
  );
  expect(scaffold.backgroundColor, expected);
  expect(
    scaffold.backgroundColor,
    isNot(equals(const Color(0xFFFFFFFF))),
  );
  if (theme.brightness == Brightness.dark) {
    expect(
      theme.colorScheme.surface.computeLuminance(),
      lessThan(0.5),
    );
  }
}

void main() {
  testWidgets('Vocabulary list dark: scaffold + title text not black', (
    tester,
  ) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      _pumpLearnSubpage(
        theme: theme,
        child: const VocabKanjiListScreen(contentId: 'mono'),
      ),
    );
    await tester.pumpAndSettle();

    _expectScaffoldUsesModuleBackground(tester, theme);
    expect(find.text('Vocabulary / Kanji'), findsOneWidget);

    final titleText = tester.widget<Text>(find.text('Vocabulary / Kanji'));
    final fg = titleText.style?.color;
    expect(fg, isNotNull);
    expect(fg!.computeLuminance(), greaterThan(0.25));
  });

  testWidgets('Grammar list dark: scaffold uses theme background', (
    tester,
  ) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      _pumpLearnSubpage(
        theme: theme,
        child: const GrammarPatternListScreen(contentId: 'mono'),
      ),
    );
    await tester.pumpAndSettle();

    _expectScaffoldUsesModuleBackground(tester, theme);
    expect(find.text('Grammar Learn'), findsOneWidget);
  });

  testWidgets('Quiz setup dark: scaffold uses theme background', (
    tester,
  ) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      _pumpLearnSubpage(
        theme: theme,
        child: const QuizSetupScreen(contentId: 'mono'),
      ),
    );
    await tester.pumpAndSettle();

    _expectScaffoldUsesModuleBackground(tester, theme);
    expect(find.text('Quiz Practice'), findsOneWidget);
  });

  testWidgets('Listening demo dark: scaffold uses theme background', (
    tester,
  ) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      _pumpLearnSubpage(
        theme: theme,
        child: const ListeningPronunciationScreen(
          contentId: 'mono',
        ),
      ),
    );
    // Audio/stream widgets may prevent pumpAndSettle from idling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    _expectScaffoldUsesModuleBackground(tester, theme);
    expect(find.textContaining('Listening'), findsWidgets);
  });

  testWidgets('Vocabulary list light: warm paper-style background', (
    tester,
  ) async {
    final theme = _lightTheme();
    await tester.pumpWidget(
      _pumpLearnSubpage(
        theme: theme,
        child: const VocabKanjiListScreen(contentId: 'mono'),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, learnModuleLightPaperBackground);
    expect(find.text('Vocabulary / Kanji'), findsOneWidget);
  });
}
