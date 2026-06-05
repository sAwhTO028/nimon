import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/core/validation/auth_validators.dart' show normalizeEmailInput;
import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/core/validation/text_normalization.dart' show charLength;
import 'package:nimon/features/create/import/nimon_import_enums.dart';
import 'package:nimon/features/create/import/nimon_import_meta.dart';
import 'package:nimon/features/create/import/nimon_import_payload.dart';
import 'package:nimon/features/create/import/nimon_import_result.dart';

// -----------------------------------------------------------------------------
// Local JSON import validator (pure; no Riverpod, no [CreatorStoryV1] mapping).
//
// Validates AI import contract shape + app context. Does not replace
// [validateStoryPublishData] — publish preflight remains on the existing path.
// -----------------------------------------------------------------------------

/// Supported `nimonImportMeta.schemaVersion` values.
const Set<int> kNimonImportSupportedSchemaVersions = {1};

/// App settings snapshot passed in by UI/providers (not read inside validator).
class NimonImportValidationContext {
  const NimonImportValidationContext({
    required this.learningLanguageCode,
    required this.contentLocaleCode,
    this.authenticatedEmail,
  });

  /// [UserPreferences.learningLanguage] wire code (e.g. `ja`).
  final String learningLanguageCode;

  /// [UserPreferences.contentLocale] wire code (`en` | `my` | `ja`).
  final String contentLocaleCode;

  /// Normalized email from authenticated session; null/empty → import blocked.
  final String? authenticatedEmail;
}

/// Validates [payload] against structure rules and [context].
NimonImportValidationResult validateNimonImportPayload(
  NimonImportRawPayload payload,
  NimonImportValidationContext context,
) {
  final blocking = <NimonImportIssue>[];
  final missingPublish = <NimonImportIssue>[];
  final warnings = <NimonImportIssue>[];

  void block(String code, String message, {String? path}) {
    blocking.add(NimonImportIssue(
      code: code,
      message: message,
      path: path,
      severity: NimonImportIssueSeverity.blocking,
    ));
  }

  void warn(String code, String message, {String? path}) {
    warnings.add(NimonImportIssue(
      code: code,
      message: message,
      path: path,
      severity: NimonImportIssueSeverity.warning,
    ));
  }

  void missingPublishReq(String code, String message, {String? path}) {
    missingPublish.add(NimonImportIssue(
      code: code,
      message: message,
      path: path,
      severity: NimonImportIssueSeverity.warning,
    ));
  }

  // --- A. Payload / root ---
  if (payload.rawJson.isEmpty) {
    block('import.payload.empty', 'Import file is empty.');
    return _finalize(blocking, missingPublish, warnings);
  }

  final meta = payload.meta;
  if (meta == null) {
    block(
      'import.meta.missing',
      'Missing required nimonImportMeta block.',
      path: 'nimonImportMeta',
    );
    return _finalize(blocking, missingPublish, warnings);
  }

  final core = payload.core;
  if (core == null) {
    block(
      'import.core.missing',
      'Missing required core section.',
      path: 'core',
    );
  }

  if (!meta.hasRecognizedImportKind) {
    block(
      'import.meta.publishKindUnsupported',
      'Unsupported or missing publishKind.',
      path: 'nimonImportMeta.publishKind',
    );
  }

  if (payload.rawJson.containsKey('sourceDraftId')) {
    final rawId = _optStr(payload.rawJson['sourceDraftId']);
    if (rawId.isEmpty) {
      block(
        'import.payload.sourceDraftIdEmpty',
        'sourceDraftId must be a non-empty string when present.',
        path: 'sourceDraftId',
      );
    }
  }

  // --- B. Meta ---
  _validateMeta(meta, block, warn);

  // --- C. App context (auth + settings) ---
  _validateAppContext(meta, context, block);

  // Stop shape validation if hard prerequisites missing.
  if (core == null || !meta.hasRecognizedImportKind) {
    return _finalize(blocking, missingPublish, warnings);
  }

  final sentences = _sentencesList(core);
  if (sentences == null) {
    block(
      'import.core.sentencesMissing',
      'core.sentences must be a list.',
      path: 'core.sentences',
    );
    return _finalize(blocking, missingPublish, warnings);
  }
  if (sentences.isEmpty) {
    block(
      'import.core.sentencesEmpty',
      'core.sentences must contain at least one sentence.',
      path: 'core.sentences',
    );
    return _finalize(blocking, missingPublish, warnings);
  }

  final usableCount = sentences.where(_sentenceHasUsableText).length;
  if (usableCount == 0) {
    block(
      'import.core.sentencesEmpty',
      'No sentence has usable text (japaneseText, text, or value).',
      path: 'core.sentences',
    );
  }

  // --- D. HTML generator limitation rules (source of truth) ---
  _validateHtmlGeneratorRules(
    payload,
    meta: meta,
    core: core,
    sentences: sentences,
    block: block,
  );

  switch (meta.importKind) {
    case NimonImportKind.readOnly:
      break;
    case NimonImportKind.fullLearn:
      _validateFullLearnShape(payload, block, missingPublishReq);
      // FullLearn-only HTML rules + rich content contract checks.
      _validateHtmlGeneratorFullLearnRules(
        payload,
        meta: meta,
        core: core,
        block: block,
      );
    case NimonImportKind.unknown:
      break;
  }

  return _finalize(blocking, missingPublish, warnings);
}

