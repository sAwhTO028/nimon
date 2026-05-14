import 'dart:math' as math;

import 'package:nimon/core/validation/learn_validators.dart'
    show
        FuriganaKind,
        grammarPatternLimits,
        quizGlobalHardMax,
        quizLimits,
        validateFurigana,
        validateGrammarPatternTitle,
        validateQuizItem,
        validateVocabularyMeaning,
        vocabularyLimits;
import 'package:nimon/core/validation/story_duration_band.dart';
import 'package:nimon/core/validation/story_validators.dart';
import 'package:nimon/core/validation/text_normalization.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';

/// Portable publish snapshot (no Flutter feature imports).
class StoryPublishData {
  StoryPublishData({
    required this.title,
    required this.description,
    required this.levelRaw,
    required this.targetDurationBandKey,
    this.durationSeconds,
    required this.sentences,
    required this.vocabEntries,
    required this.grammarEntries,
    required this.quizEntries,
    required this.moduleWorkflowStatuses,
  });

  final String? title;
  final String? description;
  final String? levelRaw;
  final String? targetDurationBandKey;
  final int? durationSeconds;

  /// Each `{ 'content': <map> }` matching backend Draft* rows.
  final List<Map<String, Object?>> sentences;
  final List<Map<String, Object?>> vocabEntries;
  final List<Map<String, Object?>> grammarEntries;
  final List<Map<String, Object?>> quizEntries;
  final Map<String, String> moduleWorkflowStatuses;
}

ValidationIssue _warn(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.warning,
      source: 'publish_validation',
      params: params,
    );

ValidationIssue _block(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      source: 'publish_validation',
      params: params,
    );

Object? _contentOf(Map<String, Object?> row) => row['content'];

