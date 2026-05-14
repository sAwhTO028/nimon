import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';

Map<String, Object?> publishedMonoListJsonRow(String id, int updatedMs) {
  return <String, Object?>{
    'id': id,
    'ownerId': 'owner_1',
    'title': 'T$id',
    'category': 'Love',
    'level': 'N5',
    'description': 'Body',
    'displayPublishKind': 'read_only',
    'createdAt': '2026-01-01T00:00:00Z',
    'updatedAt': DateTime.fromMillisecondsSinceEpoch(updatedMs, isUtc: true)
        .toIso8601String(),
  };
}

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

    test('paginated JSON envelope maps hasMore when sent as int 1', () async {
      final body = jsonEncode({
        'items': [_minimalPublishedRow],
        'nextCursor': 'opaque-next',
        'hasMore': 1,
        'totalCount': 100,
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 20));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque-next');
      expect(page.totalCount, 100);
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

    test('M17C: unwraps data envelope and snake_case pagination fields',
        () async {
      final body = jsonEncode({
        'data': {
          'items': List<Map<String, Object?>>.generate(
            10,
            (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
          ),
          'has_more': true,
          'next_cursor': 'opaque-c1',
          'total_count': 21,
        },
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 10));
      expect(page.items, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque-c1');
      expect(page.totalCount, 21);
    });

    test('M17C: pagination map supplies missing top-level fields', () async {
      final body = jsonEncode({
        'items': [_minimalPublishedRow],
        'pagination': {
          'hasMore': true,
          'nextCursor': 'from-pagination',
          'totalCount': 42,
        },
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 20));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'from-pagination');
      expect(page.totalCount, 42);
    });

    test('M17C-4: top-level items plus sibling data map pagination', () async {
      final items = List<Map<String, Object?>>.generate(
        10,
        (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
      );
      final body = jsonEncode(<String, Object?>{
        'items': items,
        'data': <String, Object?>{
          'hasMore': true,
          'nextCursor': 'opaque-c1',
          'totalCount': 21,
        },
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 10));
      expect(page.items, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque-c1');
      expect(page.totalCount, 21);
    });

    test('M17C-4: meta map fills pagination when top-level omits it', () async {
      final items = List<Map<String, Object?>>.generate(
        10,
        (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
      );
      final body = jsonEncode(<String, Object?>{
        'items': items,
        'meta': <String, Object?>{
          'hasMore': true,
          'nextCursor': 'opaque-c1',
          'totalCount': 21,
        },
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 10));
      expect(page.items, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque-c1');
      expect(page.totalCount, 21);
    });

    test('M17C-4: data array plus meta snake_case pagination', () async {
      final items = List<Map<String, Object?>>.generate(
        10,
        (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
      );
      final body = jsonEncode(<String, Object?>{
        'data': items,
        'meta': <String, Object?>{
          'has_more': true,
          'next_cursor': 'opaque-c1',
          'total_count': 21,
        },
      });
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'https://api.example',
        client: MockClient(
          (_) async => http.Response(body, 200),
        ),
      );
      final page = await repo.fetchPage(PageRequest(limit: 10));
      expect(page.items, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque-c1');
      expect(page.totalCount, 21);
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
    test('M17C-2: backend envelope three pages via cursor (limit 10)',
        () async {
      var call = 0;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient((req) async {
          call++;
          expect(req.url.path, endsWith('/v1/published-monos'));
          if (call == 1) {
            expect(req.url.queryParameters['cursor'], isNull);
            expect(
              req.url.queryParameters['limit'],
              '${PaginationDefaults.profilePublishedMonoPageLimit}',
            );
            final items = List<Map<String, Object?>>.generate(
              10,
              (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'items': items,
                'nextCursor': 'opaque-c1',
                'hasMore': true,
                'totalCount': 21,
              }),
              200,
            );
          }
          if (call == 2) {
            expect(req.url.queryParameters['cursor'], 'opaque-c1');
            final items = List<Map<String, Object?>>.generate(
              10,
              (i) => publishedMonoListJsonRow('m-${10 + i}', 2000 + i),
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'items': items,
                'nextCursor': 'opaque-c2',
                'hasMore': true,
              }),
              200,
            );
          }
          expect(req.url.queryParameters['cursor'], 'opaque-c2');
          return http.Response(
            jsonEncode(<String, Object?>{
              'items': [publishedMonoListJsonRow('m-20', 1000)],
              'nextCursor': null,
              'hasMore': false,
            }),
            200,
          );
        }),
      );

      final first = await repo.fetchPage(
        PageRequest(limit: PaginationDefaults.profilePublishedMonoPageLimit),
      );
      expect(first.items, hasLength(10));
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, 'opaque-c1');
      expect(first.totalCount, 21);

      final second = await repo.fetchPage(
        PageRequest(
          cursor: first.nextCursor,
          limit: PaginationDefaults.profilePublishedMonoPageLimit,
        ),
      );
      expect(second.items, hasLength(10));
      expect(second.hasMore, isTrue);
      expect(second.nextCursor, 'opaque-c2');

      final third = await repo.fetchPage(
        PageRequest(
          cursor: second.nextCursor,
          limit: PaginationDefaults.profilePublishedMonoPageLimit,
        ),
      );
      expect(third.items.single.id, 'm-20');
      expect(third.hasMore, isFalse);
      expect(third.nextCursor, isNull);
      expect(call, 3);
    });
  });

  group('ProfilePublishedMonoPager', () {
    test('M17C-2: end-to-end pager three fetches for 21 items (limit 10)',
        () async {
      var call = 0;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient((req) async {
          call++;
          if (call == 1) {
            final items = List<Map<String, Object?>>.generate(
              10,
              (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'items': items,
                'nextCursor': 'opaque-c1',
                'hasMore': true,
                'totalCount': 21,
              }),
              200,
            );
          }
          if (call == 2) {
            final items = List<Map<String, Object?>>.generate(
              10,
              (i) => publishedMonoListJsonRow('m-${10 + i}', 2000 + i),
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'items': items,
                'nextCursor': 'opaque-c2',
                'hasMore': true,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'items': [publishedMonoListJsonRow('m-20', 1000)],
              'nextCursor': null,
              'hasMore': false,
            }),
            200,
          );
        }),
      );
      final pager = ProfilePublishedMonoPager(repo);
      await pager.loadFirstPage();
      expect(pager.state.items, hasLength(10));
      expect(pager.state.hasMore, isTrue);
      await pager.loadMore();
      expect(pager.state.items, hasLength(20));
      expect(pager.state.hasMore, isTrue);
      await pager.loadMore();
      expect(pager.state.items, hasLength(21));
      expect(pager.state.items.last.id, 'm-20');
      expect(pager.state.hasMore, isFalse);
      expect(call, 3);
    });

    test('M17C-5: chained loadMore keeps totalCount and canLoadMore between pages',
        () async {
      var call = 0;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient((req) async {
          call++;
          if (call == 1) {
            final items = List<Map<String, Object?>>.generate(
              10,
              (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'items': items,
                'nextCursor': 'opaque-c1',
                'hasMore': true,
                'totalCount': 21,
              }),
              200,
            );
          }
          if (call == 2) {
            final items = List<Map<String, Object?>>.generate(
              10,
              (i) => publishedMonoListJsonRow('m-${10 + i}', 2000 + i),
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'items': items,
                'nextCursor': 'opaque-c2',
                'hasMore': true,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'items': [publishedMonoListJsonRow('m-20', 1000)],
              'nextCursor': null,
              'hasMore': false,
            }),
            200,
          );
        }),
      );
      final pager = ProfilePublishedMonoPager(repo);
      await pager.loadFirstPage();
      expect(pager.state.canLoadMore, isTrue);
      expect(pager.state.totalCount, 21);
      await pager.loadMore();
      expect(pager.state.items, hasLength(20));
      expect(pager.state.totalCount, 21);
      expect(pager.state.canLoadMore, isTrue);
      await pager.loadMore();
      expect(pager.state.items, hasLength(21));
      expect(pager.state.totalCount, 21);
      expect(pager.state.hasMore, isFalse);
      expect(pager.state.canLoadMore, isFalse);
      expect(call, 3);
    });

    test('M17C-4: loadFirstPage preserves totalCount from meta-only pagination',
        () async {
      final items = List<Map<String, Object?>>.generate(
        10,
        (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
      );
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'items': items,
              'meta': <String, Object?>{
                'hasMore': true,
                'nextCursor': 'opaque-c1',
                'totalCount': 21,
              },
            }),
            200,
          ),
        ),
      );
      final pager = ProfilePublishedMonoPager(repo);
      await pager.loadFirstPage();
      expect(pager.state.items, hasLength(10));
      expect(pager.state.totalCount, 21);
      expect(pager.state.hasMore, isTrue);
      expect(pager.state.nextCursor, 'opaque-c1');
    });

    test('loadMore dedupes duplicate ids from server', () async {
      var calls = 0;
      final stub = _StubPublishedMonoRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<PublishedMonoListItemDto>(
            items: [_minimalDto],
            nextCursor: 'c2',
            hasMore: true,
          );
        }
        return PageResult<PublishedMonoListItemDto>(
          items: [_minimalDto],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      await n.loadMore();
      expect(n.state.items, hasLength(1));
      expect(calls, 2);
    });

    test('loadMore failure keeps first page and cursor', () async {
      var calls = 0;
      final stub = _StubPublishedMonoRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<PublishedMonoListItemDto>(
            items: [_minimalDto],
            nextCursor: 'c-keep',
            hasMore: true,
          );
        }
        throw StateError('network');
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      await n.loadMore();
      expect(n.state.items, hasLength(1));
      expect(n.state.nextCursor, 'c-keep');
      expect(n.state.hasMore, isTrue);
      expect(n.state.error, isNotNull);
    });

    test('loadMore is no-op while a loadMore is in flight', () async {
      final hold = Completer<void>();
      var calls = 0;
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
      final stub = _StubPublishedMonoRepository((r) async {
        calls++;
        if (calls == 1) {
          return PageResult<PublishedMonoListItemDto>(
            items: [_minimalDto],
            nextCursor: 'c1',
            hasMore: true,
          );
        }
        await hold.future;
        return PageResult<PublishedMonoListItemDto>(
          items: [second],
          nextCursor: null,
          hasMore: false,
        );
      });
      final n = ProfilePublishedMonoPager(stub);
      await n.loadFirstPage();
      final slow = n.loadMore();
      await n.loadMore();
      expect(calls, 2);
      hold.complete();
      await slow;
      expect(n.state.items.map((e) => e.id).toList(), ['pm_1', 'pm_2']);
    });

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
