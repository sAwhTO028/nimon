import 'package:flutter/material.dart';
import 'package:nimon/features/create/creator_progress_logic.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// V1 creator-facing progress: Story Core, Learn modules, publish readiness.
class StoryCreatorProgressChecklist extends StatelessWidget {
  const StoryCreatorProgressChecklist({
    super.key,
    required this.story,
    this.showPublishSummary = true,
    this.compact = false,
  });

  final CreatorStoryV1 story;
  final bool showPublishSummary;
  final bool compact;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);
  static const _cardBg = Color(0xFFF7F5F0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact ? 14.0 : 18.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Creator progress',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              'Track story core, Learn modules, and what each publish mode needs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _muted,
                height: 1.4,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            _SectionLabel(text: 'Story Core', theme: theme),
            SizedBox(height: compact ? 8 : 10),
            _ChecklistRow(
              label: 'Story basics',
              status: story.basicsProgressStatus,
              hint: compact ? null : story.basicsProgressHint(),
            ),
            _ChecklistRow(
              label: 'Story sentences',
              status: story.sentencesProgressStatus,
              hint: compact ? null : story.sentencesProgressHint(),
            ),
            SizedBox(height: compact ? 14 : 18),
            _SectionLabel(text: 'Learn modules', theme: theme),
            SizedBox(height: compact ? 8 : 10),
            for (final id in LearnModuleId.values)
              _ChecklistRow(
                label: id.displayTitle,
                status: story.learnModuleProgressStatus(id),
                hint: compact ? null : story.learnModuleProgressHint(id),
              ),
            if (showPublishSummary) ...[
              SizedBox(height: compact ? 14 : 18),
              _SectionLabel(text: 'Publish readiness', theme: theme),
              SizedBox(height: compact ? 8 : 10),
              _PublishReadinessRow(
                label: 'Reading Only',
                ready: story.canPublishReadingOnly,
                helper: story.canPublishReadingOnly
                    ? 'Story basics and at least one valid sentence are done.'
                    : 'Complete story basics and at least one valid sentence for Reading Only.',
              ),
              SizedBox(height: compact ? 8 : 10),
              _PublishReadinessRow(
                label: 'Full Learn',
                ready: story.canPublishFullLearn,
                helper: story.canPublishFullLearn
                    ? 'Story core and all Learn modules meet V1 rules.'
                    : 'Complete all Learn modules (data) for Full Learn, on top of story core.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  static const _ink = Color(0xFF1A1917);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: _ink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.status,
    this.hint,
    this.trailingNote,
  });

  final String label;
  final LearnModuleTaskStatus status;
  final String? hint;
  final String? trailingNote;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);
  static const _ok = Color(0xFF2E6B3C);
  static const _warn = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg) = switch (status) {
      LearnModuleTaskStatus.completed => (
          const Color(0xFFE8F0E8),
          _ok,
        ),
      LearnModuleTaskStatus.inProgress => (
          const Color(0xFFFFF7ED),
          _warn,
        ),
      LearnModuleTaskStatus.notStarted => (
          const Color(0xFFF0F0F0),
          _muted,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (status) {
                  LearnModuleTaskStatus.completed => Icons.check_circle_rounded,
                  LearnModuleTaskStatus.inProgress => Icons.timelapse_rounded,
                  LearnModuleTaskStatus.notStarted =>
                    Icons.radio_button_unchecked_rounded,
                },
                size: 22,
                color: fg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: fg.withValues(alpha: 0.25)),
                ),
                child: Text(
                  learnModuleTaskStatusLabel(status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _muted,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (trailingNote != null && trailingNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                trailingNote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _warn,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublishReadinessRow extends StatelessWidget {
  const _PublishReadinessRow({
    required this.label,
    required this.ready,
    required this.helper,
  });

  final String label;
  final bool ready;
  final String helper;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);
  static const _ok = Color(0xFF2E6B3C);
  static const _bad = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ready ? Icons.verified_outlined : Icons.info_outline_rounded,
          size: 22,
          color: ready ? _ok : _bad,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    ready ? 'Ready' : 'Not ready',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: ready ? _ok : _muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
