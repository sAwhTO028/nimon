import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';

Map<String, Object?> _fullSummaryRow(String id) => {
      'draftId': id,
      'title': 'T',
      'coverImageUrl': null,
      'level': 'n5',
      'category': 'drama',
      'status': 'draft',
      'publishState': 'draft',
      'processingStatus': null,
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'sentenceCount': 3,
      'publishType': 'draft',
      'previewText': 'Hi',
    };

void main() {
  group('DraftListSummaryDto', () {
    test('fromJson maps server summary row', () {
      final d = DraftListSummaryDto.fromJson(_fullSummaryRow('d1'));
      expect(d.draftId, 'd1');
      expect(d.title, 'T');
      expect(d.level, 'n5');
      expect(d.sentenceCount, 3);
      expect(d.publishState, 'draft');
    });
  });

  group('DraftListPageDto.parseEnvelope', () {
    test('legacy id-only items → interim capped path', () {
      final many = <Map<String, Object?>>[
        for (var i = 0; i < 30; i++) <String, Object?>{'draftId': 'id_$i'},
      ];
      final page = DraftListPageDto.parseEnvelope(<String, Object?>{
        'items': many,
        'nextCursor': 'should-be-ignored',
        'hasMore': true,
      });
      expect(page.items.length, 20);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
      expect(page.items.first.draftId, 'id_0');
    });

    test('full envelope maps cursors and flags', () {
      final page = DraftListPageDto.parseEnvelope(<String, Object?>{
        'items': [_fullSummaryRow('a')],
        'nextCursor': 'n1',
        'hasMore': true,
        'totalCount': 42,
      });
      expect(page.items.single.draftId, 'a');
      expect(page.nextCursor, 'n1');
      expect(page.hasMore, isTrue);
      expect(page.totalCount, 42);
    });
  });

  group('RemoteStoryDraftRepository.fetchWorkspaceDraftPage', () {
    test('maps PageRequest to query parameters', () async {
      Uri? seen;
      final repo = RemoteStoryDraftRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(
            jsonEncode(<String, Object?>{
              'items': [_fullSummaryRow('x')],
              'nextCursor': null,
              'hasMore': false,
              'totalCount': null,
            }),
            200,
          );
        }),
      );
      final dt = DateTime.utc(2026, 2, 1, 12);
      await repo.fetchWorkspaceDraftPage(
        PageRequest(
          cursor: 'cur',
          limit: 15,
          sort: 'latest',
          status: 'published',
          publishState: 'draft',
          updatedAfter: dt,
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.path, endsWith('/v1/story-drafts'));
      expect(seen!.queryParameters['cursor'], 'cur');
      expect(seen!.queryParameters['limit'], '15');
      expect(seen!.queryParameters['sort'], 'latest');
      expect(seen!.queryParameters['status'], 'published');
      expect(seen!.queryParameters['publishState'], 'draft');
      expect(
          seen!.queryParameters['updatedAfter'], dt.toUtc().toIso8601String());
    });

    test('returns PageResult from GET /v1/story-drafts', () async {
      final repo = RemoteStoryDraftRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'items': [_fullSummaryRow('z')],
              'nextCursor': 'next',
              'hasMore': true,
              'totalCount': null,
            }),
            200,
          ),
        ),
      );
      final page = await repo.fetchWorkspaceDraftPage(PageRequest(limit: 10));
      expect(page, isA<PageResult<DraftListSummaryDto>>());
      expect(page.items.single.draftId, 'z');
      expect(page.nextCursor, 'next');
      expect(page.hasMore, isTrue);
    });
  });
}
