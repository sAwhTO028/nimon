import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/features/profile/data/remote_user_follow_repository.dart';

void main() {
  test('followUser calls POST /v1/users/:id/follow', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'userId': 'u2',
          'isFollowing': true,
          'followersCount': 1,
          'followingCount': 2,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteUserFollowRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    final out = await repo.followUser('u2');
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/v1/users/u2/follow');
    expect(out.isFollowing, true);
  });

  test('unfollowUser calls DELETE /v1/users/:id/follow', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'userId': 'u2',
          'isFollowing': false,
          'followersCount': 0,
          'followingCount': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteUserFollowRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    final out = await repo.unfollowUser('u2');
    expect(captured!.method, 'DELETE');
    expect(captured!.url.path, '/v1/users/u2/follow');
    expect(out.isFollowing, false);
  });

  test('fetchFollowingPage hits /v1/me/following with cursor/limit', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'userId': 'u2',
              'handle': 'h',
              'displayName': 'D',
              'avatarUrl': null,
              'followedAt': '2026-01-01T00:00:00.000Z',
            }
          ],
          'nextCursor': 'next',
          'hasMore': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteUserFollowRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    final page = await repo.fetchFollowingPage(
      PageRequest(cursor: 'c', limit: 7, sort: 'recent'),
    );
    expect(captured!.url.path, '/v1/me/following');
    expect(captured!.url.queryParameters['cursor'], 'c');
    expect(captured!.url.queryParameters['limit'], isNotNull);
    expect(page.items.single.userId, 'u2');
    expect(page.nextCursor, 'next');
    expect(page.hasMore, true);
  });

  test('fetchFollowersPage hits /v1/users/:id/followers with cursor/limit',
      () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'userId': 'f1',
              'handle': 'h',
              'displayName': 'D',
              'avatarUrl': null,
              'followedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
          'nextCursor': 'z',
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteUserFollowRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => <String, String>{},
    );

    final page = await repo.fetchFollowersPage(
      'tid',
      PageRequest(cursor: 'c', limit: 7, sort: 'recent'),
    );
    expect(captured!.method, 'GET');
    expect(captured!.url.path, '/v1/users/tid/followers');
    expect(captured!.url.queryParameters['cursor'], 'c');
    expect(page.items.single.userId, 'f1');
    expect(page.nextCursor, 'z');
    expect(page.hasMore, false);
  });

  test('cannot_follow_self mapped to friendly message', () async {
    final client = MockClient((request) async {
      return http.Response('cannot_follow_self', 400);
    });
    final repo = RemoteUserFollowRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );
    await expectLater(
      repo.followUser('me'),
      throwsA(
        predicate(
            (e) => e is StateError && e.message.contains('follow yourself')),
      ),
    );
  });
}
