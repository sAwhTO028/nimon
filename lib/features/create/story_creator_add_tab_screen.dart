import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_resume_draft.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/creator_labels.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorDraftResumeMeta, CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/profile/profile_navigation_helpers.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Add tab V1: lightweight creator hub for continuing local drafts or starting new.
class StoryCreatorAddTabScreen extends ConsumerWidget {
  const StoryCreatorAddTabScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: NimonBackButton(
          onPressed: () => context.pop(),
          icon: Icons.close_rounded,
          tooltip: 'Close',
        ),
        title: Text(
          'Create',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<_LocalDraftsSnapshot>(
        future: _LocalDraftsSnapshot.load(ref.read(storyDraftRepositoryProvider)),
        builder: (context, snap) {
          final data = snap.data;
          final loading = snap.connectionState != ConnectionState.done && data == null;

          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final drafts = data?.drafts ?? const <_DraftListItemModel>[];
          final featured = drafts.isEmpty ? null : drafts.first;
          final rest = drafts.length <= 1 ? const <_DraftListItemModel>[] : drafts.sublist(1);

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
                  onCreateNew: () => unawaited(_createNewStory(context, ref)),
                ),
              ] else ...[
                _SectionHeader(
                  title: 'Continue working',
                ),
                const SizedBox(height: 12),
                _FeaturedDraftCard(
                  item: featured,
                  onContinue: () => unawaited(
                    CreatorDraftResumeFlow.resume(context, featured.id),
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
                              CreatorDraftResumeFlow.resume(context, it.id),
                            ),
                          ),
                        ),
                      ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          ProfileNavigation.openProcessingTab(context),
                      child: const Text('View all drafts in Processing'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                _SectionHeader(title: 'Start new story'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => unawaited(_createNewStory(context, ref)),
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
        },
      ),
    );
  }

  static Future<void> _createNewStory(BuildContext context, WidgetRef ref) async {
    // Start a brand-new ephemeral session. Persist only after first meaningful edit.
    ref.read(storyCreatorDraftProvider.notifier).reset();
    if (!context.mounted) return;
    context.push('/create/story/basics');
  }
}

class _LocalDraftsSnapshot {
  final List<_DraftListItemModel> drafts;

  const _LocalDraftsSnapshot({required this.drafts});

  static Future<_LocalDraftsSnapshot> load(StoryDraftRepository repository) async {
    final ids = await repository.listDraftIds();
    final out = <_DraftListItemModel>[];
    for (final id in ids) {
      final draft = await repository.loadDraft(id);
      if (draft == null) continue;
      if (draft.publishState != StoryPublishState.draft) continue;
      final meta = await repository.loadResumeMeta(id);
      out.add(
        _DraftListItemModel.fromDraft(
          draft: draft,
          meta: meta,
        ),
      );
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _LocalDraftsSnapshot(drafts: out);
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

  static _DraftListItemModel fromDraft({
    required CreatorStoryV1 draft,
    required CreatorDraftResumeMeta? meta,
  }) {
    final basics = draft.basics;
    final title = basics.title.trim().isEmpty ? 'Untitled draft' : basics.title.trim();
    final desc = basics.description.trim();
    final preview = desc.isNotEmpty ? desc : _fallbackPreview(draft);

    final level = basics.level.trim().isEmpty ? '—' : basics.level.trim();
    final category = basics.category.trim().isEmpty ? '—' : basics.category.trim();
    final duration = _durationLabel(basics.targetDurationBandKey);

    final readiness = computeProcessingState(draft).displayLabel;

    final step = _stepLabelFromMeta(meta);

    return _DraftListItemModel(
      id: draft.id,
      title: title,
      preview: preview,
      jlptLevel: level,
      category: category,
      duration: duration,
      stepLabel: step,
      updatedAt: basics.updatedAt,
      readinessSummary: readiness,
    );
  }

  static String _stepLabelFromMeta(CreatorDraftResumeMeta? meta) {
    final m = meta?.lastActiveModule ?? CreatorLastActiveModule.storytelling;
    return CreatorLabels.progressLabelForLastActive(m);
  }

  static String _fallbackPreview(CreatorStoryV1 d) {
    final firstSentence = d.sentences
        .where((s) => s.isValidV1)
        .map((s) => s.japaneseText.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (firstSentence.isNotEmpty) return firstSentence;
    return 'Continue editing your draft';
  }

  static String _durationLabel(String? key) {
    return switch ((key ?? '').trim()) {
      '3_5' => '3–5 mins',
      '5_7' => '5–7 mins',
      '7_9' => '7–9 mins',
      _ => '—',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: StoryCreatorAddTabScreen._muted.withValues(alpha: 0.9),
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

    return Padding(
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
                            color: StoryCreatorAddTabScreen._ink,
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
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.stepLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: StoryCreatorAddTabScreen._ink,
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

    final subtitle = item.stepLabel.isNotEmpty ? item.stepLabel : item.readinessSummary;

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
            color: cs.onSurface.withValues(alpha: 0.82),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

