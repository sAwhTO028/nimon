import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/features/create/creator_publish_preflight.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

const _ownerId = 'test-owner-full-learn';
const _authEmail = 'user@example.com';

const _jaMyContext = NimonImportValidationContext(
  learningLanguageCode: 'ja',
  contentLocaleCode: 'my',
  authenticatedEmail: _authEmail,
);

Map<String, Object?> fullLearnImportJson({
  bool includeLearn = true,
  String? audioSourceUrl,
  List<Map<String, Object?>>? quizEntries,
}) {
  List<Map<String, Object?>> sentences({int count = 24, int charsPerSentence = 15}) {
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

  final learn = includeLearn
      ? <String, Object?>{
          'vocabularyKanji': {
            'entries': [
              // HTML rules (AI + JP + 3-5 mins + N5/A1 default): vocab=8
              for (var i = 0; i < 8; i++)
                {
                  'id': 'vocab-$i',
                  'type': 'vocabulary',
                  'termJapanese': 'みず$i',
                  'reading': 'みず$i',
                  'glosses': {
                    'en': 'water$i',
                    'my': 'ရေ$i',
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
                },
            ],
          },
          'grammar': {
            'entries': [
              // HTML rules (AI + JP + 3-5 mins + N5/A1 default): grammar=3
              for (var i = 0; i < 3; i++)
                {
                  'id': 'grammar-$i',
                  'headline': '〜ます$i',
                  'form': 'verbます$i',
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
                  'mistakeWrong': 'まちがい$i',
                  'mistakeCorrect': 'せいかい$i',
                },
            ],
          },
          'quiz': {
            'entries': quizEntries ??
                [
                  // HTML rules (AI + JP + 3-5 mins + N5/A1 default): total=11 (v=5, g=3, s=3)
                  for (var i = 0; i < 5; i++)
                    {
                      'id': 'quiz-v-$i',
                      'category': 'vocabulary',
                      'prompt': 'Qv$i',
                      'options': ['A$i', 'B$i', 'C$i', 'D$i'],
                      'correctIndex': 0,
                      'sourceNote': 'subtype=meaning_question;answer=A$i;target=T$i',
                      'explanations': {
                        'en': 'e$i',
                        'my': 'e$i',
                        'byLanguage': <String, Object?>{},
                      },
                    },
                  for (var i = 0; i < 3; i++)
                    {
                      'id': 'quiz-g-$i',
                      'category': 'grammar',
                      'prompt': 'Qg$i',
                      'options': ['A$i', 'B$i', 'C$i', 'D$i'],
                      'correctIndex': 1,
                      'sourceNote': 'subtype=form_question;answer=B$i;target=T$i',
                      'explanations': {
                        'en': 'e$i',
                        'my': 'e$i',
                        'byLanguage': <String, Object?>{},
                      },
                    },
                  for (var i = 0; i < 3; i++)
                    {
                      'id': 'quiz-s-$i',
                      'category': 'sample_sentence',
                      'prompt': 'Qs$i',
                      'options': ['A$i', 'B$i', 'C$i', 'D$i'],
                      'correctIndex': 2,
                      'sourceNote':
                          'subtype=sentence_question;answer=C$i;target=T$i',
                      'explanations': {
                        'en': 'e$i',
                        'my': 'e$i',
                        'byLanguage': <String, Object?>{},
                      },
                    },
                ],
          },
          'audio': {
            'storyAudio': {
              'sourceUrl': audioSourceUrl,
              'localPath': null,
            },
          },
        }
      : null;

  return {
    'nimonImportMeta': {
      'schemaVersion': 1,
      'generatorVersion': 'CSV_Generator_FullLearn_V7',
      'learningLanguage': 'Japanese',
      'contentCommunity': 'Burmese',
      'promptDataTab': 'AI_mode',
      'publishKind': 'full_learn_v1',
      'createdForEmail': _authEmail,
    },
    'core': {
      'title': 'A Full Learn Morning Story',
      'category': 'Daily Life',
      'level': 'N5',
      'description': 'A short imported full-learn story.',
      'targetDurationBandKey': '3_5',
      // HTML rules (AI + JP + 3-5 mins + N5/A1): enforce minimum sentence/chars.
      'sentences': sentences(),
    },
    if (learn != null) 'learn': learn,
  };
}

class _IntentTrackingRepo implements StoryDraftRepository {
  CreatorStoryV1? lastSaved;
  final intents = <StoryDraftRemotePublishIntent>[];

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async {
    lastSaved = draft;
    intents.add(remotePublishAfterPut);
    return draft;
  }

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {}

  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) async =>
      PageResult.empty();

  @override
  Future<void> clearActiveDraft() async {}

  @override
  Future<void> clearResumeMeta(String draftId) async {}

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteDraft(String draftId) async {}

  @override
  Future<bool> discardPublishedEditStaging(String draftId) async => false;

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) async {}

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async =>
      draft;

  @override
  Future<bool> hasAnyIndexedDraft() async => false;

  @override
  Future<bool> hasDraft(String draftId) async => false;

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() async => const [];

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) async => lastSaved;

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) async => null;

  @override
  Future<List<String>> listDraftIds() async => const [];

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) async {}

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) => saveDraft(draft);

  @override
  Future<DateTime?> savedAt(String draftId) async => DateTime.utc(2026);

  @override
  Future<DateTime?> savedAtActiveDraft() async => null;

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async {}
}

