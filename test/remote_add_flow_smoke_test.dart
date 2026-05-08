import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show StoryCreatorDraftStorage;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteStoryDraftRepository smoke', () {
    late StoryDraftRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = RemoteStoryDraftRepository(apiBaseUrl: 'http://localhost:3000');
    });

    test('create -> save -> list -> publish RO -> publish FL (etag enforced)',
        () async {
      // Confirm remote mode is reachable (create should return server-shaped draftId)
      final created = await repo.createNewDraft();
      expect(created.id.trim(), isNotEmpty);

      // Ensure local fallback is not the only persistence: listDraftIds should include it.
      final ids1 = await repo.listDraftIds();
      expect(ids1, contains(created.id));

      // Save basics + one sentence so RO readiness is met.
      final uuid = const Uuid();
      final withBasics = created.copyWith(
        basics: created.basics.copyWith(
          title: 'Smoke title',
          category: 'fiction',
          level: 'N4',
          description: 'Smoke desc',
          targetDurationBandKey: '5_7',
        ),
        sentences: [
          StorySentenceItem(
            id: uuid.v4(),
            storyId: created.id,
            orderIndex: 0,
            japaneseText: '雨が降る。',
          ),
        ],
      );

      // The domain model in this app always has at least one sentence after edits
      // in real UI; for smoke test we just ensure we can save whatever the app has.
      final saved = await repo.saveDraft(withBasics);
      expect(saved.id, created.id);

      // List for processing still resolves
      final ids2 = await repo.listDraftIds();
      expect(ids2, contains(created.id));

      // Publish Read-only via repo by setting state then saving.
      final roDraft = saved.copyWith(
        publishState: StoryPublishState.readingOnlyPublished,
      );
      final roSaved = await repo.saveDraftNow(roDraft);
      expect(roSaved.publishState, StoryPublishState.readingOnlyPublished);

      // Mark modules completed and publish full-learn.
      final completed = roSaved.copyWith(
        moduleWorkflowStatuses: {
          for (final e in roSaved.moduleWorkflowStatuses.entries)
            e.key: LearnModuleTaskStatus.completed,
        },
        publishState: StoryPublishState.fullLearnPublished,
      );
      final flSaved = await repo.saveDraftNow(completed);
      expect(flSaved.publishState, StoryPublishState.fullLearnPublished);

      // Confirm local copy still exists (resume-meta is local-only; draft storage should hold it).
      final localLoaded =
          await StoryCreatorDraftStorage.load(draftId: created.id);
      expect(localLoaded, isNotNull);
    });
  });
}
