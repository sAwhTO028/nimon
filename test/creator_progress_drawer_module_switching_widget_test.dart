import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_progress_drawer.dart';
import 'package:nimon/features/create/creator_step_id.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/main.dart';

Finder _creatorDrawerScope() =>
    find.byKey(kCreatorProgressDrawerKeySentences, skipOffstage: false);

Finder _drawerCardForTitle(String title) {
  final titleInDrawer = find.descendant(
    of: _creatorDrawerScope(),
    matching: find.text(title),
  );
  return find.ancestor(
    of: titleInDrawer.first,
    matching: find.byType(Card),
  );
}

Future<void> _go(WidgetTester tester, String location) async {
  final ctx = tester.element(find.byType(Scaffold).first);
  GoRouter.of(ctx).go(location);
  // Avoid pumpAndSettle hanging on continuous animations.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}

CreatorDrawerSessionState _session(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold).first);
  final container = ProviderScope.containerOf(ctx);
  return container.read(creatorDrawerSessionProvider);
}

String _currentUri(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold).first);
  return GoRouterState.of(ctx).uri.toString();
}

void _seedLearnModeOn(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold).first);
  final container = ProviderScope.containerOf(ctx);
  container.read(creatorDrawerSessionProvider.notifier).setLearnMode(true);
}

