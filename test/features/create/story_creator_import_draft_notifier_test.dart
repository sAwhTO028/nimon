import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

class _IntentTrackingRepo implements StoryDraftRepository {
  _IntentTrackingRepo();

  CreatorStoryV1? lastSaved;
  final intents = <StoryDraftRemotePublishIntent>[];
  CreatorDraftResumeMeta? lastResumeMeta;

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
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {
    lastResumeMeta = meta;
  }

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
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) async =>
      lastResumeMeta;

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

CreatorStoryV1 _importedDraft({
  required String id,
  String title = 'Imported Title',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return CreatorStoryV1(
    basics: StoryBasics(
      storyId: id,
      title: title,
      category: 'drama',
      level: 'N5',
      description: 'Imported description',
      promptSourceNote: '[nimon-import]',
      targetDurationBandKey: '3_5',
      creatorOwnerId: 'owner-99',
      createdAt: now,
      updatedAt: now,
    ),
    sentences: [
      StorySentenceItem(
        id: 's1',
        storyId: id,
        orderIndex: 0,
        japaneseText: 'こんにちは',
      ),
    ],
    vocabularyKanji: const VocabularyKanjiLayer(),
    grammar: const GrammarLayer(),
    quiz: const QuizLayer(),
    audio: const AudioLayer(),
    publishState: StoryPublishState.draft,
    moduleWorkflowStatuses: {
      for (final m in LearnModuleId.values) m: LearnModuleTaskStatus.notStarted,
    },
  );
}

void main() {
  group('StoryCreatorDraftNotifier.importMappedDraft', () {
    test('sets current state draft id, title, and sentences', () async {
      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, 'dev-owner');
      final imported = _importedDraft(id: 'import-draft-1');

      await notifier.importMappedDraft(imported);

      expect(notifier.state.draft.id, 'import-draft-1');
      expect(notifier.state.draft.title, 'Imported Title');
      expect(notifier.state.draft.sentences, hasLength(1));
      expect(notifier.state.draft.sentences.first.japaneseText, 'こんにちは');
      expect(notifier.state.draft.publishState, StoryPublishState.draft);
      expect(notifier.state.saveStatus, CreatorDraftSaveStatus.saved);
      expect(notifier.state.dirty, isFalse);
      expect(repo.lastSaved?.id, 'import-draft-1');
      expect(repo.lastResumeMeta?.draftId, 'import-draft-1');
      expect(
        repo.lastResumeMeta?.lastActiveModule,
        CreatorLastActiveModule.storytelling,
      );
    });

    test('persists with remotePublishAfterPut none for json_import', () async {
      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, 'dev-owner');

      await notifier.importMappedDraft(
        _importedDraft(id: 'import-draft-2'),
      );

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

    test('cancels pending debounced save so import is not overwritten', () async {
      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, 'dev-owner');
      notifier.state = notifier.state.copyWith(
        draft: CreatorStoryV1.empty(creatorOwnerId: 'dev-owner'),
      );
      notifier.persistLocalDebounced(
        reason: 'old_session',
        delay: const Duration(seconds: 30),
      );

      await notifier.importMappedDraft(
        _importedDraft(id: 'import-draft-3', title: 'After debounce cancel'),
      );

      expect(notifier.state.draft.id, 'import-draft-3');
      expect(repo.lastSaved?.id, 'import-draft-3');
    });

    test('forces draft publish state when import carried published linkage', () async {
      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, 'dev-owner');
      final publishedLike = _importedDraft(id: 'import-draft-4').copyWith(
        publishState: StoryPublishState.readingOnlyPublished,
        publishedMonoId: 'pm-should-clear',
        hasUnpublishedCoreChanges: false,
      );

      await notifier.importMappedDraft(publishedLike);

      expect(notifier.state.draft.publishState, StoryPublishState.draft);
      expect(notifier.state.draft.publishedMonoId, isNull);
      expect(notifier.state.publishedEditReadOnlyBaselineSig, isNull);
    });

    test('reset after import still starts a fresh empty session', () async {
      final repo = _IntentTrackingRepo();
      final notifier = StoryCreatorDraftNotifier(repo, 'dev-owner');

      await notifier.importMappedDraft(_importedDraft(id: 'import-draft-5'));
      notifier.reset();

      expect(notifier.state.draft.id, isNot('import-draft-5'));
      expect(notifier.state.draft.title, isEmpty);
      expect(notifier.state.draft.sentences, isEmpty);
    });
  });
}
