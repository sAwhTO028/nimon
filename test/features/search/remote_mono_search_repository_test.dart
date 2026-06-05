import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/search/data/remote_mono_search_repository.dart';

void main() {
  test('searchMonos sends q, level, category, sort, limit, cursor', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': <Object>[],
          'hasMore': false,
          'nextCursor': null,
          'totalCount': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    await repo.searchMonos(
      q: '  hello ',
      level: 'N3',
      category: ' culture ',
      sort: 'latest',
      limit: 25,
      cursor: 'abc',
    );

    expect(captured!.method, 'GET');
    expect(captured!.url.path, '/v1/search/monos');
    expect(captured!.url.queryParameters['q'], 'hello');
    expect(captured!.url.queryParameters['level'], 'N3');
    expect(captured!.url.queryParameters['category'], 'culture');
    expect(captured!.url.queryParameters['sort'], 'latest');
    expect(captured!.url.queryParameters['limit'], '25');
    expect(captured!.url.queryParameters['cursor'], 'abc');
  });

  test('searchMonos parses items, hasMore, nextCursor, totalCount', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'm1',
              'ownerId': 'o1',
              'title': 'T',
              'category': 'cat',
              'level': 'N5',
              'description': 'd',
              'publishKind': null,
              'displayPublishKind': 'read_only',
              'coverImageUrl': null,
              'targetDurationLabel': '1 min',
              'createdAt': '2020-01-01T00:00:00.000Z',
              'updatedAt': '2020-01-02T00:00:00.000Z',
              'contentSummary': null,
              'likesCount': 3,
              'isBookmarkedByMe': true,
              'myReaction': 'heart',
              'writerDisplayName': 'Writer',
              'writerHandle': 'w',
              'writerAvatarUrl': null,
              'shareUrl': 'https://example.com/mono/m1',
            },
          ],
          'hasMore': true,
          'nextCursor': 'next-token',
          'totalCount': 99,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    final page = await repo.searchMonos();
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'm1');
    expect(page.items.single.likesCount, 3);
    expect(page.items.single.isBookmarkedByMe, isTrue);
    expect(page.items.single.myReaction, 'heart');
    expect(page.items.single.shareUrl, 'https://example.com/mono/m1');
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'next-token');
    expect(page.totalCount, 99);
  });

  test('searchMonos works as guest without auth builder', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], isNull);
      return http.Response(
        jsonEncode({'items': <Object>[], 'hasMore': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    await expectLater(repo.searchMonos(), completes);
  });

  test('searchMonos merges Authorization when authHeaderBuilder returns token',
      () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[], 'hasMore': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer search-token'},
    );

    await repo.searchMonos(q: 'x');

    expect(captured!.headers['authorization'], 'Bearer search-token');
  });

  test('searchMonos clamps limit to max 50', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[], 'hasMore': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    await repo.searchMonos(limit: 999);
    expect(captured!.url.queryParameters['limit'], '50');
  });

  test('searchMonos sends catalog lens when authenticated', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[], 'hasMore': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer search-token'},
    );

    await repo.searchMonos(
      q: 'hello',
      catalogLens: const CatalogDiscoveryLens(
        contentLocale: 'my',
        learningLanguage: 'en',
      ),
    );

    expect(captured!.url.queryParameters['contentLocale'], 'my');
    expect(captured!.url.queryParameters['learningLanguage'], 'en');
    expect(captured!.url.queryParameters['q'], 'hello');
  });

  test('searchMonos omits catalog lens for guest', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[], 'hasMore': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    await repo.searchMonos(
      catalogLens: const CatalogDiscoveryLens(
        contentLocale: 'my',
        learningLanguage: 'en',
      ),
    );

    expect(captured!.url.queryParameters.containsKey('contentLocale'), isFalse);
    expect(captured!.url.queryParameters.containsKey('learningLanguage'), isFalse);
  });
}
