import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/remote_user_follow_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_followers_pager.dart';

void main() {
  test('ProfileFollowersPager loadFirstPage fills items', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/users/me-id/followers');
      return http.Response(
        jsonEncode({
          'items': [
            {
              'userId': 'x1',
              'handle': '@x',
              'displayName': 'X',
              'avatarUrl': null,
              'followedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
          'nextCursor': null,
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

    final pager = ProfileFollowersPager(repo, 'me-id');
    await pager.loadFirstPage();

    expect(pager.state.error, isNull);
    expect(pager.state.items.length, 1);
    expect(pager.state.items.single.userId, 'x1');
    expect(pager.state.isInitialLoading, false);
  });

  test('ProfileFollowersPager loadMore appends', () async {
    var call = 0;
    final client = MockClient((request) async {
      call++;
      if (call == 1) {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'userId': 'a',
                'handle': null,
                'displayName': 'A',
                'avatarUrl': null,
                'followedAt': '2026-01-02T00:00:00.000Z',
              },
            ],
            'nextCursor': 'cur',
            'hasMore': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.queryParameters['cursor'], 'cur');
      return http.Response(
        jsonEncode({
          'items': [
            {
              'userId': 'b',
              'handle': null,
              'displayName': 'B',
              'avatarUrl': null,
              'followedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
          'nextCursor': null,
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

    final pager = ProfileFollowersPager(repo, 'owner');
    await pager.loadFirstPage();
    await pager.loadMore();

    expect(pager.state.items.map((e) => e.userId).toList(), ['a', 'b']);
    expect(pager.state.hasMore, false);
  });
}
