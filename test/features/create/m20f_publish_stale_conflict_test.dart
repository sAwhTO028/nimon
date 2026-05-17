import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_remote_publish_errors.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _conflict409(String currentEtag) => http.Response(
      jsonEncode({
        'error': {
          'code': 'conflict',
          'message': 'Draft was modified; refresh and retry',
          'details': {'currentEtag': currentEtag},
        },
      }),
      409,
      headers: const {'content-type': 'application/json'},
    );

Map<String, Object?> _wire({
  required String draftId,
  required String etag,
  bool dirty = false,
  String? publishedMonoId,
}) =>
    {
      'draftId': draftId,
      'etag': etag,
      'schemaVersion': 1,
      'ownerId': RemoteBackendConfig.devOwnerId,
      'publishState': 'reading_only_published',
      if (publishedMonoId != null) 'publishedMonoId': publishedMonoId,
      'hasUnpublishedCoreChanges': dirty,
      'basics': {
        'storyId': draftId,
        'ownerId': RemoteBackendConfig.devOwnerId,
        'title': 'T',
        'category': 'fiction',
        'level': 'N4',
        'description': 'Long enough description for publish.',
        'promptSourceNote': '',
        'targetDurationBandKey': '3_5',
        'createdAt': '2020-01-01T00:00:00.000Z',
        'updatedAt': '2020-01-01T00:00:00.000Z',
      },
      'sentences': [
        for (var i = 0; i < 8; i++)
          {
            'id': 's$i',
            'storyId': draftId,
            'orderIndex': i,
            'japaneseText': '雨が降る。',
          },
      ],
      'vocabularyKanji': {'entries': <Object>[]},
      'grammar': {'entries': <Object>[]},
      'quiz': {'entries': <Object>[]},
      'audio': {'storyAudio': null},
      'moduleWorkflowStatuses': {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'completed',
      },
    };

CreatorStoryV1 _readOnlyReadyDraft() {
  final d =
      CreatorStoryV1.empty(creatorOwnerId: RemoteBackendConfig.devOwnerId);
  final sid = d.id;
  return d.copyWith(
    basics: d.basics.copyWith(
      title: 'T',
      category: 'fiction',
      level: 'N4',
      description: 'Long enough description for publish.',
      targetDurationBandKey: '3_5',
      promptSourceNote: 'n',
    ),
    sentences: List.generate(
      8,
      (i) => StorySentenceItem(
        id: 's$i',
        storyId: sid,
        orderIndex: i,
        japaneseText: '雨が降る。',
      ),
    ),
    moduleWorkflowStatuses: {
      for (final m in LearnModuleId.values) m: LearnModuleTaskStatus.completed,
    },
  );
}

class _IntentTrackingRepo implements StoryDraftRepository {
  _IntentTrackingRepo(this._draft);

  final CreatorStoryV1 _draft;
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
  Future<CreatorStoryV1?> loadDraft(String draftId) async =>
      draftId == _draft.id ? _draft : null;

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
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {}

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

class _ConflictPublishRepo implements StoryDraftRepository {
  _ConflictPublishRepo(
    this._draft, {
    this.alwaysFailPublish = true,
  });

  final CreatorStoryV1 _draft;

