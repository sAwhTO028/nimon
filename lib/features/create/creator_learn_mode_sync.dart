import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

/// True when the user is on a Learn-only surface (embedded Learn panel, or Learn hub).
bool creatorSessionIsOnLearnSurface(CreatorDrawerSessionState s) {
  switch (s.activeModule) {
    case CreatorModule.vocabulary:
    case CreatorModule.grammar:
    case CreatorModule.quiz:
    case CreatorModule.listeningPronunciation:
      return true;
    case CreatorModule.storyHub:
    case CreatorModule.storyBasics:
    case CreatorModule.storySentences:
    case CreatorModule.review:
      return false;
  }
}

/// [creatorDrawerSession] can lag after drawer interactions; query matches current URL.
bool creatorGoRouterOnLearnCreatePath(
  BuildContext context, {
  required bool learnModeEnabled,
}) {
  if (learnModeEnabled) return false;
  try {
    final uri = GoRouterState.of(context).uri;
    if (uri.path.contains('/create/story/learn')) return true;
    final panel = (uri.queryParameters['panel'] ?? '').trim();
    if (panel == 'vocabulary' ||
        panel == 'grammar' ||
        panel == 'quiz' ||
        panel == 'listening') {
      return true;
    }
  } catch (_) {
    // No GoRouter (tests) — fall through.
  }
  return false;
}

/// Updates [learnModeEnabled]. Turning **on** does not navigate or close UI.
///
/// When turning **off**, optionally runs [closeDrawerOnTurnOff] first, then leaves any
/// Learn module screen for Storytelling ([CreatorWorkspaceStep.storySentences] on the sentences host).
void applyCreatorLearnMode({
  required BuildContext context,
  required WidgetRef ref,
  required bool learnModeEnabled,
  VoidCallback? closeDrawerOnTurnOff,
}) {
  ref.read(creatorDrawerSessionProvider.notifier).setLearnMode(learnModeEnabled);

  if (learnModeEnabled) return;

  final session = ref.read(creatorDrawerSessionProvider);
  final onLearn = creatorSessionIsOnLearnSurface(session) ||
      creatorGoRouterOnLearnCreatePath(
        context,
        learnModeEnabled: learnModeEnabled,
      );
  if (!onLearn) return;

  if (!context.mounted) return;
  final draftId = ref.read(storyCreatorDraftDataProvider).id.trim();
  final r = GoRouter.of(context);
  normalizeLearnModuleToStorySentencesMain(
    ref,
    router: r,
    draftId: draftId,
  );
  // After [go], optional UI teardown (e.g. close material drawer) without relying on
  // [maybePop] before navigation (which can unmount this [context] on some routes).
  closeDrawerOnTurnOff?.call();
}
