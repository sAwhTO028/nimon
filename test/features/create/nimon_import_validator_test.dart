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

  List<Map<String, Object?>> sentences({
    int count = 24,
    int charsPerSentence = 15,
  }) {
    final t = 'あ' * charsPerSentence;
    return List.generate(
      count,
      (i) => {
        'order': i + 1,
        'content': {'japaneseText': t},
      },
    );
  }

  Map<String, Object?> meta({
    String learningLanguage = 'Japanese',
    String contentCommunity = 'Myanmar',
    String publishKind = 'read_only_v1',
    String createdForEmail = 'user@example.com',
    String promptDataTab = 'AI_mode',
    int schemaVersion = 1,
    String? generatorVersion = 'CSV_Generator_V1',
  }) {
    return {
      'schemaVersion': schemaVersion,
      if (generatorVersion != null) 'generatorVersion': generatorVersion,
      'learningLanguage': learningLanguage,
      'contentCommunity': contentCommunity,
      'promptDataTab': promptDataTab,
      'publishKind': publishKind,
      'createdForEmail': createdForEmail,
    };
  }

  Map<String, Object?> coreWithSentences({
    String level = 'N5',
    String targetDurationBandKey = '3_5',
    List<Map<String, Object?>>? sentencesList,
  }) {
    return {
      'level': level,
      'targetDurationBandKey': targetDurationBandKey,
      'sentences': sentencesList ?? sentences(),
    };
  }

  Map<String, Object?> fullLearnLearn({
    bool withAudioUrl = false,
    List<Map<String, Object?>>? quizEntries,
  }) {
    // N5 + 3-5 mins + AI(default) contract (from HTML rules):
    // vocab=8, grammar=3, quiz total=11 (vocab=5, grammar=3, sentence=3)
    final quiz = quizEntries ?? [
      for (var i = 0; i < 5; i++)
        {
          'id': 'quiz-v-$i',
          'category': 'vocabulary',
          'prompt': 'Qv$i',
          'options': ['A$i', 'B$i', 'C$i', 'D$i'],
          'correctIndex': 0,
          'sourceNote': 'subtype=meaning_question;answer=A$i;target=T$i',
        },
      for (var i = 0; i < 3; i++)
        {
          'id': 'quiz-g-$i',
          'category': 'grammar',
          'prompt': 'Qg$i',
          'options': ['A$i', 'B$i', 'C$i', 'D$i'],
          'correctIndex': 1,
          'sourceNote': 'subtype=form_question;answer=B$i;target=T$i',
        },
      for (var i = 0; i < 3; i++)
        {
          'id': 'quiz-s-$i',
          'category': 'sample_sentence',
          'prompt': 'Qs$i',
          'options': ['A$i', 'B$i', 'C$i', 'D$i'],
          'correctIndex': 2,
          'sourceNote': 'subtype=sentence_question;answer=C$i;target=T$i',
        },
    ];
    final storyAudio = withAudioUrl
        ? <String, Object?>{
            'sourceUrl': 'https://cdn.example.com/story.mp3',
          }
        : <String, Object?>{};
    return {
      'vocabularyKanji': {
        'entries': [
          for (var i = 0; i < 8; i++)
            {
              'id': 'vocab-$i',
              'type': 'vocabulary',
              'termJapanese': 'みず$i',
              'glosses': {'en': 'water$i', 'my': 'ရေ$i', 'byLanguage': <String, Object?>{}},
              'examplePairs': [
                {
                  'japanese': 'れいぶん$i',
                  'meanings': {'en': 'ex$i', 'my': 'ex$i', 'byLanguage': <String, Object?>{}},
                },
              ],
              'exampleSentence': 'れいぶん$i',
              'exampleMeanings': {'en': 'ex$i', 'my': 'ex$i', 'byLanguage': <String, Object?>{}},
            },
        ],
      },
      'grammar': {
        'entries': [
          for (var i = 0; i < 3; i++)
            {
              'id': 'grammar-$i',
              'headline': '〜ます$i',
              'form': 'verbます$i',
              'meanings': {'en': 'm$i', 'my': 'm$i', 'byLanguage': <String, Object?>{}},
              'usage': {'en': 'u$i', 'my': 'u$i', 'byLanguage': <String, Object?>{}},
              'examples': [
                {
                  'japanese': 'れいぶん$i',
                  'meanings': {'en': 'ex$i', 'my': 'ex$i', 'byLanguage': <String, Object?>{}},
                },
              ],
              'relatedNote': {'en': 'n$i', 'my': 'n$i', 'byLanguage': <String, Object?>{}},
              'mistakeWrong': 'まちがい$i',
              'mistakeCorrect': 'せいかい$i',
            },
        ],
      },
      'quiz': {'entries': quiz},
      'audio': {'storyAudio': storyAudio},
    };
  }

  group('validateNimonImportPayload', () {
    test('valid ReadOnly Japanese/Burmese with matching email', () {
      final r = validate({
        'nimonImportMeta': meta(),
        'core': coreWithSentences(),
      });
      expect(r.canImport, isTrue);
      expect(r.canPublishImmediately, isTrue);
      expect(r.blockingErrors, isEmpty);
      expect(r.missingPublishRequirements, isEmpty);
    });

    test('valid ReadOnly Japanese/Myanmar legacy alias Burmese with matching email', () {
      final r = validate({
        'nimonImportMeta': meta(contentCommunity: 'Burmese'),
        'core': coreWithSentences(),
      });
      expect(r.canImport, isTrue);
      expect(r.blockingErrors, isEmpty);
    });

    test('missing meta blocks import', () {
      final r = validate({
        'core': coreWithSentences(),
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.meta.missing'),
      );
    });

    test('English learning is blocked with englishComingSoon', () {
      final r = validate({
        'nimonImportMeta': meta(learningLanguage: 'English'),
        'core': coreWithSentences(),
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.context.englishComingSoon'),
      );
    });

    test('contentCommunity mismatch blocks import', () {
      final r = validate({
        'nimonImportMeta': meta(contentCommunity: 'Japanese'),
        'core': coreWithSentences(),
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.context.contentCommunityMismatch'),
      );
    });

    test('email mismatch blocks import', () {
      final r = validate({
        'nimonImportMeta': meta(createdForEmail: 'other@example.com'),
        'core': coreWithSentences(),
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.auth.emailMismatch'),
      );
    });

    test('no authenticated email blocks import', () {
      final payload = NimonImportRawPayload.fromJsonMap({
        'nimonImportMeta': meta(),
        'core': coreWithSentences(),
      });
      final r = validateNimonImportPayload(
        payload,
        const NimonImportValidationContext(
          learningLanguageCode: 'ja',
          contentLocaleCode: 'my',
        ),
      );
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.auth.emailRequired'),
      );
    });

    test('valid FullLearn with null audio is preview-only', () {
      final r = validate({
        'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
        'core': coreWithSentences(),
        'learn': fullLearnLearn(),
      });
      expect(r.canImport, isTrue);
      expect(r.canPublishImmediately, isFalse);
      expect(
        r.missingPublishRequirements.map((e) => e.code),
        contains('import.fullLearn.audioRequired'),
      );
    });

    test('FullLearn missing quiz entries blocks import', () {
      final learn = fullLearnLearn();
      learn['quiz'] = {'entries': <Object?>[]};
      final r = validate({
        'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
        'core': coreWithSentences(),
        'learn': learn,
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.learn.quizMissing'),
      );
    });

    test('FullLearn quiz with wrong options length blocks import', () {
      final r = validate({
        'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
        'core': coreWithSentences(),
        'learn': fullLearnLearn(
          quizEntries: [
            {
              'prompt': 'Q',
              'options': ['A', 'B', 'C'],
              'correctIndex': 0,
              'sourceNote': 'subtype=meaning_question;answer=A;target=T',
            },
          ],
        ),
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.quiz.invalidOptions'),
      );
    });

    test('unknown promptDataTab blocks import', () {
      final r = validate({
        'nimonImportMeta': meta(promptDataTab: 'Experimental_mode'),
        'core': coreWithSentences(),
      });
      expect(r.canImport, isFalse);
      expect(
        r.blockingErrors.map((e) => e.code),
        contains('import.meta.promptDataTabUnsupported'),
      );
    });

    test('FullLearn with audio URL can import and publish immediately', () {
      final r = validate({
        'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
        'core': coreWithSentences(),
        'learn': fullLearnLearn(withAudioUrl: true),
      });
      expect(r.canImport, isTrue);
      expect(r.canPublishImmediately, isTrue);
      expect(r.missingPublishRequirements, isEmpty);
    });
  });
}
