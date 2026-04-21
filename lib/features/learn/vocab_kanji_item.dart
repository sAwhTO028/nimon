/// List vs detail chrome (small label on list cards).
enum VocabKanjiType {
  vocabulary,
  kanji,
}

/// One vocabulary or kanji entry from story content (V1 mock; later from extraction pipeline).
class VocabKanjiItem {
  const VocabKanjiItem({
    required this.id,
    required this.term,
    required this.reading,
    required this.meaningMm,
    this.meaningEn,
    required this.type,
    this.exampleSentence,
    this.exampleMeaningMm,
    this.exampleMeaningEn,
    this.storySource,
    this.audioUrl,
  });

  final String id;

  /// Japanese word or expression (surface form).
  final String term;

  /// Reading (e.g. hiragana).
  final String reading;

  /// Myanmar gloss.
  final String meaningMm;

  /// English gloss (optional).
  final String? meaningEn;

  final VocabKanjiType type;

  /// Example sentence in Japanese (detail sheet).
  final String? exampleSentence;

  /// Myanmar gloss for [exampleSentence] (detail sheet).
  final String? exampleMeaningMm;

  final String? exampleMeaningEn;

  /// Story / lesson title this item came from (detail sheet, optional).
  final String? storySource;

  /// Reserved for future audio (V1 no playback).
  final String? audioUrl;

  String get typeLabel => switch (type) {
        VocabKanjiType.vocabulary => 'Vocabulary',
        VocabKanjiType.kanji => 'Kanji',
      };
}
