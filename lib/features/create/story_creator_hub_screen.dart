import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_progress_checklist.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Entry + step overview for the structured Story Creator workflow.
class StoryCreatorHubScreen extends ConsumerWidget {
  const StoryCreatorHubScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);
  static String _phaseLabel(StoryPublishState p) => switch (p) {
        StoryPublishState.draft => 'Draft only',
        StoryPublishState.readingOnlyPublished => 'Reading Only',
        StoryPublishState.fullLearnPublished => 'Full Learn',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    syncCreatorDrawerSessionFromContext(context, ref);
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Creator'),
        leading: NimonBackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'V1 workflow',
            style: theme.textTheme.titleLarge?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build the story core first (basics + sentences). Learn modules are optional add-ons. '
            'You can publish as Reading Only without finishing Learn.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current publish mode',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(
                label: Text(_phaseLabel(draft.publishState)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          StoryCreatorProgressChecklist(story: draft),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () {
              unawaited(
                ref
                    .read(storyCreatorDraftProvider.notifier)
                    .discardDraftFromDiskAndReset(),
              );
              context.push('/create/story/basics');
            },
            child: const Text('Start new story'),
          ),
          const SizedBox(height: 12),
          FutureBuilder<bool>(
            future: ref.read(storyDraftRepositoryProvider).hasAnyIndexedDraft(),
            builder: (context, snap) {
              final hasDraft = snap.data == true;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: hasDraft
                        ? () {
                            final path = _continuePath(draft);
                            context.push(path);
                          }
                        : null,
                    child: const Text('Continue current story'),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<DateTime?>(
                    future:
                        ref.read(storyDraftRepositoryProvider).savedAtActiveDraft(),
                    builder: (context, snap2) {
                      final dt = snap2.data;
                      final label = !hasDraft
                          ? 'No saved draft yet.'
                          : (dt == null
                              ? 'Draft found.'
                              : 'Last saved: ${dt.toLocal().toString()}');
                      return Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted,
                          height: 1.3,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _continuePath(CreatorStoryV1 d) {
    if (!d.isBasicsComplete) return '/create/story/basics';
    return '/create/story/sentences';
  }
}