Future<void> _openCreatorDrawer(WidgetTester tester) async {
  // Shell-owned drawer: open via floating header "Progress".
  final menu = find.byTooltip('Progress');
  expect(menu, findsOneWidget);
  await tester.tap(menu);
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _ensureLearnModeOnInDrawer(WidgetTester tester) async {
  final learnSwitch = find.descendant(
    of: _creatorDrawerScope(),
    matching: find.byType(Switch),
  );
  expect(learnSwitch, findsOneWidget);
  final sw = tester.widget<Switch>(learnSwitch);
  if (sw.value) {
    await tester.pump();
    return;
  }
  await tester.tap(learnSwitch);
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _tapDrawerStep(
  WidgetTester tester, {
  required CreatorStepId step,
  required String actionLabel,
}) async {
  final card = find.byKey(ValueKey<String>('creator_progress_${step.name}'),
      skipOffstage: false);
  expect(card, findsOneWidget);
  final action = find.descendant(
    of: card,
    matching: find.widgetWithText(TextButton, actionLabel),
  );
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action, warnIfMissed: false);
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void _expectDrawerRowState(
  WidgetTester tester, {
  required String moduleTitle,
  required String chipLabel,
  required String actionLabel,
}) {
  final card = _drawerCardForTitle(moduleTitle);
  expect(card, findsOneWidget);

  expect(
    find.descendant(of: card, matching: find.text(chipLabel)),
    findsAtLeastNWidgets(1),
    reason: '$moduleTitle should show chip=$chipLabel',
  );
  expect(
    find.descendant(
        of: card, matching: find.widgetWithText(TextButton, actionLabel)),
    findsOneWidget,
    reason: '$moduleTitle should show action=$actionLabel',
  );
}

Future<void> _assertLocalActionDoesNotNavigate(
  WidgetTester tester, {
  required Finder tapTarget,
}) async {
  final before = _currentUri(tester);
  await tester.ensureVisible(tapTarget);
  await tester.pump();
  await tester.tap(tapTarget, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  final after = _currentUri(tester);
  expect(after, before);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Creator progress drawer module switching (runtime widget)', () {
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: NimonApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('A. From Vocabulary page -> Grammar/Quiz/Listening',
        (tester) async {
      await pumpApp(tester);

      await _go(tester, '/create/story/sentences?panel=vocabulary');
      expect(find.text('Semantics'), findsOneWidget);
      expect(_session(tester).activeModule, CreatorModule.vocabulary);

      _seedLearnModeOn(tester);
      await tester.pump();
      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      // Current learn module row uses "You are here"; others use "Open".
      _expectDrawerRowState(
        tester,
        moduleTitle: 'Vocabulary',
        chipLabel: 'Not started',
        actionLabel: 'You are here',
      );
      _expectDrawerRowState(tester,
          moduleTitle: 'Grammar',
          chipLabel: 'Not started',
          actionLabel: 'Open');
      _expectDrawerRowState(tester,
          moduleTitle: 'Quiz', chipLabel: 'Not started', actionLabel: 'Open');
      _expectDrawerRowState(
        tester,
        moduleTitle: 'Listening / Pronunciation',
        chipLabel: 'Not started',
        actionLabel: 'Open',
      );

      await _tapDrawerStep(tester,
          step: CreatorStepId.grammar, actionLabel: 'Open');
      expect(find.text('Grammar'), findsAtLeastNWidgets(1));
      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
      expect(_session(tester).activeModule, CreatorModule.grammar);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      _expectDrawerRowState(tester,
          moduleTitle: 'Grammar',
          chipLabel: 'Not started',
          actionLabel: 'You are here');
      await _tapDrawerStep(tester,
          step: CreatorStepId.quiz, actionLabel: 'Open');
      // Pinned workspace header uses "Quizzes" (see _pinnedWorkspaceTitle); module body hides "Quiz" when embedded.
      expect(find.text('Quizzes'), findsAtLeastNWidgets(1));
      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
      expect(_session(tester).activeModule, CreatorModule.quiz);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      _expectDrawerRowState(tester,
          moduleTitle: 'Quiz',
          chipLabel: 'Not started',
          actionLabel: 'You are here');
      await _tapDrawerStep(
        tester,
        step: CreatorStepId.listening,
        actionLabel: 'Open',
      );
      // Pinned header uses short label "Listening" (_pinnedWorkspaceTitle); drawer row still says "Listening / Pronunciation".
      expect(find.text('Listening'), findsAtLeastNWidgets(1));
      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
      expect(
          _session(tester).activeModule, CreatorModule.listeningPronunciation);

      // Ensure we did not bounce back to sentences host.
      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
    });

    testWidgets('B. From Grammar -> Vocabulary/Quiz/Listening', (tester) async {
      await pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=grammar');
      _seedLearnModeOn(tester);
      await tester.pump();

      expect(find.text('Grammar'), findsAtLeastNWidgets(1));
      expect(_session(tester).activeModule, CreatorModule.grammar);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      _expectDrawerRowState(tester,
          moduleTitle: 'Grammar',
          chipLabel: 'Not started',
          actionLabel: 'You are here');

      await _tapDrawerStep(tester,
          step: CreatorStepId.vocabulary, actionLabel: 'Open');
      expect(find.text('Semantics'), findsOneWidget);
      expect(_session(tester).activeModule, CreatorModule.vocabulary);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      await _tapDrawerStep(tester,
          step: CreatorStepId.quiz, actionLabel: 'Open');
      expect(find.text('Quizzes'), findsAtLeastNWidgets(1));
      expect(_session(tester).activeModule, CreatorModule.quiz);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      await _tapDrawerStep(
        tester,
        step: CreatorStepId.listening,
        actionLabel: 'Open',
      );
      expect(find.text('Listening'), findsAtLeastNWidgets(1));
      expect(
          _session(tester).activeModule, CreatorModule.listeningPronunciation);

      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
    });

    testWidgets('C. From Quiz -> Vocabulary/Grammar/Listening', (tester) async {
      await pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=quiz');
      _seedLearnModeOn(tester);
      await tester.pump();

      expect(find.text('Quizzes'), findsAtLeastNWidgets(1));
      expect(_session(tester).activeModule, CreatorModule.quiz);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      _expectDrawerRowState(tester,
          moduleTitle: 'Quiz',
          chipLabel: 'Not started',
          actionLabel: 'You are here');

      await _tapDrawerStep(tester,
          step: CreatorStepId.vocabulary, actionLabel: 'Open');
      expect(find.text('Semantics'), findsOneWidget);
      expect(_session(tester).activeModule, CreatorModule.vocabulary);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      await _tapDrawerStep(tester,
          step: CreatorStepId.grammar, actionLabel: 'Open');
      expect(find.text('Grammar'), findsAtLeastNWidgets(1));
      expect(_session(tester).activeModule, CreatorModule.grammar);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      await _tapDrawerStep(
        tester,
        step: CreatorStepId.listening,
        actionLabel: 'Open',
      );
      expect(find.text('Listening'), findsAtLeastNWidgets(1));
      expect(
          _session(tester).activeModule, CreatorModule.listeningPronunciation);

      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
    });

    testWidgets('D. From Listening -> Vocabulary/Grammar/Quiz', (tester) async {
      await pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=listening');
      _seedLearnModeOn(tester);
      await tester.pump();

      expect(find.text('Listening'), findsAtLeastNWidgets(1));
      expect(
          _session(tester).activeModule, CreatorModule.listeningPronunciation);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      _expectDrawerRowState(
        tester,
        moduleTitle: 'Listening / Pronunciation',
        chipLabel: 'Not started',
        actionLabel: 'You are here',
      );

      await _tapDrawerStep(tester,
          step: CreatorStepId.vocabulary, actionLabel: 'Open');
      expect(find.text('Semantics'), findsOneWidget);
      expect(_session(tester).activeModule, CreatorModule.vocabulary);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      await _tapDrawerStep(tester,
          step: CreatorStepId.grammar, actionLabel: 'Open');
      expect(find.text('Grammar'), findsAtLeastNWidgets(1));
      expect(_session(tester).activeModule, CreatorModule.grammar);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);
      await _tapDrawerStep(tester,
          step: CreatorStepId.quiz, actionLabel: 'Open');
      expect(find.text('Quizzes'), findsAtLeastNWidgets(1));
      expect(_session(tester).activeModule, CreatorModule.quiz);

      expect(_currentUri(tester).startsWith('/create/story/sentences'), isTrue);
    });

    testWidgets('E. Learn mode off exits learn panel to storytelling',
        (tester) async {
      await pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=quiz');
      _seedLearnModeOn(tester);
      await tester.pump();
      expect(_session(tester).activeModule, CreatorModule.quiz);

      await _openCreatorDrawer(tester);
      await _ensureLearnModeOnInDrawer(tester);

      final learnSwitch = find.descendant(
        of: _creatorDrawerScope(),
        matching: find.byType(Switch),
      );
      expect(learnSwitch, findsOneWidget);
      await tester.tap(learnSwitch, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final uri = _currentUri(tester);
      expect(uri.contains('panel='), isFalse);
      expect(uri.contains('/create/story/sentences'), isTrue);
      final s = _session(tester);
      expect(s.learnModeEnabled, isFalse);
      expect(s.sentencesMainStep, CreatorWorkspaceStep.storySentences);
    });

    testWidgets('Local actions do not cross-module navigate (spot checks)',
        (tester) async {
      await pumpApp(tester);

      // Vocabulary: "Add entry" opens a sheet; route stays on vocabulary.
      await _go(tester, '/create/story/sentences?panel=vocabulary');
      _seedLearnModeOn(tester);
      await tester.pump();
      await _assertLocalActionDoesNotNavigate(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Add entry'),
      );

      // Grammar: "Add pattern" opens a sheet; route stays on grammar.
      await _go(tester, '/create/story/sentences?panel=grammar');
      _seedLearnModeOn(tester);
      await tester.pump();
      await _assertLocalActionDoesNotNavigate(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Add pattern'),
      );

      // Quiz: "Add quiz" opens a sheet; route stays on quiz.
      await _go(tester, '/create/story/sentences?panel=quiz');
      _seedLearnModeOn(tester);
      await tester.pump();
      await _assertLocalActionDoesNotNavigate(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Add quiz'),
      );

      // Listening: "Add audio source" opens a sheet; route stays on audio.
      await _go(tester, '/create/story/sentences?panel=listening');
      _seedLearnModeOn(tester);
      await tester.pump();
      await _assertLocalActionDoesNotNavigate(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Upload audio'),
      );
    });
  });
}
