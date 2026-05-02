import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_quiz_ui_state.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_provider.dart';

// -----------------------------------------------------------------------------
// Nimon V1 — centralized creator back / exit policy
//
// - **Story sentences host (main)**: [performCreatorBackFromSentencesHost] — uses
//   [creatorEntryChannelProvider] to pick the shell (Mono / More / tabs).
// - **Learn module in sentences** (`?panel=…` or legacy learn path): back **first**
//   normalizes to story sentences *main* (no panel) via
//   [normalizeLearnModuleToStorySentencesMain]; further back uses the host path.
// - **Create “wizard” sub-routes** (e.g. Story basics, pushed on top of `/create`):
//   [performPopCreateSubrouteIfPossible] — one [Navigator] pop, no channel (stack owns state).
// - **Create root** (`/create` add tab, edit-basics from review):
//   [performExitFromCreateRoot] — full exit using entry channel.
//
// All creator-tagged back/exit for these surfaces should go through the helpers
// in this file — not ad-hoc [context.go] to shell or scattered [context.pop] for
// flow-level exits. (Dialogs/sheets that dismiss themselves may still use local pop.)
// -----------------------------------------------------------------------------

/// How the user **entered** the current create session (for exit back target).
enum CreatorEntryChannel {
  /// **ADD** — primary create from the Mono shell (dock / reader add).
  add,

  /// **SHELL_MORE** — create opened from the More/Profile shell (e.g. empty state, nav drawer).
  shellMore,

  /// **PROCESSING** — Continue from Profile > Processing (incl. `resumeFromProcessing` / sheet Continue).
  processing,

  /// **PUBLISHED_REOPEN** — set by [CreatorDraftResumeFlow.tryResumeFromPublishedSurface]
  /// (Published reader dock `Edit`, Published loose-item sheet `Edit`, when a local draft id matches).
  publishedReopen,
}

/// Last known create **entry** channel for the active session. Overwritten every
/// time the user **opens** create from the shell, Profile, or a resume action.
final creatorEntryChannelProvider =
    StateProvider<CreatorEntryChannel>((ref) => CreatorEntryChannel.add);

/// True while a creator publish action is executing (Read Only / Full Learn).
///
/// Back is always available, but **exit is blocked** while publish is in progress.
final creatorPublishInProgressProvider = StateProvider<bool>((ref) => false);

/// True while an audio upload is in progress for the active creator draft.
///
/// V1 note: the audio UI currently attaches local metadata only; this flag is a
/// forward-compatible hook for the locked back policy.
final creatorAudioUploadInProgressProvider = StateProvider<bool>((ref) => false);

/// True while a creator back operation is executing.
///
/// Used as a small re-entry guard so rapid taps / system back cannot overlap
/// flush + reset + exit steps.
final creatorBackInProgressProvider = StateProvider<bool>((ref) => false);

/// Call immediately before `context.push` to any `/create/...` route.
void setCreatorEntryChannel(WidgetRef ref, CreatorEntryChannel channel) {
  ref.read(creatorEntryChannelProvider.notifier).state = channel;
}

/// Derive entry channel from the user’s current **shell/top** location (path only).
CreatorEntryChannel creatorEntryChannelForShellPath(String path) {
  if (path.startsWith('/more')) {
    return CreatorEntryChannel.shellMore;
  }
  if (path.startsWith('/profile')) {
    return CreatorEntryChannel.shellMore;
  }
  if (path.startsWith('/mono')) {
    return CreatorEntryChannel.add;
  }
  return CreatorEntryChannel.add;
}

/// True when the current route shows an embedded **learn** module in the story sentences host
/// (V1: `?panel=` for vocabulary / grammar / quiz / listening, or legacy learn path segment).
@visibleForTesting
bool creatorRouteShowsLearnModulePanel(Uri uri) {
  final panel = (uri.queryParameters['panel'] ?? '').trim();
  return panel == 'vocabulary' ||
      panel == 'grammar' ||
      panel == 'quiz' ||
      panel == 'listening';
}

/// True when [uri.path] is the `/create/story/sentences` route (with or without trailing slash).
@visibleForTesting
bool creatorUriIsStorySentencesHostPath(Uri uri) {
  final p = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  return p == '/create/story/sentences' || p.startsWith('/create/story/sentences/');
}

/// Story sentences **host** with no learn surface (`?panel=` / legacy learn path).
@visibleForTesting
bool creatorUriIsStorySentencesMainSurface(Uri uri) {
  return creatorUriIsStorySentencesHostPath(uri) &&
      !creatorRouteShowsLearnModulePanel(uri);
}