String extractJapanesePrimaryText(Object? content) {
  if (content == null || content is! Map) return '';
  final c = Map<String, Object?>.from(content);
  final candidates = [
    c['japanese'],
    c['japaneseText'],
    c['jp'],
    c['textJa'],
    c['text'],
    c['value'],
  ];
  for (final v in candidates) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

({int validCount, int totalJapaneseChars}) extractStorySentenceMetrics(
  List<Map<String, Object?>> sentences,
) {
  var validCount = 0;
  var totalJapaneseChars = 0;
  for (final s in sentences) {
    final t = extractJapanesePrimaryText(_contentOf(s));
    if (t.isNotEmpty) {
      validCount++;
      totalJapaneseChars += charLength(t);
    }
  }
  return (validCount: validCount, totalJapaneseChars: totalJapaneseChars);
}

({
  String termJapanese,
  String? reading,
  String meaningPrimary,
  bool isKanjiType
}) parseVocabEntry(Object? content) {
  if (content == null || content is! Map) {
    return (
      termJapanese: '',
      reading: null,
      meaningPrimary: '',
      isKanjiType: false,
    );
  }
  final c = Map<String, Object?>.from(content);
  final term = (c['termJapanese'] ?? c['term'] ?? '') as String? ?? '';
  final typ = (c['type'] ?? c['entryType'] ?? '').toString().toLowerCase();
  final gloss = c['glosses'] ?? c['meanings'];
  String my = '';
  String en = '';
  if (gloss is Map) {
    final g = Map<String, Object?>.from(gloss);
    my = (g['my'] as String?)?.trim() ?? '';
    en = (g['en'] as String?)?.trim() ?? '';
  }
  final meaningPrimary =
      [my, en].firstWhere((s) => s.isNotEmpty, orElse: () => '');
  final reading = c['reading'] as String?;
  return (
    termJapanese: term,
    reading: reading,
    meaningPrimary: meaningPrimary,
    isKanjiType: typ == 'kanji',
  );
}

({String headline}) parseGrammarEntry(Object? content) {
  if (content == null || content is! Map) return (headline: '');
  final c = Map<String, Object?>.from(content);
  final h = (c['headline'] ?? c['title'] ?? '') as String? ?? '';
  return (headline: h);
}

String mapQuizCategoryToValidatorCategory(String raw) {
  final k = raw.trim().toLowerCase();
  if (k == 'grammar') return 'Grammar';
  if (k == 'sample_sentence' || k == 'sentence') return 'Sentence';
  return 'Vocabulary';
}

({
  String category,
  String question,
  List<String> options,
  String correctAnswer
})? parseQuizEntry(Object? content) {
  if (content == null || content is! Map) return null;
  final c = Map<String, Object?>.from(content);
  final catRaw = (c['category'] ?? 'vocabulary').toString();
  final category = mapQuizCategoryToValidatorCategory(catRaw);
  final question = (c['prompt'] ?? c['question'] ?? '') as String? ?? '';
  final optsRaw = c['options'];
  final options =
      optsRaw is List ? optsRaw.whereType<String>().toList() : <String>[];
  String correctAnswer = '';
  if (c['correctAnswer'] is String) {
    correctAnswer = (c['correctAnswer'] as String).trim();
  } else {
    final idxRaw = c['correctIndex'];
    final idx = idxRaw is int
        ? idxRaw
        : idxRaw is num
            ? idxRaw.toInt()
            : null;
    if (idx != null && idx >= 0 && idx < options.length) {
      correctAnswer = options[idx];
    }
  }
  return (
    category: category,
    question: question,
    options: options,
    correctAnswer: correctAnswer,
  );
}

ValidationIssue? fullLearnModulesComplete(Map<String, String> statuses) {
  const keys = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'];
  for (final k in keys) {
    if ((statuses[k] ?? '').toLowerCase() != 'completed') {
      return _block(
        'module.$k',
        'learn.module.$k.notCompleted',
        'learn.module.notCompleted',
        {'module': k},
      );
    }
  }
  return null;
}

ValidationResult validateStoryPublishData(
  StoryPublishData input,
  ValidationMode mode,
) {
  final publishLikeMode = mode == ValidationMode.readOnlyPublish
      ? ValidationMode.readOnlyPublish
      : ValidationMode.fullLearnPublish;

  final pieces = <ValidationResult>[
    validateStoryTitle(input.title, publishLikeMode),
    validateStoryDescription(input.description, publishLikeMode),
  ];

  final jlpt = normalizeJlptLevel(input.levelRaw);
  final band = resolveStoryDurationBand(
    targetDurationBandKey: input.targetDurationBandKey,
    durationSeconds: input.durationSeconds,
  );

  if (jlpt == null) {
    pieces.add(resultFromIssues([
      _warn('story.level', 'story.limits.skippedNoJlpt',
          'story.limits.skippedNoJlpt'),
    ]));
  }
  if (band == null) {
    pieces.add(resultFromIssues([
      _warn(
        'story.duration',
        'story.limits.skippedNoBand',
        'story.limits.skippedNoBand',
      ),
    ]));
  }

  final metrics = extractStorySentenceMetrics(input.sentences);
  if (metrics.validCount == 0) {
    pieces.add(resultFromIssues([
      _block(
        'story.sentences',
        'story.sentences.required',
        'story.sentences.required',
      ),
    ]));
  }

  if (jlpt != null && band != null && metrics.validCount > 0) {
    final limits = storySentenceLimits[jlpt]![band]!;
    if (metrics.validCount < limits.minSentences) {
      pieces.add(resultFromIssues([
        _block(
          'story.sentences',
          'story.sentences.tooFew',
          'story.sentences.tooFew',
          {'min': limits.minSentences, 'actual': metrics.validCount},
        ),
      ]));
    }
    if (metrics.validCount > limits.maxSentences) {
      pieces.add(resultFromIssues([
        _block(
          'story.sentences',
          'story.sentences.tooMany',
          'story.sentences.tooMany',
          {'max': limits.maxSentences, 'actual': metrics.validCount},
        ),
      ]));
    }
    if (metrics.totalJapaneseChars > limits.maxChars) {
      pieces.add(resultFromIssues([
        _block(
          'story.body',
          'story.body.tooLong',
          'story.body.tooLong',
          {'max': limits.maxChars, 'actual': metrics.totalJapaneseChars},
        ),
      ]));
    }
  }

  if (mode == ValidationMode.fullLearnPublish) {
    final mod = fullLearnModulesComplete(input.moduleWorkflowStatuses);
    if (mod != null) pieces.add(resultFromIssues([mod]));

    if (jlpt != null && band != null) {
      final vLimits = vocabularyLimits[jlpt]![band]!;
      final gLimits = grammarPatternLimits[jlpt]![band]!;
      final qLimits = quizLimits[jlpt]![band]!;

      final vocabCount = input.vocabEntries.where((e) {
        final p = parseVocabEntry(_contentOf(e));
        return p.termJapanese.trim().isNotEmpty;
      }).length;
      final grammarCount = input.grammarEntries.where((e) {
        return parseGrammarEntry(_contentOf(e)).headline.trim().isNotEmpty;
      }).length;
      final quizCount = input.quizEntries
          .where((e) => parseQuizEntry(_contentOf(e)) != null)
          .length;

      if (vocabCount < vLimits.min || vocabCount > vLimits.max) {
        pieces.add(resultFromIssues([
          _block(
            'learn.vocab.count',
            'learn.count.vocab.range',
            'learn.count.vocab.range',
            {'min': vLimits.min, 'max': vLimits.max, 'actual': vocabCount},
          ),
        ]));
      }
      if (grammarCount < gLimits.min || grammarCount > gLimits.max) {
        pieces.add(resultFromIssues([
          _block(
            'learn.grammar.count',
            'learn.count.grammar.range',
            'learn.count.grammar.range',
            {'min': gLimits.min, 'max': gLimits.max, 'actual': grammarCount},
          ),
        ]));
      }
      final qMaxAllowed = math.min(
        qLimits.absoluteMax,
        math.min(quizGlobalHardMax, qLimits.max),
      );
      if (quizCount < qLimits.min || quizCount > qMaxAllowed) {
        pieces.add(resultFromIssues([
          _block(
            'learn.quiz.count',
            'learn.count.quiz.range',
            'learn.count.quiz.range',
            {
              'min': qLimits.min,
              'max': qMaxAllowed,
              'actual': quizCount,
            },
          ),
        ]));
      }
    }

    for (final row in input.vocabEntries) {
      final v = parseVocabEntry(_contentOf(row));
      if (v.termJapanese.trim().isEmpty) continue;
      pieces.add(
        validateVocabularyMeaning(
          v.meaningPrimary,
          ValidationMode.fullLearnPublish,
        ),
      );
      final furiganaKind =
          v.isKanjiType ? FuriganaKind.kanji : FuriganaKind.kana;
      pieces.add(
        validateFurigana(v.reading, v.termJapanese, furiganaKind),
      );
    }

    for (final row in input.grammarEntries) {
      final g = parseGrammarEntry(_contentOf(row));
      pieces.add(validateGrammarPatternTitle(g.headline));
    }

    final seenQuestions = <String>{};
    for (final row in input.quizEntries) {
      final parsed = parseQuizEntry(_contentOf(row));
      if (parsed == null) continue;
      final qNorm = parsed.question.trim().toLowerCase();
      pieces.add(
        validateQuizItem(
          category: parsed.category,
          question: parsed.question,
          options: parsed.options,
          correctAnswer: parsed.correctAnswer,
          existingQuestionsNormalized: qNorm.isNotEmpty ? seenQuestions : null,
        ),
      );
      if (qNorm.isNotEmpty) seenQuestions.add(qNorm);
    }
  }

  return combineResults(pieces);
}

bool hasWarningIssues(ValidationResult r) =>
    r.issues.any((i) => i.severity == ValidationSeverity.warning);
