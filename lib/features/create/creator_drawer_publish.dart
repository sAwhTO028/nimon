import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/features/profile/profile_navigation_helpers.dart';

/// Single publish path for the creator drawer (Read Only vs Full Learn).
Future<void> performCreatorDrawerPublish({
  required WidgetRef ref,
  required BuildContext context,
  required StoryReviewPublishMode mode,
}) async {
  final notifier = ref.read(storyCreatorDraftProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);

  switch (mode) {
    case StoryReviewPublishMode.readingOnly:
      final publishedId = ref.read(storyCreatorDraftDataProvider).id;
      final ok = await notifier.publishReadingOnlyToDisk();
      if (!context.mounted) return;
      final st = ref.read(storyCreatorDraftProvider);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              st.lastSaveError?.isNotEmpty == true
                  ? 'Could not publish: ${st.lastSaveError}'
                  : 'Could not publish Read Only. Try again.',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Read Only published',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can continue Learn setup anytime from Processing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onInverseSurface
                          .withValues(alpha: 0.92),
                    ),
              ),
            ],
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ProfileNavigation.openProcessingTab(
          context,
          highlightDraftId: publishedId,
        );
      });
    case StoryReviewPublishMode.fullLearn:
      final publishedId = ref.read(storyCreatorDraftDataProvider).id;
      final ok = await notifier.publishFullLearnToDisk();
      if (!context.mounted) return;
      final st = ref.read(storyCreatorDraftProvider);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              st.lastSaveError?.isNotEmpty == true
                  ? 'Could not publish: ${st.lastSaveError}'
                  : 'Could not publish Full Learn. Try again.',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full Learn published',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your full learning version is now ready.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onInverseSurface
                          .withValues(alpha: 0.92),
                    ),
              ),
            ],
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ProfileNavigation.openProcessingTab(
          context,
          highlightDraftId: publishedId,
        );
      });
  }
}
