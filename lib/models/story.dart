class Story {
  final String id;
  final String title;
  final String desc;
  final String level;

  Story({
    required this.id,
    required this.title,
    required this.desc,
    required this.level,
  });
}

final demoStories = <Story>[
  Story(id: '1', title: 'RAINY KYOTO', desc: 'A rainy-day encounter in Kyoto.', level: 'N5'),
  Story(id: '2', title: 'MORNING AT', desc: 'First day of class.', level: 'N3'),
];

class Episode {
  final String narration;
  final String footer;
  Episode({required this.narration, required this.footer});
}

final demoEpisodes = <Episode>[
  Episode(
    narration: 'きょう、きょうとは あめ です。YAMADA は かさ を わすれました。',
    footer: 'いっしょに いきますか、と AYANA は いいました。',
  ),
  Episode(
    narration: 'つぎ の ひ、そら は はれ でした。ふたり は えき で あいました。',
    footer: '「また あいましょう」 と わらいました。',
  ),
];
