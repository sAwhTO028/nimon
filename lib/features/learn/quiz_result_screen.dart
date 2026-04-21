import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/quiz_flow_theme.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 quiz results after the last question.
class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.contentId,
    this.summary,
  });

  final String contentId;
  final QuizResultSummary? summary;

  static const _bg = QuizFlowTheme.pageBg;
  static const _ink = QuizFlowTheme.ink;
  static const _inkMuted = QuizFlowTheme.inkMuted;
  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
        title: Text(
          'Quiz results',
          style: theme.textTheme.titleLarge?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: s == null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No result data.',
                style: theme.textTheme.bodyLarge?.copyWith(color: _inkMuted),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
              children: [
                Text(
                  '${s.scorePercent}%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                _StatRow(
                  label: 'Correct',
                  value: '${s.correct}',
                  valueColor: QuizFlowTheme.success,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Wrong',
                  value: '${s.wrong}',
                  valueColor: QuizFlowTheme.error,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Total',
                  value: '${s.total}',
                  theme: theme,
                ),
                const SizedBox(height: 20),
                Text(
                  'Category',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.category.displayLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () =>
                      context.go('/learn/$contentId/quiz'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: QuizFlowTheme.primary,
                    foregroundColor: QuizFlowTheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: QuizFlowTheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/learn/$contentId'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: _ink,
                    backgroundColor: QuizFlowTheme.secondaryFill,
                    side: const BorderSide(
                      color: QuizFlowTheme.secondaryBorder,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                  ),
                  child: Text(
                    'Back to Learn',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;

  static const _ink = QuizFlowTheme.ink;
  static const _inkMuted = QuizFlowTheme.inkMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: _inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor ?? _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
