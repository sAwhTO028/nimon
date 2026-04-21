import 'package:flutter/material.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_step_id.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';

// -----------------------------------------------------------------------------
// Step ids (drawer + routes)
// -----------------------------------------------------------------------------

class CreatorProgressItem {
  const CreatorProgressItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.actionLabel,
    required this.route,
  });

  final CreatorStepId id;
  final String title;
  /// Progress detail (counts, requirements) — not a second status line.
  final String subtitle;
  /// One of: Not started | In progress | Complete
  final String statusLabel;
  /// One of: Open | Continue | Edit
  final String actionLabel;
  final String route;
}

class CreatorDrawerProgressModel {
  const CreatorDrawerProgressModel({
    required this.coreItems,
    required this.learnItems,
  });

  final List<CreatorProgressItem> coreItems;
  final List<CreatorProgressItem> learnItems;
}

CreatorStepId? creatorActiveStepFromMatchedPath(String matchedPath) {
  final uri = Uri.parse(
    matchedPath.startsWith('/') ? matchedPath : '/$matchedPath',
  );
  final s = uri.pathSegments;
  if (s.length < 3 || s[0] != 'create' || s[1] != 'story') return null;

  if (s.length == 3) {
    return switch (s[2]) {
      'basics' => CreatorStepId.basics,
      'sentences' => CreatorStepId.sentences,
      'review' => CreatorStepId.reviewPublish,
      'learn' => CreatorStepId.learnHub,
      _ => null,
    };
  }

  if (s.length >= 4 && s[2] == 'learn') {
    return switch (s[3]) {
      'vocabulary' => CreatorStepId.vocabulary,
      'grammar' => CreatorStepId.grammar,
      'quiz' => CreatorStepId.quiz,
      'audio' => CreatorStepId.listening,
      _ => CreatorStepId.learnHub,
    };
  }

  return null;
}

CreatorStepId? creatorStepIdFromWorkspaceStep(CreatorWorkspaceStep step) {
  return switch (step) {
    CreatorWorkspaceStep.storyBasics => CreatorStepId.basics,
    CreatorWorkspaceStep.storySentences => CreatorStepId.sentences,
    CreatorWorkspaceStep.vocabulary => CreatorStepId.vocabulary,
    CreatorWorkspaceStep.grammar => CreatorStepId.grammar,
    CreatorWorkspaceStep.quiz => CreatorStepId.quiz,
    CreatorWorkspaceStep.listeningPronunciation => CreatorStepId.listening,
  };
}

/// Single active creator step: on `/create/story/sentences` the embedded
/// workspace step wins so Story sentences is never "Current" while a learn
/// panel is open.
CreatorStepId? creatorEffectiveActiveStep(CreatorDrawerSessionState session) {
  if (isStorySentencesCreatorPath(session.matchedPath)) {
    return switch (session.activeModule) {
      CreatorModule.vocabulary => CreatorStepId.vocabulary,
      CreatorModule.grammar => CreatorStepId.grammar,
      CreatorModule.quiz => CreatorStepId.quiz,
      CreatorModule.listeningPronunciation => CreatorStepId.listening,
      CreatorModule.storySentences => CreatorStepId.sentences,
      CreatorModule.storyBasics => CreatorStepId.basics,
      CreatorModule.storyHub => CreatorStepId.sentences,
      CreatorModule.review => CreatorStepId.sentences,
      CreatorModule.learnHub => CreatorStepId.sentences,
    };
  }
  return creatorActiveStepFromMatchedPath(session.matchedPath);
}

String _moduleSubtitleLine(CreatorModuleCompletion m) {
  final u = m.unmetMessage;
  if (u != null && u.isNotEmpty) return '${m.countLabel} · $u';
  return m.countLabel;
}

(String status, String action) _statusActionFromTask(LearnModuleTaskStatus s) {
  return switch (s) {
    LearnModuleTaskStatus.notStarted => ('Not started', 'Open'),
    LearnModuleTaskStatus.inProgress => ('In progress', 'Continue'),
    LearnModuleTaskStatus.completed => ('Complete', 'Edit'),
  };
}

/// Story basics — count-based status aligned with [computeStoryBasicsStatus].
(String status, String action, String subtitle) _labelsStoryBasics(
  CreatorStoryV1 draft,
  CreatorV1DurationThresholds? t,
) {
  final m = computeStoryBasicsStatus(draft, thresholds: t);
  final pair = _statusActionFromTask(learnModuleTaskStatusFromStoryBasics(draft));
  return (pair.$1, pair.$2, _moduleSubtitleLine(m));
}

