import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';
import 'package:nimon/features/create/story_creator_models.dart';

void main() {
  const ownerId = 'creator-user-42';

  Map<String, Object?> meta({
    String publishKind = 'read_only_v1',
  }) =>
      {
        'schemaVersion': 1,
        'generatorVersion': 'CSV_Generator_V1',
        'learningLanguage': 'Japanese',
        'contentCommunity': 'Burmese',
        'promptDataTab': 'AI_mode',
        'publishKind': publishKind,
        'createdForEmail': 'user@example.com',
      };

  Map<String, Object?> readOnlyCore({
    List<Map<String, Object?>>? sentences,
    String title = 'Imported Story',
  }) =>
      {
        'title': title,
        'level': 'N5',
        'category': 'drama',
        'description': 'Desc',
        'targetDurationBandKey': '3_5',
        'sentences': sentences ??
            [
              {
                'order': 0,
                'content': {
                  'japaneseText': '最初',
                  'meanings': {'en': 'first', 'my': 'ပထမ'},
                },
              },
            ],
      };

  Map<String, Object?> fullLearnLearn({
    bool withAudio = false,
    List<Map<String, Object?>>? quizEntries,
  }) {
    return {
      'vocabularyKanji': {
        'entries': [
          {
            'termJapanese': '水',
            'examplePairs': [
              {
                'japanese': '水が好き',
                'meanings': {'en': 'I like water'},
              },
            ],
          },
        ],
      },
      'grammar': {
        'entries': [
          {
            'headline': 'について',
            'relatedNote': {'en': 'Note'},
            'mistakeWrong': 'wrong',
            'mistakeCorrect': 'right',
          },
        ],
      },
      'quiz': {
        'entries': quizEntries ??
            [
              {
                'prompt': 'Pick',
                'options': ['A', 'B', 'C', 'D'],
                'correctIndex': 2,
                'category': 'grammar',
              },
            ],
      },
      'audio': {
        'storyAudio': withAudio
            ? {'sourceUrl': 'https://cdn.example.com/a.mp3'}
            : <String, Object?>{},
      },
    };
  }

  NimonImportRawPayload payload(Map<String, Object?> json) =>
      NimonImportRawPayload.fromJsonMap(json);

  group('mapNimonImportPayloadToCreatorStoryV1', () {
    test('ReadOnly maps basics and sentences', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': readOnlyCore(),
          'sourceDraftId': 'generator-draft-99',
        }),
        ownerId: ownerId,
      );

      expect(draft.publishState, StoryPublishState.draft);
      expect(draft.basics.title, 'Imported Story');
      expect(draft.basics.category, 'Drama');
      expect(draft.basics.level, 'N5');
      expect(draft.basics.creatorOwnerId, ownerId);
      expect(draft.sentences, hasLength(1));
      expect(draft.sentences.first.japaneseText, '最初');
      expect(draft.sentences.first.meanings?.en, 'first');
      expect(draft.vocabularyKanji.entries, isEmpty);
      expect(draft.audio.storyAudio, isNull);
      expect(draft.basics.promptSourceNote, contains('[nimon-import]'));
      expect(draft.basics.promptSourceNote, contains('sourceDraftId=generator-draft-99'));
      expect(draft.basics.contentLocale, 'my');
      expect(draft.basics.learningLanguage, 'ja');
    });

    test('sentence order is reindexed sequentially', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': readOnlyCore(sentences: [
            {'order': 2, 'japaneseText': '三番'},
            {'order': 0, 'japaneseText': '最初'},
            {'order': 1, 'japaneseText': '二番'},
          ]),
        }),
        ownerId: ownerId,
      );

      expect(draft.sentences.map((s) => s.orderIndex), [0, 1, 2]);
      expect(draft.sentences.map((s) => s.japaneseText), ['最初', '二番', '三番']);
    });

    test('FullLearn maps vocabulary entries', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
          'core': readOnlyCore(),
          'learn': fullLearnLearn(),
        }),
        ownerId: ownerId,
      );

      expect(draft.vocabularyKanji.entries, hasLength(1));
      expect(draft.vocabularyKanji.entries.first.termJapanese, '水');
    });

    test('vocabulary mirrors examplePairs[0] when exampleSentence missing', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
          'core': readOnlyCore(),
          'learn': fullLearnLearn(),
        }),
        ownerId: ownerId,
      );

      final v = draft.vocabularyKanji.entries.first;
      expect(v.exampleSentence, '水が好き');
      expect(v.exampleMeanings?.en, 'I like water');
      expect(v.examplePairs.first.sourceExample, '水が好き');
    });

    test('grammar preserves relatedNote and mistake fields', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
          'core': readOnlyCore(),
          'learn': fullLearnLearn(),
        }),
        ownerId: ownerId,
      );

      final g = draft.grammar.entries.first;
      expect(g.relatedNote?.en, 'Note');
      expect(g.mistakeWrong, 'wrong');
      expect(g.mistakeCorrect, 'right');
    });

    test('quiz maps options and correctIndex without shuffling', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
          'core': readOnlyCore(),
          'learn': fullLearnLearn(),
        }),
        ownerId: ownerId,
      );

      final q = draft.quiz.entries.first;
      expect(q.options, ['A', 'B', 'C', 'D']);
      expect(q.correctIndex, 2);
      expect(q.category, CreatorQuizCategory.grammar);
    });

    test('FullLearn with null audio does not mark audio completed', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
          'core': readOnlyCore(),
          'learn': fullLearnLearn(withAudio: false),
        }),
        ownerId: ownerId,
      );

      expect(draft.audio.storyAudio, isNull);
      expect(
        draft.moduleWorkflowStatuses[LearnModuleId.audio],
        isNot(LearnModuleTaskStatus.completed),
      );
    });

    test('uses provided ownerId', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': readOnlyCore(),
        }),
        ownerId: ownerId,
      );
      expect(draft.basics.creatorOwnerId, ownerId);
    });

    test('creates new draft id instead of trusting sourceDraftId', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': readOnlyCore(),
          'sourceDraftId': 'generator-draft-99',
        }),
        ownerId: ownerId,
      );

      expect(draft.id, isNot('generator-draft-99'));
      expect(draft.id.trim(), isNotEmpty);
      expect(draft.basics.storyId, draft.id);
    });

    test('legacy sentence shape B maps meanings from flat fields', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': readOnlyCore(sentences: [
            {
              'sentence_order': 0,
              'japaneseText': 'テスト',
              'meaning_en': 'test',
              'meaning_my': 'စမ်း',
            },
          ]),
        }),
        ownerId: ownerId,
      );

      expect(draft.sentences.first.japaneseText, 'テスト');
      expect(draft.sentences.first.meanings?.en, 'test');
      expect(draft.sentences.first.meanings?.my, 'စမ်း');
    });

    test('Daily Life category normalizes to Cultural', () {
      final core = Map<String, Object?>.from(readOnlyCore());
      core['category'] = 'Daily Life';
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': core,
        }),
        ownerId: ownerId,
      );

      expect(draft.basics.category, 'Cultural');
    });

    test('unknown category maps to empty string', () {
      final core = Map<String, Object?>.from(readOnlyCore());
      core['category'] = 'Alien Invasion';
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(),
          'core': core,
        }),
        ownerId: ownerId,
      );

      expect(draft.basics.category, '');
    });

    test('FullLearn with audio URL maps story audio', () {
      final draft = mapNimonImportPayloadToCreatorStoryV1(
        payload({
          'nimonImportMeta': meta(publishKind: 'full_learn_v1'),
          'core': readOnlyCore(),
          'learn': fullLearnLearn(withAudio: true),
        }),
        ownerId: ownerId,
      );

      expect(draft.audio.storyAudio?.sourceUrl,
          'https://cdn.example.com/a.mp3');
      expect(draft.audio.storyAudio?.isValidV1, isTrue);
    });
  });
}
