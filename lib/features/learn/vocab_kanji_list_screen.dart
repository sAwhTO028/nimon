import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/features/learn/vocab_kanji_detail_sheet.dart';
import 'package:nimon/features/learn/vocab_kanji_item.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Opens the vocabulary/kanji detail bottom sheet for the tapped [item].
void onVocabKanjiItemTapForDetail(
  BuildContext context,
  String contentId,
  VocabKanjiItem item,
) {
  showVocabKanjiDetailSheet(
    context,
    contentId: contentId,
    item: item,
  );
}

/// V1: scrollable vocabulary/kanji list for a story ([contentId]).
class VocabKanjiListScreen extends StatelessWidget {
  const VocabKanjiListScreen({
    super.key,
    required this.contentId,
  });

  final String contentId;

  static const _bg = Color(0xFFF6F3EA);
  static const _ink = Color(0xFF1A1917);

  /// V1 mock items (later: derived from story).
  static const List<VocabKanjiItem> mockItems = [
    VocabKanjiItem(
      id: 'v1',
      term: '図書館',
      reading: 'としょかん',
      meaningMm: 'စာကြည့်တိုက်',
      meaningEn: 'library',
      type: VocabKanjiType.vocabulary,
      exampleSentence: '図書館は駅から歩いて五分です。',
      exampleMeaningMm:
          'စာကြည့်တိုက်က ဘူတာကနေ လမ်းလျှောက် ၅ မိနစ်အကွာမှာ ရှိတယ်။',
      exampleMeaningEn:
          'The library is a five-minute walk from the station.',
      storySource: '町の図書館',
    ),
    VocabKanjiItem(
      id: 'v2',
      term: '話す',
      reading: 'はなす',
      meaningMm: 'ပြောသည်',
      meaningEn: 'to speak; to talk',
      type: VocabKanjiType.vocabulary,
      exampleSentence: '日本について話しましょう。',
      exampleMeaningMm: 'ဂျပန်အကြောင်း ပြောကြရအောင်။',
      exampleMeaningEn: "Let's talk about Japan.",
    ),
    VocabKanjiItem(
      id: 'v3',
      term: '勉強',
      reading: 'べんきょう',
      meaningMm: 'လေ့လာခြင်း',
      meaningEn: 'study; learning',
      type: VocabKanjiType.vocabulary,
    ),
    VocabKanjiItem(
      id: 'k1',
      term: '環境',
      reading: 'かんきょう',
      meaningMm: 'ပတ်ဝန်းကျင်',
      meaningEn: 'environment',
      type: VocabKanjiType.kanji,
    ),
    VocabKanjiItem(
      id: 'v4',
      term: '返却',
      reading: 'へんきゃく',
      meaningMm: 'ပြန်အပ်ခြင်း',
      meaningEn: 'returning (e.g. a book)',
      type: VocabKanjiType.vocabulary,
    ),
    VocabKanjiItem(
      id: 'v5',
      term: '静か',
      reading: 'しずか',
      meaningMm: 'ငြိမ်သက်သော',
      meaningEn: 'quiet; calm',
      type: VocabKanjiType.vocabulary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
        title: Text(
          'Vocabulary / Kanji',
          style: theme.textTheme.titleLarge?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset + 18),
        itemCount: mockItems.length,
        itemBuilder: (context, index) {
          final item = mockItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _VocabKanjiListCard(
              item: item,
              onTap: () =>
                  onVocabKanjiItemTapForDetail(context, contentId, item),
            ),
          );
        },
      ),
    );
  }
}

class _VocabKanjiListCard extends ConsumerWidget {
  const _VocabKanjiListCard({
    required this.item,
    required this.onTap,
  });

  final VocabKanjiItem item;
  final VoidCallback onTap;

  static const _radius = 16.0;
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

    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      elevation: 0,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.term,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x0A000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.typeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _inkMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.reading,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _inkMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meaningLine ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
