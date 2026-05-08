import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/learn/grammar_pattern.dart';
import 'package:nimon/features/learn/quiz_mcq.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/features/learn/vocab_kanji_item.dart';
import 'package:nimon/features/profile/data/published_mono_learn_snapshot_parser.dart';

/// True when catalog learn rows should drive UI (not mocks).
///
/// Requires **full learn** publish kind and a non-empty parsed snapshot.
/// `read_only_v1` and unknown kinds return **false** even if `content` contains stray keys.
bool shouldUsePublishedLearnSnapshot(
  String? publishKind,
  LearnPublishedSnapshot? snapshot,
) {
  if (snapshot == null || !snapshot.hasAnyLearnData) return false;
  final k = (publishKind ?? '').trim();
  return k == 'full_learn_v1' || k == 'full_learn';
}

String _trimOrEmpty(String? s) => (s ?? '').trim();

String? _nullableTrim(String? s) {
  final t = (s ?? '').trim();
  return t.isEmpty ? null : t;
}

String _meaningPrimary(LocalizedMeaningsDto? m) => _trimOrEmpty(m?.my);

String? _meaningEnglish(LocalizedMeaningsDto? m) => _nullableTrim(m?.en);

VocabKanjiType _vocabTypeFromStorageKey(String? type) {
  switch ((type ?? '').trim()) {
    case 'kanji':
      return VocabKanjiType.kanji;
    default:
      return VocabKanjiType.vocabulary;
  }
}

/// Maps one published vocab row to the Learn list/detail UI model.
VocabKanjiItem vocabKanjiItemFromPublishedEntry(VocabularyKanjiEntryDto e) {
  final gloss = e.glosses;
  final exMean = e.exampleMeanings;
  return VocabKanjiItem(
    id: e.id,
    term: e.termJapanese,
    reading: _trimOrEmpty(e.reading),
    meaningMm: _meaningPrimary(gloss).isEmpty ? '' : _meaningPrimary(gloss),
    meaningEn: _meaningEnglish(gloss),
    type: _vocabTypeFromStorageKey(e.type),
    exampleSentence: _nullableTrim(e.exampleSentence),
    exampleMeaningMm: _nullableTrim(exMean?.my),
    exampleMeaningEn: _nullableTrim(exMean?.en),
  );
}

GrammarPatternExample _grammarExampleFromDto(GrammarExampleDto x) {
  final m = x.meanings;
  return GrammarPatternExample(
    japanese: x.japanese,
    myanmar: _meaningPrimary(m).isEmpty ? '' : _meaningPrimary(m),
    englishGloss: _meaningEnglish(m),
  );
}

/// Maps one published grammar row to the Learn grammar UI model.
GrammarPattern grammarPatternFromPublishedEntry(GrammarEntryDto e) {
  final mistakes = <GrammarPatternMistake>[];
  final mw = _nullableTrim(e.mistakeWrong);
  final mc = _nullableTrim(e.mistakeCorrect);
  if (mw != null && mc != null) {
    mistakes.add(GrammarPatternMistake(incorrect: mw, correct: mc));
  }

  return GrammarPattern(
    id: e.id,
    title: e.headline,
    meaning:
        _meaningPrimary(e.meanings).isEmpty ? '' : _meaningPrimary(e.meanings),
    meaningEn: _meaningEnglish(e.meanings),
    form: _trimOrEmpty(e.form),
    whenToUse: _meaningPrimary(e.usage).isEmpty ? '' : _meaningPrimary(e.usage),
    whenToUseEn: _meaningEnglish(e.usage),
    usageHint: _nullableTrim(e.form),
    examples: [for (final x in e.examples) _grammarExampleFromDto(x)],
    commonMistakes: mistakes,
    relatedNote: _meaningPrimary(e.relatedNote).isEmpty
        ? null
        : _meaningPrimary(e.relatedNote),
    relatedNoteEn: _meaningEnglish(e.relatedNote),
  );
}

LearnQuizCategory _learnQuizCategoryFromStorageKey(String? category) {
  switch ((category ?? '').trim()) {
    case 'kanji':
      return LearnQuizCategory.kanji;
    case 'grammar':
      return LearnQuizCategory.grammar;
    case 'sample_sentence':
      return LearnQuizCategory.sampleSentence;
    default:
      return LearnQuizCategory.vocabulary;
  }
}

List<String> _fourOptions(List<String> options) {
  final out = List<String>.from(options.map((x) => x));
  while (out.length < 4) {
    out.add('');
  }
  return out.length > 4 ? out.sublist(0, 4) : out;
}

/// Maps one published quiz row to the shared MCQ engine model.
///
/// [sourceStoryId] is optional metadata (e.g. mono id) for analytics/display.
QuizMcqItem quizMcqItemFromPublishedEntry(
  QuizEntryDto e, {
  String? sourceStoryId,
}) {
  final opts = _fourOptions(e.options);
  final idx = e.correctIndex.clamp(0, 3);
  final expl = e.explanations;
  return QuizMcqItem(
    id: e.id,
    category: _learnQuizCategoryFromStorageKey(e.category),
    prompt: e.prompt,
    options: opts,
    correctIndex: idx,
    explanation: _nullableTrim(expl?.en),
    explanationMy: _nullableTrim(expl?.my),
    sourceStoryId: sourceStoryId,
  );
}
