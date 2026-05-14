import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';

Map<String, Object?> get _row => <String, Object?>{
      'id': 'pm_1',
      'ownerId': 'owner_1',
      'title': 'Hello',
      'category': 'Love',
      'level': 'N5',
      'description': 'Body',
      'displayPublishKind': 'read_only',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-02T00:00:00Z',
      'trashedAt': '2026-01-03T12:00:00Z',
    };

void main() {
  group('RemotePublishedMonoRepository trash APIs', () {
    test('fetchTrashedPage adds trashed=true', () async {
      Uri? seen;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((req) async {
          seen = req.url;
          return http.Response('{"items":[]}', 200);
        }),
      );
      await repo.fetchTrashedPage(PageRequest(limit: 15));
      expect(seen!.queryParameters['trashed'], 'true');
      expect(seen!.queryParameters['limit'], '15');
    });

    test('list item parses trashedAt', () async {
      final body = jsonEncode({
        'items': [_row]
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      final page = await repo.fetchTrashedPage(PageRequest(limit: 20));
      expect(page.items.single.trashedAt, '2026-01-03T12:00:00Z');
    });

    test('trashPublishedMono POSTs trash endpoint', () async {
      http.Request? cap;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode(
              {'id': 'pm_1', 'trashedAt': '2026-01-03T15:30:00.000Z'},
            ),
            200,
          );
        }),
      );
      final out = await repo.trashPublishedMono('pm_1');
      expect(out.id, 'pm_1');
      expect(out.trashedAt, '2026-01-03T15:30:00.000Z');
      expect(cap!.method, 'POST');
      expect(cap!.url.path, endsWith('/v1/published-monos/pm_1/trash'));
    });

    test('restorePublishedMono POSTs restore endpoint', () async {
      http.Request? cap;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((req) async {
          cap = req;
          return http.Response(
            jsonEncode({'id': 'pm_1', 'trashedAt': null}),
            200,
          );
        }),
      );
      final out = await repo.restorePublishedMono('pm_1');
      expect(out.id, 'pm_1');
      expect(out.trashedAt, isNull);
      expect(cap!.method, 'POST');
      expect(cap!.url.path, endsWith('/v1/published-monos/pm_1/restore'));
    });

    test('restore maps published_mono_not_trashed to friendly text', () async {
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'published_mono_not_trashed'}),
            400,
          ),
        ),
      );
      await expectLater(
        repo.restorePublishedMono('pm_1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not in Trash'),
          ),
        ),
      );
    });

    test('restore throws AppQuotaExceededException on 403 quota body',
        () async {
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(
            '{"code":"quota_exceeded","key":"published_mono_limit_reached","limit":30,"current":30}',
            403,
            headers: const {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        repo.restorePublishedMono('pm_1'),
        throwsA(isA<AppQuotaExceededException>()),
      );
    });

    test('permanent delete throws AppQuotaExceededException on 403 quota body',
        () async {
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(
            '{"code":"quota_exceeded","key":"published_mono_limit_reached","limit":30,"current":30}',
            403,
            headers: const {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        repo.permanentlyDeletePublishedMono('pm_1'),
        throwsA(isA<AppQuotaExceededException>()),
      );
    });
  });
}
