import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/features/learn/vocab_kanji_item.dart';

/// Opens the V1 vocabulary/kanji detail bottom sheet for [item].
///
/// [contentId] is kept for future wiring (e.g. analytics); sheet UI stays minimal.
void showVocabKanjiDetailSheet(
  BuildContext context, {
  required String contentId,
  required VocabKanjiItem item,
}) {
  assert(contentId.isNotEmpty, 'contentId required for vocab sheet flow');

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF6F3EA),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: SingleChildScrollView(
          child: _VocabKanjiDetailSheetBody(item: item),
        ),
      );
    },
  );
}

class _VocabKanjiDetailSheetBody extends ConsumerWidget {
  const _VocabKanjiDetailSheetBody({required this.item});

  final VocabKanjiItem item;

  static const _ink = Color(0xFF1A1917);
  static const _inkMuted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(learnExplanationLanguageProvider);
    final meaningLine = pickSupportText(
      lang,
      en: item.meaningEn,
      my: item.meaningMm,
    );
    final exJp = item.exampleSentence?.trim();
    final exGloss = pickSupportText(
      lang,
      en: item.exampleMeaningEn,
      my: item.exampleMeaningMm,
    );
    final hasExample = (exJp != null && exJp.isNotEmpty) ||
        (exGloss != null && exGloss.isNotEmpty);
    final src = item.storySource?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetSection(
          label: 'Word',
          child: Text(
            item.term,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SheetSection(
          label: 'Reading',
          child: Text(
            item.reading,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _inkMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SheetSection(
          label: 'Meaning',
          child: Text(
            meaningLine ?? '—',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
        if (hasExample) ...[
          const SizedBox(height: 20),
          _SheetSection(
            label: 'Example',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (exJp != null && exJp.isNotEmpty)
                  Text(
                    exJp,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                if (exJp != null &&
                    exJp.isNotEmpty &&
                    exGloss != null &&
                    exGloss.isNotEmpty)
                  const SizedBox(height: 10),
                if (exGloss != null && exGloss.isNotEmpty)
                  Text(
                    exGloss,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _inkMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (src != null && src.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SheetSection(
            label: 'Story source',
            child: Text(
              src,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _inkMuted,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  static const _inkMuted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: _inkMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
