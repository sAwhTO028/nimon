import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Staging save (no auto-publish)', () {
    const draftId = 'staging-draft-1';

    test(
        'reading_only_published draft + intent none only PUTs (no publish POST)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final uuid = const Uuid();
      final empty = CreatorStoryV1.empty(
        creatorOwnerId: RemoteBackendConfig.devOwnerId,
      );
      final publishedDraft = empty.copyWith(
        basics: empty.basics.copyWith(storyId: draftId),
        sentences: [
          StorySentenceItem(
            id: uuid.v4(),
            storyId: draftId,
            orderIndex: 0,
            japaneseText: '雨が降る。',
          ),
        ],
        publishState: StoryPublishState.readingOnlyPublished,
      );

      final calls = <String>[];

      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        calls.add(key);

        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode({
              'draftId': draftId,
              'etag': '"v3"',
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

        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['publishState'], isNot('draft'));
          return http.Response(
            jsonEncode({
              'draftId': draftId,
              'etag': '"v4"',
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

        fail('unexpected request: $key');
      });

      final repo = RemoteStoryDraftRepository(
        apiBaseUrl: 'http://127.0.0.1:9',
        client: client,
        fallbackLocal: const LocalStoryDraftRepository(),
      );

      await repo.saveDraft(
        publishedDraft,
        remotePublishAfterPut: StoryDraftRemotePublishIntent.none,
      );

      expect(
        calls,
        containsAllInOrder(<String>[
          'GET /v1/story-drafts/$draftId',
          'PUT /v1/story-drafts/$draftId',
        ]),
      );
      expect(calls.any((c) => c.contains('publish/read-only')), isFalse);
      expect(calls.any((c) => c.contains('publish/full-learn')), isFalse);
    });
  });
}
