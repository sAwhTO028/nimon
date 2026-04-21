/// One bilingual example line for a grammar pattern detail page.
class GrammarPatternExample {
  const GrammarPatternExample({
    required this.japanese,
    required this.myanmar,
    this.englishGloss,
  });

  final String japanese;
  final String myanmar;

  /// V1: optional; omit in UI when null.
  final String? englishGloss;
}

/// Wrong vs correct pair for the common mistakes section.
class GrammarPatternMistake {
  const GrammarPatternMistake({
    required this.incorrect,
    required this.correct,
  });

  final String incorrect;
  final String correct;
}

/// One grammar pattern; a story may attach many. Detail page renders one instance.
class GrammarPattern {
  const GrammarPattern({
    required this.id,
    required this.title,
    required this.meaning,
    this.meaningEn,
    required this.form,
    required this.whenToUse,
    this.whenToUseEn,
    this.usageHint,
    this.examples = const [],
    this.commonMistakes = const [],
    this.relatedNote,
    this.relatedNoteEn,
  });

  final String id;
  final String title;

  /// Myanmar (or other non-English) support line for “meaning”.
  final String meaning;

  /// English support line for “meaning” (optional).
  final String? meaningEn;

  final String form;

  /// Myanmar (or primary non-English) explanation of when to use this pattern.
  final String whenToUse;

  final String? whenToUseEn;

  /// Short line for list cards (e.g. Japanese hint); optional.
  final String? usageHint;

  final List<GrammarPatternExample> examples;
  final List<GrammarPatternMistake> commonMistakes;

  /// Myanmar (or primary) related note.
  final String? relatedNote;

  final String? relatedNoteEn;
}
