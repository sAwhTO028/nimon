import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/quiz_flow_theme.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1: choose category + question count, then start quiz (play screen next).
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({
    super.key,
    required this.contentId,
  });

  final String contentId;

  static const _bg = QuizFlowTheme.pageBg;
  static const _ink = QuizFlowTheme.ink;
  static const _inkMuted = QuizFlowTheme.inkMuted;

  static const List<int> questionCountOptions = [5, 10];

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  LearnQuizCategory? _category;
  int? _questionCount;

  static const _cardRadius = 14.0;

  bool get _canStart =>
      _category != null && _questionCount != null;

  void _selectCategory(LearnQuizCategory c) {
    setState(() => _category = c);
  }

  void _selectCount(int n) {
    setState(() => _questionCount = n);
  }

  void _startQuiz() {
    if (!_canStart) return;
    context.push(
      '/learn/${widget.contentId}/quiz/play',
      extra: QuizSessionStartArgs(
        contentId: widget.contentId,
        category: _category!,
        questionCount: _questionCount!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: QuizSetupScreen._bg,
      appBar: AppBar(
        backgroundColor: QuizSetupScreen._bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
        title: Text(
          'Quiz Practice',
          style: theme.textTheme.titleLarge?.copyWith(
            color: QuizSetupScreen._ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset + 24),
        children: [
          Text(
            'Choose one quiz type',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: QuizSetupScreen._inkMuted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: theme.textTheme.titleSmall?.copyWith(
              color: QuizSetupScreen._ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...LearnQuizCategory.values.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryOption(
                label: c.displayLabel,
                selected: _category == c,
                radius: _cardRadius,
                onTap: () => _selectCategory(c),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Number of questions',
            style: theme.textTheme.titleSmall?.copyWith(
              color: QuizSetupScreen._ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0;
                  i < QuizSetupScreen.questionCountOptions.length;
                  i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _CountOption(
                    count: QuizSetupScreen.questionCountOptions[i],
                    selected:
                        _questionCount == QuizSetupScreen.questionCountOptions[i],
                    radius: _cardRadius,
                    onTap: () =>
                        _selectCount(QuizSetupScreen.questionCountOptions[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _canStart ? _startQuiz : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: QuizFlowTheme.primary,
              foregroundColor: QuizFlowTheme.onPrimary,
              disabledBackgroundColor:
                  QuizFlowTheme.primary.withValues(alpha: 0.38),
              disabledForegroundColor:
                  QuizFlowTheme.onPrimary.withValues(alpha: 0.65),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
            ),
            child: Text(
              'Start Quiz',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: QuizFlowTheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.selected,
    required this.radius,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double radius;
  final VoidCallback onTap;

  static const _ink = QuizFlowTheme.ink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: selected ? 0.95 : 0.86),
      elevation: 0,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? QuizFlowTheme.primary.withValues(alpha: 0.55)
                  : const Color(0x14000000),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 22,
                color: selected
                    ? QuizFlowTheme.primary
                    : _ink.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountOption extends StatelessWidget {
  const _CountOption({
    required this.count,
    required this.selected,
    required this.radius,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final double radius;
  final VoidCallback onTap;

  static const _ink = QuizFlowTheme.ink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: selected ? 0.95 : 0.86),
      elevation: 0,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? QuizFlowTheme.primary.withValues(alpha: 0.55)
                  : const Color(0x14000000),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              '$count questions',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
