import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_navigation_debug.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

/// Pushes the current `/create/story/...` location into [creatorDrawerSessionProvider].
void syncCreatorDrawerSessionFromContext(BuildContext context, WidgetRef ref) {
  try {
    final st = GoRouterState.of(context);
    creatorNavDebug(
      'route_sync',
      'uri=${st.uri} matchedLocation=${st.matchedLocation} '
      'panel=${st.uri.queryParameters['panel']}',
    );
    // Prefer full [Uri]: [matchedLocation] can be a subtree while the user is
    // still on `/create/story/sentences?panel=vocabulary` (embedded learn).
    //
    // Important: schedule after build to avoid Riverpod "modify during build"
    // assertions when screens call this from build() (common in creator pages).
    final notifier = ref.read(creatorDrawerSessionProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final canonicalMatched = st.uri.path.startsWith('/create/story/sentences')
          ? '/create/story/sentences'
          : st.matchedLocation;
      notifier.reportRoute(
        canonicalMatched,
        locationUri: st.uri,
      );

      // Persist per-draft resume metadata: last active module + subpage (panel).
      //
      // Draft id is explicit on creator routes; fall back to in-memory draft id.
      final qp = st.uri.queryParameters;
      final fromQ = (qp['draftId'] ?? '').trim();
      final draftId = fromQ.isNotEmpty ? fromQ : ref.read(storyCreatorDraftDataProvider).id;
      if (draftId.trim().isEmpty) return;

      final path = st.uri.path;
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
          StoryCreatorDraftResumeStorage.recordLastActive(
            draftId: draftId,
            module: module,
            subPage: subPage,
          ),
        );
      }
    });
  } catch (_) {
    // No GoRouter in tree (tests / embeds) — ignore.
  }
}
