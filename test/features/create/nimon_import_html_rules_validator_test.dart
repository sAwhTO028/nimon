import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';

void main() {
  const jaMyContext = NimonImportValidationContext(
    learningLanguageCode: 'ja',
    contentLocaleCode: 'my',
    authenticatedEmail: 'user@example.com',
  );

  NimonImportValidationResult validate(Map<String, Object?> json) {
    final payload = NimonImportRawPayload.fromJsonMap(json);
    return validateNimonImportPayload(payload, jaMyContext);
  }

  Map<String, Object?> meta({
    String learningLanguage = 'Japanese',
    String contentCommunity = 'Burmese',
    String publishKind = 'full_learn_v1',
    String createdForEmail = 'user@example.com',
    String promptDataTab = 'AI_mode',
    int schemaVersion = 1,
    String generatorVersion = 'Json_Generator_ImportReadyPrompt_v7',
  }) {
    return {
      'schemaVersion': schemaVersion,
      'generatorVersion': generatorVersion,
      'learningLanguage': learningLanguage,
      'contentCommunity': contentCommunity,
      'promptDataTab': promptDataTab,
      'publishKind': publishKind,
      'createdForEmail': createdForEmail,
    };
  }

  List<Map<String, Object?>> storySentences({
    int count = 42,
    int charsPerSentence = 18,
  }) {
    final t = 'あ' * charsPerSentence;
    return List.generate(
      count,
      (i) => {
        'order': i + 1,
        'content': {
          'japaneseText': t,
          'meanings': {
            'en': 'x',
            'my': 'x',
            'byLanguage': <String, Object?>{},
          },
          'furiganaSpans': <Object>[],
        },
      },
    );
  }

  Map<String, Object?> core({
    String level = 'N4',
    String targetDurationBandKey = '5_7',
    List<Map<String, Object?>>? sentences,
  }) {
    return {
      'title': 'Imported Story',
      'category': 'Daily Life',
      'level': level,
      'description': 'desc',
      'targetDurationBandKey': targetDurationBandKey,
      'sentences': sentences ?? storySentences(),
    };
  }

  Map<String, Object?> vocabEntry(int i) {
    return {
      'id': 'vocab-$i',
      'type': 'vocabulary',
      'termJapanese': 'たんご$i',
      'glosses': {
        'en': 'g$i',
        'my': 'g$i',
        'byLanguage': <String, Object?>{},
      },
      'examplePairs': [
        {
          'japanese': 'れいぶん$i',
          'meanings': {
            'en': 'ex$i',
            'my': 'ex$i',
            'byLanguage': <String, Object?>{},
          },
        },
      ],
      'exampleSentence': 'れいぶん$i',
      'exampleMeanings': {
        'en': 'ex$i',
        'my': 'ex$i',
        'byLanguage': <String, Object?>{},
      },
    };
  }

  Map<String, Object?> grammarEntry(int i) {
    return {
      'id': 'grammar-$i',
      'headline': 'ぶんぽう$i',
      'form': 'form$i',
      'meanings': {
        'en': 'm$i',
        'my': 'm$i',
        'byLanguage': <String, Object?>{},
      },
      'usage': {
        'en': 'u$i',
        'my': 'u$i',
        'byLanguage': <String, Object?>{},
      },
      'examples': [
        {
          'japanese': 'れいぶん$i',
          'meanings': {
            'en': 'ex$i',
            'my': 'ex$i',
            'byLanguage': <String, Object?>{},
          },
        },
      ],
      'relatedNote': {
        'en': 'n$i',
        'my': 'n$i',
        'byLanguage': <String, Object?>{},
      },
      'mistakeWrong': 'wrong$i',
      'mistakeCorrect': 'correct$i',
    };
  }

  Map<String, Object?> quizEntry({
    required String id,
    required String category,
    required String answer,
    required int correctIndex,
  }) {
    final options = ['A$id', 'B$id', 'C$id', 'D$id'];
    options[correctIndex] = answer;
    return {
      'id': id,
      'category': category,
      'prompt': 'Q$id',
      'options': options,
      'correctIndex': correctIndex,
      'sourceNote': 'subtype=mcq;answer=$answer;target=T$id',
    };
  }

  Map<String, Object?> learnAiN4_5_7_default({
    int vocabCount = 16,
    int grammarCount = 6,
    int vocabQuiz = 11,
    int grammarQuiz = 5,
    int sentenceQuiz = 4,
    bool withAudioUrl = false,
  }) {
    final quiz = <Map<String, Object?>>[
      for (var i = 0; i < vocabQuiz; i++)
        quizEntry(
          id: 'v$i',
          category: 'vocabulary',
          answer: 'AnsV$i',
          correctIndex: 0,
        ),
      for (var i = 0; i < grammarQuiz; i++)
        quizEntry(
          id: 'g$i',
          category: 'grammar',
          answer: 'AnsG$i',
          correctIndex: 1,
        ),
      for (var i = 0; i < sentenceQuiz; i++)
        quizEntry(
          id: 's$i',
          category: 'sample_sentence',
          answer: 'AnsS$i',
          correctIndex: 2,
        ),
      // HTML config expects totalQuizCount=21 while (vocab+grammar+sentence)=20 for this combo.
      // The generator includes one extra quiz entry that is not counted in the category-specific totals.
      quizEntry(
        id: 'k0',
        category: 'kanji',
        answer: 'AnsK0',
        correctIndex: 3,
      ),
    ];

    final audio = withAudioUrl
        ? <String, Object?>{
            'storyAudio': {'sourceUrl': 'https://cdn.example.com/story.mp3'},
          }
        : <String, Object?>{
            'storyAudio': <String, Object?>{},
          };

    return {
      'vocabularyKanji': {
        'entries': [for (var i = 0; i < vocabCount; i++) vocabEntry(i)],
      },
      'grammar': {
        'entries': [for (var i = 0; i < grammarCount; i++) grammarEntry(i)],
      },
      'quiz': {'entries': quiz},
      'audio': audio,
    };
  }

  Map<String, Object?> fullLearnAiPayload({
    Map<String, Object?>? metaOverride,
    Map<String, Object?>? coreOverride,
    Map<String, Object?>? learnOverride,
  }) {
    return {
      'nimonImportMeta': metaOverride ?? meta(),
      'core': coreOverride ?? core(),
      'learn': learnOverride ?? learnAiN4_5_7_default(),
    };
  }

  group('HTML generator rule enforcement (import validator)', () {
    test('A. valid AI FullLearn JP N4 5_7 default passes (audio null => preview-only)', () {
      final r = validate(fullLearnAiPayload());
      expect(
        r.canImport,
        isTrue,
        reason: '${r.toString()} blocking=${r.blockingErrors} missing=${r.missingPublishRequirements}',
      );
      expect(r.canPublishImmediately, isFalse);
      expect(r.blockingErrors, isEmpty, reason: r.toString());
      expect(
        r.missingPublishRequirements.map((e) => e.code),
        contains('import.fullLearn.audioRequired'),
      );
    });

    test('B. too few story sentences blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          coreOverride: core(sentences: storySentences(count: 41)),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.storySentenceTooFew'),
      );
    });

    test('C. too many story sentences blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          coreOverride: core(sentences: storySentences(count: 61)),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.storySentenceTooMany'),
      );
    });

    test('D. too few Japanese chars blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          coreOverride: core(sentences: storySentences(count: 42, charsPerSentence: 17)),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.storyCharsTooFew'),
      );
    });

    test('E. too many Japanese chars blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          coreOverride: core(sentences: storySentences(count: 42, charsPerSentence: 27)),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.storyCharsTooMany'),
      );
    });

    test('F. FullLearn AI vocab count mismatch blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          learnOverride: learnAiN4_5_7_default(vocabCount: 15),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.vocabularyCountMismatch'),
      );
    });

    test('G. FullLearn AI grammar count mismatch blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          learnOverride: learnAiN4_5_7_default(grammarCount: 5),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.grammarCountMismatch'),
      );
    });

    test('H. FullLearn AI quiz distribution mismatch blocks import', () {
      final r = validate(
        fullLearnAiPayload(
          learnOverride: learnAiN4_5_7_default(vocabQuiz: 10, grammarQuiz: 5, sentenceQuiz: 6),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.quizVocabularyMismatch'),
      );
    });

    test('I. ReadOnly enforces story sentence/char only (no learn required)', () {
      final json = {
        'nimonImportMeta': meta(publishKind: 'read_only_v1'),
        'core': core(),
      };
      final r = validate(json);
      expect(r.canImport, isTrue, reason: r.toString());
      expect(r.canPublishImmediately, isTrue);
      expect(r.blockingErrors, isEmpty);
    });

    test('J. English learning still blocked', () {
      final r = validate(
        fullLearnAiPayload(
          metaOverride: meta(learningLanguage: 'English'),
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.context.englishComingSoon'),
      );
    });

    test('K. missing vocabulary exampleSentence/exampleMeanings blocks import', () {
      final learn = learnAiN4_5_7_default();
      final vocab = (learn['vocabularyKanji'] as Map)['entries'] as List;
      final first = Map<String, Object?>.from((vocab.first as Map).cast<String, Object?>());
      first['exampleSentence'] = '';
      first['exampleMeanings'] = null;
      vocab[0] = first;

      final r = validate(
        fullLearnAiPayload(learnOverride: learn),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.vocabExampleMissing'),
      );
    });

    test('L. missing grammar relatedNote/mistakes blocks import', () {
      final learn = learnAiN4_5_7_default();
      final grammar = (learn['grammar'] as Map)['entries'] as List;
      final first = Map<String, Object?>.from((grammar.first as Map).cast<String, Object?>());
      first['relatedNote'] = null;
      first['mistakeWrong'] = '';
      first['mistakeCorrect'] = '';
      grammar[0] = first;

      final r = validate(
        fullLearnAiPayload(learnOverride: learn),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.grammarMistakeMissing'),
      );
    });

    test('M. invalid quiz sourceNote answer mismatch blocks import', () {
      final learn = learnAiN4_5_7_default();
      final quiz = (learn['quiz'] as Map)['entries'] as List;
      final first = Map<String, Object?>.from((quiz.first as Map).cast<String, Object?>());
      // correctIndex=0 but answer points to a different option
      first['sourceNote'] = 'subtype=mcq;answer=NOT_THE_OPTION;target=T';
      quiz[0] = first;

      final r = validate(
        fullLearnAiPayload(learnOverride: learn),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.htmlRules.quizSourceNoteInvalid'),
      );
    });
  });
}

