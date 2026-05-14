import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_publish_preflight.dart';
import 'package:nimon/features/create/creator_publish_status_provider.dart';
import 'package:nimon/features/create/data/story_draft_remote_publish_errors.dart';
import 'package:nimon/features/create/publish_validation_sheet.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/features/profile/profile_navigation_helpers.dart';
import 'package:nimon/ui/app_messenger.dart';
import 'package:nimon/ui/blocking_loading_overlay.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';

String _publishOverlayMessage(
    StoryReviewPublishMode mode, CreatorStoryV1 draft) {
  if (mode == StoryReviewPublishMode.readingOnly) {
    final updating =
        draft.publishState == StoryPublishState.readingOnlyPublished &&
            draft.hasUnpublishedCoreChanges == true;
    return updating ? 'Updating…' : 'Publishing…';
  }
  final updating = draft.publishState == StoryPublishState.fullLearnPublished &&
      draft.hasUnpublishedCoreChanges == true;
  return updating ? 'Updating…' : 'Publishing…';
}

Future<bool> _preflightCreatorPublish({
  required WidgetRef ref,
  required BuildContext context,
  required StoryReviewPublishMode publishMode,
}) async {
  final draft = ref.read(storyCreatorDraftDataProvider);
  final data = storyPublishDataFromCreator(draft);
  final vm = publishMode == StoryReviewPublishMode.readingOnly
      ? ValidationMode.readOnlyPublish
      : ValidationMode.fullLearnPublish;
  final pre = validateStoryPublishData(data, vm);
  if (hasBlockingIssues(pre)) {
    if (context.mounted) {
      await showPublishValidationSheet(context, issues: pre.issues);
    }
    return false;
  }
  if (hasWarningIssues(pre)) {
    if (!context.mounted) return false;
    final go = await showPublishValidationSheet(
      context,
      issues: pre.issues,
      showPublishAnyway: true,
    );
    if (!go) return false;
  }
  return true;
}

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
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.publishStory,
    )) {
      return;
    }
    if (!context.mounted) return;
    if (!await _preflightCreatorPublish(
      ref: ref,
      context: context,
      publishMode: mode,
    )) {
      return;
    }

    switch (mode) {
      case StoryReviewPublishMode.readingOnly:
        final publishedId = ref.read(storyCreatorDraftDataProvider).id;
        final closeLoading = showBlockingLoadingOverlay(
          context,
          _publishOverlayMessage(mode, ref.read(storyCreatorDraftDataProvider)),
        );
        var ok = false;
        StoryDraftValidationFailedException? validationErr;
        AppQuotaExceededException? quotaErr;
        try {
          ok = await notifier.publishReadingOnlyToDisk();
        } on StoryDraftValidationFailedException catch (e) {
          validationErr = e;
        } on AppQuotaExceededException catch (e) {
          quotaErr = e;
        } finally {
          closeLoading();
        }
        if (validationErr != null) {
          if (context.mounted) {
            await showPublishValidationSheet(context, issues: validationErr.issues);
          }
          return;
        }
        if (quotaErr != null) {
          if (context.mounted) {
            await showQuotaExceededDialog(context, quotaErr);
          }
          return;
        }
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
        final closeLoadingFl = showBlockingLoadingOverlay(
          context,
          _publishOverlayMessage(mode, ref.read(storyCreatorDraftDataProvider)),
        );
        var ok = false;
        StoryDraftValidationFailedException? validationErrFl;
        AppQuotaExceededException? quotaErrFl;
        try {
          ok = await notifier.publishFullLearnToDisk();
        } on StoryDraftValidationFailedException catch (e) {
          validationErrFl = e;
        } on AppQuotaExceededException catch (e) {
          quotaErrFl = e;
        } finally {
          closeLoadingFl();
        }
        if (validationErrFl != null) {
          if (context.mounted) {
            await showPublishValidationSheet(context, issues: validationErrFl.issues);
          }
          return;
        }
        if (quotaErrFl != null) {
          if (context.mounted) {
            await showQuotaExceededDialog(context, quotaErrFl);
          }
          return;
        }
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
              Text('Your full learning version is now ready.',
                  style: bodyStyle),
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
    ref.read(creatorPublishStatusTextProvider.notifier).state = null;
  }
}
