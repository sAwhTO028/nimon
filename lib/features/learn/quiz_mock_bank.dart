import 'dart:math';

import 'package:nimon/features/learn/quiz_mcq.dart';
import 'package:nimon/features/learn/quiz_session.dart';

/// V1 mock MCQ bank; one engine serves all categories.
final class QuizMockBank {
  QuizMockBank._();

  static final List<QuizMcqItem> _all = [
    // --- Vocabulary ---
    const QuizMcqItem(
      id: 'v1',
      category: LearnQuizCategory.vocabulary,
      prompt: '図書館',
      options: [
        'စာကြည့်တိုက်',
        'ဘူတာရုံ',
        'ဈေးဆိုင်',
        'အလုပ်ရုံ',
      ],
      correctIndex: 0,
      explanation: '図書館（としょかん）= library',
      explanationMy: '図書館（としょかん）= စာကြည့်တိုက်',
    ),
    const QuizMcqItem(
      id: 'v2',
      category: LearnQuizCategory.vocabulary,
      prompt: 'Which Japanese word means “ပြောသည်”?',
      options: ['読む', '話す', '書く', '聞く'],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'v3',
      category: LearnQuizCategory.vocabulary,
      prompt: '勉強',
      options: [
        'ကစားခြင်း',
        'လေ့လာခြင်း',
        'အိပ်ခြင်း',
        'စားခြင်း',
      ],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'v4',
      category: LearnQuizCategory.vocabulary,
      prompt: '返却',
      options: [
        'ငှားရမ်းခြင်း',
        'ပြန်အပ်ခြင်း',
        'ဝယ်ယူခြင်း',
        'ပြန်ပေးခြင်း（လက်ဆောင်）',
      ],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'v5',
      category: LearnQuizCategory.vocabulary,
      prompt: 'Choose the word for “ငြိမ်သက်သော”.',
      options: ['うるさい', 'しずか', 'あつい', 'さむい'],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'v6',
      category: LearnQuizCategory.vocabulary,
      prompt: '環境',
      options: [
        'စီးပွားရေး',
        'ပတ်ဝန်းကျင်',
        'ပညာရေး',
        'သမိုင်း',
      ],
      correctIndex: 1,
    ),
    // --- Kanji ---
    const QuizMcqItem(
      id: 'k1',
      category: LearnQuizCategory.kanji,
      prompt: '環境 のよみは？',
      options: ['かんきょう', 'かんけい', 'かんがい', 'げんきょう'],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 'k2',
      category: LearnQuizCategory.kanji,
      prompt: '図書館 の「図」の音読みとして自然なのは？',
      options: ['と', 'ず', 'し', 'としょ'],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 'k3',
      category: LearnQuizCategory.kanji,
      prompt: '返却 の意味に近いのは？',
      options: ['借りる', '返す・戻す', '買う', '読む'],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'k4',
      category: LearnQuizCategory.kanji,
      prompt: '勉強する の「勉」の読みは？',
      options: ['べん', 'みん', 'きょう', 'れん'],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 'k5',
      category: LearnQuizCategory.kanji,
      prompt: '静か の読みは？',
      options: ['しずか', 'せいか', 'しょうか', 'じゃか'],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 'k6',
      category: LearnQuizCategory.kanji,
      prompt: '話す の「話」の読みは？',
      options: ['はなす', 'わす', 'はす', 'はなし'],
      correctIndex: 0,
    ),
    // --- Grammar ---
    const QuizMcqItem(
      id: 'g1',
      category: LearnQuizCategory.grammar,
      prompt: '日本＿＿＿話しましょう。',
      options: ['について', 'ために', 'ように', 'によって'],
      correctIndex: 0,
      explanation: '名詞＋について ＝ about …',
    ),
    const QuizMcqItem(
      id: 'g2',
      category: LearnQuizCategory.grammar,
      prompt: '早く起きる＿＿＿アラームをセットした。',
      options: ['について', 'ために', 'ように', 'ばかり'],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'g3',
      category: LearnQuizCategory.grammar,
      prompt: '忘れない＿＿＿メモした。',
      options: ['について', 'ために', 'ように', 'までに'],
      correctIndex: 2,
    ),
    const QuizMcqItem(
      id: 'g4',
      category: LearnQuizCategory.grammar,
      prompt: '「〜ことになる」に近い意味は？',
      options: [
        '自分で決めた結果',
        '決まり・自然の帰結としてそうなる',
        '否定の推量だけ',
        '過去の願望だけ',
      ],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'g5',
      category: LearnQuizCategory.grammar,
      prompt: '食べる＿＿＿は自然ですか？ → ✓ 食べることについて',
      options: [
        '食べるについて（そのまま）',
        '食べることについて',
        '食べているについて',
        '食べたについて',
      ],
      correctIndex: 1,
    ),
    const QuizMcqItem(
      id: 'g6',
      category: LearnQuizCategory.grammar,
      prompt: '「目的」を言うのに使いやすいのは？',
      options: ['について', 'ために', 'によると', 'にしても'],
      correctIndex: 1,
    ),
    // --- Sample sentence ---
    const QuizMcqItem(
      id: 's1',
      category: LearnQuizCategory.sampleSentence,
      prompt:
          '「စာကြည့်တိုက်က ဘူတာကနေ လမ်းလျှောက် ၅ မိနစ်လောက် အကွာမှာ ရှိတယ်။」に近い日本語は？',
      options: [
        '図書館は駅から歩いて五分くらいのところにあります。',
        '図書館は駅の中にあります。',
        '図書館は今日休みです。',
        '図書館へバスで行きます。',
      ],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 's2',
      category: LearnQuizCategory.sampleSentence,
      prompt: '「ပြန်အပ်ရမယ့်ရက်ကို မေ့နေလို့ မဖြစ်အောင်」＿＿＿。',
      options: [
        '返却日を忘れないように工夫が大切だ。',
        '返却日について話そう。',
        '返却日によって休む。',
        '返却日ばかり勉強する。',
      ],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 's3',
      category: LearnQuizCategory.sampleSentence,
      prompt: '図書館で本を読むとき、求められるのは？',
      options: [
        '静かに読む',
        '大声で話す',
        '走り回る',
        '飲食はどこでもOK',
      ],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 's4',
      category: LearnQuizCategory.sampleSentence,
      prompt: '「一緒に日本語で話そう」に近いのは？',
      options: [
        '日本について話しましょう。',
        '日本へ帰りましょう。',
        '日本を買いましょう。',
        '日本が嫌いです。',
      ],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 's5',
      category: LearnQuizCategory.sampleSentence,
      prompt: '会員証がないと、たいていできないのは？',
      options: ['貸出', '天気予報', '睡眠', '散歩'],
      correctIndex: 0,
    ),
    const QuizMcqItem(
      id: 's6',
      category: LearnQuizCategory.sampleSentence,
      prompt: '「子ども向けの読書会」向けの雰囲気は？',
      options: [
        '親子で楽しめる短い読み聞かせ',
        '法律の条文だけを読む',
        '無言で退館する',
        '試験だけ行う',
      ],
      correctIndex: 0,
    ),
  ];

  /// Picks [count] questions for [category], shuffled; cycles if count > pool size.
  static List<QuizMcqItem> pickQuestions(
    LearnQuizCategory category,
    int count,
  ) {
    final pool =
        _all.where((q) => q.category == category).toList(growable: false);
    if (pool.isEmpty) return [];
    final n = count.clamp(1, 999);
    final out = <QuizMcqItem>[];
    final shuffled = List<QuizMcqItem>.from(pool)..shuffle(Random());
    for (var i = 0; i < n; i++) {
      out.add(shuffled[i % shuffled.length]);
    }
    return out;
  }
}