/// Story sentences — valid count vs minimum (aligned with [computeStorySentencesStatus]).
(String status, String action, String subtitle) _labelsStorySentences(
  CreatorStoryV1 draft,
  CreatorV1DurationThresholds? t,
) {
  final m = computeStorySentencesStatus(draft, thresholds: t);
  final pair = _statusActionFromTask(learnModuleTaskStatusFromStorySentences(draft));
  return (pair.$1, pair.$2, _moduleSubtitleLine(m));
}

(String status, String action, String subtitle) _labelsLearnModule(
  CreatorStoryV1 draft,
  LearnModuleId id,
  CreatorV1DurationThresholds? t,
) {
  final m = switch (id) {
    LearnModuleId.vocabularyKanji => computeVocabularyStatus(draft, thresholds: t),
    LearnModuleId.grammar => computeGrammarStatus(draft, thresholds: t),
    LearnModuleId.quiz => computeQuizStatus(draft, thresholds: t),
    LearnModuleId.audio => computeListeningStatus(draft, thresholds: t),
  };
  final pair =
      _statusActionFromTask(learnModuleProgressTaskStatus(draft, id, thresholds: t));
  return (pair.$1, pair.$2, _moduleSubtitleLine(m));
}

CreatorDrawerProgressModel buildCreatorDrawerProgressModel({
  required CreatorStoryV1 draft,
}) {
  final t = resolveV1ThresholdsForDraft(draft);

  final basics = _labelsStoryBasics(draft, t);
  final sentences = _labelsStorySentences(draft, t);
  final vocab = _labelsLearnModule(draft, LearnModuleId.vocabularyKanji, t);
  final grammar = _labelsLearnModule(draft, LearnModuleId.grammar, t);
  final quiz = _labelsLearnModule(draft, LearnModuleId.quiz, t);
  final listening = _labelsLearnModule(draft, LearnModuleId.audio, t);

  final learn = <CreatorProgressItem>[
    CreatorProgressItem(
      id: CreatorStepId.vocabulary,
      title: 'Vocabulary',
      subtitle: vocab.$3,
      statusLabel: vocab.$1,
      actionLabel: vocab.$2,
      route: '/create/story/learn/vocabulary',
    ),
    CreatorProgressItem(
      id: CreatorStepId.grammar,
      title: 'Grammar',
      subtitle: grammar.$3,
      statusLabel: grammar.$1,
      actionLabel: grammar.$2,
      route: '/create/story/learn/grammar',
    ),
    CreatorProgressItem(
      id: CreatorStepId.quiz,
      title: 'Quiz',
      subtitle: quiz.$3,
      statusLabel: quiz.$1,
      actionLabel: quiz.$2,
      route: '/create/story/learn/quiz',
    ),
    CreatorProgressItem(
      id: CreatorStepId.listening,
      title: 'Listening / Pronunciation',
      subtitle: listening.$3,
      statusLabel: listening.$1,
      actionLabel: listening.$2,
      route: '/create/story/learn/audio',
    ),
  ];

  return CreatorDrawerProgressModel(
    coreItems: [
      CreatorProgressItem(
        id: CreatorStepId.basics,
        title: 'Story basics',
        subtitle: basics.$3,
        statusLabel: basics.$1,
        actionLabel: basics.$2,
        route: '/create/story/basics',
      ),
      CreatorProgressItem(
        id: CreatorStepId.sentences,
        title: 'Story sentences',
        subtitle: sentences.$3,
        statusLabel: sentences.$1,
        actionLabel: sentences.$2,
        route: '/create/story/sentences',
      ),
    ],
    learnItems: learn,
  );
}

// -----------------------------------------------------------------------------
// Drawer UI
// -----------------------------------------------------------------------------

/// Test / finder scope for the creator progress panel (not a [Scaffold] drawer).
const ValueKey<String> kCreatorProgressDrawerKey =
    ValueKey<String>('creator_progress_drawer');