HtmlPromptMode? _promptModeFromMeta(NimonImportMeta meta) {
  return switch (meta.promptDataTab) {
    NimonPromptDataTab.manualMode => HtmlPromptMode.manual,
    NimonPromptDataTab.aiMode => HtmlPromptMode.ai,
    _ => null,
  };
}

HtmlLearningLanguage? _learningLanguageFromMeta(NimonImportMeta meta) {
  return switch (meta.learningLanguage) {
    NimonLearningLanguage.japanese => HtmlLearningLanguage.jp,
    NimonLearningLanguage.english => HtmlLearningLanguage.en,
    _ => null,
  };
}

HtmlPublishKind? _publishKindFromMeta(NimonImportMeta meta) {
  return switch (meta.importKind) {
    NimonImportKind.readOnly => HtmlPublishKind.readOnly,
    NimonImportKind.fullLearn => HtmlPublishKind.fullLearn,
    _ => null,
  };
}

String _extractSentenceJapaneseText(dynamic sentence) {
  if (sentence is! Map) return '';
  final m = Map<String, dynamic>.from(sentence.cast<String, dynamic>());
  final direct = [
    m['japaneseText'],
    m['text'],
    m['value'],
  ];
  for (final v in direct) {
    final s = _optStr(v);
    if (s.isNotEmpty) return s;
  }
  final content = m['content'];
  if (content is Map) {
    final cm = Map<String, dynamic>.from(content.cast<String, dynamic>());
    final s = _optStr(cm['japaneseText'] ?? cm['text'] ?? cm['value']);
    if (s.isNotEmpty) return s;
  }
  return '';
}

int _countHtmlCharsFromSentences(List<dynamic> sentences) {
  // Mirror the HTML: join all sentences and count characters with whitespace removed.
  var out = 0;
  for (final s in sentences) {
    final t = _extractSentenceJapaneseText(s).trim();
    if (t.isEmpty) continue;
    out += charLength(t.replaceAll(RegExp(r'\s'), ''));
  }
  return out;
}

