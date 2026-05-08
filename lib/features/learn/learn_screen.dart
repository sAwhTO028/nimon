import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

class LearnScreen extends ConsumerWidget {
  final String contentId;
  const LearnScreen({super.key, required this.contentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = _mockLearnContent(contentId);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EA), // paper-like warm background
      appBar: AppBar(
        title: const Text('Learn'),
        backgroundColor: const Color(0xFFF6F3EA),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const NimonBackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (content.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      content.subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                        color: Colors.black.withOpacity(0.62),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  for (final block in content.blocks) ...[
                    _Block(block: block),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----- Mock content model (V1-only) -----

sealed class LearnBlock {
  const LearnBlock();
}

class LearnSectionTitle extends LearnBlock {
  final String text;
  const LearnSectionTitle(this.text);
}

class LearnParagraph extends LearnBlock {
  final String jp;
  final String? en;
  final String? my;
  const LearnParagraph({required this.jp, this.en, this.my});
}

class LearnDialogueLine extends LearnBlock {
  final String speaker;
  final String jp;
  final String? en;
  final String? my;
  const LearnDialogueLine({
    required this.speaker,
    required this.jp,
    this.en,
    this.my,
  });
}

class LearnNote extends LearnBlock {
  final String title;
  final String body;
  const LearnNote({required this.title, required this.body});
}

class _LearnContent {
  final String title;
  final String? subtitle;
  final List<LearnBlock> blocks;
  const _LearnContent(
      {required this.title, this.subtitle, required this.blocks});
}

_LearnContent _mockLearnContent(String id) {
  // Keep it simple: map a few ids to slightly different content.
  final variant = id.hashCode.abs() % 3;

  if (variant == 0) {
    return const _LearnContent(
      title: 'Mini Dialogue: “Do you have time?”',
      subtitle:
          'A clean reading view for dialogue + quick explanations. Swipe back to return to Mono.',
      blocks: [
        LearnSectionTitle('Dialogue'),
        LearnDialogueLine(
          speaker: 'A',
          jp: '今、時間ある？',
          en: 'Do you have time now?',
          my: 'အခု အချိန်ရမလား။',
        ),
        LearnDialogueLine(
          speaker: 'B',
          jp: 'ちょっとだけ。',
          en: 'Only a little.',
          my: 'နည်းနည်းပဲ။',
        ),
        LearnDialogueLine(
          speaker: 'A',
          jp: 'じゃあ、駅まで一緒に行こう。',
          en: 'Then let’s go to the station together.',
          my: 'ဒါဆို ဘူတာရုံအထိ အတူ သွားကြရအောင်။',
        ),
        LearnSectionTitle('Explanation'),
        LearnParagraph(
          jp: '「ちょっとだけ」= “just a little / only briefly”。',
          en: 'Common casual reply when you can spare a small amount of time.',
          my: 'အချိန်နည်းနည်းပဲ ရှိတဲ့အခါ ပြောလေ့ရှိတဲ့ စကား။',
        ),
        LearnNote(
          title: 'Tip',
          body: '「じゃあ」 is a natural “then / in that case” connector.',
        ),
      ],
    );
  }

  if (variant == 1) {
    return const _LearnContent(
      title: 'Reading: Short Paragraph',
      subtitle:
          'Textbook-style paragraph + notes. Designed for comfortable reading.',
      blocks: [
        LearnSectionTitle('Paragraph'),
        LearnParagraph(
          jp: '彼は「大丈夫」と言った。でも、その声は震えていた。\n私は何も聞かなかった。',
          en: 'He said “I’m fine.” But his voice was shaking.\nI didn’t ask anything.',
          my: 'သူက “မင်းပဲ” လို့ ပြောတယ်။ ဒါပေမယ့် အသံက တုန်နေတယ်။\nငါဘာမှ မေးမနေခဲ့ဘူး။',
        ),
        LearnSectionTitle('Notes'),
        LearnNote(
          title: 'Contrast with でも',
          body:
              '「でも」 highlights contrast between what is said and what is observed.',
        ),
        LearnNote(
          title: 'Tone',
          body:
              '短い文を重ねると、静かな緊張感を作れます。\nShort sentences can create quiet tension.',
        ),
      ],
    );
  }

  return const _LearnContent(
    title: 'Grammar Focus: もう / まだ',
    subtitle: 'Simple explanations + examples in a scrollable reading format.',
    blocks: [
      LearnSectionTitle('Meaning'),
      LearnParagraph(
        jp: 'もう = already / anymore\nまだ = still / not yet',
        en: 'Two high-frequency adverbs that appear everywhere.',
        my: 'နေ့စဉ်သုံးလေ့ရှိတဲ့ နာမဝိသေသန နှစ်ခု။',
      ),
      LearnSectionTitle('Examples'),
      LearnDialogueLine(
        speaker: 'A',
        jp: 'もう食べました。',
        en: 'I already ate.',
        my: 'ငါ စားပြီးပြီ။',
      ),
      LearnDialogueLine(
        speaker: 'B',
        jp: 'まだ食べていません。',
        en: 'I haven’t eaten yet.',
        my: 'ငါ မစားရသေးဘူး။',
      ),
      LearnNote(
        title: 'Tip',
        body: '「まだ〜ない」 is a very common pattern: “not yet …”.',
      ),
    ],
  );
}

// ----- UI blocks -----

class _Block extends ConsumerWidget {
  final LearnBlock block;
  const _Block({required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(learnExplanationLanguageProvider);

    return switch (block) {
      LearnSectionTitle(:final text) => Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      LearnParagraph(:final jp, :final en, :final my) =>
        _TextPair(jp: jp, en: en, my: my, lang: lang),
      LearnDialogueLine(:final speaker, :final jp, :final en, :final my) =>
        _DialogueLine(
          speaker: speaker,
          jp: jp,
          en: en,
          my: my,
          lang: lang,
        ),
      LearnNote(:final title, :final body) => _Note(title: title, body: body),
    };
  }
}

class _TextPair extends StatelessWidget {
  final String jp;
  final String? en;
  final String? my;
  final LearnExplanationLanguage lang;
  const _TextPair({
    required this.jp,
    required this.lang,
    this.en,
    this.my,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gloss = pickSupportText(lang, en: en, my: my);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          jp,
          style: theme.textTheme.titleLarge?.copyWith(
            height: 1.55,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        if (gloss != null) ...[
          const SizedBox(height: 8),
          Text(
            gloss,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: Colors.black.withOpacity(0.62),
            ),
          ),
        ],
      ],
    );
  }
}

class _DialogueLine extends StatelessWidget {
  final String speaker;
  final String jp;
  final String? en;
  final String? my;
  final LearnExplanationLanguage lang;
  const _DialogueLine({
    required this.speaker,
    required this.jp,
    required this.lang,
    this.en,
    this.my,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              speaker,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TextPair(jp: jp, en: en, my: my, lang: lang),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String title;
  final String body;
  const _Note({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: Colors.black.withOpacity(0.72),
            ),
          ),
        ],
      ),
    );
  }
}
