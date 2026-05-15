import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/search/data/mono_search_remote.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';
import 'package:nimon/features/search/presentation/mono_search_notifier.dart';

MonoSearchResult _row(String id,
    {String updatedAt = '2020-01-01T00:00:00.000Z'}) {
  return MonoSearchResult(
    listItem: PublishedMonoListItemDto(
      id: id,
      ownerId: 'o',
      sourceDraftId: null,
      title: 't',
      category: 'c',
      level: 'N5',
      description: 'd',
      publishKind: null,
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      contentSummary: null,
    ),
  );
}

typedef _SearchHandler = Future<PaginatedPage<MonoSearchResult>> Function({
  String? q,
  String? level,
  String? category,
  String sort,
  int limit,
  String? cursor,
});

class _ThrowIfCalledRemote implements MonoSearchRemote {
  int calls = 0;

  @override
  Future<PaginatedPage<MonoSearchResult>> searchMonos({
    String? q,
    String? level,
    String? category,
    String sort = 'latest',
    int limit = 20,
    String? cursor,
  }) async {
    calls++;
    throw StateError('unexpected search');
  }
}

class _FakeSearchRemote implements MonoSearchRemote {
  _FakeSearchRemote(this._handler);

  final _SearchHandler _handler;

  int callCount = 0;

  @override
  Future<PaginatedPage<MonoSearchResult>> searchMonos({
    String? q,
    String? level,
    String? category,
    String sort = 'latest',
    int limit = 20,
    String? cursor,
  }) async {
    callCount++;
    return _handler(
      q: q,
      level: level,
      category: category,
      sort: sort,
      limit: limit,
      cursor: cursor,
    );
  }
}

void main() {
  test('empty query and no filters skips remote search', () async {
    final remote = _ThrowIfCalledRemote();
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.refresh();
    expect(remote.calls, 0);
    expect(n.state.hasEverFetched, isFalse);
    expect(n.state.items, isEmpty);
  });

  test('first search loads first page', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      expect(cursor, isNull);
      return PaginatedPage<MonoSearchResult>(
        items: [_row('a')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('hi');
    expect(n.state.items, hasLength(1));
    expect(n.state.items.single.id, 'a');
    expect(n.state.isLoadingFirstPage, isFalse);
    expect(n.state.error, isNull);
    expect(remote.callCount, 1);
  });

  test('changing query resets items and cursor before new results', () async {
    String? lastQ;
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      lastQ = q;
      if (q == 'one') {
        return PaginatedPage<MonoSearchResult>(
          items: [_row('1')],
          hasMore: true,
          nextCursor: 'c1',
          totalCount: 2,
        );
      }
      return PaginatedPage<MonoSearchResult>(
        items: [_row('2')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('one');
    expect(n.state.items.single.id, '1');
    expect(n.state.nextCursor, 'c1');

    await n.setQueryAndReload('two');
    expect(lastQ, 'two');
    expect(n.state.items.single.id, '2');
    expect(n.state.nextCursor, isNull);
  });

  test('changing level resets items and cursor', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      if (level == 'N4') {
        return PaginatedPage<MonoSearchResult>(
          items: [_row('n4')],
          hasMore: true,
          nextCursor: 'x',
          totalCount: 5,
        );
      }
      return PaginatedPage<MonoSearchResult>(
        items: [_row('any')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setLevel('N5');
    expect(n.state.items.single.id, 'any');

    await n.setLevel('N4');
    expect(n.state.items.single.id, 'n4');
    expect(n.state.nextCursor, 'x');
  });

  test('changing category resets items and cursor', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      if (category == 'verbs') {
        return PaginatedPage<MonoSearchResult>(
          items: [_row('v')],
          hasMore: true,
          nextCursor: 'cv',
          totalCount: 3,
        );
      }
      return PaginatedPage<MonoSearchResult>(
        items: [_row('all')],
        hasMore: false,
        nextCursor: null,
        totalCount: 10,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setCategory('verbs');
    expect(n.state.items.single.id, 'v');
    expect(n.state.nextCursor, 'cv');
  });

  test('loadMore appends page 2', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      if (cursor == null) {
        return PaginatedPage<MonoSearchResult>(
          items: [_row('p1')],
          hasMore: true,
          nextCursor: 'c2',
          totalCount: 2,
        );
      }
      expect(cursor, 'c2');
      return PaginatedPage<MonoSearchResult>(
        items: [_row('p2')],
        hasMore: false,
        nextCursor: null,
        totalCount: 2,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('p');
    await n.loadMore();
    expect(n.state.items.map((e) => e.id).toList(), ['p1', 'p2']);
    expect(n.state.hasMore, isFalse);
  });

  test('loadMore dedupes duplicate ids', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      if (cursor == null) {
        return PaginatedPage<MonoSearchResult>(
          items: [_row('dup')],
          hasMore: true,
          nextCursor: 'c',
          totalCount: 2,
        );
      }
      return PaginatedPage<MonoSearchResult>(
        items: [_row('dup')],
        hasMore: false,
        nextCursor: null,
        totalCount: 2,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('p');
    await n.loadMore();
    expect(n.state.items, hasLength(1));
    expect(n.state.items.single.id, 'dup');
  });

  test('loadMore clears isLoadingMore on error', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      if (cursor == null) {
        return PaginatedPage<MonoSearchResult>(
          items: [_row('a')],
          hasMore: true,
          nextCursor: 'c',
          totalCount: 2,
        );
      }
      throw StateError('network');
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('p');
    await n.loadMore();
    expect(n.state.isLoadingMore, isFalse);
    expect(n.state.error, isA<StateError>());
  });

  test('hasMore=false prevents extra search calls on loadMore', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [_row('only')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('only');
    expect(remote.callCount, 1);
    await n.loadMore();
    expect(remote.callCount, 1);
  });

  test('setQuery debounces rapid edits into one fetch', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [if (q != null) _row(q!) else _row('empty')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final n = MonoSearchNotifier(
      remote,
      debounce: const Duration(milliseconds: 30),
    );
    addTearDown(n.dispose);

    n.setQuery('a');
    n.setQuery('ab');
    n.setQuery('abc');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remote.callCount, 1);
    expect(n.state.query, 'abc');
    expect(n.state.items.single.id, 'abc');
  });

  test('optional viewer fields preserved from repo on first page', () async {
    final remote = _FakeSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [
          MonoSearchResult(
            listItem: PublishedMonoListItemDto(
              id: 'x',
              ownerId: 'o',
              sourceDraftId: null,
              title: 't',
              category: 'c',
              level: 'N5',
              description: 'd',
              publishKind: null,
              displayPublishKind: 'read_only',
              coverImageUrl: null,
              targetDurationLabel: null,
              createdAt: '2020-01-01T00:00:00.000Z',
              updatedAt: '2020-01-01T00:00:00.000Z',
              contentSummary: null,
            ),
            likesCount: 9,
            isBookmarkedByMe: true,
            myReaction: 'heart',
          ),
        ],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final n = MonoSearchNotifier(remote, debounce: Duration.zero);
    addTearDown(n.dispose);

    await n.setQueryAndReload('only');
    expect(n.state.items.single.isBookmarkedByMe, isTrue);
    expect(n.state.items.single.myReaction, 'heart');
    expect(n.state.items.single.likesCount, 9);
  });
}
