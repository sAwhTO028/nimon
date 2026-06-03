import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_resume_draft.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_processing_copy.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/presentation/providers/story_creator_add_tab_draft_summary_provider.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';
import 'package:nimon/features/profile/profile_navigation_helpers.dart';
import 'package:nimon/features/create/import/nimon_hidden_json_import_flow.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Add tab V1: lightweight creator hub for continuing local drafts or starting new.
class StoryCreatorAddTabScreen extends ConsumerWidget {
  const StoryCreatorAddTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    ref.listen<int>(profileProcessingListRefreshProvider, (previous, next) {
      unawaited(
        ref.read(storyCreatorAddTabDraftSummaryProvider.notifier).refresh(),
      );
    });

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: NimonBackButton(
          onPressed: () => unawaited(handleCreatorBackPressed(context, ref)),
          icon: Icons.close_rounded,
          tooltip: 'Close',
        ),
        title: NimonHiddenJsonImportLongPress(
          child: Text(
            'Create',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _StoryCreatorAddTabBody(theme: theme, cs: cs),
    );
  }

  static Future<void> _createNewStory(
      BuildContext context, WidgetRef ref) async {
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.createStory,
    )) {
      return;
    }
    // Start a brand-new ephemeral session. Persist only after first meaningful edit.
    ref.read(storyCreatorDraftProvider.notifier).reset();
    if (!context.mounted) return;
    context.push('/create/story/basics');
  }
}

/// Isolated so [build] can register [ref.listen] once cleanly with stable descendants.
class _StoryCreatorAddTabBody extends ConsumerWidget {
  const _StoryCreatorAddTabBody({
    required this.theme,
    required this.cs,
  });

  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(storyCreatorAddTabDraftSummaryProvider);
    final drafts = [
      for (final s in summary.items) _DraftListItemModel.fromSummary(s),
    ];

    final loading =
        summary.isInitialLoading && drafts.isEmpty && summary.error == null;
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summary.error != null && drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load drafts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(
                  ref
                      .read(storyCreatorAddTabDraftSummaryProvider.notifier)
                      .refresh(),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final featured = drafts.isEmpty ? null : drafts.first;
    final rest =
        drafts.length <= 1 ? const <_DraftListItemModel>[] : drafts.sublist(1);

    final listPadding = EdgeInsets.fromLTRB(
      20,
      16,
      20,
      24 + MediaQuery.of(context).padding.bottom,
    );

    return ListView(
      padding: listPadding,
      children: [
        if (featured == null) ...[
          _EmptyStateCard(
            onCreateNew: () => unawaited(
              StoryCreatorAddTabScreen._createNewStory(context, ref),
            ),
          ),
        ] else ...[
          _SectionHeader(
            title: 'Continue working',
          ),
          const SizedBox(height: 12),
          _FeaturedDraftCard(
            item: featured,
            onContinue: () => unawaited(
              CreatorDraftResumeFlow.resume(
                context,
                featured.id,
                entryChannel: CreatorEntryChannel.add,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (rest.isNotEmpty) ...[
            _SectionHeader(
              title: 'Drafts in progress',
            ),
            const SizedBox(height: 10),
            ...rest.take(3).map(
                  (it) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DraftRowCard(
                      item: it,
                      onTap: () => unawaited(
                        CreatorDraftResumeFlow.resume(
                          context,
                          it.id,
                          entryChannel: CreatorEntryChannel.add,
                        ),
                      ),
                    ),
                  ),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => ProfileNavigation.openProcessingTab(context),
                child: const Text('View all drafts in Processing'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _SectionHeader(title: 'Start new story'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => unawaited(
              StoryCreatorAddTabScreen._createNewStory(context, ref),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Create new story'),
          ),
          const SizedBox(height: 6),
          Text(
            'Create story basics first, then continue with storytelling and optional learn modules.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _DraftListItemModel {
  final String id;
  final String title;
  final String preview;
  final String jlptLevel;
  final String category;
  final String duration;
  final String stepLabel;
  final DateTime updatedAt;
  final String readinessSummary;

  const _DraftListItemModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.jlptLevel,
    required this.category,
    required this.duration,
    required this.stepLabel,
    required this.updatedAt,
    required this.readinessSummary,
  });

  /// List rows from [DraftListSummaryDto] only — no full-story load (see provider).
  ///
  factory _DraftListItemModel.fromSummary(DraftListSummaryDto s) {
    final title = s.title.trim().isEmpty ? 'Untitled draft' : s.title.trim();
    final preview = (s.previewText != null && s.previewText!.trim().isNotEmpty)
        ? s.previewText!.trim()
        : 'Continue editing your draft';
    final level = s.level.trim().isEmpty ? '—' : s.level.trim();
    final category = s.category.trim().isEmpty ? '—' : s.category.trim();
    var updatedAt = DateTime.tryParse(s.updatedAt ?? '');
    updatedAt ??= DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final readiness = CreatorProcessingCopy.draftSummaryReadinessLine(
      completionPercent: s.completionPercent,
      sentenceCount: s.sentenceCount,
    );
    final step = CreatorProcessingCopy.draftSummaryLastEditingLabel(
      s.lastEditingStep,
    );

    return _DraftListItemModel(
      id: s.draftId.trim(),
      title: title,
      preview: preview,
      jlptLevel: level,
      category: category,
      duration: CreatorProcessingCopy.draftSummaryDurationChip(
        s.targetDurationBandKey,
      ),
      stepLabel: step,
      updatedAt: updatedAt,
      readinessSummary: readiness,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final VoidCallback onCreateNew;

  const _EmptyStateCard({required this.onCreateNew});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return NimonHiddenJsonImportLongPress(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.auto_stories_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Start your next story',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create story basics first, then continue with storytelling and optional learn modules.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onCreateNew,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Create new story'),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _FeaturedDraftCard extends StatelessWidget {
  final _DraftListItemModel item;
  final VoidCallback onContinue;

  const _FeaturedDraftCard({required this.item, required this.onContinue});

  String _timeLabel() {
    final dt = item.updatedAt.toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onContinue,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.25,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniChip(label: item.jlptLevel),
                            _MiniChip(label: item.category),
                            _MiniChip(label: item.duration),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.stepLabel.trim().isNotEmpty
                            ? item.stepLabel
                            : 'Continue editing',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Updated ${_timeLabel()}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            item.readinessSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftRowCard extends StatelessWidget {
  final _DraftListItemModel item;
  final VoidCallback onTap;

  const _DraftRowCard({required this.item, required this.onTap});

  String _timeLabel() {
    final dt = item.updatedAt.toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final subtitle =
        item.stepLabel.isNotEmpty ? item.stepLabel : item.readinessSummary;

    return Card(
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _timeLabel(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
