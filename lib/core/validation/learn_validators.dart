import 'package:nimon/core/validation/story_validators.dart';
import 'package:nimon/core/validation/text_normalization.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart'
    show okResult, resultFromIssues, ValidationResult;
import 'package:nimon/core/validation/validation_severity.dart';

class VocabBandLimits {
  const VocabBandLimits({required this.min, required this.max});
  final int min;
  final int max;
}

class GrammarBandLimits {
  const GrammarBandLimits({required this.min, required this.max});
  final int min;
  final int max;
}

class QuizBandLimits {
  const QuizBandLimits({
    required this.min,
    required this.max,
    required this.absoluteMax,
  });
  final int min;
  final int max;
  final int absoluteMax;
}

final vocabularyLimits = <JlptLevel, Map<StoryDurationBand, VocabBandLimits>>{
  'N5': {
    '3_5': const VocabBandLimits(min: 8, max: 18),
    '5_7': const VocabBandLimits(min: 12, max: 28),
    '7_9': const VocabBandLimits(min: 18, max: 40),
  },
  'N4': {
    '3_5': const VocabBandLimits(min: 10, max: 22),
    '5_7': const VocabBandLimits(min: 15, max: 32),
    '7_9': const VocabBandLimits(min: 22, max: 45),
  },
  'N3': {
    '3_5': const VocabBandLimits(min: 12, max: 25),
    '5_7': const VocabBandLimits(min: 18, max: 38),
    '7_9': const VocabBandLimits(min: 25, max: 55),
  },
  'N2': {
    '3_5': const VocabBandLimits(min: 10, max: 24),
    '5_7': const VocabBandLimits(min: 16, max: 36),
    '7_9': const VocabBandLimits(min: 22, max: 50),
  },
  'N1': {
    '3_5': const VocabBandLimits(min: 8, max: 20),
    '5_7': const VocabBandLimits(min: 14, max: 32),
    '7_9': const VocabBandLimits(min: 20, max: 45),
  },
};

final grammarPatternLimits =
    <JlptLevel, Map<StoryDurationBand, GrammarBandLimits>>{
  'N5': {
    '3_5': const GrammarBandLimits(min: 3, max: 5),
    '5_7': const GrammarBandLimits(min: 4, max: 7),
    '7_9': const GrammarBandLimits(min: 5, max: 9),
  },
  'N4': {
    '3_5': const GrammarBandLimits(min: 4, max: 6),
    '5_7': const GrammarBandLimits(min: 5, max: 8),
    '7_9': const GrammarBandLimits(min: 6, max: 10),
  },
  'N3': {
    '3_5': const GrammarBandLimits(min: 4, max: 7),
    '5_7': const GrammarBandLimits(min: 6, max: 9),
    '7_9': const GrammarBandLimits(min: 7, max: 12),
  },
  'N2': {
    '3_5': const GrammarBandLimits(min: 3, max: 6),
    '5_7': const GrammarBandLimits(min: 5, max: 8),
    '7_9': const GrammarBandLimits(min: 6, max: 10),
  },
  'N1': {
    '3_5': const GrammarBandLimits(min: 3, max: 5),
    '5_7': const GrammarBandLimits(min: 4, max: 7),
    '7_9': const GrammarBandLimits(min: 5, max: 9),
  },
};

final quizLimits = <JlptLevel, Map<StoryDurationBand, QuizBandLimits>>{
  'N5': {
    '3_5': const QuizBandLimits(min: 6, max: 10, absoluteMax: 18),
    '5_7': const QuizBandLimits(min: 9, max: 14, absoluteMax: 18),
    '7_9': const QuizBandLimits(min: 12, max: 18, absoluteMax: 18),
  },
  'N4': {
    '3_5': const QuizBandLimits(min: 7, max: 11, absoluteMax: 20),
    '5_7': const QuizBandLimits(min: 10, max: 16, absoluteMax: 20),
    '7_9': const QuizBandLimits(min: 14, max: 20, absoluteMax: 20),
  },
  'N3': {
    '3_5': const QuizBandLimits(min: 8, max: 12, absoluteMax: 24),
    '5_7': const QuizBandLimits(min: 12, max: 18, absoluteMax: 24),
    '7_9': const QuizBandLimits(min: 16, max: 24, absoluteMax: 24),
  },
  'N2': {
    '3_5': const QuizBandLimits(min: 7, max: 11, absoluteMax: 22),
    '5_7': const QuizBandLimits(min: 10, max: 16, absoluteMax: 22),
    '7_9': const QuizBandLimits(min: 14, max: 22, absoluteMax: 22),
  },
  'N1': {
    '3_5': const QuizBandLimits(min: 6, max: 10, absoluteMax: 20),
    '5_7': const QuizBandLimits(min: 9, max: 15, absoluteMax: 20),
    '7_9': const QuizBandLimits(min: 12, max: 20, absoluteMax: 20),
  },
};

