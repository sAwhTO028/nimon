import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetchPage attaches Authorization Bearer header', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[], 'nextCursor': null}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemotePublishedMonoRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer pub-token'},
    );

    await repo.list(limit: 10);

    expect(captured!.headers['authorization'], 'Bearer pub-token');
  });

  test('get 404 throws PublishedMonoHiddenWhileEditingException', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"published_mono_not_found"}', 404);
    });
    final repo = RemotePublishedMonoRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );
    await expectLater(
      repo.get('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
      throwsA(isA<PublishedMonoHiddenWhileEditingException>()),
    );
  });
}
