import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/grammar_pattern.dart';
import 'package:nimon/features/learn/learn_catalog_content_gate.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_published_snapshot_mappers.dart';
import 'package:nimon/features/learn/learn_published_snapshot_providers.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Scrollable list of grammar patterns for a story ([contentId] = catalog mono id).
class GrammarPatternListScreen extends ConsumerWidget {
  const GrammarPatternListScreen({
    super.key,
    required this.contentId,
  });

  final String contentId;

  static const _bg = Color(0xFFF6F3EA);
  static const _ink = Color(0xFF1A1917);

  /// Dev-only demo patterns when [contentId] is not a catalog UUID.
  static const List<GrammarPattern> mockPatterns = [
    GrammarPattern(
      id: 'ni-tsuite',
      title: '〜について',
      meaning: '…အကြောင်း / …နဲ့ပတ်သက်ပြီး',
      meaningEn: 'about; regarding (a topic)',
      form: 'N + について',
      whenToUse: 'Topic တစ်ခုကို subject လုပ်ပြီး ပြောတဲ့အခါ သုံးတယ်',
      whenToUseEn: 'Used when you make something the topic and talk about it.',
      usageHint: '話題を広げるときに使う',
      examples: [
        GrammarPatternExample(
          japanese: '日本について話しましょう。',
          myanmar: 'ဂျပန်အကြောင်း ပြောကြရအောင်။',
        ),
        GrammarPatternExample(
          japanese: 'この問題について先生に聞きました。',
          myanmar: 'ဒီပြဿနာအကြောင်း ဆရာ့ကို မေးခဲ့တယ်။',
        ),
        GrammarPatternExample(
          japanese: '環境問題について勉強しています。',
          myanmar: 'ပတ်ဝန်းကျင်ပြဿနာအကြောင်း လေ့လာနေတယ်။',
        ),
      ],
      commonMistakes: [
        GrammarPatternMistake(
          incorrect: '食べるについて',
          correct: '食べることについて',
        ),
      ],
      relatedNote:
          'အများအားဖြင့် နောက်မှာ နာမည်သုံးပါ။ ကိစ္စကြောင်းကို ပြောမယ်ဆို 〜ことについて လို နာမည်ပုံစံသို့ ပြောင်းပါ။',
      relatedNoteEn:
          'Use this pattern mainly after nouns. If attached to a verb idea, convert it into a noun-like form such as ～ことについて.',
    ),
    GrammarPattern(
      id: 'tame-ni',
      title: '〜ために',
      meaning: '…ဖြစ်စေရန် / …အတွက်',
      meaningEn: 'for the purpose of; in order to',
      form: '辞書形／ない形 + ために',
      whenToUse: 'ရည်ရွယ်ချက်၊ အကြောင်းရင်းကို ပြောတဲ့အခါ သုံးတယ်။',
      whenToUseEn: 'Used to express purpose or reason.',
      usageHint: '目的を言う',
      examples: [
        GrammarPatternExample(
          japanese: '早く起きるためにアラームをセットした。',
          myanmar: 'စောစော ထလာဖို့ အချက်ပေးနာရီ သတ်မှတ်ထားတယ်။',
        ),
        GrammarPatternExample(
          japanese: '風邪をひかないためにマスクをする。',
          myanmar: 'အအေးမိမှု မဖြစ်အောင် မက်ခ်တပ်တယ်။',
        ),
      ],
      commonMistakes: [
        GrammarPatternMistake(
          incorrect: '見るために本',
          correct: '本を見るために',
        ),
      ],
      relatedNote: null,
    ),
    GrammarPattern(
      id: 'yo-ni',
      title: '〜ように',
      meaning: '…အောင် / …နိုင်အောင်',
      meaningEn: 'so that; in such a way that',
      form: '辞書形／可能形 + ように',
      whenToUse:
          'ပုံစံ၊ ချမှတ်ချက်၊ တောင်းဆိုချက်၊ အကျင့်စဉ်စတဲ့ အသုံးအများကို ဖော်ပြတယ်။',
      whenToUseEn:
          'Used for manner, goals, requests, habits, and similar “so that” senses.',
      usageHint: '努力・習慣・依頼など',
      examples: [
        GrammarPatternExample(
          japanese: '忘れないようにメモした。',
          myanmar: 'မမေ့အောင် မှတ်စုထားတယ်။',
        ),
        GrammarPatternExample(
          japanese: '子どもにも分かるように説明する。',
          myanmar: 'ကလေးတွေလည်း နားလည်အောင် ရှင်းပြတယ်။',
        ),
      ],
      commonMistakes: [
        GrammarPatternMistake(
          incorrect: '行くように時間がある',
          correct: '行けるように時間を作る',
        ),
      ],
      relatedNote: null,
    ),
    GrammarPattern(
      id: 'koto-ni-naru',
      title: '〜ことになる',
      meaning: '…ဖြစ်လာသည် / （決まり）…ことに',
      meaningEn: 'It is decided or arranged that…; come to (a result).',
      form: '普通形 + ことになる',
      whenToUse: 'အစီအစဉ်၊ စည်းမျဉ်း၊ သဘာဝကျရလဒ်တွေကို ပြောတဲ့အခါ သုံးတယ်။',
      whenToUseEn:
          'Used for plans, rules, and natural outcomes that “become the case”.',
      usageHint: '決定・自然の帰結',
      examples: [
        GrammarPatternExample(
          japanese: '来週から東京に行くことになった。',
          myanmar: 'လာမယ့်အပတ်ကစပြီး တိုကျိုသွားဖို့ ဖြစ်သွားတယ်။',
        ),
        GrammarPatternExample(
          japanese: '規則により、ここでは禁煙することになっている。',
          myanmar: 'စည်းမျဉ်းအရ ဒီမှာ မီးခိုးမသောက်ရဘူး ဖြစ်ထားတယ်။',
        ),
      ],
      commonMistakes: [
        GrammarPatternMistake(
          incorrect: 'することになっている（文脈なく乱用）',
          correct: '決定・ルール・習慣に合わせて使う',
        ),
      ],
      relatedNote: null,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (learnDemoMocksAllowed(contentId)) {
      return _buildScaffold(
        context,
        theme,
        body: _buildPatternList(context, mockPatterns),
      );
    }

    final detailAsync =
        ref.watch(catalogPublishedMonoDetailProvider(contentId));
    final snapAsync = ref.watch(learnPublishedSnapshotProvider(contentId));

    return detailAsync.when(
      loading: () => _buildScaffold(
        context,
        theme,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _buildScaffold(
        context,
        theme,
        body: _GrammarErrorBody(
          message: publishedMonoCatalogDetailErrorTitle(err),
          detail: publishedMonoCatalogDetailErrorBody(err),
          onRetry: () =>
              ref.invalidate(catalogPublishedMonoDetailProvider(contentId)),
        ),
      ),
      data: (detail) {
        return snapAsync.when(
          loading: () => _buildScaffold(
            context,
            theme,
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => _buildScaffold(
            context,
            theme,
            body: _GrammarErrorBody(
              message: 'Could not load learning content.',
              detail: err.toString(),
              onRetry: () =>
                  ref.invalidate(catalogPublishedMonoDetailProvider(contentId)),
            ),
          ),
          data: (snap) {
            final useLearn =
                shouldUsePublishedLearnSnapshot(detail.publishKind, snap);
            final patterns = useLearn && snap != null
                ? snap.grammarEntries
                    .map(grammarPatternFromPublishedEntry)
                    .toList()
                : <GrammarPattern>[];

            if (!useLearn || patterns.isEmpty) {
              final msg = !useLearn
                  ? 'Published grammar isn’t available for this story yet. '
                      'Stories published as read-only don’t include learning modules '
                      'until you publish full learn.'
                  : 'No grammar patterns for this story yet.';
              return _buildScaffold(
                context,
                theme,
                body: _GrammarEmptyBody(message: msg),
              );
            }

            return _buildScaffold(
              context,
              theme,
              body: _buildPatternList(context, patterns),
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeData theme, {
    required Widget body,
  }) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
        title: Text(
          'Grammar Learn',
          style: theme.textTheme.titleLarge?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: body,
    );
  }

  Widget _buildPatternList(
      BuildContext context, List<GrammarPattern> patterns) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset + 18),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final p = patterns[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GrammarPatternCard(
            pattern: p,
            contentId: contentId,
          ),
        );
      },
    );
  }
}

class _GrammarEmptyBody extends StatelessWidget {
  const _GrammarEmptyBody({required this.message});

  final String message;

  static const _ink = Color(0xFF1A1917);
  static const _inkMuted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _ink,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Publish Full Learn from the creator workspace to sync grammar to readers.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _inkMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrammarErrorBody extends StatelessWidget {
  const _GrammarErrorBody({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  static const _ink = Color(0xFF1A1917);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(color: _ink),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _GrammarPatternCard extends ConsumerWidget {
  const _GrammarPatternCard({
    required this.pattern,
    required this.contentId,
  });

  final GrammarPattern pattern;
  final String contentId;

  static const _radius = 16.0;
  static const _ink = Color(0xFF1A1917);
  static const _inkMuted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hint = pattern.usageHint?.trim();
    final lang = ref.watch(learnExplanationLanguageProvider);
    final meaningLine = pickSupportText(
      lang,
      en: pattern.meaningEn,
      my: pattern.meaning,
    );

    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      elevation: 0,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () {
          context.push(
            '/learn/$contentId/grammar/detail',
            extra: pattern,
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pattern.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meaningLine ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _inkMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pattern.form,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              if (hint != null && hint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _inkMuted.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