void _validateHtmlGeneratorRules(
  NimonImportRawPayload payload, {
  required NimonImportMeta meta,
  required Map<String, dynamic> core,
  required List<dynamic> sentences,
  required void Function(String code, String message, {String? path}) block,
}) {
  final promptMode = _promptModeFromMeta(meta);
  if (promptMode == null) {
    block(
      'import.htmlRules.promptModeInvalid',
      'promptDataTab could not be normalized to Manual/AI.',
      path: 'nimonImportMeta.promptDataTab',
    );
    return;
  }

  final learningLanguage = _learningLanguageFromMeta(meta);
  if (learningLanguage == null) {
    block(
      'import.htmlRules.languageInvalid',
      'learningLanguage could not be normalized.',
      path: 'nimonImportMeta.learningLanguage',
    );
    return;
  }

  final publishKind = _publishKindFromMeta(meta);
  if (publishKind == null) {
    block(
      'import.htmlRules.publishKindInvalid',
      'publishKind could not be normalized to readOnly/fullLearn.',
      path: 'nimonImportMeta.publishKind',
    );
    return;
  }

  final rawLevel = _optStr(core['level']);
  final level = normalizeHtmlLevel(rawLevel);
  if (level == null) {
    block(
      'import.htmlRules.levelInvalid',
      'core.level could not be normalized to a supported level.',
      path: 'core.level',
    );
    return;
  }

  final rawBand = _optStr(
    core['targetDurationBandKey'] ?? core['target_duration_band_key'],
  );
  final duration = normalizeHtmlDuration(rawBand);
  if (duration == null) {
    block(
      'import.htmlRules.durationInvalid',
      'core.targetDurationBandKey could not be normalized to a supported duration band.',
      path: 'core.targetDurationBandKey',
    );
    return;
  }

  final lim = HtmlGeneratorLimits.sentenceLimit(
    mode: promptMode,
    language: learningLanguage,
    duration: duration,
    level: level,
  );
  if (lim == null) {
    block(
      'import.htmlRules.sentenceLimitMissing',
      'No sentence limitation rule found for this combination.',
      path: 'core',
    );
    return;
  }

  final sentenceCount = sentences.length;
  if (sentenceCount < lim.minSentences) {
    block(
      'import.htmlRules.storySentenceTooFew',
      'Story has too few sentences for HTML rules.',
      path: 'core.sentences',
    );
  } else if (sentenceCount > lim.maxSentences) {
    block(
      'import.htmlRules.storySentenceTooMany',
      'Story has too many sentences for HTML rules.',
      path: 'core.sentences',
    );
  }

  final charCount = _countHtmlCharsFromSentences(sentences);
  if (charCount < lim.minChars) {
    block(
      'import.htmlRules.storyCharsTooFew',
      'Story has too few characters for HTML rules.',
      path: 'core.sentences',
    );
  } else if (charCount > lim.maxChars) {
    block(
      'import.htmlRules.storyCharsTooMany',
      'Story has too many characters for HTML rules.',
      path: 'core.sentences',
    );
  }

  // ReadOnly vs FullLearn behavior:
  // - ReadOnly enforces only sentence/char limits here.
  // - FullLearn limits are enforced in _validateHtmlGeneratorFullLearnRules.
  if (publishKind == HtmlPublishKind.readOnly) return;
}

({String subtype, String answer, String target})? _parseQuizSourceNote(
    String raw) {
  final parts = raw
      .split(';')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final kv = <String, String>{};
  for (final p in parts) {
    final eq = p.indexOf('=');
    if (eq <= 0 || eq == p.length - 1) continue;
    final k = p.substring(0, eq).trim().toLowerCase();
    final v = p.substring(eq + 1).trim();
    if (k.isEmpty || v.isEmpty) continue;
    kv[k] = v;
  }
  final subtype = (kv['subtype'] ?? '').trim();
  final answer = (kv['answer'] ?? '').trim();
  final target = (kv['target'] ?? '').trim();
  if (subtype.isEmpty || answer.isEmpty || target.isEmpty) return null;
  return (subtype: subtype, answer: answer, target: target);
}

String _normalizeQuizCategory(String raw) {
  final k = raw.trim().toLowerCase();
  if (k == 'sentence') return 'sample_sentence';
  return k;
}

