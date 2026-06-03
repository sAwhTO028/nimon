import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/core/validation/learn_validators.dart'
    show
        FuriganaKind,
        validateFurigana,
        validateGrammarPatternTitle,
        validateQuizItem,
        validateVocabularyMeaning;
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
    this.promptSourceNote,
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
  final String? promptSourceNote;

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
      totalJapaneseChars += charLength(t.trim().replaceAll(RegExp(r'\s'), ''));
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

({int total, int vocabulary, int grammar, int sentence}) _quizCountsForHtmlRules(
  List<Map<String, Object?>> quizRows,
) {
  var total = 0;
  var v = 0;
  var g = 0;
  var s = 0;
  for (final row in quizRows) {
    final parsed = parseQuizEntry(_contentOf(row));
    if (parsed == null) continue;
    total++;
    final raw = (_contentOf(row) is Map)
        ? ((Map<String, Object?>.from(_contentOf(row) as Map))['category'] ??
                '')
            .toString()
        : '';
    final k = raw.trim().toLowerCase();
    if (k == 'grammar') {
      g++;
    } else if (k == 'sample_sentence' || k == 'sentence') {
      s++;
    } else if (k == 'vocabulary') {
      v++;
    } else {
      // Kanji or unknown: counts towards total only.
    }
  }
  return (total: total, vocabulary: v, grammar: g, sentence: s);
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

  final htmlLevel = normalizeHtmlLevel(input.levelRaw);
  final bandKey = resolveStoryDurationBand(
    targetDurationBandKey: input.targetDurationBandKey,
    durationSeconds: input.durationSeconds,
  );
  final htmlDuration = normalizeHtmlDuration(bandKey);
  final htmlMode = resolveHtmlPromptModeFromSourceNote(input.promptSourceNote);

  if (htmlLevel == null) {
    pieces.add(resultFromIssues([
      _block(
        'story.level',
        'publish.htmlRules.levelInvalid',
        'publish.htmlRules.levelInvalid',
      ),
    ]));
  }
  if (htmlDuration == null) {
    pieces.add(resultFromIssues([
      _block(
        'story.duration',
        'publish.htmlRules.durationInvalid',
        'publish.htmlRules.durationInvalid',
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

  if (htmlLevel != null && htmlDuration != null && metrics.validCount > 0) {
    final limits = HtmlGeneratorLimits.sentenceLimit(
      mode: htmlMode,
      language: HtmlLearningLanguage.jp,
      duration: htmlDuration,
      level: htmlLevel,
    );
    if (limits == null) {
      pieces.add(resultFromIssues([
        _block(
          'story.sentences',
          'publish.htmlRules.promptModeInvalid',
          'publish.htmlRules.promptModeInvalid',
        ),
      ]));
    } else {
      if (metrics.validCount < limits.minSentences) {
        pieces.add(resultFromIssues([
          _block(
            'story.sentences',
            'publish.htmlRules.storySentenceTooFew',
            'publish.htmlRules.storySentenceTooFew',
            {'min': limits.minSentences, 'actual': metrics.validCount},
          ),
        ]));
      }
      if (metrics.validCount > limits.maxSentences) {
        pieces.add(resultFromIssues([
          _block(
            'story.sentences',
            'publish.htmlRules.storySentenceTooMany',
            'publish.htmlRules.storySentenceTooMany',
            {'max': limits.maxSentences, 'actual': metrics.validCount},
          ),
        ]));
      }
      if (metrics.totalJapaneseChars < limits.minChars) {
        pieces.add(resultFromIssues([
          _block(
            'story.body',
            'publish.htmlRules.storyCharsTooFew',
            'publish.htmlRules.storyCharsTooFew',
            {'min': limits.minChars, 'actual': metrics.totalJapaneseChars},
          ),
        ]));
      }
      if (metrics.totalJapaneseChars > limits.maxChars) {
        pieces.add(resultFromIssues([
          _block(
            'story.body',
            'publish.htmlRules.storyCharsTooMany',
            'publish.htmlRules.storyCharsTooMany',
            {'max': limits.maxChars, 'actual': metrics.totalJapaneseChars},
          ),
        ]));
      }
    }
  }

  if (mode == ValidationMode.fullLearnPublish) {
    final mod = fullLearnModulesComplete(input.moduleWorkflowStatuses);
    if (mod != null) pieces.add(resultFromIssues([mod]));

    if (htmlLevel != null && htmlDuration != null) {
      final vocabLimit = HtmlGeneratorLimits.vocabularyLimit(
        language: HtmlLearningLanguage.jp,
        duration: htmlDuration,
        level: htmlLevel,
      );
      final grammarLimit = HtmlGeneratorLimits.grammarLimit(
        language: HtmlLearningLanguage.jp,
        duration: htmlDuration,
        level: htmlLevel,
      );

      final vocabCount = input.vocabEntries.where((e) {
        final p = parseVocabEntry(_contentOf(e));
        return p.termJapanese.trim().isNotEmpty;
      }).length;
      final grammarCount = input.grammarEntries.where((e) {
        return parseGrammarEntry(_contentOf(e)).headline.trim().isNotEmpty;
      }).length;

      final quizCounts = _quizCountsForHtmlRules(input.quizEntries);

      if (vocabLimit != null) {
        final requiredV = htmlMode == HtmlPromptMode.ai
            ? vocabLimit.defaultValue
            : null;
        if (htmlMode == HtmlPromptMode.ai) {
          if (vocabCount != requiredV) {
            pieces.add(resultFromIssues([
              _block(
                'learn.vocab.count',
                'publish.htmlRules.vocabularyCountMismatch',
                'publish.htmlRules.vocabularyCountMismatch',
                {'expected': requiredV, 'actual': vocabCount},
              ),
            ]));
          }
        } else {
          if (vocabCount < vocabLimit.manualMin || vocabCount > vocabLimit.manualMax) {
            pieces.add(resultFromIssues([
              _block(
                'learn.vocab.count',
                'publish.htmlRules.vocabularyCountMismatch',
                'publish.htmlRules.vocabularyCountMismatch',
                {
                  'min': vocabLimit.manualMin,
                  'max': vocabLimit.manualMax,
                  'actual': vocabCount,
                },
              ),
            ]));
          }
        }
      }

      if (grammarLimit != null) {
        final requiredG = htmlMode == HtmlPromptMode.ai
            ? grammarLimit.defaultValue
            : null;
        if (htmlMode == HtmlPromptMode.ai) {
          if (grammarCount != requiredG) {
            pieces.add(resultFromIssues([
              _block(
                'learn.grammar.count',
                'publish.htmlRules.grammarCountMismatch',
                'publish.htmlRules.grammarCountMismatch',
                {'expected': requiredG, 'actual': grammarCount},
              ),
            ]));
          }
        } else {
          if (grammarCount < grammarLimit.manualMin ||
              grammarCount > grammarLimit.manualMax) {
            pieces.add(resultFromIssues([
              _block(
                'learn.grammar.count',
                'publish.htmlRules.grammarCountMismatch',
                'publish.htmlRules.grammarCountMismatch',
                {
                  'min': grammarLimit.manualMin,
                  'max': grammarLimit.manualMax,
                  'actual': grammarCount,
                },
              ),
            ]));
          }
        }
      }

      final selected = htmlMode == HtmlPromptMode.ai
          ? HtmlGeneratorLimits.selectedFullLearnLimits(
              mode: HtmlPromptMode.ai,
              language: HtmlLearningLanguage.jp,
              duration: htmlDuration,
              level: htmlLevel,
              preset: HtmlLimitPreset.defaultValue,
            )
          : null;

      if (htmlMode == HtmlPromptMode.ai && selected != null) {
        if (quizCounts.total != selected.totalQuizCount) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.count',
              'publish.htmlRules.quizTotalMismatch',
              'publish.htmlRules.quizTotalMismatch',
              {'expected': selected.totalQuizCount, 'actual': quizCounts.total},
            ),
          ]));
        }
        if (quizCounts.vocabulary != selected.vocabularyQuizCount) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.vocabulary',
              'publish.htmlRules.quizVocabularyMismatch',
              'publish.htmlRules.quizVocabularyMismatch',
              {
                'expected': selected.vocabularyQuizCount,
                'actual': quizCounts.vocabulary
              },
            ),
          ]));
        }
        if (quizCounts.grammar != selected.grammarQuizCount) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.grammar',
              'publish.htmlRules.quizGrammarMismatch',
              'publish.htmlRules.quizGrammarMismatch',
              {'expected': selected.grammarQuizCount, 'actual': quizCounts.grammar},
            ),
          ]));
        }
        if (quizCounts.sentence != selected.sentenceQuizCount) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.sentence',
              'publish.htmlRules.quizSentenceMismatch',
              'publish.htmlRules.quizSentenceMismatch',
              {
                'expected': selected.sentenceQuizCount,
                'actual': quizCounts.sentence
              },
            ),
          ]));
        }
      } else if (htmlMode == HtmlPromptMode.manual) {
        final totalLim = HtmlGeneratorLimits.quizLimit(
          duration: htmlDuration,
          level: htmlLevel,
          quizCategory: 'Total Quiz',
        );
        final vLim = HtmlGeneratorLimits.quizLimit(
          duration: htmlDuration,
          level: htmlLevel,
          quizCategory: 'Vocabulary Quiz',
        );
        final gLim = HtmlGeneratorLimits.quizLimit(
          duration: htmlDuration,
          level: htmlLevel,
          quizCategory: 'Grammar Quiz',
        );
        final sLim = HtmlGeneratorLimits.quizLimit(
          duration: htmlDuration,
          level: htmlLevel,
          quizCategory: 'Sentence Quiz',
        );
        if (totalLim != null &&
            (quizCounts.total < totalLim.manualMin ||
                quizCounts.total > totalLim.manualMax)) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.count',
              'publish.htmlRules.quizTotalMismatch',
              'publish.htmlRules.quizTotalMismatch',
              {
                'min': totalLim.manualMin,
                'max': totalLim.manualMax,
                'actual': quizCounts.total,
              },
            ),
          ]));
        }
        if (vLim != null &&
            (quizCounts.vocabulary < vLim.manualMin ||
                quizCounts.vocabulary > vLim.manualMax)) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.vocabulary',
              'publish.htmlRules.quizVocabularyMismatch',
              'publish.htmlRules.quizVocabularyMismatch',
              {
                'min': vLim.manualMin,
                'max': vLim.manualMax,
                'actual': quizCounts.vocabulary,
              },
            ),
          ]));
        }
        if (gLim != null &&
            (quizCounts.grammar < gLim.manualMin ||
                quizCounts.grammar > gLim.manualMax)) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.grammar',
              'publish.htmlRules.quizGrammarMismatch',
              'publish.htmlRules.quizGrammarMismatch',
              {
                'min': gLim.manualMin,
                'max': gLim.manualMax,
                'actual': quizCounts.grammar,
              },
            ),
          ]));
        }
        if (sLim != null &&
            (quizCounts.sentence < sLim.manualMin ||
                quizCounts.sentence > sLim.manualMax)) {
          pieces.add(resultFromIssues([
            _block(
              'learn.quiz.sentence',
              'publish.htmlRules.quizSentenceMismatch',
              'publish.htmlRules.quizSentenceMismatch',
              {
                'min': sLim.manualMin,
                'max': sLim.manualMax,
                'actual': quizCounts.sentence,
              },
            ),
          ]));
        }
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
