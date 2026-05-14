import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/learn_module_surface_tokens.dart';
import 'package:nimon/features/learn/learn_quiz_navigation.dart';
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

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pageBg = learnModuleListPageBackground(context);
    final s = summary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final successTone = theme.brightness == Brightness.dark
        ? cs.tertiary
        : const Color(0xFF16A34A);
    final errorTone = theme.brightness == Brightness.dark
        ? cs.error
        : const Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
        title: Text(
          'Quiz results',
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onSurface,
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
              children: [
                Text(
                  '${s.scorePercent}%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                _StatRow(
                  label: 'Correct',
                  value: '${s.correct}',
                  valueColor: successTone,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Wrong',
                  value: '${s.wrong}',
                  valueColor: errorTone,
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
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.category.displayLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/learn/$contentId/quiz'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => unawaited(
                    navigateQuizResultBackToLearnHub(
                      GoRouter.of(context),
                      contentId,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: cs.onSurface,
                    backgroundColor: cs.surfaceContainerHighest.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.65,
                    ),
                    side: BorderSide(
                      color: cs.outlineVariant,
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
                      color: cs.onSurface,
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

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor ?? cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