void _validateHtmlGeneratorFullLearnRules(
  NimonImportRawPayload payload, {
  required NimonImportMeta meta,
  required Map<String, dynamic> core,
  required void Function(String code, String message, {String? path}) block,
}) {
  final learn = payload.learn;
  if (learn == null) return; // shape validator will already block

  final promptMode = _promptModeFromMeta(meta);
  final learningLanguage = _learningLanguageFromMeta(meta);
  if (promptMode == null || learningLanguage == null) return;

  final rawLevel = _optStr(core['level']);
  final level = normalizeHtmlLevel(rawLevel);
  final rawBand = _optStr(
    core['targetDurationBandKey'] ?? core['target_duration_band_key'],
  );
  final duration = normalizeHtmlDuration(rawBand);
  if (level == null || duration == null) return;

  final vocabEntries = _entriesList(
        learn,
        moduleKeys: ['vocabularyKanji', 'vocabulary_kanji'],
      ) ??
      const [];
  final grammarEntries = _entriesList(learn, moduleKeys: ['grammar']) ?? const [];
  final quizEntries = _entriesList(learn, moduleKeys: ['quiz']) ?? const [];

  // --- Count rules ---
  if (promptMode == HtmlPromptMode.ai) {
    final selected = HtmlGeneratorLimits.selectedFullLearnLimits(
      mode: HtmlPromptMode.ai,
      language: learningLanguage,
      duration: duration,
      level: level,
      preset: HtmlLimitPreset.defaultValue,
    );
    if (selected == null) return;

    if (vocabEntries.length != selected.vocabularyCount) {
      block(
        'import.htmlRules.vocabularyCountMismatch',
        'Vocabulary count must match HTML default selected count.',
        path: 'learn.vocabularyKanji.entries',
      );
    }
    if (grammarEntries.length != selected.grammarCount) {
      block(
        'import.htmlRules.grammarCountMismatch',
        'Grammar count must match HTML default selected count.',
        path: 'learn.grammar.entries',
      );
    }
    if (quizEntries.length != selected.totalQuizCount) {
      block(
        'import.htmlRules.quizTotalMismatch',
        'Total quiz count must match HTML default selected count.',
        path: 'learn.quiz.entries',
      );
    }

    var vocabQuiz = 0;
    var grammarQuiz = 0;
    var sentenceQuiz = 0;
    for (final q in quizEntries) {
      if (q is! Map) continue;
      final m = Map<String, dynamic>.from(q.cast<String, dynamic>());
      final cat = _normalizeQuizCategory(_optStr(m['category']));
      switch (cat) {
        case 'vocabulary':
          vocabQuiz++;
        case 'grammar':
          grammarQuiz++;
        case 'sample_sentence':
          sentenceQuiz++;
      }
    }
    if (vocabQuiz != selected.vocabularyQuizCount) {
      block(
        'import.htmlRules.quizVocabularyMismatch',
        'Vocabulary quiz count must match HTML default selected count.',
        path: 'learn.quiz.entries',
      );
    }
    if (grammarQuiz != selected.grammarQuizCount) {
      block(
        'import.htmlRules.quizGrammarMismatch',
        'Grammar quiz count must match HTML default selected count.',
        path: 'learn.quiz.entries',
      );
    }
    if (sentenceQuiz != selected.sentenceQuizCount) {
      block(
        'import.htmlRules.quizSentenceMismatch',
        'Sentence quiz count must match HTML default selected count.',
        path: 'learn.quiz.entries',
      );
    }
  } else {
    final vocabLim = HtmlGeneratorLimits.vocabularyLimit(
      language: learningLanguage,
      duration: duration,
      level: level,
    );
    final grammarLim = HtmlGeneratorLimits.grammarLimit(
      language: learningLanguage,
      duration: duration,
      level: level,
    );
    if (vocabLim != null &&
        (vocabEntries.length < vocabLim.manualMin ||
            vocabEntries.length > vocabLim.manualMax)) {
      block(
        'import.htmlRules.vocabularyCountMismatch',
        'Vocabulary count must be within HTML manual range.',
        path: 'learn.vocabularyKanji.entries',
      );
    }
    if (grammarLim != null &&
        (grammarEntries.length < grammarLim.manualMin ||
            grammarEntries.length > grammarLim.manualMax)) {
      block(
        'import.htmlRules.grammarCountMismatch',
        'Grammar count must be within HTML manual range.',
        path: 'learn.grammar.entries',
      );
    }

    // Manual quiz ranges: per-category + total.
    final totalLim = HtmlGeneratorLimits.quizLimit(
      duration: duration,
      level: level,
      quizCategory: 'Total Quiz',
    );
    if (totalLim != null &&
        (quizEntries.length < totalLim.manualMin ||
            quizEntries.length > totalLim.manualMax)) {
      block(
        'import.htmlRules.quizTotalMismatch',
        'Total quiz count must be within HTML manual range.',
        path: 'learn.quiz.entries',
      );
    }

    Map<String, int> countsByCat = {
      'vocabulary': 0,
      'grammar': 0,
      'sample_sentence': 0,
    };
    for (final q in quizEntries) {
      if (q is! Map) continue;
      final m = Map<String, dynamic>.from(q.cast<String, dynamic>());
      final cat = _normalizeQuizCategory(_optStr(m['category']));
      if (countsByCat.containsKey(cat)) countsByCat[cat] = countsByCat[cat]! + 1;
    }

    void checkCat(String catKey, String quizCategory, String code) {
      final lim = HtmlGeneratorLimits.quizLimit(
        duration: duration,
        level: level,
        quizCategory: quizCategory,
      );
      if (lim == null) return;
      final n = countsByCat[catKey] ?? 0;
      if (n < lim.manualMin || n > lim.manualMax) {
        block(
          code,
          'Quiz category count must be within HTML manual range.',
          path: 'learn.quiz.entries',
        );
      }
    }

    checkCat('vocabulary', 'Vocabulary Quiz', 'import.htmlRules.quizVocabularyMismatch');
    checkCat('grammar', 'Grammar Quiz', 'import.htmlRules.quizGrammarMismatch');
    checkCat('sample_sentence', 'Sentence Quiz', 'import.htmlRules.quizSentenceMismatch');
  }

  // --- Rich learning data contract (blocking) ---
  for (var i = 0; i < vocabEntries.length; i++) {
    if (vocabEntries[i] is! Map) continue;
    final e = Map<String, dynamic>.from((vocabEntries[i] as Map).cast<String, dynamic>());
    final term = _optStr(e['termJapanese']);
    final glosses = e['glosses'];
    final examplePairs = e['examplePairs'];
    final exampleSentence = _optStr(e['exampleSentence']);
    final exampleMeanings = e['exampleMeanings'];

    final pathBase = 'learn.vocabularyKanji.entries[$i]';
    if (term.isEmpty || glosses is! Map) {
      block('import.htmlRules.vocabExampleMissing', 'Vocabulary entry is missing required fields.', path: pathBase);
      continue;
    }
    if (examplePairs is! List || examplePairs.isEmpty) {
      block('import.htmlRules.vocabExampleMissing', 'Vocabulary entry must include examplePairs.', path: '$pathBase.examplePairs');
    }
    if (exampleSentence.isEmpty) {
      block('import.htmlRules.vocabExampleMissing', 'Vocabulary entry must include exampleSentence.', path: '$pathBase.exampleSentence');
    }
    if (exampleMeanings is! Map) {
      block('import.htmlRules.vocabExampleMissing', 'Vocabulary entry must include exampleMeanings.', path: '$pathBase.exampleMeanings');
    }
    if (examplePairs is List && examplePairs.isNotEmpty) {
      final first = examplePairs.first;
      if (first is Map) {
        final fm = Map<String, dynamic>.from(first.cast<String, dynamic>());
        final jp = _optStr(
          fm['japanese'] ?? fm['source'] ?? fm['sourceExample'] ?? fm['japaneseText'] ?? fm['jp'],
        );
        if (jp.isNotEmpty && exampleSentence.isNotEmpty && jp != exampleSentence) {
          block(
            'import.htmlRules.vocabExampleMissing',
            'exampleSentence must match examplePairs[0] Japanese text.',
            path: '$pathBase.exampleSentence',
          );
        }
      }
    }
  }

  for (var i = 0; i < grammarEntries.length; i++) {
    if (grammarEntries[i] is! Map) continue;
    final e = Map<String, dynamic>.from((grammarEntries[i] as Map).cast<String, dynamic>());
    final headline = _optStr(e['headline'] ?? e['title']);
    final form = _optStr(e['form']);
    final meanings = e['meanings'];
    final usage = e['usage'];
    final examples = e['examples'];
    final relatedNote = e['relatedNote'] ?? e['related_note'];
    final mistakeWrong = _optStr(e['mistakeWrong'] ?? e['mistake_wrong']);
    final mistakeCorrect = _optStr(e['mistakeCorrect'] ?? e['mistake_correct']);

    final pathBase = 'learn.grammar.entries[$i]';
    if (headline.isEmpty ||
        form.isEmpty ||
        meanings is! Map ||
        usage is! Map ||
        examples is! List ||
        examples.isEmpty ||
        relatedNote == null ||
        mistakeWrong.isEmpty ||
        mistakeCorrect.isEmpty ||
        mistakeWrong == mistakeCorrect) {
      block(
        'import.htmlRules.grammarMistakeMissing',
        'Grammar entry is missing required fields (headline/form/meaning/usage/examples/relatedNote/mistakes).',
        path: pathBase,
      );
    }
  }

  for (var i = 0; i < quizEntries.length; i++) {
    if (quizEntries[i] is! Map) continue;
    final e = Map<String, dynamic>.from((quizEntries[i] as Map).cast<String, dynamic>());
    final prompt = _optStr(e['prompt']);
    final optionsRaw = e['options'];
    final correctIndexRaw = e['correctIndex'];
    final sourceNote = _optStr(e['sourceNote'] ?? e['source_note']);

    final pathBase = 'learn.quiz.entries[$i]';
    if (prompt.isEmpty) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz prompt must be non-empty.', path: '$pathBase.prompt');
      continue;
    }
    if (optionsRaw is! List || optionsRaw.length != 4) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz options must contain exactly 4 items.', path: '$pathBase.options');
      continue;
    }
    final options = [for (final o in optionsRaw) _optStr(o)];
    if (options.any((o) => o.isEmpty)) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz options must be non-empty strings.', path: '$pathBase.options');
    }
    final norm = options.map((o) => o.trim().toLowerCase()).toList();
    if (norm.toSet().length != norm.length) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz options must be unique.', path: '$pathBase.options');
    }

    final int? correctIndex = switch (correctIndexRaw) {
      int v => v,
      num v when v == v.roundToDouble() => v.toInt(),
      _ => null,
    };
    if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz correctIndex must be 0..3.', path: '$pathBase.correctIndex');
      continue;
    }

    if (sourceNote.isEmpty) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz sourceNote is required.', path: '$pathBase.sourceNote');
      continue;
    }
    final parsed = _parseQuizSourceNote(sourceNote);
    if (parsed == null) {
      block('import.htmlRules.quizSourceNoteInvalid', 'Quiz sourceNote format is invalid.', path: '$pathBase.sourceNote');
      continue;
    }
    final chosen = options[correctIndex].trim();
    if (chosen != parsed.answer.trim()) {
      block(
        'import.htmlRules.quizSourceNoteInvalid',
        'Quiz answer does not match sourceNote answer.',
        path: '$pathBase.sourceNote',
      );
    }
  }
}

