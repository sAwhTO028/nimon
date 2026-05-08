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

Map<String, Object?> _minimalWire({
  required String draftId,
  required String etag,
  String? publishedMonoId,
  String publishState = 'draft',
}) {
  return {
    'draftId': draftId,
    'etag': etag,
    'schemaVersion': 1,
    'ownerId': RemoteBackendConfig.devOwnerId,
    'publishState': publishState,
    if (publishedMonoId != null) 'publishedMonoId': publishedMonoId,
    'basics': {
      'storyId': draftId,
      'ownerId': RemoteBackendConfig.devOwnerId,
      'title': 'Smoke title',
      'category': 'fiction',
      'level': 'N4',
      'description': 'Smoke desc',
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
      'vocabulary_kanji': 'completed',
      'grammar': 'completed',
      'quiz': 'completed',
      'audio': 'completed',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full learn publish without publishedMonoId', () {
    const draftId = 'seq-draft-1';

    late CreatorStoryV1 fullLearnDraft;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final uuid = const Uuid();
      final empty = CreatorStoryV1.empty(
        creatorOwnerId: RemoteBackendConfig.devOwnerId,
      );
      // Force stable id for URLs in the mock.
      fullLearnDraft = empty.copyWith(
        basics: empty.basics.copyWith(storyId: draftId),
        sentences: [
          StorySentenceItem(
            id: uuid.v4(),
            storyId: draftId,
            orderIndex: 0,
            japaneseText: '雨が降る。',
          ),
        ],
        moduleWorkflowStatuses: {
          for (final k in LearnModuleId.values)
            k: LearnModuleTaskStatus.completed,
        },
        publishState: StoryPublishState.fullLearnPublished,
      );
    });

    test('saveDraft runs read-only publish then full-learn publish', () async {
      final calls = <String>[];

      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        calls.add(key);

        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-get-1',
              publishState: 'draft',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-put-2',
              publishState: 'draft',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path
                .endsWith('/v1/story-drafts/$draftId/publish/read-only')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-ro-3',
              publishedMonoId: 'pm-new',
              publishState: 'reading_only_published',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path
                .endsWith('/v1/story-drafts/$draftId/publish/full-learn')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-fl-4',
              publishedMonoId: 'pm-new',
              publishState: 'full_learn_published',
            )),
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

      final out = await repo.saveDraft(
        fullLearnDraft,
        remotePublishAfterPut: StoryDraftRemotePublishIntent.fullLearn,
      );
      expect(out.publishState, StoryPublishState.fullLearnPublished);

      expect(
        calls,
        containsAllInOrder(<String>[
          'GET /v1/story-drafts/$draftId',
          'PUT /v1/story-drafts/$draftId',
          'POST /v1/story-drafts/$draftId/publish/read-only',
          'POST /v1/story-drafts/$draftId/publish/full-learn',
        ]),
      );
    });

    test('when read-only publish fails, full-learn is not requested', () async {
      final calls = <String>[];

      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        calls.add(key);

        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-get-1',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-put-2',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path
                .endsWith('/v1/story-drafts/$draftId/publish/read-only')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'unprocessable_entity',
                'message': 'Read-only publish requirements not met',
                'details': {
                  'unmet': ['sentence_0_invalid']
                },
              },
            }),
            422,
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

      // Default test VM has strict remote drafts off: repo falls back to local
      // after the failed read-only POST, but must never continue to full-learn.
      final out = await repo.saveDraft(
        fullLearnDraft,
        remotePublishAfterPut: StoryDraftRemotePublishIntent.fullLearn,
      );
      expect(out.id, fullLearnDraft.id);
      expect(calls.any((c) => c.contains('publish/read-only')), isTrue);
      expect(calls.any((c) => c.contains('publish/full-learn')), isFalse);
    });

    test('skips read-only when PUT body already has publishedMonoId', () async {
      final calls = <String>[];

      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        calls.add(key);

        if (request.method == 'GET' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-get-1',
              publishedMonoId: 'pm-existing',
              publishState: 'reading_only_published',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'PUT' &&
            request.url.path.endsWith('/v1/story-drafts/$draftId')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-put-2',
              publishedMonoId: 'pm-existing',
              publishState: 'reading_only_published',
            )),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path
                .endsWith('/v1/story-drafts/$draftId/publish/full-learn')) {
          return http.Response(
            jsonEncode(_minimalWire(
              draftId: draftId,
              etag: 'etag-fl-3',
              publishedMonoId: 'pm-existing',
              publishState: 'full_learn_published',
            )),
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
        fullLearnDraft,
        remotePublishAfterPut: StoryDraftRemotePublishIntent.fullLearn,
      );

      expect(calls.any((c) => c.contains('publish/read-only')), isFalse);
      expect(
        calls,
        contains('POST /v1/story-drafts/$draftId/publish/full-learn'),
      );
    });
  });
}
