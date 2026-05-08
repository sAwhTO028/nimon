import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';

Map<String, Object?> get _minimalPublishedRow => <String, Object?>{
      'id': 'pm_1',
      'ownerId': 'owner_1',
      'title': 'Hello',
      'category': 'Love',
      'level': 'N5',
      'description': 'Body',
      'displayPublishKind': 'read_only',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-02T00:00:00Z',
    };

PublishedMonoListItemDto get _minimalDto => PublishedMonoListItemDto(
      id: 'pm_1',
      ownerId: 'owner_1',
      sourceDraftId: null,
      title: 'Hello',
      category: 'Love',
      level: 'N5',
      description: 'Body',
      publishKind: null,
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-02T00:00:00Z',
      contentSummary: null,
    );

class _StubPublishedMonoRepository extends RemotePublishedMonoRepository {
  _StubPublishedMonoRepository(this._fetch)
      : super(
          apiBaseUrl: 'http://stub.test',
          client: MockClient(
            (_) async => http.Response('internal: use fetchPage override', 500),
          ),
        );

  final Future<PageResult<PublishedMonoListItemDto>> Function(PageRequest r)
      _fetch;

  @override
  Future<PageResult<PublishedMonoListItemDto>> fetchPage(PageRequest request) {
    return _fetch(request);
  }
}

