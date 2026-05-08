import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/mono/data/remote_mono_feed_repository.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';

void main() {
  test(
      'fetchFeedPage builds /v1/mono/feed query with limit, cursor, level, category',
      () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': <Object>[],
          'nextCursor': null,
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    await repo.fetchFeedPage(
      PageRequest(
        cursor: 'abc',
        limit: 15,
        sort: 'recent',
      ),
      level: 'N4',
      category: 'Culture',
    );

    final uri = captured!.url;
    expect(uri.path, '/v1/mono/feed');
    expect(uri.queryParameters['limit'], isNotNull);
    expect(uri.queryParameters['sort'], 'recent');
    expect(uri.queryParameters['cursor'], 'abc');
    expect(uri.queryParameters['level'], 'N4');
    expect(uri.queryParameters['category'], 'Culture');
  });

  test('fetchFeedPage maps envelope to PageResult', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'monoId': 'id1',
              'title': 'Hello',
              'coverUrl': null,
              'level': 'N5',
              'category': '',
              'categories': <String>[],
              'description': '',
              'writerId': 'u1',
              'writerHandle': '',
              'writerDisplayName': '',
              'publishedAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-02T00:00:00.000Z',
              'likesCount': 0,
              'hasAudio': false,
              'isBookmarkedByMe': false,
              'myReaction': null,
              'shareUrl': null,
              'publishKind': '',
              'accessType': 'public',
            },
          ],
          'nextCursor': 'next',
          'hasMore': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    final page = await repo.fetchFeedPage(
      PageRequest(limit: 15, sort: 'recent'),
    );

    expect(page.items, hasLength(1));
    expect(page.items.single, isA<MonoFeedSummaryDto>());
    expect(page.items.single.monoId, 'id1');
    expect(page.nextCursor, 'next');
    expect(page.hasMore, true);
  });

  test('fetchMonoDetail hits /v1/mono/:id', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': 'mid',
          'ownerId': 'oid',
          'title': 't',
          'category': '',
          'level': '',
          'description': '',
          'displayPublishKind': 'read_only',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-02T00:00:00.000Z',
          'content': {'x': 1},
          'likesCount': 5,
          'isBookmarkedByMe': true,
          'myReaction': 'heart',
          'shareUrl': 'http://localhost:3000/mono/mid',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );

    final d = await repo.fetchMonoDetail('mid');
    expect(captured!.url.path, '/v1/mono/mid');
    expect(d.id, 'mid');
    expect(d.content, {'x': 1});
    expect(d.likesCount, 5);
    expect(d.isBookmarkedByMe, true);
    expect(d.myReaction, 'heart');
    expect(d.shareUrl, 'http://localhost:3000/mono/mid');
  });

  test('fetchMonoDetail 404 throws PublishedMonoHiddenWhileEditingException',
      () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"published_mono_not_found"}', 404);
    });
    final repo = RemoteMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
    );
    await expectLater(
      repo.fetchMonoDetail('mid'),
      throwsA(isA<PublishedMonoHiddenWhileEditingException>()),
    );
  });

  test('optional auth headers merged when builder returns Bearer', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[], 'hasMore': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer tok'},
    );

    await repo.fetchFeedPage(PageRequest(limit: 15, sort: 'recent'));
    expect(captured!.headers['authorization'], 'Bearer tok');
  });
}