  /// When false, only the first publish intent throws (notifier retry can succeed).
  final bool alwaysFailPublish;
  var publishAttempts = 0;

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async {
    if (remotePublishAfterPut == StoryDraftRemotePublishIntent.readOnly) {
      publishAttempts++;
      if (alwaysFailPublish || publishAttempts == 1) {
        throw StoryDraftPublishConflictException(
          draftId: draft.id,
          currentEtag: 'v341',
          refreshedDraft: draft.copyWith(
            basics: draft.basics.copyWith(title: 'Server title'),
          ),
        );
      }
    }
    return draft.copyWith(
      publishedMonoId: 'pm-1',
      hasUnpublishedCoreChanges: false,
    );
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
  Future<CreatorStoryV1?> loadDraft(String draftId) async =>
      draftId == _draft.id ? _draft : null;

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
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const draftId = 'm20f-draft-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteStoryDraftRepository M20F', () {
    test('persistent publish 409 reloads draft and throws conflict', () async {
      var publishPostCount = 0;
      var reloadGetCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          reloadGetCount++;
          return http.Response(
            jsonEncode(_wire(
              draftId: draftId,
              etag: '"v341"',
              dirty: true,
              publishedMonoId: 'pm-old',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_wire(
              draftId: draftId,
              etag: '"v340"',
              dirty: true,
              publishedMonoId: 'pm-old',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/publish/read-only')) {
          publishPostCount++;
          return _conflict409('v341');
        }
        fail('unexpected ${request.method} ${request.url}');
      });

      final repo = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://127.0.0.1:9',
        client: client,
        authHeaderBuilder: () async => <String, String>{},
      );

      final base = _readOnlyReadyDraft();
      final story = base.copyWith(
        basics: base.basics.copyWith(storyId: draftId),
      );

      await expectLater(
        repo.saveDraft(
          story,
          remotePublishAfterPut: StoryDraftRemotePublishIntent.readOnly,
        ),
        throwsA(
          predicate<StoryDraftPublishConflictException>(
            (e) =>
                e.message == kStoryDraftPublishConflictMessage &&
                e.refreshedDraft != null,
          ),
        ),
      );

      expect(publishPostCount, 2);
      expect(reloadGetCount, greaterThanOrEqualTo(2));
    });

    test('isDraftVersionConflictResponse detects Nest conflict body', () {
      expect(
        isDraftVersionConflictResponse(
          statusCode: 409,
          body: _conflict409('v341').body,
        ),
        isTrue,
      );
      expect(
        draftVersionConflictCurrentEtagFromBody(_conflict409('v341').body),
        'v341',
      );
    });
  });

  group('StoryCreatorDraftNotifier M20F', () {
    test('stale publish conflict sets friendly error and returns false',
        () async {
      final draft = _readOnlyReadyDraft();
      expect(computeReadOnlyReady(draft).ready, isTrue);
      final repo = _ConflictPublishRepo(draft);
      final notifier = StoryCreatorDraftNotifier(
        repo,
        RemoteBackendConfig.devOwnerId,
      );
      notifier.state = notifier.state.copyWith(draft: draft, dirty: false);

      final ok = await notifier.publishReadingOnlyToDisk();
      expect(ok, isFalse);
      expect(
        notifier.state.lastSaveError,
        kStoryDraftPublishConflictMessage,
      );
      expect(notifier.state.draft.basics.title, 'Server title');
      expect(notifier.state.draft.publishState, StoryPublishState.draft);
    });

    test('publish retries at most once after conflict reload', () async {
      final draft = _readOnlyReadyDraft();
      final repo = _ConflictPublishRepo(draft, alwaysFailPublish: false);
      final notifier = StoryCreatorDraftNotifier(
        repo,
        RemoteBackendConfig.devOwnerId,
      );
      notifier.state = notifier.state.copyWith(draft: draft, dirty: false);

      final ok = await notifier.publishReadingOnlyToDisk();
      expect(ok, isTrue);
      expect(repo.publishAttempts, 2);
    });

    test('publish awaits pending debounced save before publish intent',
        () async {
      final draft = _readOnlyReadyDraft();
      final repo = _IntentTrackingRepo(draft);
      final notifier = StoryCreatorDraftNotifier(
        repo,
        RemoteBackendConfig.devOwnerId,
      );
      notifier.state = notifier.state.copyWith(draft: draft, dirty: true);
      expect(computeReadOnlyReady(draft).ready, isTrue);

      notifier.persistLocalDebounced(reason: 'sentence_edit');
      await Future<void>.delayed(Duration.zero);

      final publishFuture = notifier.publishReadingOnlyToDisk();
      await publishFuture;

      expect(
        repo.intents,
        [
          StoryDraftRemotePublishIntent.none,
          StoryDraftRemotePublishIntent.readOnly,
        ],
      );
    });
  });
}
