import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/auth/current_user_id_provider.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_remote_publish_errors.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_v1_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const draftId = 'm20e-draft-1';
  const pmId = 'pm-m20e-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  CreatorStoryV1 stagingStory({bool dirty = true, int sentenceCount = 1}) {
    final now = DateTime.utc(2020);
    final basics = StoryBasics(
      storyId: draftId,
      title: 'T',
      category: 'fiction',
      level: 'N4',
      description: 'D',
      promptSourceNote: '',
      targetDurationBandKey: '5_7',
      creatorOwnerId: RemoteBackendConfig.devOwnerId,
      createdAt: now,
      updatedAt: now,
    );
    final sentences = [
      for (var i = 0; i < sentenceCount; i++)
        StorySentenceItem(
          id: 's$i',
          storyId: draftId,
          orderIndex: i,
          japaneseText: '雨が降る。',
        ),
    ];
    final modules = {
      for (final m in LearnModuleId.values) m: LearnModuleTaskStatus.notStarted,
    };
    return CreatorStoryV1(
      basics: basics,
      sentences: sentences,
      vocabularyKanji: const VocabularyKanjiLayer(entries: []),
      grammar: const GrammarLayer(entries: []),
      quiz: const QuizLayer(entries: []),
      audio: const AudioLayer(storyAudio: null),
      moduleWorkflowStatuses: modules,
      publishState: StoryPublishState.readingOnlyPublished,
      publishedMonoId: pmId,
      hasUnpublishedCoreChanges: dirty,
    );
  }

  Map<String, Object?> _stagingDraftJson({
    bool dirty = true,
    String etag = '"e2"',
  }) =>
      {
        'draftId': draftId,
        'etag': etag,
        'schemaVersion': 1,
        'ownerId': RemoteBackendConfig.devOwnerId,
        'publishState': 'reading_only_published',
        'publishedMonoId': pmId,
        'hasUnpublishedCoreChanges': dirty,
        'basics': {
          'storyId': draftId,
          'ownerId': RemoteBackendConfig.devOwnerId,
          'title': 'T',
          'category': 'fiction',
          'level': 'N4',
          'description': 'D',
          'promptSourceNote': '',
          'targetDurationBandKey': '5_7',
          'createdAt': '2020-01-01T00:00:00.000Z',
          'updatedAt': '2020-01-01T00:00:00.000Z',
        },
        'sentences': [
          {
            'id': 's1',
            'storyId': draftId,
            'orderIndex': 0,
            'japaneseText': '雨が降る。',
          }
        ],
        'vocabularyKanji': {'entries': <Object>[]},
        'grammar': {'entries': <Object>[]},
        'quiz': {'entries': <Object>[]},
        'audio': {'storyAudio': null},
        'moduleWorkflowStatuses': {
          'vocabulary_kanji': 'not_started',
          'grammar': 'not_started',
          'quiz': 'not_started',
          'audio': 'not_started',
        },
      };

  group('RemoteStoryDraftRepository M20E', () {
    test('read-only publish after PUT clears hasUnpublishedCoreChanges', () async {
      var publishCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_stagingDraftJson()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_stagingDraftJson(dirty: true, etag: '"e3"')),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/publish/read-only')) {
          publishCalls++;
          return http.Response(
            jsonEncode(_stagingDraftJson(dirty: false, etag: '"e4"')),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        fail('unexpected ${request.method} ${request.url}');
      });

      final repo = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://127.0.0.1:9',
        client: client,
        authHeaderBuilder: () async => <String, String>{},
      );

      final saved = await repo.saveDraft(
        stagingStory(),
        remotePublishAfterPut: StoryDraftRemotePublishIntent.readOnly,
      );

      expect(publishCalls, 1);
      expect(saved.hasUnpublishedCoreChanges, isFalse);
      expect(saved.publishedMonoId, pmId);
    });

    test('read-only publish skipped when etag missing throws (no fake success)', () async {
      var getCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          getCount++;
          if (getCount == 1) {
            return http.Response(
              jsonEncode(_stagingDraftJson(etag: '"e1"')),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_stagingDraftJson(dirty: true, etag: '')),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        fail('unexpected ${request.method} ${request.url}');
      });

      final repo = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://127.0.0.1:9',
        client: client,
        authHeaderBuilder: () async => <String, String>{},
      );

      await expectLater(
        repo.saveDraft(
          stagingStory(),
          remotePublishAfterPut: StoryDraftRemotePublishIntent.readOnly,
        ),
        throwsA(isA<StoryDraftHttpResponseException>()),
      );
    });
  });

  group('StoryCreatorDraftNotifier M20E', () {
    test('publishReadingOnlyToDisk returns false when server draft stays dirty', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(_stagingDraftJson()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode(_stagingDraftJson(dirty: true, etag: '"e3"')),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/publish/read-only')) {
          return http.Response(
            jsonEncode(_stagingDraftJson(dirty: true, etag: '"e4"')),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        fail('unexpected ${request.method} ${request.url}');
      });

      var catalogRefreshCount = 0;
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith(
            (ref) => RemoteBackendConfig.devOwnerId,
          ),
          storyDraftRepositoryProvider.overrideWithValue(
            RemoteStoryDraftRepository(
              apiBaseUrl: 'http://127.0.0.1:9',
              client: client,
              authHeaderBuilder: () async => <String, String>{},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = StoryCreatorDraftNotifier(
        container.read(storyDraftRepositoryProvider),
        RemoteBackendConfig.devOwnerId,
        onProfileCatalogSurfacesChanged: () {
          catalogRefreshCount++;
        },
      );

      notifier.state = notifier.state.copyWith(
        draft: stagingStory(sentenceCount: 14),
      );

      final ok = await notifier.publishReadingOnlyToDisk();
      expect(ok, isFalse);
      expect(catalogRefreshCount, 0);
    });
  });
}
