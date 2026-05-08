import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/creator_drawer_publish_labels.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_publish_status_provider.dart';
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
      // Standalone /create/story/learn hub is removed from the product flow.
      // If the router ever reports it (unexpected), treat it as sentences.
      'learn' => CreatorStepId.sentences,
      _ => null,
    };
  }

  if (s.length >= 4 && s[2] == 'learn') {
    return switch (s[3]) {
      'vocabulary' => CreatorStepId.vocabulary,
      'grammar' => CreatorStepId.grammar,
      'quiz' => CreatorStepId.quiz,
      'audio' => CreatorStepId.listening,
      _ => CreatorStepId.sentences,
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
  final pair =
      _statusActionFromTask(learnModuleTaskStatusFromStoryBasics(draft));
  return (pair.$1, pair.$2, _moduleSubtitleLine(m));
}

/// Story sentences — valid count vs minimum (aligned with [computeStorySentencesStatus]).
(String status, String action, String subtitle) _labelsStorySentences(
  CreatorStoryV1 draft,
  CreatorV1DurationThresholds? t,
) {
  final m = computeStorySentencesStatus(draft, thresholds: t);
  final pair =
      _statusActionFromTask(learnModuleTaskStatusFromStorySentences(draft));
  return (pair.$1, pair.$2, _moduleSubtitleLine(m));
}

(String status, String action, String subtitle) _labelsLearnModule(
  CreatorStoryV1 draft,
  LearnModuleId id,
  CreatorV1DurationThresholds? t,
) {
  final m = switch (id) {
    LearnModuleId.vocabularyKanji =>
      computeVocabularyStatus(draft, thresholds: t),
    LearnModuleId.grammar => computeGrammarStatus(draft, thresholds: t),
    LearnModuleId.quiz => computeQuizStatus(draft, thresholds: t),
    LearnModuleId.audio => computeListeningStatus(draft, thresholds: t),
  };
  final pair = _statusActionFromTask(
      learnModuleProgressTaskStatus(draft, id, thresholds: t));
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
      route: '/create/story/sentences?panel=vocabulary',
    ),
    CreatorProgressItem(
      id: CreatorStepId.grammar,
      title: 'Grammar',
      subtitle: grammar.$3,
      statusLabel: grammar.$1,
      actionLabel: grammar.$2,
      route: '/create/story/sentences?panel=grammar',
    ),
    CreatorProgressItem(
      id: CreatorStepId.quiz,
      title: 'Quiz',
      subtitle: quiz.$3,
      statusLabel: quiz.$1,
      actionLabel: quiz.$2,
      route: '/create/story/sentences?panel=quiz',
    ),
    CreatorProgressItem(
      id: CreatorStepId.listening,
      title: 'Listening / Pronunciation',
      subtitle: listening.$3,
      statusLabel: listening.$1,
      actionLabel: listening.$2,
      route: '/create/story/sentences?panel=listening',
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

/// Distinct [KeyedSubtree] keys so Sentences + module editors can coexist briefly
/// (e.g. during navigation) without "Duplicate key" / GlobalKey-style collisions.
const ValueKey<String> kCreatorProgressDrawerKeySentences =
    ValueKey<String>('creator_progress_drawer_sentences');
const ValueKey<String> kCreatorProgressDrawerKeyVocabulary =
    ValueKey<String>('creator_progress_drawer_vocabulary');
const ValueKey<String> kCreatorProgressDrawerKeyGrammar =
    ValueKey<String>('creator_progress_drawer_grammar');
const ValueKey<String> kCreatorProgressDrawerKeyQuiz =
    ValueKey<String>('creator_progress_drawer_quiz');
const ValueKey<String> kCreatorProgressDrawerKeyListening =
    ValueKey<String>('creator_progress_drawer_listening');

class CreatorProgressDrawer extends ConsumerStatefulWidget {
  const CreatorProgressDrawer({
    super.key,

    /// Must match [kCreatorProgressDrawerKey*] used for this host (sentences / vocab / grammar).
    required this.drawerKeySlot,
    required this.coreItems,
    required this.learnItems,
    required this.publishModel,
    required this.readOnlyPublishedExists,
    required this.readOnlyHasUnpublishedChanges,
    required this.fullLearnPublishedExists,
    required this.fullLearnHasUnpublishedChanges,
    required this.learnModeEnabled,
    required this.currentStepId,
    required this.onLearnModeChanged,
    required this.onOpenStep,
    required this.onSaveDraft,
    required this.onPublish,
    required this.creatorDraft,
    required this.localDraftDirty,
    required this.readOnlyPublishedCoreSig,
    required this.publishedEditReadOnlyBaselineSig,
    required this.publishedEditFullLearnBaselineSig,
  });

  /// Drives a unique [KeyedSubtree] so multiple creator surfaces never share one key.
  final ValueKey<String> drawerKeySlot;
  final List<CreatorProgressItem> coreItems;
  final List<CreatorProgressItem> learnItems;
  final StoryReviewDisplayModel publishModel;

  /// True when a Read Only version exists (published at least once).
  final bool readOnlyPublishedExists;

  /// True when the current draft core differs from the last Read Only published core.
  final bool readOnlyHasUnpublishedChanges;

  /// True when [CreatorStoryV1.publishState] is [StoryPublishState.fullLearnPublished].
  final bool fullLearnPublishedExists;

  /// True when Full Learn needs republish (core staging and/or unsaved learn edits).
  final bool fullLearnHasUnpublishedChanges;

  /// Current in-memory draft (trace + parity with flags computed upstream).
  final CreatorStoryV1 creatorDraft;

  /// True while local edits are not flushed to disk / remote ([StoryCreatorDraftState.dirty]).
  final bool localDraftDirty;

  /// Local baseline signature after last Read-only publish ([StoryCreatorDraftState.readOnlyPublishedCoreSig]).
  final String? readOnlyPublishedCoreSig;

  /// v2 read-only published baseline (prefs + notifier).
  final String? publishedEditReadOnlyBaselineSig;

  /// Last full-learn published baseline.
  final String? publishedEditFullLearnBaselineSig;

  /// From [CreatorDrawerSessionState.learnModeEnabled] — single source of truth.
  final bool learnModeEnabled;
  final CreatorStepId? currentStepId;
  final ValueChanged<bool> onLearnModeChanged;
  final void Function(String route) onOpenStep;
  final VoidCallback onSaveDraft;
  final Future<void> Function(StoryReviewPublishMode mode) onPublish;

  @override
  ConsumerState<CreatorProgressDrawer> createState() =>
      _CreatorProgressDrawerState();
}

class _CreatorProgressDrawerState extends ConsumerState<CreatorProgressDrawer> {
  bool _publishing = false;

  @override
  void didUpdateWidget(covariant CreatorProgressDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publishModel.isFullLearnReady !=
            widget.publishModel.isFullLearnReady ||
        oldWidget.publishModel.isReadingOnlyReady !=
            widget.publishModel.isReadingOnlyReady ||
        oldWidget.readOnlyPublishedExists != widget.readOnlyPublishedExists ||
        oldWidget.readOnlyHasUnpublishedChanges !=
            widget.readOnlyHasUnpublishedChanges ||
        oldWidget.fullLearnPublishedExists != widget.fullLearnPublishedExists ||
        oldWidget.fullLearnHasUnpublishedChanges !=
            widget.fullLearnHasUnpublishedChanges ||
        oldWidget.localDraftDirty != widget.localDraftDirty ||
        oldWidget.creatorDraft.hasUnpublishedCoreChanges !=
            widget.creatorDraft.hasUnpublishedCoreChanges ||
        oldWidget.creatorDraft.publishState !=
            widget.creatorDraft.publishState ||
        oldWidget.publishedEditReadOnlyBaselineSig !=
            widget.publishedEditReadOnlyBaselineSig ||
        oldWidget.publishedEditFullLearnBaselineSig !=
            widget.publishedEditFullLearnBaselineSig) {
      setState(() {});
    }
  }

  StoryReviewPublishMode get _publishMode => widget.learnModeEnabled
      ? StoryReviewPublishMode.fullLearn
      : StoryReviewPublishMode.readingOnly;

  bool get _readOnlyUpToDate =>
      widget.readOnlyPublishedExists && !widget.readOnlyHasUnpublishedChanges;

  bool get _fullLearnUpToDate =>
      widget.fullLearnPublishedExists && !widget.fullLearnHasUnpublishedChanges;

  bool get _publishEnabled {
    if (_publishMode == StoryReviewPublishMode.readingOnly &&
        _readOnlyUpToDate) {
      return false;
    }
    if (_publishMode == StoryReviewPublishMode.fullLearn &&
        _fullLearnUpToDate) {
      return false;
    }
    return isStoryReviewModeAllowed(_publishMode, widget.publishModel);
  }

  String _publishDisabledReason(bool publishEnabled) {
    if (_publishing) return 'publishing';
    if (publishEnabled) return 'ok';
    if (_publishMode == StoryReviewPublishMode.readingOnly &&
        _readOnlyUpToDate) {
      return 'read_only_up_to_date';
    }
    if (_publishMode == StoryReviewPublishMode.fullLearn &&
        _fullLearnUpToDate) {
      return 'full_learn_up_to_date';
    }
    if (!isStoryReviewModeAllowed(_publishMode, widget.publishModel)) {
      return 'requirements_not_met';
    }
    return 'unknown';
  }

  String? _publishHelperText() {
    return creatorProgressDrawerPublishHelperText(
      learnModeEnabled: widget.learnModeEnabled,
      publishEnabled: _publishEnabled,
      readOnlyPublishedExists: widget.readOnlyPublishedExists,
      readOnlyHasUnpublishedChanges: widget.readOnlyHasUnpublishedChanges,
      fullLearnPublishedExists: widget.fullLearnPublishedExists,
      fullLearnHasUnpublishedChanges: widget.fullLearnHasUnpublishedChanges,
      hasLocalUnsavedEdits: widget.localDraftDirty,
      publishModel: widget.publishModel,
    );
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
    final publishPhase = ref.watch(creatorPublishStatusTextProvider);
    final publishEnabled = _publishEnabled;
    final helper = _publishHelperText();
    final publishLabel = creatorProgressDrawerPublishPrimaryLabel(
      learnModeEnabled: widget.learnModeEnabled,
      readOnlyPublishedExists: widget.readOnlyPublishedExists,
      readOnlyHasUnpublishedChanges: widget.readOnlyHasUnpublishedChanges,
      fullLearnPublishedExists: widget.fullLearnPublishedExists,
      fullLearnHasUnpublishedChanges: widget.fullLearnHasUnpublishedChanges,
    );
    debugTraceCreatorDrawerPublish(
      surface: widget.drawerKeySlot.value,
      draft: widget.creatorDraft,
      localDirty: widget.localDraftDirty,
      readOnlyPublishedCoreSig: widget.readOnlyPublishedCoreSig,
      publishedEditReadOnlyBaselineSig: widget.publishedEditReadOnlyBaselineSig,
      publishedEditFullLearnBaselineSig:
          widget.publishedEditFullLearnBaselineSig,
      learnModeEnabled: widget.learnModeEnabled,
      readOnlyPublishedExists: widget.readOnlyPublishedExists,
      readOnlyHasUnpublishedChanges: widget.readOnlyHasUnpublishedChanges,
      fullLearnPublishedExists: widget.fullLearnPublishedExists,
      fullLearnHasUnpublishedChanges: widget.fullLearnHasUnpublishedChanges,
      publishEnabled: publishEnabled,
      publishDisabledReason: _publishDisabledReason(publishEnabled),
      publishLabel: publishLabel,
      helperText: helper,
    );

    return KeyedSubtree(
      key: widget.drawerKeySlot,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Drawer(
            key: const ValueKey<String>('creator_progress_drawer'),
            width: constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 304,
            backgroundColor: cs.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
            ),
            // Full-bounds [ColoredBox] under the scroll content: the Drawer itself
            // does not always make every sub-area participate in hit testing. An explicit
            // same-color layer ensures pointer events in the open drawer never fall through
            // to the translated story page behind (Group A: Open on learn rows).
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ColoredBox(color: cs.surface),
                ),
                SafeArea(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onSaveDraft,
                                  child: Text(
                                    (widget.readOnlyPublishedExists ||
                                                widget
                                                    .fullLearnPublishedExists) &&
                                            (widget.readOnlyHasUnpublishedChanges ||
                                                widget
                                                    .fullLearnHasUnpublishedChanges)
                                        ? 'Save changes (workspace)'
                                        : 'Save draft',
                                  ),
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
                                      : const Icon(Icons.publish_rounded,
                                          size: 20),
                                  label: Text(publishLabel),
                                ),
                              ),
                            ],
                          ),
                          if (_publishing &&
                              (publishPhase ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              publishPhase!.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onVar,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _CreatorProgressSection(
                        title: 'Core progress',
                        items: widget.coreItems,
                        currentStepId: widget.currentStepId,
                        onOpenStep: widget.onOpenStep,
                      ),
                      const SizedBox(height: 16),
                      _LearnModulesBlock(
                        learnItems: widget.learnItems,
                        learnModeEnabled: widget.learnModeEnabled,
                        onLearnModeChanged: widget.onLearnModeChanged,
                        currentStepId: widget.currentStepId,
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
              ],
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
    required this.currentStepId,
    required this.onOpenStep,
    required this.theme,
    required this.colorScheme,
  });

  final List<CreatorProgressItem> learnItems;
  final bool learnModeEnabled;
  final ValueChanged<bool> onLearnModeChanged;
  final CreatorStepId? currentStepId;
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
                        _CreatorProgressRow(
                          item: i,
                          isCurrent: i.id == currentStepId,
                          onOpenStep: onOpenStep,
                        ),
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
    required this.currentStepId,
    required this.onOpenStep,
  });

  final String title;
  final List<CreatorProgressItem> items;
  final CreatorStepId? currentStepId;
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
        ...items.map(
          (i) => _CreatorProgressRow(
            item: i,
            isCurrent: i.id == currentStepId,
            onOpenStep: onOpenStep,
          ),
        ),
      ],
    );
  }
}

class _CreatorProgressRow extends StatelessWidget {
  const _CreatorProgressRow({
    required this.item,
    required this.isCurrent,
    required this.onOpenStep,
  });

  final CreatorProgressItem item;
  final bool isCurrent;
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
            final titleText = Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            );
            final chip = Container(
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: chipTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
            final titleChipRow = narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText,
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerLeft, child: chip),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleText),
                      const SizedBox(width: 8),
                      Flexible(child: chip),
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
              onPressed: isCurrent ? null : () => onOpenStep(item.route),
              child: Text(
                isCurrent ? 'You are here' : actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isCurrent) ...[
                    Text(
                      'Current',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
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
                      if (isCurrent) ...[
                        Text(
                          'Current',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
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
