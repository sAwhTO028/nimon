import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_navigation_debug.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_provider.dart';

final Expando<String> _nimonCreatorLastSyncSig =
    Expando<String>('nimon_creator_last_sync_sig');
final Expando<String> _nimonCreatorPendingPostFrameSig =
    Expando<String>('nimon_creator_pending_post_frame_sig');

/// Stable route identity for sync dedupe (hand-built [Uri] vs [GoRouter.state.uri]).
String _creatorRouteDedupeUriKey(Uri uri) {
  final path = uri.path;
  if (path != '/create/story/sentences' &&
      !path.startsWith('/create/story/sentences/')) {
    return uri.toString();
  }
  final draft = (uri.queryParameters['draftId'] ?? '').trim();
  final panel = (uri.queryParameters['panel'] ?? '').trim();
  final q = <String, String>{};
  if (draft.isNotEmpty) q['draftId'] = draft;
  if (panel.isNotEmpty) q['panel'] = panel;
  return Uri(
    path: '/create/story/sentences',
    queryParameters: q.isEmpty ? null : q,
  ).toString();
}

bool _sentencesUriShowsLearnEmbed(Uri u) {
  if (!u.path.startsWith('/create/story/sentences')) return false;
  return creatorWorkspaceStepForSentencesPanel(u.queryParameters['panel']) !=
      null;
}

String _creatorSyncSig({
  required Uri uri,
  required String matchedLocation,
  required String draftId,
  required bool learnModeEnabled,
}) {
  return '${_creatorRouteDedupeUriKey(uri)}|matched=$matchedLocation|draft=$draftId|learn=$learnModeEnabled';
}

/// Loads the local story draft to match the router [draftId] (canonical in V1). Idempotent
/// for matching ids; not invoked from [Widget.build] — only from the route→session reconciler.
///
/// Same-id skips are enforced in [StoryCreatorDraftNotifier.loadDraftById] so in-memory edits
/// are never replaced by a redundant disk read when the URL draftId matches the active draft.
void _reconcileDraftIdWithRouter(WidgetRef ref, Uri locationUri) {
  final fromQ = (locationUri.queryParameters['draftId'] ?? '').trim();
  if (fromQ.isEmpty) return;
  unawaited(
    ref.read(storyCreatorDraftProvider.notifier).loadDraftById(fromQ),
  );
}

void _recordResumeFromLocationUri(WidgetRef ref, Uri fresh) {
  final qp = fresh.queryParameters;
  final fromQ = (qp['draftId'] ?? '').trim();
  final draftId =
      fromQ.isNotEmpty ? fromQ : ref.read(storyCreatorDraftDataProvider).id;
  if (draftId.trim().isEmpty) return;

  final path = fresh.path;
  final panel = (qp['panel'] ?? '').trim();

  CreatorLastActiveModule? module;
  String? subPage;

  if (path.startsWith('/create/story/basics')) {
    module = CreatorLastActiveModule.storyBasics;
  } else if (path.startsWith('/create/story/sentences')) {
    if (panel == 'vocabulary') {
      module = CreatorLastActiveModule.semantics;
      subPage = 'vocabulary';
    } else if (panel == 'grammar') {
      module = CreatorLastActiveModule.grammar;
      subPage = 'grammar';
    } else if (panel == 'quiz') {
      module = CreatorLastActiveModule.quizzes;
      subPage = 'quiz';
    } else if (panel == 'listening') {
      module = CreatorLastActiveModule.listening;
      subPage = 'listening';
    } else {
      module = CreatorLastActiveModule.storytelling;
      subPage = null;
    }
  }

  if (module != null) {
    unawaited(
      ref.read(storyDraftRepositoryProvider).recordResumeNavigation(
            draftId: draftId,
            module: module,
            subPage: subPage,
          ),
    );
  }
}

