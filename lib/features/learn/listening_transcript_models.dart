/// V1 transcript line for Listening / Pronunciation (no sync metadata).
class ListeningTranscriptLine {
  const ListeningTranscriptLine({
    required this.japanese,
    this.reading,
    this.translationMyanmar,
    this.translationEnglish,
  });

  final String japanese;
  final String? reading;

  /// Myanmar meaning (same as [meaningMy]).
  final String? translationMyanmar;

  /// English meaning (same as [meaningEn]).
  final String? translationEnglish;

  String? get meaningEn => translationEnglish;
  String? get meaningMy => translationMyanmar;
}

/// Sample story + audio for V1 when the route passes no custom payload.
abstract final class ListeningSampleData {
  ListeningSampleData._();

  /// Public sample MP3 (network). Replace with story audio in production.
  static const defaultAudioUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

  static const List<ListeningTranscriptLine> mockLines = [
    ListeningTranscriptLine(
      japanese: '朝、めがねをかけて新聞を読みました。',
      reading: 'あさ、めがねをかけてしんぶんをよみました。',
      translationEnglish: 'In the morning, I put on my glasses and read the newspaper.',
      translationMyanmar: 'မနက်ပိုင်းမှာ မျက်မှန်တပ်ပြီး သတင်းစာဖတ်ခဲ့တယ်။',
    ),
    ListeningTranscriptLine(
      japanese: '駅まで歩いて、電車に乗りました。',
      reading: 'えきまであるいて、でんしゃにのりました。',
      translationEnglish: 'I walked to the station and got on the train.',
      translationMyanmar: 'ဘူတာရုံအထိ လမ်းလျှောက်သွားပြီး ရထားစီးခဲ့တယ်။',
    ),
    ListeningTranscriptLine(
      japanese: '会社で会議がありました。',
      reading: 'かいしゃでかいぎがありました。',
      translationEnglish: 'There was a meeting at the company.',
      translationMyanmar: 'ကုမ္ပဏီမှာ အစည်းအဝေးရှိခဲ့တယ်။',
    ),
    ListeningTranscriptLine(
      japanese: '昼休みに弁当を食べました。',
      reading: 'ひるやすみにべんとうをたべました。',
      translationEnglish: 'During lunch break I ate my bento.',
      translationMyanmar: 'နေ့လည်နားချိန်မှာ ဘင်တိုစားခဲ့တယ်။',
    ),
    ListeningTranscriptLine(
      japanese: '午後は資料を整理しました。',
      reading: 'ごごはしりょうをせいりしました。',
      translationEnglish: 'In the afternoon I organized the materials.',
      translationMyanmar: 'နေ့လည်ပိုင်းမှာ စာရွက်စာတမ်းတွေ စီစဉ်ခဲ့တယ်။',
    ),
    ListeningTranscriptLine(
      japanese: '帰り道で友だちに会いました。',
      reading: 'かえりみちでともだちにあいました。',
      translationEnglish: 'On the way home I met a friend.',
      translationMyanmar: 'အိမ်ပြန်လမ်းမှာ သူငယ်ချင်းနဲ့ တွေ့ခဲ့တယ်။',
    ),
  ];
}