void _validateMeta(
  NimonImportMeta meta,
  void Function(String code, String message, {String? path}) block,
  void Function(String code, String message, {String? path}) warn,
) {
  final schema = meta.schemaVersion;
  if (schema == null || !kNimonImportSupportedSchemaVersions.contains(schema)) {
    block(
      'import.meta.schemaVersionUnsupported',
      'Unsupported or missing schemaVersion (expected 1).',
      path: 'nimonImportMeta.schemaVersion',
    );
  }

  if ((meta.generatorVersion ?? '').trim().isEmpty) {
    warn(
      'import.meta.generatorVersionMissing',
      'generatorVersion is missing.',
      path: 'nimonImportMeta.generatorVersion',
    );
  }

  if (meta.promptDataTab == NimonPromptDataTab.unknown) {
    block(
      'import.meta.promptDataTabUnsupported',
      'promptDataTab must be Manual_mode or AI_mode.',
      path: 'nimonImportMeta.promptDataTab',
    );
  }

  if (meta.learningLanguage == NimonLearningLanguage.unknown) {
    block(
      'import.meta.learningLanguageUnsupported',
      'learningLanguage is missing or not recognized.',
      path: 'nimonImportMeta.learningLanguage',
    );
  }

  if (meta.contentCommunity == NimonContentCommunity.unknown) {
    block(
      'import.meta.contentCommunityUnsupported',
      'contentCommunity is missing or not recognized.',
      path: 'nimonImportMeta.contentCommunity',
    );
  }

  if (!meta.hasCreatedForEmail) {
    block(
      'import.meta.createdForEmailMissing',
      'createdForEmail is required in import metadata.',
      path: 'nimonImportMeta.createdForEmail',
    );
  }
}

