import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/grammar_pattern.dart';
import 'package:nimon/features/learn/learn_catalog_content_gate.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_creator_module_tokens.dart';
import 'package:nimon/features/learn/learn_module_surface_tokens.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 grammar pattern detail: one [GrammarPattern] at a time (from route [extra]).
class GrammarPatternDetailScreen extends ConsumerWidget {
  const GrammarPatternDetailScreen({
    super.key,
    required this.contentId,
    this.pattern,
  });

  final String contentId;
  final GrammarPattern? pattern;

  static const _cardRadius = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pageBg = learnModuleListPageBackground(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final p = pattern;
    final lang = ref.watch(learnExplanationLanguageProvider);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
      ),
      body: p == null
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                catalogMonoIdLooksLikeUuid(contentId)
                    ? 'No grammar pattern was opened for this story. '
                        'Go back and choose a pattern from the list.'
                    : 'No pattern data.',
                style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurface),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderSection(
                    title: p.title,
                    theme: theme,
                  ),
                  const SizedBox(height: 14),
                  _LabeledSection(
                    label: 'Meaning',
                    child: Text(
                      pickSupportText(
                            lang,
                            en: p.meaningEn,
                            my: p.meaning,
                          ) ??
                          '—',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledSection(
                    label: 'Form',
                    child: Text(
                      p.form,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledSection(
                    label: 'When to use',
                    child: Text(
                      pickSupportText(
                            lang,
                            en: p.whenToUseEn,
                            my: p.whenToUse,
                          ) ??
                          '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionHeading(text: 'Examples', theme: theme),
                  const SizedBox(height: 8),
                  for (var i = 0; i < p.examples.length; i++) ...[
                    _ExampleCard(
                      index: i + 1,
                      example: p.examples[i],
                      theme: theme,
                      explanationLanguage: lang,
                    ),
                    if (i < p.examples.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 16),
                  _SectionHeading(text: 'Common mistakes', theme: theme),
                  const SizedBox(height: 8),
                  _MistakesBlock(
                    mistakes: p.commonMistakes,
                    theme: theme,
                  ),
                  if (_relatedNoteForLearner(p, lang) != null) ...[
                    const SizedBox(height: 16),
                    _LabeledSection(
                      label: 'Related note',
                      child: Text(
                        _relatedNoteForLearner(p, lang)!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  static String? _relatedNoteForLearner(
    GrammarPattern p,
    LearnExplanationLanguage lang,
  ) {
    return pickSupportText(
      lang,
      en: p.relatedNoteEn,
      my: p.relatedNote,
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.title,
    required this.theme,
  });

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grammar Pattern',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.text,
    required this.theme,
  });

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LabeledSection extends StatelessWidget {
  const _LabeledSection({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.index,
    required this.example,
    required this.theme,
    required this.explanationLanguage,
  });

  final int index;
  final GrammarPatternExample example;
  final ThemeData theme;
  final LearnExplanationLanguage explanationLanguage;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final gloss = pickSupportText(
      explanationLanguage,
      en: example.englishGloss,
      my: example.myanmar,
    );

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            example.japanese,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (gloss != null) ...[
            const SizedBox(height: 8),
            Text(
              gloss,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MistakesBlock extends StatelessWidget {
  const _MistakesBlock({
    required this.mistakes,
    required this.theme,
  });

  final List<GrammarPatternMistake> mistakes;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (mistakes.isEmpty) {
      return _SurfaceCard(
        child: Text(
          '—',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < mistakes.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _MistakeRow(mistake: mistakes[i], theme: theme),
          ],
        ],
      ),
    );
  }
}

class _MistakeRow extends StatelessWidget {
  const _MistakeRow({
    required this.mistake,
    required this.theme,
  });

  final GrammarPatternMistake mistake;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wrongFill = isDark
        ? cs.errorContainer.withValues(alpha: 0.45)
        : const Color(0xFFFFF0F0);
    final wrongBorder =
        isDark ? cs.error.withValues(alpha: 0.45) : const Color(0x33CC0000);
    final okFill = isDark
        ? cs.tertiaryContainer.withValues(alpha: 0.45)
        : const Color(0xFFF0FAF4);
    final okBorder =
        isDark ? cs.tertiary.withValues(alpha: 0.45) : const Color(0x3316A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MistakeLine(
          prefix: '✗',
          text: mistake.incorrect,
          fill: wrongFill,
          border: wrongBorder,
          theme: theme,
          strong: true,
        ),
        const SizedBox(height: 8),
        _MistakeLine(
          prefix: '✓',
          text: mistake.correct,
          fill: okFill,
          border: okBorder,
          theme: theme,
          strong: false,
        ),
      ],
    );
  }
}

class _MistakeLine extends StatelessWidget {
  const _MistakeLine({
    required this.prefix,
    required this.text,
    required this.fill,
    required this.border,
    required this.theme,
    required this.strong,
  });

  final String prefix;
  final String text;
  final Color fill;
  final Color border;
  final ThemeData theme;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefix,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: learnCreatorModuleCardSurfaceColor(context),
        borderRadius:
            BorderRadius.circular(GrammarPatternDetailScreen._cardRadius),
        border: Border.all(color: learnCreatorModuleCardBorderColor(context)),
      ),
      child: child,
    );
  }
}
