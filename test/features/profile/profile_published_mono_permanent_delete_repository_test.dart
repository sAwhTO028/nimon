import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';

void main() {
  group('RemotePublishedMonoRepository permanent delete', () {
    test('DELETEs endpoint with confirm body', () async {
      http.Request? cap;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((req) async {
          cap = req;
          return http.Response('', 204);
        }),
      );

      await repo.permanentlyDeletePublishedMono('pm_1');
      expect(cap!.method, 'DELETE');
      expect(cap!.url.path, endsWith('/v1/published-monos/pm_1/permanent'));
      expect(jsonDecode(cap!.body), {'confirm': 'DELETE'});
    });

    test('404 maps to already deleted message', () async {
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({'message': 'published_mono_not_found'}),
            404,
          );
        }),
      );

      await expectLater(
        repo.permanentlyDeletePublishedMono('pm_1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already deleted'),
          ),
        ),
      );
    });

    test('must be trashed maps to friendly message', () async {
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({'message': 'published_mono_must_be_trashed_first'}),
            400,
          );
        }),
      );

      await expectLater(
        repo.permanentlyDeletePublishedMono('pm_1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Move this story to Trash first'),
          ),
        ),
      );
    });
  });
}
