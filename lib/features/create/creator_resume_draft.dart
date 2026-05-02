import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

/// Centralized local-draft resume workflow (V1).
///
/// **Resume target (single resolver — [_v1ResumeTargetUriForDraft]):**
/// - **Learn mode OFF** — always [creatorStorySentencesMainLocation]: story sentences **main**
///   (no `?panel=`), never the old learn hub, never a learn `?panel=`.
/// - **Learn mode ON** — if [CreatorLastActiveModule] maps to a learn surface, use canonical
///   `?panel=` on `/create/story/sentences`; if it maps to **Story basics** (`B1`), open basics;
///   for storytelling / review / unknown → story sentences main.
///
/// **Entry context** (who opened create) is set on the [creatorEntryChannelProvider] **before**
/// [context.push] so [performCreatorBackFromSentencesHost] and related policy stay correct.
///
/// Used by Add tab, Profile > Processing, and Published-surface `Edit` resume.
abstract final class CreatorDraftResumeFlow {
  CreatorDraftResumeFlow._();

  static const _profileIdPrefix = 'profile-';

  static String _normPath(String p) {
    if (p.length > 1 && p.endsWith('/')) {
      return p.substring(0, p.length - 1);
    }
    return p;
  }

  /// True when [current] and [target] refer to the same creator story resume
  /// screen (path + `draftId` + optional `?panel=`). Ignores unrelated query keys.
  static bool _resumeUrisAreSameDestination(Uri current, Uri target) {
    if (_normPath(current.path) != _normPath(target.path)) {
      return false;
    }
    for (final k in const <String>['draftId', 'panel']) {
      if ((current.queryParameters[k] ?? '').trim() !=
          (target.queryParameters[k] ?? '').trim()) {
        return false;
      }
    }
    return true;
  }

