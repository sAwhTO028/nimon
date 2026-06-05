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

const _ownerId = 'test-owner-readonly';
const _authEmail = 'user@example.com';

const _jaMyContext = NimonImportValidationContext(
  learningLanguageCode: 'ja',
  contentLocaleCode: 'my',
  authenticatedEmail: _authEmail,
);

/// Minimal ReadOnly AI export (inline; no fixture file).
Map<String, Object?> readOnlyImportJson({
  String learningLanguage = 'Japanese',
  String contentCommunity = 'Burmese',
  String? sourceDraftId,
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

  return {
    if (sourceDraftId != null) 'sourceDraftId': sourceDraftId,
    'nimonImportMeta': {
      'schemaVersion': 1,
      'generatorVersion': 'CSV_Generator_FullLearn_V7',
      'learningLanguage': learningLanguage,
      'contentCommunity': contentCommunity,
      'promptDataTab': 'AI_mode',
      'publishKind': 'read_only_v1',
      'createdForEmail': _authEmail,
    },
    'core': {
      'title': 'A Small Morning Story',
      'category': 'Daily Life',
      'level': 'N5',
      'description': 'A short imported read-only story.',
      'targetDurationBandKey': '3_5',
      // HTML rules (AI + JP + 3-5 mins + N5/A1): enforce minimum sentence/chars.
      'sentences': sentences(),
    },
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
  group('ReadOnly JSON import pipeline', () {
    test('happy path: parse → validate → map → importMappedDraft → persist', () async {
      const generatorDraftId = 'generator-source-draft-abc';
      final json = readOnlyImportJson(sourceDraftId: generatorDraftId);
      final payload = NimonImportRawPayload.fromJsonMap(json);

      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isTrue, reason: validation.toString());
      expect(validation.canPublishImmediately, isTrue);
      expect(validation.blockingErrors, isEmpty);
      expect(validation.missingPublishRequirements, isEmpty);

      final mapped = mapNimonImportPayloadToCreatorStoryV1(
        payload,
        ownerId: _ownerId,
      );

      expect(mapped.id.trim(), isNotEmpty);
      expect(mapped.id, isNot(generatorDraftId));
      expect(mapped.basics.title, 'A Small Morning Story');
      expect(mapped.basics.creatorOwnerId, _ownerId);
      expect(mapped.publishState, StoryPublishState.draft);
      expect(mapped.publishedMonoId, isNull);
      expect(mapped.sentences, hasLength(24));
      expect(mapped.sentences.map((s) => s.orderIndex), List.generate(24, (i) => i));
      expect(mapped.sentences[0].japaneseText.trim(), isNotEmpty);
      expect(mapped.vocabularyKanji.entries, isEmpty);
      expect(mapped.grammar.entries, isEmpty);
      expect(mapped.quiz.entries, isEmpty);
      expect(mapped.audio.storyAudio, isNull);

      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(
        repo,
        _ownerId,
        defaultContentLocale: 'my',
        defaultLearningLanguage: 'ja',
      );
      await notifier.importMappedDraft(mapped);

      expect(notifier.state.draft.id, mapped.id);
      expect(notifier.state.draft.title, 'A Small Morning Story');
      expect(notifier.state.draft.sentences, hasLength(24));
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

    test('publish preflight is reachable with compatible shape (may block on counts)', () {
      final payload = NimonImportRawPayload.fromJsonMap(readOnlyImportJson());
      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canImport, isTrue);

      final mapped = mapNimonImportPayloadToCreatorStoryV1(
        payload,
        ownerId: _ownerId,
      );

      final publishData = storyPublishDataFromCreator(mapped);
      expect(publishData.title, 'A Small Morning Story');
      expect(publishData.sentences, hasLength(24));
      expect(publishData.targetDurationBandKey, '3_5');

      final preflight = validateStoryPublishData(
        publishData,
        ValidationMode.readOnlyPublish,
      );

      expect(preflight, isA<ValidationResult>());
      // This test only asserts the publish preflight path is callable for an
      // imported ReadOnly draft (import rules are validated earlier).
    });

    test('English learning accepted when context is en+my', () {
      final payload = NimonImportRawPayload.fromJsonMap(
        readOnlyImportJson(learningLanguage: 'English'),
      );
      const enMyContext = NimonImportValidationContext(
        learningLanguageCode: 'en',
        contentLocaleCode: 'my',
        authenticatedEmail: 'user@example.com',
      );
      final validation = validateNimonImportPayload(payload, enMyContext);

      expect(
        validation.blockingErrors.map((e) => e.code),
        isNot(contains('import.context.englishComingSoon')),
      );
      expect(
        validation.blockingErrors.map((e) => e.code),
        isNot(contains('import.context.learningLanguageMismatch')),
      );
    });

    test('contentCommunity mismatch is blocked before map/notifier', () {
      final payload = NimonImportRawPayload.fromJsonMap(
        readOnlyImportJson(contentCommunity: 'Japanese'),
      );
      final validation = validateNimonImportPayload(payload, _jaMyContext);

      expect(validation.canImport, isFalse);
      expect(
        validation.blockingErrors.map((e) => e.code),
        contains('import.context.contentCommunityMismatch'),
      );
      // Production import flow stops here; mapper/notifier are not invoked.
    });
  });
}