void _validateAppContext(
  NimonImportMeta meta,
  NimonImportValidationContext context,
  void Function(String code, String message, {String? path}) block,
) {
  final authEmail = normalizeEmailInput(context.authenticatedEmail);
  if (authEmail.isEmpty) {
    block(
      'import.auth.emailRequired',
      'Please sign in with an email account before importing JSON.',
      path: 'auth',
    );
    return;
  }

  final createdFor = normalizeEmailInput(meta.createdForEmail);
  if (createdFor.isEmpty) {
    // Covered by meta.createdForEmailMissing; skip duplicate.
    return;
  }

  if (createdFor != authEmail) {
    block(
      'import.auth.emailMismatch',
      'Import createdForEmail does not match the signed-in account.',
      path: 'nimonImportMeta.createdForEmail',
    );
  }

  final expectedLearning = context.learningLanguageCode.trim().toLowerCase();
  final metaLearning = meta.learningLanguage.preferencesWireCode;
  if (metaLearning != null &&
      meta.learningLanguage != NimonLearningLanguage.unknown &&
      metaLearning != expectedLearning) {
    block(
      'import.context.learningLanguageMismatch',
      'Import learningLanguage does not match your app learning language setting.',
      path: 'nimonImportMeta.learningLanguage',
    );
  }

  final expectedWire = normalizeContentLocaleWireCode(context.contentLocaleCode);
  final importRaw = meta.contentCommunityRaw ?? meta.contentCommunity.debugLabel;
  if (meta.contentCommunity != NimonContentCommunity.unknown &&
      expectedWire != null &&
      !contentCommunityMatchesPreference(
        preferenceContentLocale: expectedWire,
        importContentCommunityRaw: importRaw,
      )) {
    block(
      'import.context.contentCommunityMismatch',
      'Import contentCommunity does not match your Content Community setting.',
      path: 'nimonImportMeta.contentCommunity',
    );
  }

  final communityWire = meta.contentCommunity.contentLocaleWireCode;
  final learningWire = meta.learningLanguage.preferencesWireCode;
  if (communityWire != null &&
      learningWire != null &&
      isSameLanguagePair(
        contentLocale: communityWire,
        learningLanguage: learningWire,
      )) {
    block(
      'import.context.languagePairSameNotAllowed',
      'Import content community and learning language must be different.',
      path: 'nimonImportMeta',
    );
  }
}