/// GoRouter location for **story sentences main** (no `panel=`), for the given draft.
String creatorStorySentencesMainLocation({required String? draftId}) {
  final id = (draftId ?? '').trim();
  if (id.isEmpty) return '/create/story/sentences';
  return '/create/story/sentences?draftId=${Uri.encodeQueryComponent(id)}';
}

void _syncDrawerAfterHostGo(GoRouter? r, WidgetRef ref) {
  if (r != null) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      syncCreatorDrawerSessionForRouter(r, ref);
    });
  }
}

/// Pops a **single** child route in the create stack (e.g. Story basics, legacy learn
/// sub-screen). Does **not** use entry channel. Prefer this over raw [context.pop]
/// for create-flow back from wizard steps.
void performPopCreateSubrouteIfPossible(BuildContext context) {
  if (!context.mounted) return;
  if (context.canPop()) {
    context.pop();
  }
}

/// Closes a Material [Scaffold] drawer or end drawer (e.g. embedded learn module UIs)
/// without running create back / exit logic. Returns true if a drawer was open and closed.
///
/// Uses [Scaffold.maybeOf] and [ScaffoldState.closeDrawer] / [closeEndDrawer] (lifecycle-safe
/// equivalents of popping the drawer route) so we do not look up an ancestor on a deactivated
/// element during route / module transitions.
bool tryCloseEmbeddedScaffoldSideDrawers(BuildContext context) {
  if (!context.mounted) return false;
  try {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold == null) return false;
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return true;
    }
    if (scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
      return true;
    }
  } catch (_) {
    // Context no longer has a safe Scaffold ancestor (deactivated during transition).
  }
  return false;
}

/// Replaces the URL with story sentences **main** (no learn `panel=`). The drawer
/// session is updated from the route by [syncCreatorDrawerSessionForRouter] after
/// [GoRouter.go]. Use when backing out of a learn module **before** applying the
/// entry-channel parent exit.
///
/// Prefer the same [GoRouter] instance the caller used for [handleCreatorBackPressed]
/// (not [BuildContext.go] after an `async` gap — the context may be inactive, which
/// previously caused silent no-ops from swallowed exceptions).
void normalizeLearnModuleToStorySentencesMain(
  WidgetRef ref, {
  required GoRouter router,
  required String draftId,
}) {
  final id = draftId.trim();
  final target = creatorStorySentencesMainLocation(
    draftId: id.isEmpty ? null : id,
  );
  router.go(target);
  _syncDrawerAfterHostGo(router, ref);
}

void _goToParentForEntryChannel(WidgetRef ref, GoRouter router) {
  final ch = ref.read(creatorEntryChannelProvider);
  if (ch == CreatorEntryChannel.processing) {
    router.go('/more?tab=workspace');
  } else if (ch == CreatorEntryChannel.shellMore) {
    router.go('/more');
  } else if (ch == CreatorEntryChannel.publishedReopen) {
    router.go(
      Uri(
        path: '/more',
        queryParameters: const {'tab': 'uploaded'},
      ).toString(),
    );
  } else {
    router.go('/mono');
  }
}

/// Exits the **/create** hub / add tab / “edit from review” surface using
/// [creatorEntryChannelProvider] (Mono vs More + tab).
void performExitFromCreateRoot(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  final g = GoRouter.maybeOf(context);
  if (g == null) return;
  _goToParentForEntryChannel(ref, g);
}

Future<bool> _flushMeaningfulDraftStateForExit(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
  Uri? locationUri,
}) async {
  // [BuildContext] is not needed for the notifier + repository work; a false
  // "unmounted" at an async edge (widget tests) must not block flush — that
  // surfaces as `!ok` and prevents learn→main normalization on back.
  final draftId = ref.read(storyCreatorDraftDataProvider).id.trim();
  CreatorLastActiveModule? lastModule;
  String? lastSubPage;
  if (draftId.isNotEmpty && locationUri != null) {
    final panel = (locationUri.queryParameters['panel'] ?? '').trim();
    lastSubPage = panel.isEmpty ? null : panel;
    lastModule = panel == 'vocabulary'
        ? CreatorLastActiveModule.semantics
        : (panel == 'grammar'
            ? CreatorLastActiveModule.grammar
            : (panel == 'quiz'
                ? CreatorLastActiveModule.quizzes
                : (panel == 'listening'
                    ? CreatorLastActiveModule.listening
                    : (locationUri.path.startsWith('/create/story/basics')
                        ? CreatorLastActiveModule.storyBasics
                        : CreatorLastActiveModule.storytelling))));
  }

  return ref.read(storyCreatorDraftProvider.notifier).flushDraftToProcessing(
        reason: reason,
        lastActiveModule: lastModule,
        lastActiveSubPage: lastSubPage,
      );
}

