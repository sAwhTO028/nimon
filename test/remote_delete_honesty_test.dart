import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show StoryCreatorDraftStorage, StoryCreatorDraftResumeStorage;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteStoryDraftRepository delete honesty', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StoryCreatorDraftStorage.clear();
    });

    test('strict mode: remote delete failure does not cleanup locally',
        () async {
      if (!RemoteBackendConfig.strictRemoteDrafts) {
        // This test is only meaningful when compiled with:
        // --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true
        return;
      }

      final local = const LocalStoryDraftRepository();
      final created = await local.createNewDraft();
      // Ensure resume meta exists (local repo creates it).
      final meta = await StoryCreatorDraftResumeStorage.loadMeta(created.id);
      expect(meta, isNotNull);

      final remote = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://localhost:3999', // intentionally wrong / offline
      );

      await expectLater(remote.deleteDraft(created.id), throwsA(isA<Object>()));

      // Strict mode must stay honest: local is untouched on remote failure.
      expect(await local.hasDraft(created.id), isTrue);
      expect(
          await StoryCreatorDraftResumeStorage.loadMeta(created.id), isNotNull);
    });

    test('non-strict mode: remote delete failure falls back to local cleanup',
        () async {
      if (RemoteBackendConfig.strictRemoteDrafts) {
        // Compile/run this test with strict mode OFF.
        return;
      }

      final local = const LocalStoryDraftRepository();
      final created = await local.createNewDraft();
      expect(await local.hasDraft(created.id), isTrue);
      expect(
          await StoryCreatorDraftResumeStorage.loadMeta(created.id), isNotNull);

      final remote = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://localhost:3999', // intentionally wrong / offline
      );

      // In non-strict mode, we should not throw; we should clean up locally.
      await remote.deleteDraft(created.id);

      expect(await local.hasDraft(created.id), isFalse);
      expect(await StoryCreatorDraftResumeStorage.loadMeta(created.id), isNull);
    });
  });
}
