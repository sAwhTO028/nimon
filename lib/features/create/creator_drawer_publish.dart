import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/features/profile/profile_navigation_helpers.dart';
import 'package:nimon/ui/app_messenger.dart';

/// Single publish path for the creator drawer (Read Only vs Full Learn).
Future<void> performCreatorDrawerPublish({
  required WidgetRef ref,
  required BuildContext context,
  required StoryReviewPublishMode mode,
}) async {
  // Capture inherited dependencies synchronously. After an async publish, this
  // element can become inactive during navigation/back presses; avoid inherited
  // lookups like Theme.of(context) / ScaffoldMessenger.of(context) afterward.
  final router = GoRouter.maybeOf(context);
  final notifier = ref.read(storyCreatorDraftProvider.notifier);
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final titleStyle = theme.textTheme.titleSmall?.copyWith(
    fontWeight: FontWeight.w800,
    color: cs.onInverseSurface,
  );
  final bodyStyle = theme.textTheme.bodySmall?.copyWith(
    color: cs.onInverseSurface.withValues(alpha: 0.92),
  );

  final publishing = ref.read(creatorPublishInProgressProvider.notifier);
  if (!publishing.state) publishing.state = true;
  try {
    switch (mode) {
      case StoryReviewPublishMode.readingOnly:
        final publishedId = ref.read(storyCreatorDraftDataProvider).id;
        final ok = await notifier.publishReadingOnlyToDisk();
        if (!context.mounted) return;
        final st = ref.read(storyCreatorDraftProvider);
        final failureSnack = SnackBar(
          content: Text(
            st.lastSaveError?.isNotEmpty == true
                ? 'Could not publish: ${st.lastSaveError}'
                : 'Could not publish Read Only. Try again.',
          ),
        );
        final successSnack = SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Read Only published', style: titleStyle),
              const SizedBox(height: 4),
              Text(
                'You can continue Learn setup anytime from Workspace.',
                style: bodyStyle,
              ),
            ],
          ),
        );
        if (!ok) {
          nimonShowRootSnackBarAfterRouteSettles(failureSnack);
          return;
        }
        if (router != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ProfileNavigation.openPublishedTabForRouter(
              router,
              highlightDraftId: publishedId,
            );
            nimonShowRootSnackBarAfterRouteSettles(successSnack);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ProfileNavigation.openPublishedTab(
              context,
              highlightDraftId: publishedId,
            );
            nimonShowRootSnackBarAfterRouteSettles(successSnack);
          });
        }
      case StoryReviewPublishMode.fullLearn:
        final publishedId = ref.read(storyCreatorDraftDataProvider).id;
        final ok = await notifier.publishFullLearnToDisk();
        if (!context.mounted) return;
        final st = ref.read(storyCreatorDraftProvider);
        final failureSnack = SnackBar(
          content: Text(
            st.lastSaveError?.isNotEmpty == true
                ? 'Could not publish: ${st.lastSaveError}'
                : 'Could not publish Full Learn. Try again.',
          ),
        );
        final successSnack = SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Full Learn published', style: titleStyle),
              const SizedBox(height: 4),
              Text('Your full learning version is now ready.', style: bodyStyle),
            ],
          ),
        );
        if (!ok) {
          nimonShowRootSnackBarAfterRouteSettles(failureSnack);
          return;
        }
        if (router != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ProfileNavigation.openPublishedTabForRouter(
              router,
              highlightDraftId: publishedId,
            );
            nimonShowRootSnackBarAfterRouteSettles(successSnack);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ProfileNavigation.openPublishedTab(
              context,
              highlightDraftId: publishedId,
            );
            nimonShowRootSnackBarAfterRouteSettles(successSnack);
          });
        }
    }
  } finally {
    publishing.state = false;
  }
}
