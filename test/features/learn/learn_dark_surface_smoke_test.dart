import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/story_creator_grammar_overlays.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/features/learn/vocab_kanji_list_screen.dart';

ThemeData _dark() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.dark,
    ),
  );
}

void main() {
  testWidgets('Learn hub: key labels visible in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: _dark(),
          home: const LearnHubScreen(
            contentId: 'cid',
            storyTitle: 'T',
            description: 'D',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Vocabulary / Kanji'), findsOneWidget);
  });

  testWidgets('Vocab list (debug mock): first term visible in dark mode',
      (tester) async {
    expect(kDebugMode, isTrue,
        reason: 'Mock vocabulary list is debug-only (learnDemoMocksAllowed).');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: _dark(),
          home: const VocabKanjiListScreen(contentId: 'mono'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('図書館'), findsWidgets);
  });

  testWidgets('Grammar how-to sheet: no overflow on small height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: _dark(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () =>
                        StoryCreatorGrammarOverlays.showHowTo(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
    expect(find.text('How to create Grammar patterns'), findsOneWidget);
  });
}