void main() {
  group('RemotePublishedMonoRepository.fetchPage', () {
    test('legacy JSON {"items":[...]} → PageResult hasMore false', () async {
      final body = jsonEncode({
        'items': [_minimalPublishedRow],
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 20));
      expect(page.items, hasLength(1));
      expect(page.items.single.id, 'pm_1');
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
      expect(page.totalCount, isNull);
    });

    test('paginated JSON envelope maps nextCursor, hasMore, totalCount',
        () async {
      final body = jsonEncode({
        'items': [_minimalPublishedRow],
        'nextCursor': 'opaque-next',
        'hasMore': true,
        'totalCount': 100,
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 20));
      expect(page.items, hasLength(1));
      expect(page.nextCursor, 'opaque-next');
      expect(page.hasMore, isTrue);
      expect(page.totalCount, 100);
    });

    test('maps PageRequest to query parameters', () async {
      Uri? seen;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient((req) async {
          seen = req.url;
          return http.Response('{"items":[]}', 200);
        }),
      );
      await repo.fetchPage(
        PageRequest(cursor: 'abc-9', limit: 20),
      );
      expect(seen, isNotNull);
      expect(seen!.path, endsWith('/v1/published-monos'));
      expect(seen!.queryParameters['cursor'], 'abc-9');
      expect(seen!.queryParameters['limit'], '20');
      expect(seen!.queryParameters['sort'], isNotNull);
    });
  });

  group('ProfilePublishedMonoPager', () {
    test('loadFirstPage loads items', () async {
      final stub = _StubPublishedMonoRepository((_) async {
        return PageResult<PublishedMonoListItemDto>(
          items: [_minimalDto],
          nextCursor: null,
          hasMore: false,
        );
      });
      final pager = ProfilePublishedMonoPager(stub);
      await pager.loadFirstPage();
      expect(pager.state.items, hasLength(1));
      expect(pager.state.isInitialLoading, isFalse);
      expect(pager.state.hasMore, isFalse);
    });

    test('loadMore appends when hasMore', () async {
      final second = PublishedMonoListItemDto(
        id: 'pm_2',
        ownerId: 'owner_1',
        sourceDraftId: null,
        title: 'Two',
        category: 'Love',
        level: 'N4',
        description: 'd2',
        publishKind: null,
        displayPublishKind: 'read_only',
        coverImageUrl: null,
        targetDurationLabel: null,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-02T00:00:00Z',
        contentSummary: null,
      );
      var calls = 0;
      final stub = _StubPublishedMonoRepository((r) async {
        calls++;
        if (calls == 1) {
          expect(r.cursor, isNull);
          return PageResult<PublishedMonoListItemDto>(
            items: [_minimalDto],
            nextCursor: 'c2',
            hasMore: true,
          );
        }
        expect(r.cursor, 'c2');
        return PageResult<PublishedMonoListItemDto>(
          items: [second],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      await n.loadMore();
      expect(n.state.items.map((e) => e.id).toList(), ['pm_1', 'pm_2']);
      expect(n.state.hasMore, isFalse);
      expect(calls, 2);
    });

    test('loadMore is a no-op when hasMore is false', () async {
      var calls = 0;
      final stub = _StubPublishedMonoRepository((_) async {
        calls++;
        return PageResult<PublishedMonoListItemDto>(
          items: [_minimalDto],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      await n.loadMore();
      expect(calls, 1);
    });

    test('refresh resets and replaces items', () async {
      var calls = 0;
      final stub = _StubPublishedMonoRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<PublishedMonoListItemDto>(
            items: [_minimalDto],
            nextCursor: 'old',
            hasMore: true,
          );
        }
        expect(r.cursor, isNull);
        return PageResult<PublishedMonoListItemDto>(
          items: [
            PublishedMonoListItemDto(
              id: 'pm_x',
              ownerId: 'owner_1',
              sourceDraftId: null,
              title: 'Fresh',
              category: 'Love',
              level: 'N5',
              description: 'd',
              publishKind: null,
              displayPublishKind: 'read_only',
              coverImageUrl: null,
              targetDurationLabel: null,
              createdAt: '2026-01-01T00:00:00Z',
              updatedAt: '2026-01-02T00:00:00Z',
              contentSummary: null,
            ),
          ],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      expect(n.state.nextCursor, 'old');
      await n.refresh();
      expect(n.state.items.single.id, 'pm_x');
      expect(n.state.nextCursor, isNull);
      expect(n.state.hasMore, isFalse);
      expect(calls, 2);
    });

    test(
        'stale loadFirstPage does not leave isInitialLoading true after refresh',
        () async {
      final hold = Completer<void>();
      var calls = 0;
      final stub = _StubPublishedMonoRepository((_) async {
        calls++;
        if (calls == 1) {
          await hold.future;
          return PageResult<PublishedMonoListItemDto>(
            items: const [],
            nextCursor: null,
            hasMore: false,
          );
        }
        return PageResult<PublishedMonoListItemDto>(
          items: [_minimalDto],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      final slowFirst = n.loadFirstPage();
      await n.refresh();
      hold.complete();
      await slowFirst;
      await pumpEventQueue();
      expect(n.state.isInitialLoading, isFalse);
      expect(n.state.isRefreshing, isFalse);
      expect(n.state.items, hasLength(1));
    });

    test('stale loadMore result ignored after refresh bumps epoch', () async {
      final hold = Completer<void>();
      var calls = 0;
      final stub = _StubPublishedMonoRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<PublishedMonoListItemDto>(
            items: [_minimalDto],
            nextCursor: 'c1',
            hasMore: true,
          );
        }
        if (calls == 2) {
          await hold.future;
          return PageResult<PublishedMonoListItemDto>(
            items: [
              PublishedMonoListItemDto(
                id: 'pm_stale',
                ownerId: 'o',
                sourceDraftId: null,
                title: 'Stale',
                category: 'c',
                level: 'N5',
                description: 'd',
                publishKind: null,
                displayPublishKind: 'read_only',
                coverImageUrl: null,
                targetDurationLabel: null,
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-02T00:00:00Z',
                contentSummary: null,
              ),
            ],
            nextCursor: null,
            hasMore: false,
          );
        }
        return PageResult<PublishedMonoListItemDto>(
          items: [
            PublishedMonoListItemDto(
              id: 'pm_fresh',
              ownerId: 'o',
              sourceDraftId: null,
              title: 'Fresh',
              category: 'c',
              level: 'N5',
              description: 'd',
              publishKind: null,
              displayPublishKind: 'read_only',
              coverImageUrl: null,
              targetDurationLabel: null,
              createdAt: '2026-01-01T00:00:00Z',
              updatedAt: '2026-01-02T00:00:00Z',
              contentSummary: null,
            ),
          ],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      expect(calls, 1);
      final slowMore = n.loadMore();
      await n.refresh();
      hold.complete();
      await slowMore;
      await pumpEventQueue();
      expect(n.state.items.map((e) => e.id).toList(), ['pm_fresh']);
      expect(n.state.isLoadingMore, isFalse);
    });
  });
}
