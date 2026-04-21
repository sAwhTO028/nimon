import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

/// Centralized local-draft resume workflow (V1).
///
/// Used by Add tab, Profile > Processing, and any other "Continue" entry point.
abstract final class CreatorDraftResumeFlow {
  CreatorDraftResumeFlow._();

  static Future<void> resume(BuildContext context, String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;

    final container = ProviderScope.containerOf(context, listen: false);
    await _restoreDraftState(container, id);
    if (!context.mounted) return;
    final target = await _targetUri(container, id);
    if (!context.mounted) return;
    context.push(target);
  }

  /// Resume from Profile > Processing — primary action follows [publishState].
  static Future<void> resumeFromProcessing(
    BuildContext context,
    String draftId, {
    required StoryPublishState publishState,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) return;

    final container = ProviderScope.containerOf(context, listen: false);
    await _restoreDraftState(container, id);
    if (!context.mounted) return;

    if (publishState == StoryPublishState.readingOnlyPublished) {
      // Learn modules entry — not story basics unless user edits elsewhere.
      context.push('/create/story/learn?draftId=$id');
      return;
    }

    final target = await _targetUri(container, id);
    if (!context.mounted) return;
    context.push(target);
  }

  static Future<void> _restoreDraftState(ProviderContainer c, String draftId) async {
    await c.read(storyDraftRepositoryProvider).ensureResumeMetaInitialized(draftId);
    await c.read(storyCreatorDraftProvider.notifier).loadDraftById(draftId);
  }

  static Future<String> _targetUri(ProviderContainer c, String draftId) async {
    final id = draftId.trim();
    final meta = await c.read(storyDraftRepositoryProvider).loadResumeMeta(id);
    final module = meta?.lastActiveModule ?? CreatorLastActiveModule.storytelling;

    final drawer = c.read(creatorDrawerSessionProvider.notifier);

    switch (module) {
      case CreatorLastActiveModule.storyBasics:
        return '/create/story/basics?draftId=$id';
      case CreatorLastActiveModule.storytelling:
        // Ensure embedded workspace points at story sentences (no panel).
        drawer.setSentencesMainStep(CreatorWorkspaceStep.storySentences);
        return '/create/story/sentences?draftId=$id';
      case CreatorLastActiveModule.semantics:
        drawer.setSentencesMainStep(CreatorWorkspaceStep.vocabulary);
        return '/create/story/sentences?draftId=$id&panel=vocabulary';
      case CreatorLastActiveModule.grammar:
        drawer.setSentencesMainStep(CreatorWorkspaceStep.grammar);
        return '/create/story/sentences?draftId=$id&panel=grammar';
      case CreatorLastActiveModule.quizzes:
        drawer.setSentencesMainStep(CreatorWorkspaceStep.quiz);
        return '/create/story/sentences?draftId=$id&panel=quiz';
      case CreatorLastActiveModule.listening:
        drawer.setSentencesMainStep(CreatorWorkspaceStep.listeningPronunciation);
        return '/create/story/sentences?draftId=$id&panel=listening';
      case CreatorLastActiveModule.review:
        return '/create/story/sentences?draftId=$id';
    }
  }
}