const quizGlobalHardMax = 24;

final _kanji = RegExp(
  r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF々〇]',
  unicode: true,
);

bool containsKanji(String text) => _kanji.hasMatch(text);

final _furiganaAllowed = RegExp(
  r'^[\u3041-\u3096\u30A1-\u30FC\u30FB/\uFF0F]+$',
  unicode: true,
);

ValidationIssue _block(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      source: 'learn_validators',
      params: params,
    );

ValidationResult validateVocabularyMeaning(String? raw, ValidationMode mode) {
  final normalized = normalizeSingleLineText(trimText(raw ?? ''));
  final fullLearn = mode == ValidationMode.fullLearnPublish;

  if (normalized.isEmpty) {
    if (fullLearn) {
      return resultFromIssues([
        _block(
          'learn.vocab.meaning',
          'learn.vocab.meaning.required',
          'learn.vocab.meaning.required',
        ),
      ]);
    }
    return okResult();
  }

  final issues = <ValidationIssue>[];
  final len = charLength(normalized);
  if (len < 1 || len > 80) {
    issues.add(
      _block(
        'learn.vocab.meaning',
        'learn.vocab.meaning.length',
        'learn.vocab.meaning.length',
        {'min': 1, 'max': 80, 'actual': len},
      ),
    );
  }

  if (RegExp(r'\p{Extended_Pictographic}', unicode: true)
      .hasMatch(normalized)) {
    issues.add(
      _block(
        'learn.vocab.meaning',
        'learn.vocab.meaning.noEmoji',
        'learn.vocab.meaning.noEmoji',
      ),
    );
  }

  if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
    issues.add(
      _block(
        'learn.vocab.meaning',
        'learn.vocab.meaning.lineBreak',
        'learn.vocab.meaning.lineBreak',
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.add(
      _block(
        'learn.vocab.meaning',
        'learn.vocab.meaning.unsafe',
        'learn.vocab.meaning.unsafe',
      ),
    );
  }

  if (containsUrl(normalized)) {
    issues.add(
      _block(
        'learn.vocab.meaning',
        'learn.vocab.meaning.noUrl',
        'learn.vocab.meaning.noUrl',
      ),
    );
  }

  if (normalized.contains('#')) {
    issues.add(
      _block(
        'learn.vocab.meaning',
        'learn.vocab.meaning.noHashtag',
        'learn.vocab.meaning.noHashtag',
      ),
    );
  }

  return resultFromIssues(issues);
}

enum FuriganaKind { kanji, kana }

ValidationResult validateFurigana(
  String? raw,
  String surfaceText,
  FuriganaKind kind,
) {
  final normalized = normalizeSingleLineText(trimText(raw ?? ''));
  final needReading =
      kind == FuriganaKind.kanji || containsKanji(trimText(surfaceText));

  if (normalized.isEmpty) {
    if (needReading) {
      return resultFromIssues([
        _block(
          'learn.vocab.reading',
          'learn.vocab.reading.required',
          'learn.vocab.reading.required',
        ),
      ]);
    }
    return okResult();
  }

  final issues = <ValidationIssue>[];
  final len = charLength(normalized);
  if (len > 40) {
    issues.add(
      _block(
        'learn.vocab.reading',
        'learn.vocab.reading.tooLong',
        'learn.vocab.reading.tooLong',
        {'max': 40, 'actual': len},
      ),
    );
  }

  final segments =
      normalized.split('/').where((s) => trimText(s).isNotEmpty).length;
  if (segments > 3) {
    issues.add(
      _block(
        'learn.vocab.reading',
        'learn.vocab.reading.tooManyAlternatives',
        'learn.vocab.reading.tooManyAlternatives',
        {'max': 3, 'actual': segments},
      ),
    );
  }

  if (!_furiganaAllowed.hasMatch(normalized)) {
    issues.add(
      _block(
        'learn.vocab.reading',
        'learn.vocab.reading.invalidChars',
        'learn.vocab.reading.invalidChars',
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.add(
      _block(
        'learn.vocab.reading',
        'learn.vocab.reading.unsafe',
        'learn.vocab.reading.unsafe',
      ),
    );
  }

  return resultFromIssues(issues);
}

ValidationResult validateGrammarPatternTitle(String? raw) {
  final normalized = normalizeSingleLineText(trimText(raw ?? ''));
  if (normalized.isEmpty) {
    return resultFromIssues([
      _block(
        'learn.grammar.title',
        'learn.grammar.title.required',
        'learn.grammar.title.required',
      ),
    ]);
  }

  final issues = <ValidationIssue>[];
  final len = charLength(normalized);
  if (len < 2 || len > 40) {
    issues.add(
      _block(
        'learn.grammar.title',
        'learn.grammar.title.length',
        'learn.grammar.title.length',
        {'min': 2, 'max': 40, 'actual': len},
      ),
    );
  }

  if (RegExp(r'\p{Extended_Pictographic}', unicode: true)
      .hasMatch(normalized)) {
    issues.add(
      _block(
        'learn.grammar.title',
        'learn.grammar.title.noEmoji',
        'learn.grammar.title.noEmoji',
      ),
    );
  }

  if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
    issues.add(
      _block(
        'learn.grammar.title',
        'learn.grammar.title.lineBreak',
        'learn.grammar.title.lineBreak',
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.add(
      _block(
        'learn.grammar.title',
        'learn.grammar.title.unsafe',
        'learn.grammar.title.unsafe',
      ),
    );
  }

  if (containsUrl(normalized)) {
    issues.add(
      _block(
        'learn.grammar.title',
        'learn.grammar.title.noUrl',
        'learn.grammar.title.noUrl',
      ),
    );
  }

  return resultFromIssues(issues);
}

ValidationResult validateQuizItem({
  required String category,
  required String question,
  required List<String> options,
  required String correctAnswer,
  Set<String>? existingQuestionsNormalized,
}) {
  final issues = <ValidationIssue>[];
  const allowed = {'Vocabulary', 'Grammar', 'Sentence'};
  if (!allowed.contains(trimText(category))) {
    issues.add(
      _block(
        'learn.quiz.category',
        'learn.quiz.category.invalid',
        'learn.quiz.category.invalid',
      ),
    );
  }

  final qRaw = trimText(question);
  final qNorm = normalizeSingleLineText(qRaw);
  final qLen = charLength(qNorm);
  if (qNorm.isEmpty) {
    issues.add(
      _block(
        'learn.quiz.question',
        'learn.quiz.question.required',
        'learn.quiz.question.required',
      ),
    );
  } else if (qLen < 5 || qLen > 120) {
    issues.add(
      _block(
        'learn.quiz.question',
        'learn.quiz.question.length',
        'learn.quiz.question.length',
        {'min': 5, 'max': 120, 'actual': qLen},
      ),
    );
  }

  if (containsHtmlOrScript(qNorm) || containsUrl(qNorm)) {
    issues.add(
      _block(
        'learn.quiz.question',
        'learn.quiz.question.unsafe',
        'learn.quiz.question.unsafe',
      ),
    );
  }

  final normalizedOpts = options
      .map((o) => normalizeSingleLineText(trimText(o)))
      .where((o) => o.isNotEmpty)
      .toList();

  if (normalizedOpts.length < 2 || normalizedOpts.length > 4) {
    issues.add(
      _block(
        'learn.quiz.options',
        'learn.quiz.options.count',
        'learn.quiz.options.count',
        {'min': 2, 'max': 4, 'actual': normalizedOpts.length},
      ),
    );
  }

  final uniq = normalizedOpts.map((o) => o.toLowerCase()).toSet();
  if (uniq.length != normalizedOpts.length) {
    issues.add(
      _block(
        'learn.quiz.options',
        'learn.quiz.options.duplicate',
        'learn.quiz.options.duplicate',
      ),
    );
  }

  final correct = normalizeSingleLineText(trimText(correctAnswer));
  if (correct.isEmpty) {
    issues.add(
      _block(
        'learn.quiz.answer',
        'learn.quiz.answer.required',
        'learn.quiz.answer.required',
      ),
    );
  } else if (!normalizedOpts.contains(correct)) {
    issues.add(
      _block(
        'learn.quiz.answer',
        'learn.quiz.answer.notInOptions',
        'learn.quiz.answer.notInOptions',
      ),
    );
  }

  final correctCount = normalizedOpts.where((o) => o == correct).length;
  if (correct.isNotEmpty && correctCount != 1) {
    issues.add(
      _block(
        'learn.quiz.answer',
        'learn.quiz.answer.singleCorrect',
        'learn.quiz.answer.singleCorrect',
      ),
    );
  }

  if (existingQuestionsNormalized != null &&
      existingQuestionsNormalized.contains(qNorm.toLowerCase())) {
    issues.add(
      _block(
        'learn.quiz.question',
        'learn.quiz.question.duplicate',
        'learn.quiz.question.duplicate',
      ),
    );
  }

  return resultFromIssues(issues);
}