Future<void> _resetEphemeralUiForBack(
  BuildContext context, {
  required WidgetRef ref,
  bool? progressDrawerDismissed,
  Future<void> Function()? closeProgressDrawer,
}) async {
  if (!context.mounted) return;
  // Ephemeral UI layers are an implementation detail, not a competing navigation rule.
  tryCloseEmbeddedScaffoldSideDrawers(context);
  if (progressDrawerDismissed != null &&
      closeProgressDrawer != null &&
      !progressDrawerDismissed) {
    await closeProgressDrawer();
  }

  // Reset ephemeral provider-backed UI state (must not touch content data).
  ref.read(creatorDrawerSessionProvider.notifier).resetEphemeralUiState();
  ref.read(quizTabIndexProvider.notifier).state = 0;
  ref.read(creatorPublishInProgressProvider.notifier).state = false;
  ref.read(creatorAudioUploadInProgressProvider.notifier).state = false;
}

Future<String?> _showLockedSaveFailureDialog(
  BuildContext context, {
  required bool allowDiscardLeave,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Couldn’t save'),
      content: const Text(
        'We couldn’t save your latest changes. Retry to save, or stay on this page.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('stay'),
          child: const Text('Stay'),
        ),
        if (allowDiscardLeave)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard_leave'),
            child: const Text('Discard and leave'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('retry'),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}

Future<String?> _showLockedAudioUploadBlockingDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Upload in progress'),
      content: const Text(
        'Audio is uploading. You can stay, or cancel the upload and leave.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('stay'),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('cancel_leave'),
          child: const Text('Cancel upload and leave'),
        ),
      ],
    ),
  );
}

Future<void> _handleBackFromStoryBasics(
  BuildContext context,
  WidgetRef ref, {
  required bool hasMeaningfulEdits,
}) async {
  if (!context.mounted) return;

  // Untouched session: in-stack back only.
  if (!hasMeaningfulEdits) {
    performPopCreateSubrouteIfPossible(context);
    return;
  }

  final draftId = ref.read(storyCreatorDraftDataProvider).id.trim();

  // Dirty session: flush local save before leaving, so the draft appears in Processing.
  final ok = await _flushMeaningfulDraftStateForExit(
    context,
    ref,
    reason: 'exit_story_basics',
    locationUri: GoRouter.maybeOf(context)?.state.uri,
  );
  if (!context.mounted) return;
  if (ok) {
    performPopCreateSubrouteIfPossible(context);
    return;
  }

  final hasPersisted = draftId.isNotEmpty
      ? await ref.read(storyDraftRepositoryProvider).hasDraft(draftId)
      : false;
  if (!context.mounted) return;

  final action = await _showLockedSaveFailureDialog(
    context,
    allowDiscardLeave: hasPersisted,
  );

  if (!context.mounted) return;
  if (action == null || action == 'stay') return;

  if (action == 'retry') {
    final ok2 = await _flushMeaningfulDraftStateForExit(
      context,
      ref,
      reason: 'exit_story_basics_retry_flush',
      locationUri: GoRouter.maybeOf(context)?.state.uri,
    );
    if (!context.mounted) return;
    if (ok2) {
      performPopCreateSubrouteIfPossible(context);
    }
    return;
  }

  if (action == 'discard_leave' && hasPersisted) {
    // Discard local in-memory edits and leave; persisted draft remains intact.
    ref.read(storyCreatorDraftProvider.notifier).reset();
    if (!context.mounted) return;
    performPopCreateSubrouteIfPossible(context);
    return;
  }
}

