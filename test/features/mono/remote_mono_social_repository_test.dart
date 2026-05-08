import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/features/mono/data/remote_mono_social_repository.dart';

void main() {
  test('bookmarkMono POST hits /v1/mono/:id/bookmark with auth', () async {
    http.BaseRequest? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'publishedMonoId': 'mid', 'isBookmarkedByMe': true}),
        200,
      );
    });
    final repo = RemoteMonoSocialRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer tok'},
    );
    final out = await repo.bookmarkMono('mid');
    expect(out, true);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/v1/mono/mid/bookmark');
    expect(captured!.headers['authorization'], 'Bearer tok');
  });

  test('unreactMono DELETE hits /v1/mono/:id/react and returns likesCount',
      () async {
    http.BaseRequest? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode(
            {'publishedMonoId': 'mid', 'likesCount': 12, 'myReaction': null}),
        200,
      );
    });
    final repo = RemoteMonoSocialRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer tok'},
    );
    final out = await repo.unreactMono('mid');
    expect(out, 12);
    expect(captured!.method, 'DELETE');
    expect(captured!.url.path, '/v1/mono/mid/react');
  });

  test('throws friendly sign-in required when auth header missing', () async {
    final client = MockClient((req) async => http.Response('{}', 200));
    final repo = RemoteMonoSocialRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => <String, String>{},
    );
    await expectLater(
      repo.bookmarkMono('mid'),
      throwsA(isA<StateError>()),
    );
  });

  test('fetchBookmarkedPage GET hits /v1/me/bookmarks and maps MonoFeedItem',
      () async {
    http.BaseRequest? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'monoId': 'mid',
              'title': 'T',
              'coverUrl': null,
              'level': 'N5',
              'category': '',
              'categories': <String>[],
              'description': 'D',
              'writerId': 'u1',
              'writerHandle': '@h',
              'writerDisplayName': 'Name',
              'publishedAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-02T00:00:00.000Z',
              'likesCount': 2,
              'hasAudio': false,
              'isBookmarkedByMe': true,
              'myReaction': 'heart',
              'shareUrl': 'http://localhost:3000/mono/mid',
              'publishKind': 'read_only_v1',
              'accessType': 'public',
            }
          ],
          'nextCursor': 'next',
          'hasMore': true,
        }),
        200,
      );
    });
    final repo = RemoteMonoSocialRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer tok'},
    );
    final page = await repo.fetchBookmarkedPage(
      PageRequest(limit: 15, cursor: 'abc'),
    );
    expect(captured!.method, 'GET');
    expect(captured!.url.path, '/v1/me/bookmarks');
    expect(captured!.url.queryParameters['cursor'], 'abc');
    expect(captured!.url.queryParameters['limit'], '15');
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'mid');
    expect(page.items.single.isBookmarkedByMe, true);
    expect(page.items.single.likesCount, 2);
    expect(page.nextCursor, 'next');
    expect(page.hasMore, true);
  });
}