void _validateFullLearnShape(
  NimonImportRawPayload payload,
  void Function(String code, String message, {String? path}) block,
  void Function(String code, String message, {String? path}) missingPublishReq,
) {
  final learn = payload.learn;
  if (learn == null) {
    block(
      'import.learn.missing',
      'Full Learn import requires a learn section.',
      path: 'learn',
    );
    return;
  }

  _requireNonEmptyEntriesList(
    learn,
    keys: ['vocabularyKanji', 'vocabulary_kanji'],
    entriesPath: 'learn.vocabularyKanji.entries',
    missingCode: 'import.learn.vocabularyMissing',
    missingMessage: 'learn.vocabularyKanji.entries must be a non-empty list.',
    block: block,
  );

  _requireNonEmptyEntriesList(
    learn,
    keys: ['grammar'],
    entriesPath: 'learn.grammar.entries',
    missingCode: 'import.learn.grammarMissing',
    missingMessage: 'learn.grammar.entries must be a non-empty list.',
    block: block,
  );

  final quizEntries = _entriesList(learn, moduleKeys: ['quiz']);
  if (quizEntries == null) {
    block(
      'import.learn.quizMissing',
      'learn.quiz.entries must be a list.',
      path: 'learn.quiz.entries',
    );
  } else if (quizEntries.isEmpty) {
    block(
      'import.learn.quizMissing',
      'learn.quiz.entries must be a non-empty list.',
      path: 'learn.quiz.entries',
    );
  } else {
    _validateQuizEntries(quizEntries, block);
  }

  _validateFullLearnAudio(learn, missingPublishReq);
}

void _requireNonEmptyEntriesList(
  Map<String, dynamic> learn, {
  required List<String> keys,
  required String entriesPath,
  required String missingCode,
  required String missingMessage,
  required void Function(String code, String message, {String? path}) block,
}) {
  final entries = _entriesList(learn, moduleKeys: keys);
  if (entries == null || entries.isEmpty) {
    block(missingCode, missingMessage, path: entriesPath);
  }
}

void _validateQuizEntries(
  List<dynamic> entries,
  void Function(String code, String message, {String? path}) block,
) {
  for (var i = 0; i < entries.length; i++) {
    final path = 'learn.quiz.entries[$i]';
    if (entries[i] is! Map) {
      block(
        'import.quiz.invalidOptions',
        'Quiz entry must be an object.',
        path: path,
      );
      continue;
    }
    final m = Map<String, dynamic>.from(
      (entries[i] as Map).cast<String, dynamic>(),
    );
    final prompt = _optStr(m['prompt']);
    if (prompt.isEmpty) {
      block(
        'import.quiz.invalidOptions',
        'Quiz prompt must be non-empty.',
        path: '$path.prompt',
      );
    }

    final optionsRaw = m['options'];
    if (optionsRaw is! List) {
      block(
        'import.quiz.invalidOptions',
        'Quiz options must be a list of exactly 4 non-empty strings.',
        path: '$path.options',
      );
      continue;
    }

    if (optionsRaw.length != 4) {
      block(
        'import.quiz.invalidOptions',
        'Quiz options must contain exactly 4 items.',
        path: '$path.options',
      );
      continue;
    }

    for (var oi = 0; oi < optionsRaw.length; oi++) {
      if (_optStr(optionsRaw[oi]).isEmpty) {
        block(
          'import.quiz.invalidOptions',
          'Quiz option ${oi + 1} must be non-empty.',
          path: '$path.options[$oi]',
        );
      }
    }

    final correctIndexRaw = m['correctIndex'];
    final int? correctIndex = switch (correctIndexRaw) {
      int v => v,
      num v when v == v.roundToDouble() => v.toInt(),
      _ => null,
    };
    if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
      block(
        'import.quiz.invalidCorrectIndex',
        'Quiz correctIndex must be an integer from 0 to 3.',
        path: '$path.correctIndex',
      );
    }
  }
}