/// Apply [locationUri] to [creatorDrawerSessionProvider] and advance router sync dedupe
/// so post-frame callbacks scheduled from an *intermediate* [GoRouter.state] during
/// [context.go] cannot clobber learn `?panel=` (Group A: drawer Open vs session drift).
///
/// Call with the same [Uri] passed to [GoRouter.go] (router remains canonical).
void syncCreatorDrawerSessionForResolvedLocation(
  GoRouter router,
  WidgetRef ref,
  Uri locationUri,
) {
  if (!locationUri.path.startsWith('/create/story')) return;

  _reconcileDraftIdWithRouter(ref, locationUri);

  final matchedNow = locationUri.path.startsWith('/create/story/sentences')
      ? '/create/story/sentences'
      : router.state.matchedLocation;
  final fromQ = (locationUri.queryParameters['draftId'] ?? '').trim();
  final draftIdForSig = fromQ.isNotEmpty
      ? fromQ
      : ref.read(storyCreatorDraftDataProvider).id.trim();
  final learnNow = ref.read(creatorDrawerSessionProvider).learnModeEnabled;
  final sig = _creatorSyncSig(
    uri: locationUri,
    matchedLocation: matchedNow,
    draftId: draftIdForSig,
    learnModeEnabled: learnNow,
  );

  _nimonCreatorLastSyncSig[router] = sig;

  creatorNavDebug(
    'route_sync_resolved',
    'uri=$locationUri matched=$matchedNow panel=${locationUri.queryParameters['panel']}',
  );

  ref.read(creatorDrawerSessionProvider.notifier).reportRoute(
        matchedNow,
        locationUri: locationUri,
      );
  _recordResumeFromLocationUri(ref, locationUri);
}

/// Syncs creator drawer session from the current [GoRouter] state (no [BuildContext]).
///
/// Use this after [context.go] / route swaps when the caller's [BuildContext] may already
/// be [ElementLifecycle.inactive] while [State.mounted] is still true.
void syncCreatorDrawerSessionForRouter(GoRouter router, WidgetRef ref) {
  // Route guard: after publishing we may navigate away (e.g. to `/more`).
  // Avoid continuing creator session sync when not under `/create/story`.
  if (!router.state.uri.path.startsWith('/create/story')) {
    return;
  }

  _reconcileDraftIdWithRouter(ref, router.state.uri);

  final uriNow = router.state.uri;
  final matchedNow = router.state.matchedLocation;
  final fromQ = (uriNow.queryParameters['draftId'] ?? '').trim();
  final draftIdForSig = fromQ.isNotEmpty
      ? fromQ
      : ref.read(storyCreatorDraftDataProvider).id.trim();
  final learnNow = ref.read(creatorDrawerSessionProvider).learnModeEnabled;
  final sig = _creatorSyncSig(
    uri: uriNow,
    matchedLocation: matchedNow,
    draftId: draftIdForSig,
    learnModeEnabled: learnNow,
  );

  if (_nimonCreatorLastSyncSig[router] == sig) return;
  _nimonCreatorLastSyncSig[router] = sig;

  creatorNavDebug(
    'route_sync',
    'router uri=${router.state.uri} matchedLocation=${router.state.matchedLocation} '
        'panel=${router.state.uri.queryParameters['panel']}',
  );
  final notifier = ref.read(creatorDrawerSessionProvider.notifier);

  // Dedupe post-frame scheduling.
  if (_nimonCreatorPendingPostFrameSig[router] == sig) return;
  _nimonCreatorPendingPostFrameSig[router] = sig;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      // Superseded by a newer [syncCreatorDrawerSessionForRouter] (route changed again
      // before this frame). Avoids session / provider work after the creator subtree exits.
      if (_nimonCreatorLastSyncSig[router] != sig) {
        return;
      }
      if (_nimonCreatorPendingPostFrameSig[router] == sig) {
        _nimonCreatorPendingPostFrameSig[router] = null;
      }
      if (!router.state.uri.path.startsWith('/create/story')) {
        return;
      }
      final fresh = router.state.uri;
      if (_sentencesUriShowsLearnEmbed(uriNow) &&
          !_sentencesUriShowsLearnEmbed(fresh)) {
        // [router.state.uri] can lag the delegate notification that scheduled this
        // callback; retry once after microtasks instead of applying a stale main host.
        unawaited(
          Future<void>.microtask(
              () => syncCreatorDrawerSessionForRouter(router, ref)),
        );
        return;
      }
      final canonicalMatched = fresh.path.startsWith('/create/story/sentences')
          ? '/create/story/sentences'
          : router.state.matchedLocation;
      notifier.reportRoute(
        canonicalMatched,
        locationUri: fresh,
      );

      _recordResumeFromLocationUri(ref, fresh);
    } catch (_) {
      // [ref] / router subtree disposed while the post-frame callback was queued.
    }
  });
}