/// Single back entry point for all creator screens.
///
/// Screens must route both system back (`PopScope`) and in-app back buttons here.
///
/// Locked Back rule:
/// - Back is always available.
/// - Only explicit blocking work may interrupt immediate exit:
///   - save/flush failure (minimal dialog)
///   - audio upload in progress (minimal dialog)
///   - publish in progress (block exit until publish resolves)
/// - When not blocked: flush meaningful state -> reset ephemeral UI -> leave page.
Future<void> handleCreatorBackPressed(
  BuildContext context,
  WidgetRef ref, {
  bool? progressDrawerDismissed,
  Future<void> Function()? closeProgressDrawer,
  bool storyBasicsHasMeaningfulEdits = true,
  Future<void> Function()? cancelAudioUpload,
}) async {
  // Back is async (flush + dialogs + navigation). Prevent overlapping invocations
  // (e.g. rapid taps) from racing each other.
  if (ref.read(creatorBackInProgressProvider)) return;
  ref.read(creatorBackInProgressProvider.notifier).state = true;
  try {
    // Capture router state synchronously; avoid inherited lookups after awaits.
    final router = GoRouter.maybeOf(context);
    final uri = router?.state.uri;

  // 0) Detect explicit blocking work (locked rule).
  if (ref.read(creatorPublishInProgressProvider)) {
    // V1: block exit until publish completes.
    return;
  }
  if (ref.read(creatorAudioUploadInProgressProvider)) {
    final action = await _showLockedAudioUploadBlockingDialog(context);
    if (!context.mounted) {
      return;
    }
    if (action == null || action == 'stay') {
      return;
    }
    if (action == 'cancel_leave') {
      if (cancelAudioUpload != null) {
        try {
          await cancelAudioUpload();
        } catch (_) {
          // Cancel failure should not crash back; leaving is still allowed by policy.
        }
      }
      await _resetEphemeralUiForBack(
        context,
        ref: ref,
        progressDrawerDismissed: progressDrawerDismissed,
        closeProgressDrawer: closeProgressDrawer,
      );
      if (router != null) {
        _goToParentForEntryChannel(ref, router);
      }
      return;
    }
  }

  if (router == null || uri == null) {
    performPopCreateSubrouteIfPossible(context);
    return;
  }

  // Create root: exit by entry context.
  if (uri.path == '/create' || uri.path == '/create/') {
    await _resetEphemeralUiForBack(
      context,
      ref: ref,
      progressDrawerDismissed: progressDrawerDismissed,
      closeProgressDrawer: closeProgressDrawer,
    );
    if (!context.mounted) {
      return;
    }
    performExitFromCreateRoot(context, ref);
    return;
  }

  // Story basics: in-stack pop, but flush meaningful state first.
  if (uri.path.startsWith('/create/story/basics')) {
    await _handleBackFromStoryBasics(
      context,
      ref,
      hasMeaningfulEdits: storyBasicsHasMeaningfulEdits,
    );
    return;
  }

  // Any learn panel under create/story: normalize to sentences main (no exit yet).
  if (uri.path.startsWith('/create/story') && creatorRouteShowsLearnModulePanel(uri)) {
    final id = ref.read(storyCreatorDraftDataProvider).id;
    normalizeLearnModuleToStorySentencesMain(
      ref,
      router: router,
      draftId: id,
    );
    // Do not continue in this invocation: normalization schedules route changes and
    // may deactivate the current element; the next back press handles exit/flush.
    return;
  }

  // Sentences main: flush meaningful state then exit by entry context.
  if (creatorUriIsStorySentencesMainSurface(uri)) {
    final ok = await _flushMeaningfulDraftStateForExit(
      context,
      ref,
      reason: 'exit_story_sentences',
      locationUri: uri,
    );
    if (!ok) {
      if (!context.mounted) return;
      final draftId = ref.read(storyCreatorDraftDataProvider).id.trim();
      final hasPersisted = draftId.isNotEmpty
          ? await ref.read(storyDraftRepositoryProvider).hasDraft(draftId)
          : false;
      if (!context.mounted) {
        return;
      }
      final action = await _showLockedSaveFailureDialog(
        context,
        allowDiscardLeave: hasPersisted,
      );
      if (!context.mounted) {
        return;
      }
      if (action == null || action == 'stay') {
        return;
      }
      if (action == 'retry') {
        final ok2 = await _flushMeaningfulDraftStateForExit(
          context,
          ref,
          reason: 'exit_story_sentences_retry_flush',
          locationUri: uri,
        );
        if (!context.mounted) {
          return;
        }
        if (!ok2) {
          return;
        }
      } else if (action == 'discard_leave' && hasPersisted) {
        ref.read(storyCreatorDraftProvider.notifier).reset();
      } else {
        return;
      }
    }

    if (context.mounted) {
      await _resetEphemeralUiForBack(
        context,
        ref: ref,
        progressDrawerDismissed: progressDrawerDismissed,
        closeProgressDrawer: closeProgressDrawer,
      );
    }
    _goToParentForEntryChannel(ref, router);
    return;
  }

  // Any other create/story surface: pop once if possible; otherwise exit.
  if (uri.path.startsWith('/create/story')) {
    final ok = await _flushMeaningfulDraftStateForExit(
      context,
      ref,
      reason: 'back_create_story_surface',
      locationUri: uri,
    );
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      final draftId = ref.read(storyCreatorDraftDataProvider).id.trim();
      final hasPersisted = draftId.isNotEmpty
          ? await ref.read(storyDraftRepositoryProvider).hasDraft(draftId)
          : false;
      if (!context.mounted) {
        return;
      }
      final action = await _showLockedSaveFailureDialog(
        context,
        allowDiscardLeave: hasPersisted,
      );
      if (!context.mounted) {
        return;
      }
      if (action == null || action == 'stay') {
        return;
      }
      if (action == 'retry') {
        final ok2 = await _flushMeaningfulDraftStateForExit(
          context,
          ref,
          reason: 'back_create_story_surface_retry_flush',
          locationUri: uri,
        );
        if (!context.mounted) {
          return;
        }
        if (!ok2) {
          return;
        }
      } else if (action == 'discard_leave' && hasPersisted) {
        ref.read(storyCreatorDraftProvider.notifier).reset();
      } else {
        return;
      }
    }

    await _resetEphemeralUiForBack(
      context,
      ref: ref,
      progressDrawerDismissed: progressDrawerDismissed,
      closeProgressDrawer: closeProgressDrawer,
    );
    if (!context.mounted) {
      return;
    }

    final couldPopBefore = context.canPop();
    performPopCreateSubrouteIfPossible(context);
    if (!context.mounted) {
      return;
    }
    if (!couldPopBefore) {
      _goToParentForEntryChannel(ref, router);
    }
    return;
  }

  // Fallback: exit by entry context.
  await _resetEphemeralUiForBack(
    context,
    ref: ref,
    progressDrawerDismissed: progressDrawerDismissed,
    closeProgressDrawer: closeProgressDrawer,
  );
  if (!context.mounted) {
    return;
  }
  _goToParentForEntryChannel(ref, router);
  } finally {
    // Always clear even if navigation disposes the caller.
    ref.read(creatorBackInProgressProvider.notifier).state = false;
  }
}

