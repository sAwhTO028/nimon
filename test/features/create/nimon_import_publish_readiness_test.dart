import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/creator_publish_preflight.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';

import 'nimon_import_full_learn_flow_test.dart' show fullLearnImportJson;
import 'nimon_import_read_only_flow_test.dart' show readOnlyImportJson;

class _IntentTrackingRepo implements StoryDraftRepository {
  final intents = <StoryDraftRemotePublishIntent>[];

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async {
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
  Future<CreatorStoryV1?> loadDraft(String draftId) async => null;

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
  Future<DateTime?> savedAt(String draftId) async => null;

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

const _ownerId = 'test-owner-readiness';
const _jaMyContext = NimonImportValidationContext(
  learningLanguageCode: 'ja',
  contentLocaleCode: 'my',
  authenticatedEmail: 'user@example.com',
);

CreatorStoryV1 _mapValidatedReadOnly() {
  final payload = NimonImportRawPayload.fromJsonMap(readOnlyImportJson());
  final validation = validateNimonImportPayload(payload, _jaMyContext);
  expect(validation.canImport, isTrue);
  return mapNimonImportPayloadToCreatorStoryV1(payload, ownerId: _ownerId);
}

CreatorStoryV1 _mapValidatedFullLearn({String? audioSourceUrl}) {
  final payload = NimonImportRawPayload.fromJsonMap(
    fullLearnImportJson(audioSourceUrl: audioSourceUrl),
  );
  final validation = validateNimonImportPayload(payload, _jaMyContext);
  expect(validation.canImport, isTrue);
  return mapNimonImportPayloadToCreatorStoryV1(payload, ownerId: _ownerId);
}

void main() {
  group('Test A — ReadOnly imported draft readiness/preflight', () {
    test('preflight runs without crash; creator readiness matches HTML rules', () {
      final draft = _mapValidatedReadOnly();

      final roReady = computeReadOnlyReady(draft);
      final review = buildStoryReviewDisplayModel(draft);
      final publishData = storyPublishDataFromCreator(draft);
      final preflight = validateStoryPublishData(
        publishData,
        ValidationMode.readOnlyPublish,
      );

      expect(publishData.sentences, hasLength(24));
      expect(preflight, isA<ValidationResult>());
      // Phase 3: creator readiness reflects HTML generator limits; publish validation is unchanged.
      expect(roReady.ready, isTrue, reason: roReady.unmetMessages.join(' | '));
      expect(review.isReadingOnlyReady, isTrue);
      expect(
        isStoryReviewModeAllowed(StoryReviewPublishMode.readingOnly, review),
        isTrue,
      );
    });
  });

  group('Test B — FullLearn imported draft with null audio', () {
    test('import preview-only; creator readiness and preflight block publish', () {
      final payload = NimonImportRawPayload.fromJsonMap(fullLearnImportJson());
      final validation = validateNimonImportPayload(payload, _jaMyContext);

      expect(validation.canImport, isTrue);
      expect(validation.canPublishImmediately, isFalse);
      expect(
        validation.missingPublishRequirements.map((e) => e.code),
        contains('import.fullLearn.audioRequired'),
      );

      final draft = mapNimonImportPayloadToCreatorStoryV1(payload, ownerId: _ownerId);

      expect(draft.audio.storyAudio, isNull);
      expect(
        draft.moduleWorkflowStatuses[LearnModuleId.audio],
        isNot(LearnModuleTaskStatus.completed),
      );

      final flReady = computeFullLearnReady(draft);
      final review = buildStoryReviewDisplayModel(draft);
      final preflight = validateStoryPublishData(
        storyPublishDataFromCreator(draft),
        ValidationMode.fullLearnPublish,
      );

      expect(flReady.ready, isFalse);
      expect(review.isFullLearnReady, isFalse);
      expect(
        isStoryReviewModeAllowed(StoryReviewPublishMode.fullLearn, review),
        isFalse,
      );
      expect(hasBlockingIssues(preflight), isTrue);
      expect(preflight.issues, isNotEmpty);
    });
  });

  group('Test C — FullLearn imported draft with audio URL', () {
    test('import layer clear of audio requirement; creator readiness matches HTML rules', () {
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

      final draft = mapNimonImportPayloadToCreatorStoryV1(payload, ownerId: _ownerId);

      expect(draft.audio.storyAudio?.sourceUrl, audioUrl);
      expect(draft.audio.storyAudio?.isValidV1, isTrue);
      expect(
        draft.moduleWorkflowStatuses[LearnModuleId.audio],
        LearnModuleTaskStatus.completed,
      );

      final flReady = computeFullLearnReady(draft);
      final preflight = validateStoryPublishData(
        storyPublishDataFromCreator(draft),
        ValidationMode.fullLearnPublish,
      );

      expect(flReady.ready, isTrue, reason: flReady.unmetMessages.join(' | '));
      expect(preflight, isA<ValidationResult>());
    });
  });

  group('import vs creator readiness distinction', () {
    test('canPublishImmediately does not imply computeFullLearnReady', () {
      final payload = NimonImportRawPayload.fromJsonMap(fullLearnImportJson());
      final validation = validateNimonImportPayload(payload, _jaMyContext);
      expect(validation.canPublishImmediately, isFalse);

      final draft = mapNimonImportPayloadToCreatorStoryV1(payload, ownerId: _ownerId);
      expect(computeFullLearnReady(draft).ready, isFalse);
    });
  });

  group('route session safety after importMappedDraft', () {
    test('same draftId loadDraftById does not wipe in-memory import', () async {
      final draft = _mapValidatedFullLearn();
      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, _ownerId);

      await notifier.importMappedDraft(draft);
      final title = notifier.state.draft.title;
      final sentenceCount = notifier.state.draft.sentences.length;

      await notifier.loadDraftById(draft.id);

      expect(notifier.state.draft.id, draft.id);
      expect(notifier.state.draft.title, title);
      expect(notifier.state.draft.sentences.length, sentenceCount);
      expect(repo.intents, [StoryDraftRemotePublishIntent.none]);
    });
  });
}
