import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';

/// Strict session checks for `/create/story/sentences?panel=vocabulary` embed.
/// Complements manual log verification (`[creator_nav|` in debug console).
void main() {
  group('embedded vocabulary panel session', () {
    late ProviderContainer container;
    late CreatorDrawerSessionNotifier n;

    void goVocabEmbed() {
      n.reportRoute(
        'sentences',
        locationUri: Uri.parse('/create/story/sentences?panel=vocabulary'),
      );
    }

    setUp(() {
      container = ProviderContainer();
      n = container.read(creatorDrawerSessionProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('reportRoute: subtree matchedLocation + panel URI keeps vocabulary', () {
      goVocabEmbed();
      final s = container.read(creatorDrawerSessionProvider);
      expect(s.sentencesMainStep, CreatorWorkspaceStep.vocabulary);
      expect(s.activeModule, CreatorModule.vocabulary);
      expect(s.sentencesMainStep == CreatorWorkspaceStep.storySentences, isFalse);
    });

    test(
        'reportRoute: no panel= on sentences host is canonical main storytelling (V1 router truth)',
        () {
      goVocabEmbed();
      n.reportRoute(
        '/create/story/sentences',
        locationUri: Uri.parse('/create/story/sentences'),
      );
      final s = container.read(creatorDrawerSessionProvider);
      expect(s.sentencesMainStep, CreatorWorkspaceStep.storySentences);
      expect(s.activeModule, CreatorModule.storySentences);
    });

    test('reportRoute: leaving sentences host resets embedded step to story sentences', () {
      goVocabEmbed();
      n.reportRoute(
        '/create/story/basics',
        locationUri: Uri.parse('/create/story/basics'),
      );
      expect(
        container.read(creatorDrawerSessionProvider).sentencesMainStep,
        CreatorWorkspaceStep.storySentences,
      );
    });

    test('retainSentencesHostEmbeddedStep restores vocabulary after story list step', () {
      goVocabEmbed();
      n.setSentencesMainStep(CreatorWorkspaceStep.storySentences);
      expect(
        container.read(creatorDrawerSessionProvider).sentencesMainStep,
        CreatorWorkspaceStep.storySentences,
      );
      n.retainSentencesHostEmbeddedStep(
        CreatorWorkspaceStep.vocabulary,
        debugAction: 'unit_vocab_retain',
      );
      final s = container.read(creatorDrawerSessionProvider);
      expect(s.sentencesMainStep, CreatorWorkspaceStep.vocabulary);
      expect(s.activeModule, CreatorModule.vocabulary);
    });

    test('vocabulary action ids: retain after drift never leaves vocabulary embed', () {
      goVocabEmbed();
      const actions = <String>[
        'vocab_add_from_story',
        'vocab_edit_save',
        'vocab_details_save',
        'vocab_reorder',
        'vocab_delete',
        'vocab_save_draft',
      ];
      for (final a in actions) {
        n.setSentencesMainStep(CreatorWorkspaceStep.storySentences);
        n.retainSentencesHostEmbeddedStep(
          CreatorWorkspaceStep.vocabulary,
          debugAction: a,
        );
        final s = container.read(creatorDrawerSessionProvider);
        expect(
          s.sentencesMainStep,
          CreatorWorkspaceStep.vocabulary,
          reason: 'after retain simulating $a',
        );
        expect(s.sentencesMainStep == CreatorWorkspaceStep.storySentences, isFalse);
        expect(s.activeModule, CreatorModule.vocabulary);
      }
    });
  });
}
