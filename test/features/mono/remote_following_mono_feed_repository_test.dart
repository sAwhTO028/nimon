import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/features/mono/data/remote_following_mono_feed_repository.dart';

void main() {
  test('fetchFeedPage adds following=true and requires auth', () async {
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

    final repo = RemoteFollowingMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    await repo.fetchFeedPage(PageRequest(limit: 15, sort: 'recent'));

    final uri = captured!.url;
    expect(uri.path, '/v1/mono/feed');
    expect(uri.queryParameters['following'], 'true');
    expect(captured!.headers['Authorization'], 'Bearer t');
  });

  test('fetchFeedPage when unauthenticated throws StateError', () async {
    final repo = RemoteFollowingMonoFeedRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: MockClient((_) async => http.Response('no', 200)),
      authHeaderBuilder: () async => <String, String>{},
    );

    await expectLater(
      repo.fetchFeedPage(PageRequest(limit: 15, sort: 'recent')),
      throwsA(isA<StateError>()),
    );
  });
}