/// Main back for [StoryCreatorSentencesScreen] (floating header, Android / PopScope).
///
/// 1) If a Material [Scaffold] drawer / endDrawer is open (e.g. embedded module chrome),
///    [tryCloseEmbeddedScaffoldSideDrawers] and return (one back gesture closes one layer).
/// 2) If the in-app **progress** drawer is not fully dismissed, [closeProgressDrawer] and return.
/// 3) If a learn `panel=` (or legacy learn path) is active under `/create/story`, first
///    [normalizeLearnModuleToStorySentencesMain] (one visible navigation per back).
/// 4) If on story sentences **main** (host path, no learn surface), **always**
///    [_goToParentForEntryChannel] — never a pop-only path that can no-op when there is
///    no inner [Navigator] stack.
/// 5) Otherwise under `/create/story`, [performPopCreateSubrouteIfPossible]; if nothing
///    was popped, [_goToParentForEntryChannel] so back always does something visible.
/// 6) Any other location: [_goToParentForEntryChannel].
///
/// Uses [GoRouter.maybeOf] and guarded [context.go] so back during route / drawer
/// transitions does not throw on a deactivated ancestor.
Future<void> performCreatorBackFromSentencesHost(
  BuildContext context,
  WidgetRef ref, {
  required bool progressDrawerDismissed,
  required Future<void> Function() closeProgressDrawer,
}) async {
  return handleCreatorBackPressed(
    context,
    ref,
    progressDrawerDismissed: progressDrawerDismissed,
    closeProgressDrawer: closeProgressDrawer,
  );
}

/// When the story sentences page is only showing the draft-id loading scaffold.
Future<void> performCreatorBackFromSentencesDraftLoading(
  BuildContext context, {
  required bool progressDrawerDismissed,
  required Future<void> Function() closeProgressDrawer,
}) async {
  if (!context.mounted) return;
  if (tryCloseEmbeddedScaffoldSideDrawers(context)) {
    return;
  }
  if (!progressDrawerDismissed) {
    await closeProgressDrawer();
    if (!context.mounted) return;
    return;
  }
  if (!context.mounted) return;
  performPopCreateSubrouteIfPossible(context);
}
