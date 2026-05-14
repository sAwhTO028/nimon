import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/story_creator_grammar_overlays.dart';
import 'package:nimon/features/create/widgets/creator_fit_info_bottom_sheet.dart';
import 'package:nimon/features/create/widgets/creator_info_bottom_sheet.dart';
import 'package:nimon/ui/widgets/nimon_scrollable_help_bottom_sheet.dart';

double _logicalHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

Future<void> _pumpOpenSheet(
  WidgetTester tester, {
  required VoidCallback onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: onOpen,
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void _assertNoOverflow(WidgetTester tester) {
  final exc = tester.takeException();
  if (exc != null) {
    expect(exc.toString(), isNot(contains('overflowed')));
  }
}

void main() {
  testWidgets('Storytelling info sheet fits content (< 70% height)', (
    tester,
  ) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => showCreatorFitInfoBottomSheet(
        context: tester.element(find.text('Open')),
        title: 'How this works',
        children: const [
          CreatorInfoBulletColumn(
            lines: [
              'Write one Japanese sentence at a time.',
              'Tap send to add it to your story.',
              'Tap a sentence to edit text, readings, and translations.',
              'Reorder sentences anytime.',
              'Publish Read Only or Full Learn from the progress menu when you are ready.',
            ],
          ),
        ],
      ),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    expect(sheet.height, lessThan(h * 0.70));
    expect(find.byKey(creatorFitInfoTitleKey), findsOneWidget);
    expect(find.byKey(creatorFitInfoGotItButtonKey), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    _assertNoOverflow(tester);
  });

  testWidgets('Vocabulary info sheet fits content (< 70% height)', (
    tester,
  ) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => showCreatorFitInfoBottomSheet(
        context: tester.element(find.text('Open')),
        title: 'How to add vocabulary / kanji',
        children: const [
          CreatorInfoBulletColumn(
            lines: [
              'Tap Add entry.',
              'Select a word or phrase from the story.',
              'Choose Vocabulary or Kanji.',
              'Add source meaning first.',
              'Optionally add English meaning.',
              'Optionally add up to 3 example sentences.',
            ],
          ),
        ],
      ),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    expect(sheet.height, lessThan(h * 0.70));
    expect(find.byKey(creatorFitInfoGotItButtonKey), findsOneWidget);
    _assertNoOverflow(tester);
  });

  testWidgets('Grammar info sheet fits content (< 80% height)', (tester) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => StoryCreatorGrammarOverlays.showHowTo(
          tester.element(find.text('Open'))),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    // Content may fill the 80% max-height cap on small logical windows.
    expect(sheet.height, lessThanOrEqualTo(h * 0.80 + 1));
    expect(find.byKey(creatorFitInfoGotItButtonKey), findsOneWidget);
    _assertNoOverflow(tester);
  });

  testWidgets('Quiz info sheet height capped (<= max sheet constraint)', (
    tester,
  ) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => showNimonScrollableHelpBottomSheet(
        context: tester.element(find.text('Open')),
        title: 'How to create quiz items',
        body: 'Quiz types:\n'
            '- Vocabulary: word/meaning questions\n'
            '- Kanji: kanji reading/meaning questions\n'
            '- Grammar: pattern meaning/usage questions\n'
            '- Sentence: comprehension about a story sentence\n\n'
            'How to add:\n'
            '1. Pick a tab (type)\n'
            '2. Tap “Add quiz”\n'
            '3. Write a clear prompt/question\n'
            '4. Add 4 answer options (A–D)\n'
            '5. Choose the correct answer\n\n'
            'Explanations:\n'
            '- Source explanation is primary\n'
            '- English explanation is optional and hidden by default',
      ),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    expect(sheet.height, lessThanOrEqualTo(h * 0.80 + 1));
    expect(sheet.height, lessThan(h * 0.90));
    expect(find.byKey(creatorFitInfoGotItButtonKey), findsOneWidget);
    _assertNoOverflow(tester);
  });

  testWidgets('Listening info sheet height capped (<= max sheet constraint)', (
    tester,
  ) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => showNimonScrollableHelpBottomSheet(
        context: tester.element(find.text('Open')),
        title: 'Listening / Pronunciation',
        body: 'Upload story audio for listening practice in Full Learn.\n\n'
            'How to add audio:\n'
            '1. Tap “Choose audio file”\n'
            '2. Pick mp3, m4a, or wav (sign in to save online)\n'
            '3. After upload, tap “Add audio to story” to attach it to this draft\n\n'
            'Optional display name or length: expand “Optional details” on the success screen.\n\n'
            'You can Replace audio or Remove audio anytime.',
      ),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    expect(sheet.height, lessThanOrEqualTo(h * 0.80 + 1));
    expect(sheet.height, lessThan(h * 0.90));
    expect(find.byKey(creatorFitInfoGotItButtonKey), findsOneWidget);
    _assertNoOverflow(tester);
  });
}
