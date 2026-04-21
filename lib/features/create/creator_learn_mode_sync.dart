import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

/// True when the user is on a Learn-only surface (embedded Learn panel, or Learn hub).
bool creatorSessionIsOnLearnSurface(CreatorDrawerSessionState s) {
  switch (s.activeModule) {
    case CreatorModule.vocabulary:
    case CreatorModule.grammar:
    case CreatorModule.quiz:
    case CreatorModule.listeningPronunciation:
    case CreatorModule.learnHub:
      return true;
    case CreatorModule.storyHub:
    case CreatorModule.storyBasics:
    case CreatorModule.storySentences:
    case CreatorModule.review:
      return false;
  }
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

  closeDrawerOnTurnOff?.call();

  final session = ref.read(creatorDrawerSessionProvider);
  if (!creatorSessionIsOnLearnSurface(session)) return;

  ref
      .read(creatorDrawerSessionProvider.notifier)
      .setSentencesMainStep(CreatorWorkspaceStep.storySentences);

  if (!context.mounted) return;

  final draftId = ref.read(storyCreatorDraftDataProvider).id.trim();
  final target = draftId.isEmpty
      ? '/create/story/sentences'
      : '/create/story/sentences?draftId=$draftId';
  context.go(target);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    syncCreatorDrawerSessionFromContext(context, ref);
  });
}
