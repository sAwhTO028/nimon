import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';

Future<Map<String, String>> _auth() async =>
    <String, String>{'Authorization': 'Bearer t'};

Map<String, Object?> _collRow(String id) => {
      'id': id,
      'ownerId': 'owner',
      'title': 'T',
      'description': null,
      'coverImageUrl': null,
      'visibility': 'public',
      'itemCount': 1,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
    };

void main() {
  group('RemoteCreatorCollectionsRepository', () {
    test('fetchMyCollections GET /v1/me/creator-collections', () async {
      http.Request? cap;
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode({
              'collections': [_collRow('c1')],
            }),
            200,
          );
        }),
      );
      final list = await repo.fetchMyCollections();
      expect(cap!.method, 'GET');
      expect(cap!.url.path, endsWith('/v1/me/creator-collections'));
      expect(list.single.id, 'c1');
    });

    test(
        'createCollection 400 validation_failed → HttpValidationFailedException',
        () async {
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'statusCode': 400,
              'message': 'validation_failed',
              'issues': [
                {
                  'code': 'collection.title.required',
                  'field': 'collection.title',
                  'messageKey': 'collection.title.required',
                  'severity': 'blocking',
                  'source': 'collection-validation',
                },
              ],
            }),
            400,
          ),
        ),
      );
      await expectLater(
        repo.createCollection(title: ''),
        throwsA(isA<HttpValidationFailedException>()),
      );
    });

    test('createCollection POST title + parses collection envelope', () async {
      http.Request? cap;
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode({'collection': _collRow('new-id')}),
            201,
          );
        }),
      );
      final c = await repo.createCollection(title: ' Hello ');
      expect(cap!.method, 'POST');
      expect(cap!.url.path, endsWith('/v1/me/creator-collections'));
      expect(
          (jsonDecode(cap!.body) as Map<String, dynamic>)['title'], ' Hello ');
      expect(c.id, 'new-id');
    });

    test('bulkAddItems POST items/bulk with publishedMonoIds array', () async {
      http.Request? cap;
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode({
              'inserted': 1,
              'skippedDuplicates': 0,
              'skippedNotOwnedOrMissing': 0,
            }),
            200,
          );
        }),
      );
      final r = await repo.bulkAddItems('col-1', ['a', 'b']);
      expect(cap!.method, 'POST');
      expect(
        cap!.url.path,
        endsWith('/v1/me/creator-collections/col-1/items/bulk'),
      );
      final body = jsonDecode(cap!.body) as Map<String, dynamic>;
      expect(body['publishedMonoIds'], ['a', 'b']);
      expect(r.inserted, 1);
    });

    test('403 not_owner_of_published_mono → friendly StateError', () async {
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'not_owner_of_published_mono'}),
            403,
          ),
        ),
      );
      expect(
        () => repo.bulkAddItems('c', ['x']),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'You can only add your own published stories.',
          ),
        ),
      );
    });

    test('401 → Sign in required', () async {
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient(
          (_) async => http.Response('{"message":"Unauthorized"}', 401),
        ),
      );
      expect(
        () => repo.fetchMyCollections(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Sign in required.',
          ),
        ),
      );
    });

    test('updateCollection PATCH /v1/me/creator-collections/:id', () async {
      http.Request? cap;
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode({'collection': _collRow('c1')..['title'] = 'New'}),
            200,
          );
        }),
      );
      await repo.updateCollection('c1', title: 'New');
      expect(cap!.method, 'PATCH');
      expect(cap!.url.path, endsWith('/v1/me/creator-collections/c1'));
      expect((jsonDecode(cap!.body) as Map<String, dynamic>)['title'], 'New');
    });

    test('deleteCollection maps 409 collection_not_empty to friendly message',
        () async {
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: _auth,
        client: MockClient(
          (_) async => http.Response(
              jsonEncode({'message': 'collection_not_empty'}), 409),
        ),
      );
      expect(
        () => repo.deleteCollection('c1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Remove all stories before deleting this collection.',
          ),
        ),
      );
    });

    test(
      'fetchPublicCollections GET /v1/users/:userId/creator-collections',
      () async {
        http.Request? cap;
        final repo = RemoteCreatorCollectionsRepository(
          apiBaseUrl: 'https://api.example',
          authHeaderBuilder: _auth,
          client: MockClient((req) async {
            cap = req;
            return http.Response(
              jsonEncode({
                'collections': [_collRow('pub1')],
              }),
              200,
            );
          }),
        );
        final list = await repo.fetchPublicCollections('user-xyz');
        expect(cap!.method, 'GET');
        expect(
          cap!.url.path,
          endsWith('/v1/users/user-xyz/creator-collections'),
        );
        expect(list.single.id, 'pub1');
        expect(list.single.itemCount, 1);
      },
    );

    test(
      'fetchPublicCollectionMonos GET .../creator-collections/:id/monos '
      'with cursor + limit',
      () async {
        http.Request? cap;
        final repo = RemoteCreatorCollectionsRepository(
          apiBaseUrl: 'https://api.example',
          authHeaderBuilder: _auth,
          client: MockClient((req) async {
            cap = req;
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'mono-a',
                    'ownerId': 'user-xyz',
                    'title': 'T',
                    'category': '',
                    'level': 'N5',
                    'description': '',
                    'displayPublishKind': 'read_only',
                    'createdAt': '2026-01-01T00:00:00.000Z',
                    'updatedAt': '2026-01-02T00:00:00.000Z',
                  },
                ],
                'nextCursor': 'next-c',
              }),
              200,
            );
          }),
        );
        final page = await repo.fetchPublicCollectionMonos(
          'user-xyz',
          'col-99',
          cursor: 'c1',
          limit: 12,
        );
        expect(cap!.method, 'GET');
        expect(
          cap!.url.path,
          endsWith(
            '/v1/users/user-xyz/creator-collections/col-99/monos',
          ),
        );
        expect(cap!.url.queryParameters['cursor'], 'c1');
        expect(cap!.url.queryParameters['limit'], '12');
        expect(page.items.single.id, 'mono-a');
        expect(page.nextCursor, 'next-c');
      },
    );

    test('fetchPublicCollections works when auth builder is empty (guest)',
        () async {
      http.Request? cap;
      final repo = RemoteCreatorCollectionsRepository(
        apiBaseUrl: 'https://api.example',
        authHeaderBuilder: () async => <String, String>{},
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode({'collections': const <Object>[]}),
            200,
          );
        }),
      );
      final list = await repo.fetchPublicCollections('guest-user');
      expect(list, isEmpty);
      expect(cap!.headers['Authorization'], isNull);
    });
  });
}
