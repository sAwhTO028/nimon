import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/learn_catalog_content_gate.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/quiz_flow_theme.dart';
import 'package:nimon/features/learn/quiz_mcq.dart';
import 'package:nimon/features/learn/quiz_mock_bank.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 MCQ play: one question at a time, reveal, then Next → result.
class QuizPlayScreen extends ConsumerStatefulWidget {
  const QuizPlayScreen({
    super.key,
    required this.contentId,
    this.args,
  });

  final String contentId;
  final QuizSessionStartArgs? args;

  static const _bg = QuizFlowTheme.pageBg;
  static const _ink = QuizFlowTheme.ink;
  static const _inkMuted = QuizFlowTheme.inkMuted;

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  late final List<QuizMcqItem> _questions;
  int _index = 0;
  int? _selectedIndex;
  bool _revealed = false;
  int _correct = 0;
  int _wrong = 0;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    if (a == null) {
      _questions = [];
    } else if (a.publishedQuizPool != null && a.publishedQuizPool!.isNotEmpty) {
      _questions = pickPublishedQuizQuestionsForSession(
        category: a.category,
        questionCount: a.questionCount,
        pool: a.publishedQuizPool!,
      );
    } else if (learnDemoMocksAllowed(widget.contentId)) {
      _questions = QuizMockBank.pickQuestions(a.category, a.questionCount);
    } else {
      _questions = [];
    }
  }

  QuizMcqItem? get _current =>
      _index >= 0 && _index < _questions.length ? _questions[_index] : null;

  void _onOptionTap(int i) {
    if (_revealed) return;
    final q = _current;
    if (q == null) return;
    setState(() {
      _selectedIndex = i;
      _revealed = true;
      if (i == q.correctIndex) {
        _correct++;
      } else {
        _wrong++;
      }
    });
  }

  void _next() {
    final q = _current;
    if (q == null) return;
    if (_index >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selectedIndex = null;
      _revealed = false;
    });
  }

  void _finish() {
    final a = widget.args;
    if (a == null) return;
    context.pushReplacement(
      '/learn/${widget.contentId}/quiz/result',
      extra: QuizResultSummary(
        contentId: widget.contentId,
        category: a.category,
        correct: _correct,
        wrong: _wrong,
      ),
    );
  }

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.args;
    final q = _current;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final explanationLang = ref.watch(learnExplanationLanguageProvider);
    final explanationLine = q?.explanationForLearner(explanationLang)?.trim();

    if (a == null) {
      final missingMsg = catalogMonoIdLooksLikeUuid(widget.contentId)
          ? 'Missing quiz session. Use Start Quiz from the quiz setup screen '
              'for this story.'
          : 'Missing quiz session. Go back and tap Start Quiz again.';
      return Scaffold(
        backgroundColor: QuizPlayScreen._bg,
        appBar: AppBar(
          backgroundColor: QuizPlayScreen._bg,
          leading: NimonBackButton(onPressed: () => context.pop()),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            missingMsg,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: QuizPlayScreen._inkMuted,
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      final emptyMsg = catalogMonoIdLooksLikeUuid(widget.contentId) &&
              !learnDemoMocksAllowed(widget.contentId)
          ? 'No quiz questions available for this setup. '
              'Go back and choose another category or check that this story '
              'includes quiz items.'
          : 'No questions for this category.';
      return Scaffold(
        backgroundColor: QuizPlayScreen._bg,
        appBar: AppBar(
          backgroundColor: QuizPlayScreen._bg,
          leading: NimonBackButton(onPressed: () => context.pop()),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            emptyMsg,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: QuizPlayScreen._inkMuted,
            ),
          ),
        ),
      );
    }

    final total = _questions.length;
    final n = _index + 1;
    final progress = n / total;

    return Scaffold(
      backgroundColor: QuizPlayScreen._bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
              child: Row(
                children: [
                  NimonCircleNavButton(
                    onPressed: () => context.pop(),
                    tooltip: 'Back',
                  ),
                  Text(
                    'QUIZ',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: QuizPlayScreen._ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
                children: [
                  _QuizQuestionPanel(
                    categoryLabel: a.category.displayLabel,
                    progress: progress,
                    questionNumber: n,
                    total: total,
                    prompt: q!.prompt,
                    theme: theme,
                  ),
                  const SizedBox(height: 32),
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _OptionTile(
                      label: String.fromCharCode(65 + i),
                      text: q.options[i],
                      index: i,
                      revealed: _revealed,
                      selectedIndex: _selectedIndex,
                      correctIndex: q.correctIndex,
                      onTap: () => _onOptionTap(i),
                    ),
                  ],
                  if (_revealed) ...[
                    const SizedBox(height: 20),
                    if (explanationLine != null && explanationLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  QuizPlayScreen._ink.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            explanationLine,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: QuizPlayScreen._inkMuted,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    _FeedbackBanner(
                      isCorrect: _selectedIndex == q.correctIndex,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: QuizFlowTheme.primary,
                        foregroundColor: QuizFlowTheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radius),
                        ),
                      ),
                      child: Text(
                        _index >= total - 1 ? 'See results' : 'Next question',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: QuizFlowTheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One main card: category chip, progress, "Question" label, and prompt.
class _QuizQuestionPanel extends StatelessWidget {
  const _QuizQuestionPanel({
    required this.categoryLabel,
    required this.progress,
    required this.questionNumber,
    required this.total,
    required this.prompt,
    required this.theme,
  });

  final String categoryLabel;
  final double progress;
  final int questionNumber;
  final int total;
  final String prompt;
  final ThemeData theme;

  static const _ink = QuizFlowTheme.ink;
  static const _inkSoft = QuizFlowTheme.inkMuted;

  /// Matches option cards (`_OptionTile`) for one aligned column.
  static const _cardRadius = _QuizPlayScreenState._radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _ink.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2EC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _ink.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  categoryLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _inkSoft,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$questionNumber / $total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _ink.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: _ink.withValues(alpha: 0.08),
              color: QuizFlowTheme.progressFill,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Question',
            style: theme.textTheme.labelSmall?.copyWith(
              color: _inkSoft.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.isCorrect,
    required this.theme,
  });

  final bool isCorrect;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final accent = isCorrect ? QuizFlowTheme.success : QuizFlowTheme.error;
    final fill = isCorrect ? QuizFlowTheme.successBg : QuizFlowTheme.errorBg;
    final border =
        isCorrect ? QuizFlowTheme.successBorder : QuizFlowTheme.errorBorder;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCorrect ? 'Correct' : 'Incorrect',
              style: theme.textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.index,
    required this.revealed,
    required this.selectedIndex,
    required this.correctIndex,
    required this.onTap,
  });

  final String label;
  final String text;
  final int index;
  final bool revealed;
  final int? selectedIndex;
  final int correctIndex;
  final VoidCallback onTap;

  static const _ink = QuizFlowTheme.ink;
  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;
    final isCorrect = index == correctIndex;

    Color borderColor = _ink.withValues(alpha: 0.1);
    Color bg = Colors.white;
    double borderWidth = 1.5;
    List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
    Color badgeFill = const Color(0xFFF0EBE3);
    Color badgeBorder = _ink.withValues(alpha: 0.08);
    Color badgeText = _ink.withValues(alpha: 0.5);
    Widget? trailing;

    if (revealed) {
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
      if (isCorrect) {
        borderColor = QuizFlowTheme.successBorder;
        bg = QuizFlowTheme.successBg;
        borderWidth = 2;
        badgeFill = QuizFlowTheme.success.withValues(alpha: 0.14);
        badgeBorder = QuizFlowTheme.successBorder.withValues(alpha: 0.65);
        badgeText = QuizFlowTheme.success;
        trailing = Icon(
          Icons.check_rounded,
          color: QuizFlowTheme.success,
          size: 22,
        );
      } else if (isSelected) {
        borderColor = QuizFlowTheme.errorBorder;
        bg = QuizFlowTheme.errorBg;
        borderWidth = 2;
        badgeFill = QuizFlowTheme.error.withValues(alpha: 0.12);
        badgeBorder = QuizFlowTheme.errorBorder.withValues(alpha: 0.7);
        badgeText = QuizFlowTheme.error;
        trailing = Icon(
          Icons.close_rounded,
          color: QuizFlowTheme.error,
          size: 22,
        );
      } else {
        borderColor = _ink.withValues(alpha: 0.06);
        bg = const Color(0xFFFAFAF8);
        borderWidth = 1;
        badgeFill = _ink.withValues(alpha: 0.05);
        badgeText = _ink.withValues(alpha: 0.35);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: revealed ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeBorder, width: 1.5),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: badgeText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