void _validateFullLearnAudio(
  Map<String, dynamic> learn,
  void Function(String code, String message, {String? path}) missingPublishReq,
) {
  final audioRoot = _nestedMap(learn, ['audio']);
  if (audioRoot == null) {
    missingPublishReq(
      'import.fullLearn.audioRequired',
      'Audio upload is required before Full Learn publish.',
      path: 'learn.audio.storyAudio',
    );
    return;
  }

  final storyAudio = _nestedMap(audioRoot, ['storyAudio', 'story_audio']);
  if (storyAudio == null) {
    missingPublishReq(
      'import.fullLearn.audioRequired',
      'Audio upload is required before Full Learn publish.',
      path: 'learn.audio.storyAudio',
    );
    return;
  }

  final sourceUrl = _optStr(storyAudio['sourceUrl'] ?? storyAudio['source_url']);
  final localPath =
      _optStr(storyAudio['localPath'] ?? storyAudio['local_path']);

  if (sourceUrl.isEmpty && localPath.isEmpty) {
    missingPublishReq(
      'import.fullLearn.audioRequired',
      'Audio upload is required before Full Learn publish.',
      path: 'learn.audio.storyAudio.sourceUrl',
    );
  }
}

NimonImportValidationResult _finalize(
  List<NimonImportIssue> blocking,
  List<NimonImportIssue> missingPublish,
  List<NimonImportIssue> warnings,
) {
  if (blocking.isNotEmpty) {
    return NimonImportValidationResult(
      canImport: false,
      canPublishImmediately: false,
      blockingErrors: List.unmodifiable(blocking),
      missingPublishRequirements: List.unmodifiable(missingPublish),
      warnings: List.unmodifiable(warnings),
    );
  }
  if (missingPublish.isNotEmpty) {
    return NimonImportValidationResult.importPreviewOnly(
      missingPublishRequirements: List.unmodifiable(missingPublish),
      warnings: List.unmodifiable(warnings),
    );
  }
  return NimonImportValidationResult.importAndPublishReady(
    warnings: List.unmodifiable(warnings),
  );
}

List<dynamic>? _sentencesList(Map<String, dynamic> core) {
  final raw = core['sentences'];
  if (raw is! List) return null;
  return raw;
}

bool _sentenceHasUsableText(dynamic sentence) {
  if (sentence is! Map) return false;
  final m = Map<String, dynamic>.from(sentence.cast<String, dynamic>());

  final direct = [
    m['japaneseText'],
    m['text'],
    m['value'],
  ];
  for (final v in direct) {
    if (_optStr(v).isNotEmpty) return true;
  }

  final content = m['content'];
  if (content is Map) {
    final cm = Map<String, dynamic>.from(content.cast<String, dynamic>());
    if (_optStr(cm['japaneseText']).isNotEmpty) return true;
  }

  return false;
}

List<dynamic>? _entriesList(
  Map<String, dynamic> learn, {
  required List<String> moduleKeys,
}) {
  for (final key in moduleKeys) {
    final module = _nestedMap(learn, [key]);
    if (module == null) continue;
    final entries = module['entries'];
    if (entries is List) return entries;
  }
  return null;
}

Map<String, dynamic>? _nestedMap(
  Map<String, dynamic> root,
  List<String> keys,
) {
  for (final key in keys) {
    final v = root[key];
    if (v is Map) {
      return Map<String, dynamic>.from(v.cast<String, dynamic>());
    }
  }
  return null;
}

String _optStr(Object? v) {
  if (v == null) return '';
  return v.toString().trim();
}
