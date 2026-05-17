import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show StoryCreatorDraftStorage, StoryCreatorDraftResumeStorage;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('discardPublishedEditStaging (local)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StoryCreatorDraftStorage.clear();
    });

    test('returns true and removes staging draft; plain draft returns false',
        () async {
      const local = LocalStoryDraftRepository();
      final created = await local.createNewDraft();
      final uuid = const Uuid();
      final staging = created.copyWith(
        publishState: StoryPublishState.readingOnlyPublished,
        publishedMonoId: 'pm-99',
        sentences: [
          StorySentenceItem(
            id: uuid.v4(),
            storyId: created.id,
            orderIndex: 0,
            japaneseText: '雨が降る。',
          ),
        ],
      );
      await local.saveDraft(staging);

      expect(await local.discardPublishedEditStaging(created.id), isTrue);
      expect(await local.hasDraft(created.id), isFalse);
      expect(
        await StoryCreatorDraftResumeStorage.loadMeta(created.id),
        isNull,
      );

      final plain = await local.createNewDraft();
      expect(await local.discardPublishedEditStaging(plain.id), isFalse);
      expect(await local.hasDraft(plain.id), isTrue);
    });
  });

  group('discardPublishedEditStaging (remote)', () {
    const draftId = 'remote-staging-discard-1';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StoryCreatorDraftStorage.clear();
    });

    test('uses GET draft then DELETE story-drafts only (no published-mono)',
        () async {
      final httpCalls = <String>[];

      final client = MockClient((request) async {
        httpCalls.add('${request.method} ${request.url.path}');
        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode({
              'draftId': draftId,
              'etag': '"e1"',
              'schemaVersion': 1,
              'ownerId': RemoteBackendConfig.devOwnerId,
              'publishState': 'reading_only_published',
              'publishedMonoId': 'pm-1',
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
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response('', 204);
        }
        fail('unexpected ${request.method} ${request.url}');
      });

      final remote = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://127.0.0.1:9',
        client: client,
        authHeaderBuilder: () async => <String, String>{},
      );

      expect(await remote.discardPublishedEditStaging(draftId), isTrue);

      expect(
        httpCalls.where((c) => c.startsWith('GET ')),
        contains('GET /v1/story-drafts/$draftId'),
      );
      expect(
        httpCalls.where((c) => c.startsWith('DELETE ')),
        contains('DELETE /v1/story-drafts/$draftId'),
      );
      expect(
        httpCalls.any((c) => c.contains('published-monos')),
        isFalse,
      );
    });

    test(
        'discardPublishedEditStaging succeeds on DELETE even when body looks like quota (M20E cancel exempt)',
        () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode({
              'draftId': draftId,
              'etag': '"e1"',
              'schemaVersion': 1,
              'ownerId': RemoteBackendConfig.devOwnerId,
              'publishState': 'reading_only_published',
              'publishedMonoId': 'pm-1',
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
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response('', 204);
        }
        fail('unexpected ${request.method} ${request.url}');
      });

      final remote = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://127.0.0.1:9',
        client: client,
        authHeaderBuilder: () async => <String, String>{},
      );

      expect(await remote.discardPublishedEditStaging(draftId), isTrue);
    });
  });
}