  /// Pushes a new creator route when opening create from *outside* the
  /// `/create/story/...` tree; uses [GoRouter.go] when already under
  /// `/create/story/...` so we never stack duplicate story routes (reopen while
  /// already on Story Sentences would otherwise break Back / subtree lifecycle).
  static void _navigateToResumeTarget(BuildContext context, String target) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      context.push(target);
      return;
    }
    final t = Uri.parse(target);
    final cur = router.state.uri;
    if (_resumeUrisAreSameDestination(cur, t)) {
      return;
    }
    if (cur.path.startsWith('/create/story')) {
      context.go(target);
    } else {
      context.push(target);
    }
  }

  static String _createPathWithQuery({
    required String path,
    required String draftId,
    Map<String, String> extra = const <String, String>{},
  }) {
    final id = draftId.trim();
    final q = <String, String>{'draftId': id, ...extra}..removeWhere(
        (k, v) => v.isEmpty,
      );
    return Uri(
      path: path,
      queryParameters: q,
    ).toString();
  }

  static bool _inferLearnModeFromDraft(CreatorStoryV1 d) {
    // Learn mode is a persistent workflow choice. V1 does not store an explicit flag,
    // so infer it from meaningful learn content / publish intent.
    if (d.publishState == StoryPublishState.fullLearnPublished) return true;
    if (d.vocabularyKanji.entries.isNotEmpty) return true;
    if (d.grammar.entries.isNotEmpty) return true;
    if (d.quiz.entries.isNotEmpty) return true;
    if (d.audio.storyAudio?.isValidV1 == true) return true;
    // Module workflow statuses (e.g. "in_progress") indicate learn work has begun.
    if (d.moduleWorkflowStatuses.values.any(
      (s) => s == LearnModuleTaskStatus.inProgress || s == LearnModuleTaskStatus.completed,
    )) {
      return true;
    }
    return false;
  }

  static Future<String> _v1ResumeTargetUriForDraft(
    ProviderContainer c,
    String draftId,
  ) async {
    final id = draftId.trim();
    final draft = c.read(storyCreatorDraftDataProvider);
    final learnOn = _inferLearnModeFromDraft(draft);
    // Ensure creator session matches persistent intent on resume.
    c.read(creatorDrawerSessionProvider.notifier).setLearnMode(learnOn);
    final meta = await c.read(storyDraftRepositoryProvider).loadResumeMeta(id);
    final module = meta?.lastActiveModule ?? CreatorLastActiveModule.storytelling;
    final sub = (meta?.lastActiveSubPage ?? '').trim();

    if (!learnOn) {
      // Locked V1: Read Only / "story first" — never open learn `?panel=` on resume; never
      // route through the removed learn hub. S0 is the only sentences target.
      return creatorStorySentencesMainLocation(draftId: id);
    }

    // Learn mode ON: honor last module when it maps to B1, S0, or canonical `?panel=`.
    if (sub == 'vocabulary' || sub == 'grammar' || sub == 'quiz' || sub == 'listening') {
      return _createPathWithQuery(
        path: '/create/story/sentences',
        draftId: id,
        extra: <String, String>{'panel': sub},
      );
    }
    switch (module) {
      case CreatorLastActiveModule.storyBasics:
        return _createPathWithQuery(
          path: '/create/story/basics',
          draftId: id,
        );
      case CreatorLastActiveModule.storytelling:
      case CreatorLastActiveModule.review:
        return _createPathWithQuery(
          path: '/create/story/sentences',
          draftId: id,
        );
      case CreatorLastActiveModule.semantics:
        return _createPathWithQuery(
          path: '/create/story/sentences',
          draftId: id,
          extra: const <String, String>{'panel': 'vocabulary'},
        );
      case CreatorLastActiveModule.grammar:
        return _createPathWithQuery(
          path: '/create/story/sentences',
          draftId: id,
          extra: const <String, String>{'panel': 'grammar'},
        );
      case CreatorLastActiveModule.quizzes:
        return _createPathWithQuery(
          path: '/create/story/sentences',
          draftId: id,
          extra: const <String, String>{'panel': 'quiz'},
        );
      case CreatorLastActiveModule.listening:
        return _createPathWithQuery(
          path: '/create/story/sentences',
          draftId: id,
          extra: const <String, String>{'panel': 'listening'},
        );
    }
  }

  /// Re-open a **local** draft from a **Published** surface (reader `Edit`, profile loose-item `Edit`, …).
  ///
  /// [monoOrDraftId] may be a [MonoFeedItem] id with a `profile-` prefix or a raw local draft id.
  /// If no local draft is found, shows the legacy **Edit — coming soon** snack (V1 mock / non-local monos).
  static Future<void> tryResumeFromPublishedSurface(
    BuildContext context,
    String monoOrDraftId,
  ) async {
    var id = monoOrDraftId.trim();
    if (id.startsWith(_profileIdPrefix)) {
      id = id.substring(_profileIdPrefix.length);
    }
    if (id.isEmpty) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final draft = await container.read(storyDraftRepositoryProvider).loadDraft(id);
    if (!context.mounted) return;
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edit - Coming soon')),
      );
      return;
    }
    await resume(
      context,
      id,
      entryChannel: CreatorEntryChannel.publishedReopen,
    );
  }

  /// [entryChannel] must match how the user entered this resume (Add tab vs Processing sheet, etc.).
  static Future<void> resume(
    BuildContext context,
    String draftId, {
    required CreatorEntryChannel entryChannel,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) return;

    final container = ProviderScope.containerOf(context, listen: false);
    await _restoreDraftState(container, id);
    if (!context.mounted) return;
    final target = await _v1ResumeTargetUriForDraft(container, id);
    if (!context.mounted) return;
    ProviderScope.containerOf(context, listen: false)
        .read(creatorEntryChannelProvider.notifier)
        .state = entryChannel;
    if (!context.mounted) return;
    _navigateToResumeTarget(context, target);
  }

  /// Resume from Profile > Processing (row primary, sheets, etc.).
  ///
  /// [publishState] is part of the V1 public API for future gating; target resolution uses
  /// learn mode + resume meta + canonical `?panel=` only.
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

    final target = await _v1ResumeTargetUriForDraft(container, id);
    if (!context.mounted) return;
    container.read(creatorEntryChannelProvider.notifier).state =
        CreatorEntryChannel.processing;
    if (!context.mounted) return;
    _navigateToResumeTarget(context, target);
  }

  static Future<void> _restoreDraftState(ProviderContainer c, String draftId) async {
    await c.read(storyDraftRepositoryProvider).ensureResumeMetaInitialized(draftId);
    await c.read(storyCreatorDraftProvider.notifier).loadDraftById(
          draftId,
          forceReloadFromDisk: true,
        );
  }
}