void main() {
  group('FullLearn JSON import pipeline', () {
    test(
        'null audio: validate preview-only → map learn layers → importMappedDraft',
        () async {
      final payload = NimonImportRawPayload.fromJsonMap(fullLearnImportJson());

      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isTrue, reason: validation.toString());
      expect(validation.canPublishImmediately, isFalse);
      expect(validation.blockingErrors, isEmpty);
      expect(
        validation.missingPublishRequirements.map((e) => e.code),
        contains('import.fullLearn.audioRequired'),
      );

      final mapped = mapNimonImportPayloadToCreatorStoryV1(
        payload,
        ownerId: _ownerId,
      );

      expect(mapped.id.trim(), isNotEmpty);
      expect(mapped.basics.title, 'A Full Learn Morning Story');
      expect(mapped.basics.creatorOwnerId, _ownerId);
      expect(mapped.publishState, StoryPublishState.draft);
      expect(mapped.publishedMonoId, isNull);
      expect(mapped.sentences, hasLength(24));

      expect(mapped.vocabularyKanji.entries, hasLength(8));
      final vocab = mapped.vocabularyKanji.entries.first;
      expect(vocab.termJapanese.trim(), isNotEmpty);
      expect(vocab.glosses?.en?.trim(), isNotEmpty);
      expect(vocab.exampleSentence?.trim(), isNotEmpty);
      expect(vocab.exampleMeanings?.en?.trim(), isNotEmpty);
      expect(vocab.examplePairs.first.sourceExample.trim(), isNotEmpty);

      expect(mapped.grammar.entries, hasLength(3));
      final grammar = mapped.grammar.entries.first;
      expect(grammar.headline.trim(), isNotEmpty);
      expect(grammar.relatedNote?.en?.trim(), isNotEmpty);
      expect(grammar.mistakeWrong?.trim(), isNotEmpty);
      expect(grammar.mistakeCorrect?.trim(), isNotEmpty);

      expect(mapped.quiz.entries, hasLength(11));
      final quiz = mapped.quiz.entries.first;
      expect(quiz.options, hasLength(4));
      expect(quiz.correctIndex, 0);
      expect(quiz.category, CreatorQuizCategory.vocabulary);
      expect(quiz.sourceNote, contains('meaning_question'));

      expect(mapped.audio.storyAudio, isNull);
      expect(
        mapped.moduleWorkflowStatuses[LearnModuleId.audio],
        isNot(LearnModuleTaskStatus.completed),
      );

      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, _ownerId);
      await notifier.importMappedDraft(mapped);

      expect(notifier.state.draft.id, mapped.id);
      expect(notifier.state.draft.title, 'A Full Learn Morning Story');
      expect(notifier.state.draft.vocabularyKanji.entries, hasLength(8));
      expect(notifier.state.draft.grammar.entries, hasLength(3));
      expect(notifier.state.draft.quiz.entries, hasLength(11));
      expect(notifier.state.draft.audio.storyAudio, isNull);
      expect(repo.lastSaved?.id, mapped.id);
      expect(repo.intents, [StoryDraftRemotePublishIntent.none]);
      expect(
        repo.intents,
        isNot(contains(StoryDraftRemotePublishIntent.readOnly)),
      );
      expect(
        repo.intents,
        isNot(contains(StoryDraftRemotePublishIntent.fullLearn)),
      );
    });

    test('with audio URL: no audio missing requirement; maps StoryAudioAsset', () {
      const audioUrl = 'https://example.com/audio/story.mp3';
      final payload = NimonImportRawPayload.fromJsonMap(
        fullLearnImportJson(audioSourceUrl: audioUrl),
      );

      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isTrue);
      expect(validation.canPublishImmediately, isTrue);
      expect(
        validation.missingPublishRequirements.map((e) => e.code),
        isNot(contains('import.fullLearn.audioRequired')),
      );

      final mapped = mapNimonImportPayloadToCreatorStoryV1(
        payload,
        ownerId: _ownerId,
      );

      expect(mapped.audio.storyAudio, isNotNull);
      expect(mapped.audio.storyAudio!.sourceUrl, audioUrl);
      expect(mapped.audio.storyAudio!.isValidV1, isTrue);
    });

    test('invalid quiz options length blocks before map/notifier', () {
      final payload = NimonImportRawPayload.fromJsonMap(
        fullLearnImportJson(
          quizEntries: [
            {
              'id': 'quiz-bad',
              'category': 'vocabulary',
              'prompt': 'Bad quiz',
              'options': ['A', 'B', 'C'],
              'correctIndex': 0,
            },
          ],
        ),
      );

      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isFalse);
      expect(
        validation.blockingErrors.map((e) => e.code),
        contains('import.quiz.invalidOptions'),
      );
    });

    test('missing learn section blocks before map/notifier', () {
      final payload = NimonImportRawPayload.fromJsonMap(
        fullLearnImportJson(includeLearn: false),
      );

      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isFalse);
      expect(
        validation.blockingErrors.map((e) => e.code),
        contains('import.learn.missing'),
      );
    });

    test(
        'full learn publish preflight is reachable (may block on counts/audio/modules)',
        () {
      final payload = NimonImportRawPayload.fromJsonMap(fullLearnImportJson());
      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isTrue);

      final mapped = mapNimonImportPayloadToCreatorStoryV1(
        payload,
        ownerId: _ownerId,
      );

      final publishData = storyPublishDataFromCreator(mapped);
      expect(publishData.title, 'A Full Learn Morning Story');
      expect(publishData.sentences, hasLength(24));
      expect(publishData.vocabEntries, hasLength(8));
      expect(publishData.grammarEntries, hasLength(3));
      expect(publishData.quizEntries, hasLength(11));

      final preflight = validateStoryPublishData(
        publishData,
        ValidationMode.fullLearnPublish,
      );

      expect(preflight, isA<ValidationResult>());
      expect(preflight.issues, isNotEmpty);
      expect(hasBlockingIssues(preflight), isTrue);
    });
  });
}
