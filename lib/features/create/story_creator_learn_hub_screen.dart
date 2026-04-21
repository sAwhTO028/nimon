import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/creator_publish_validation.dart';
import 'package:nimon/features/create/creator_progress_logic.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_progress_checklist.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Step 4 — optional Learn tasks (editors are stubs in V1).
class StoryCreatorLearnHubScreen extends ConsumerWidget {
  const StoryCreatorLearnHubScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  static String _desc(LearnModuleId id) => switch (id) {
        LearnModuleId.vocabularyKanji => 'Add key words readers should learn.',
        LearnModuleId.grammar => 'Add grammar patterns from this story.',
        LearnModuleId.quiz => 'Add practice questions for readers.',
        LearnModuleId.audio => 'Attach one full-story audio source.',
      };

  static String _ctaLabel(LearnModuleTaskStatus s) => switch (s) {
        LearnModuleTaskStatus.notStarted => 'Open',
        LearnModuleTaskStatus.inProgress => 'Continue',
        LearnModuleTaskStatus.completed => 'Edit',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    syncCreatorDrawerSessionFromContext(context, ref);
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final draftId = draft.id;
    final theme = Theme.of(context);
    final incompleteLearn = draft.incompleteLearnModulesV1();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn modules'),
        leading: NimonBackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Optional add-ons',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These modules are optional for Reading Only. Complete all modules for Full Learn.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _muted,
              height: 1.4,
            ),
          ),
          if (draft.publishState == StoryPublishState.readingOnlyPublished &&
              incompleteLearn.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ReadingOnlyUpgradeHintCard(
              label: draft.incompleteLearnModulesLabel(),
              onContinueEditing: () =>
                  context.push('/create/story/sentences?draftId=$draftId'),
            ),
          ],
          const SizedBox(height: 16),
          StoryCreatorProgressChecklist(
            story: draft,
            showPublishSummary: false,
            compact: true,
          ),
          const SizedBox(height: 20),
          for (final id in LearnModuleId.values)
            _ModuleCard(
              title: id.displayTitle,
              description: _desc(id),
              effectiveStatus: draft.learnModuleProgressStatus(id),
              effectiveLabel: draft.learnModuleProgressLabel(id),
              ctaLabel: _ctaLabel(draft.learnModuleProgressStatus(id)),
              onOpenStub: () {
                if (id == LearnModuleId.vocabularyKanji) {
                  context.push(
                    '/create/story/sentences?draftId=$draftId&panel=vocabulary',
                  );
                  return;
                }
                if (id == LearnModuleId.grammar) {
                  context.push(
                    '/create/story/sentences?draftId=$draftId&panel=grammar',
                  );
                  return;
                }
                if (id == LearnModuleId.quiz) {
                  context.push(
                    '/create/story/sentences?draftId=$draftId&panel=quiz',
                  );
                  return;
                }
                if (id == LearnModuleId.audio) {
                  context.push(
                    '/create/story/sentences?draftId=$draftId&panel=listening',
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('${id.displayTitle} editor — V1 structure only.'),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () =>
                context.push('/create/story/sentences?draftId=$draftId'),
            child: const Text('Back to story'),
          ),
        ],
      ),
    );
  }
}

class _ReadingOnlyUpgradeHintCard extends StatelessWidget {
  const _ReadingOnlyUpgradeHintCard({
    required this.label,
    required this.onContinueEditing,
  });

  final String label;
  final VoidCallback onContinueEditing;

  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Published for reading',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You can keep adding Learn modules to upgrade toward Full Learn later.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Still incomplete: $label',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onContinueEditing,
              child: const Text('Continue editing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.description,
    required this.effectiveStatus,
    required this.effectiveLabel,
    required this.ctaLabel,
    required this.onOpenStub,
  });

  final String title;
  final String description;
  final LearnModuleTaskStatus effectiveStatus;
  final String effectiveLabel;
  final String ctaLabel;
  final VoidCallback onOpenStub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color chipBg, Color chipFg, IconData icon) = switch (effectiveStatus) {
      LearnModuleTaskStatus.completed => (
          const Color(0xFFE8F0E8),
          const Color(0xFF2E6B3C),
          Icons.check_circle_rounded,
        ),
      LearnModuleTaskStatus.inProgress => (
          const Color(0xFFFFF7ED),
          const Color(0xFFB45309),
          Icons.timelapse_rounded,
        ),
      LearnModuleTaskStatus.notStarted => (
          const Color(0xFFF0F0F0),
          const Color(0xFF5C5A55),
          Icons.radio_button_unchecked_rounded,
        ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: chipFg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: chipFg.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    effectiveLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: chipFg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenStub,
                    child: Text(ctaLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