class CreatorProgressDrawer extends StatefulWidget {
  const CreatorProgressDrawer({
    super.key,
    required this.coreItems,
    required this.learnItems,
    required this.publishModel,
    required this.learnModeEnabled,
    required this.onLearnModeChanged,
    required this.onOpenStep,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final List<CreatorProgressItem> coreItems;
  final List<CreatorProgressItem> learnItems;
  final StoryReviewDisplayModel publishModel;
  /// From [CreatorDrawerSessionState.learnModeEnabled] — single source of truth.
  final bool learnModeEnabled;
  final ValueChanged<bool> onLearnModeChanged;
  final void Function(String route) onOpenStep;
  final VoidCallback onSaveDraft;
  final Future<void> Function(StoryReviewPublishMode mode) onPublish;

  @override
  State<CreatorProgressDrawer> createState() => _CreatorProgressDrawerState();
}

class _CreatorProgressDrawerState extends State<CreatorProgressDrawer> {
  bool _publishing = false;

  StoryReviewPublishMode get _publishMode => widget.learnModeEnabled
      ? StoryReviewPublishMode.fullLearn
      : StoryReviewPublishMode.readingOnly;

  bool get _publishEnabled =>
      isStoryReviewModeAllowed(_publishMode, widget.publishModel);

  String? _publishHelperText() {
    if (_publishEnabled) return null;
    if (!widget.learnModeEnabled) {
      return widget.publishModel.isReadingOnlyReady
          ? null
          : 'Finish story basics and storytelling first.';
    }
    if (!widget.publishModel.isReadingOnlyReady) {
      return 'Finish story basics and storytelling first.';
    }
    return 'Complete all Learn modules to publish Full Learn.';
  }

  Future<void> _handlePublish() async {
    if (_publishing || !_publishEnabled) return;
    setState(() => _publishing = true);
    try {
      await widget.onPublish(_publishMode);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onVar = cs.onSurfaceVariant;
    final helper = _publishHelperText();
    final publishLabel = widget.learnModeEnabled ? 'Full Learn' : 'Read Only';

    return KeyedSubtree(
      key: kCreatorProgressDrawerKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Drawer(
            width: constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 304,
            backgroundColor: cs.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text(
                    'Creator progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onSaveDraft,
                          child: const Text('Save draft'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _publishing || !_publishEnabled
                              ? null
                              : _handlePublish,
                          icon: _publishing
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.publish_rounded, size: 20),
                          label: Text(publishLabel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CreatorProgressSection(
                    title: 'Core progress',
                    items: widget.coreItems,
                    onOpenStep: widget.onOpenStep,
                  ),
                  const SizedBox(height: 16),
                  _LearnModulesBlock(
                    learnItems: widget.learnItems,
                    learnModeEnabled: widget.learnModeEnabled,
                    onLearnModeChanged: widget.onLearnModeChanged,
                    onOpenStep: widget.onOpenStep,
                    theme: theme,
                    colorScheme: cs,
                  ),
                  if (helper != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      helper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onVar,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LearnModulesBlock extends StatelessWidget {
  const _LearnModulesBlock({
    required this.learnItems,
    required this.learnModeEnabled,
    required this.onLearnModeChanged,
    required this.onOpenStep,
    required this.theme,
    required this.colorScheme,
  });

  final List<CreatorProgressItem> learnItems;
  final bool learnModeEnabled;
  final ValueChanged<bool> onLearnModeChanged;
  final void Function(String route) onOpenStep;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Learn modules',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Learn mode',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: learnModeEnabled,
              onChanged: onLearnModeChanged,
            ),
          ],
        ),
        if (!learnModeEnabled) ...[
          const SizedBox(height: 8),
          Text(
            'Turn on Learn mode to work on Vocabulary, Grammar, Quiz, and Listening. '
            'Read Only flow uses story core only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: learnModeEnabled
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final i in learnItems)
                        _CreatorProgressRow(item: i, onOpenStep: onOpenStep),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CreatorProgressSection extends StatelessWidget {
  const _CreatorProgressSection({
    required this.title,
    required this.items,
    required this.onOpenStep,
  });

  final String title;
  final List<CreatorProgressItem> items;
  final void Function(String route) onOpenStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((i) => _CreatorProgressRow(item: i, onOpenStep: onOpenStep)),
      ],
    );
  }
}

class _CreatorProgressRow extends StatelessWidget {
  const _CreatorProgressRow({
    required this.item,
    required this.onOpenStep,
  });

  final CreatorProgressItem item;
  final void Function(String route) onOpenStep;

  static const _completeGreen = Color(0xFFDDF5E3);
  static const _completeGreenInk = Color(0xFF1E6B33);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final status = item.statusLabel;
    final isComplete = status == 'Complete';
    final isInProgress = status == 'In progress';

    final (chipLabel, chipColor, chipTextColor) = isComplete
        ? ('Complete', _completeGreen, _completeGreenInk)
        : isInProgress
            ? ('In progress', cs.primaryContainer, cs.onPrimaryContainer)
            : ('Not started', cs.surfaceContainerHighest, cs.onSurfaceVariant);

    final actionLabel = item.actionLabel;

    return Card(
      key: ValueKey<String>('creator_progress_${item.id.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 232;
            final titleChipRow = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: chipTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
            final subtitle = Text(
              item.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.25,
              ),
            );
            final action = TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onOpenStep(item.route),
              child: Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleChipRow,
                  const SizedBox(height: 4),
                  subtitle,
                  Align(
                    alignment: Alignment.centerRight,
                    child: action,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleChipRow,
                      const SizedBox(height: 4),
                      subtitle,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
