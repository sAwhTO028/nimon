import 'package:flutter/material.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_audio_editor_screen.dart';
import 'package:nimon/features/create/story_creator_grammar_editor_screen.dart';
import 'package:nimon/features/create/story_creator_quiz_editor_screen.dart';
import 'package:nimon/features/create/story_creator_vocab_kanji_editor_screen.dart';

/// Lightweight V1 working surface for learn modules embedded in the sentences
/// creator workspace (drawer + main area).
class CreatorWorkspaceModulePlaceholder extends StatelessWidget {
  const CreatorWorkspaceModulePlaceholder({
    super.key,
    required this.step,
    required this.topPadding,
  });

  final CreatorWorkspaceStep step;
  final double topPadding;

  static (String title, String body) copyFor(CreatorWorkspaceStep step) {
    return switch (step) {
      CreatorWorkspaceStep.vocabulary => (
          'Vocabulary',
          'Extract and manage key words and kanji',
        ),
      CreatorWorkspaceStep.grammar => (
          'Grammar',
          'Define grammar patterns from this story',
        ),
      CreatorWorkspaceStep.quiz => (
          'Quiz',
          'Create practice questions',
        ),
      CreatorWorkspaceStep.listeningPronunciation => (
          'Listening / Pronunciation',
          'Attach story-level audio and pronunciation support',
        ),
      CreatorWorkspaceStep.storyBasics => ('', ''),
      CreatorWorkspaceStep.storySentences => ('', ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Vocabulary is implemented as a real working module inside the drawer-based workspace.
    if (step == CreatorWorkspaceStep.vocabulary) {
      return StoryCreatorVocabKanjiModuleBody(
        padding: EdgeInsets.fromLTRB(0, topPadding, 0, 8),
        showBottomActions: true,
        showLearnExitButton: false,
        useCompactModuleHeader: true,
        hideWorkspaceModuleTitle: false,
      );
    }

    if (step == CreatorWorkspaceStep.grammar) {
      return StoryCreatorGrammarModuleBody(
        padding: EdgeInsets.fromLTRB(0, topPadding, 0, 8),
        showBottomActions: true,
        showLearnExitButton: false,
        useCompactModuleHeader: true,
        hideWorkspaceModuleTitle: true,
      );
    }

    if (step == CreatorWorkspaceStep.quiz) {
      return StoryCreatorQuizModuleBody(
        padding: EdgeInsets.fromLTRB(0, topPadding, 0, 8),
        showBottomActions: true,
        showLearnExitButton: false,
        useCompactModuleHeader: true,
        hideWorkspaceModuleTitle: true,
      );
    }

    if (step == CreatorWorkspaceStep.listeningPronunciation) {
      return StoryCreatorListeningModuleBody(
        padding: EdgeInsets.fromLTRB(0, topPadding, 0, 8),
        showBottomActions: true,
        showLearnExitButton: false,
        useCompactModuleHeader: true,
        hideWorkspaceModuleTitle: true,
      );
    }

    final (title, body) = copyFor(step);
    if (title.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      // Horizontal padding comes from the sentences host; avoid double padding.
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 24),
      children: [
        Card(
          elevation: 0,
          color: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.85)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
