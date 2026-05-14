import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

class _MutableMonoFeedRepo implements MonoFeedRepository {
  _MutableMonoFeedRepo(this._page);

  PageResult<MonoFeedSummaryDto> _page;

  set page(PageResult<MonoFeedSummaryDto> v) => _page = v;

  int feedCalls = 0;
  PageRequest? lastRequest;

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    feedCalls++;
    lastRequest = request;
    return _page;
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) async {
    throw UnimplementedError();
  }
}

class _PagedMonoFeedRepo implements MonoFeedRepository {
  _PagedMonoFeedRepo({
    required this.first,
    required this.second,
  });

  final PageResult<MonoFeedSummaryDto> first;
  final PageResult<MonoFeedSummaryDto> second;

  int feedCalls = 0;
  final List<PageRequest> requests = [];

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    feedCalls++;
    requests.add(request);
    if (request.cursor != null) {
      return second;
    }
    return first;
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) async {
    throw UnimplementedError();
  }
}

MonoFeedSummaryDto _row(String id) => MonoFeedSummaryDto(
      monoId: id,
      title: 't',
      coverUrl: null,
      level: 'N5',
      category: '',
      categories: const [],
      description: '',
      writerId: '',
      writerHandle: '',
      writerDisplayName: '',
      writerAvatarUrl: '',
      publishedAt: '',
      updatedAt: '',
      likesCount: 0,
      hasAudio: false,
      isBookmarkedByMe: false,
      myReaction: null,
      shareUrl: null,
      publishKind: '',
      accessType: 'public',
    );

void main() {
  test('loadFirstPage loads items', () async {
    final fake = _MutableMonoFeedRepo(
      PageResult(
        items: [_row('a')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(monoFeedPagerProvider.notifier).loadFirstPage();
    final s = container.read(monoFeedPagerProvider);
    expect(s.items, hasLength(1));
    expect(s.items.single.monoId, 'a');
    expect(s.isInitialLoading, false);
    expect(fake.feedCalls, 1);
    expect(fake.lastRequest?.limit, 7);
  });

  test('refresh replaces items', () async {
    final pageA = PageResult(
      items: [_row('a')],
      hasMore: false,
      nextCursor: null,
    );
    final pageB = PageResult(
      items: [_row('b')],
      hasMore: false,
      nextCursor: null,
    );
    final fake = _MutableMonoFeedRepo(pageA);
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(monoFeedPagerProvider.notifier);
    await notifier.loadFirstPage();
    expect(container.read(monoFeedPagerProvider).items.single.monoId, 'a');

    fake.page = pageB;
    await notifier.refresh();
    final s = container.read(monoFeedPagerProvider);
    expect(s.items.single.monoId, 'b');
    expect(s.isRefreshing, false);
    expect(fake.feedCalls, 2);
  });

  test('loadMore appends and uses cursor', () async {
    final second = PageResult(
      items: [_row('b')],
      hasMore: false,
      nextCursor: null,
    );
    final fake = _PagedMonoFeedRepo(
      first: PageResult(
        items: [_row('a')],
        hasMore: true,
        nextCursor: 'c1',
      ),
      second: second,
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(monoFeedPagerProvider.notifier).loadFirstPage();
    await container.read(monoFeedPagerProvider.notifier).loadMore();

    final s = container.read(monoFeedPagerProvider);
    expect(s.items.map((e) => e.monoId).toList(), ['a', 'b']);
    expect(fake.feedCalls, 2);
    expect(fake.requests.first.limit, 7);
    expect(fake.requests.last.limit, 10);
  });

  test('loadMore is skipped when canLoadMore is false', () async {
    final fake = _MutableMonoFeedRepo(
      PageResult(
        items: [_row('a')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(monoFeedPagerProvider.notifier).loadFirstPage();
    await container.read(monoFeedPagerProvider.notifier).loadMore();

    expect(fake.feedCalls, 1);
  });

  test('loadMore dedupes by monoId (preserves order)', () async {
    final fake = _PagedMonoFeedRepo(
      first: PageResult(
        items: [_row('a'), _row('b')],
        hasMore: true,
        nextCursor: 'c1',
      ),
      second: PageResult(
        items: [_row('b'), _row('c')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(monoFeedPagerProvider.notifier).loadFirstPage();
    await container.read(monoFeedPagerProvider.notifier).loadMore();

    final s = container.read(monoFeedPagerProvider);
    expect(s.items.map((e) => e.monoId).toList(), ['a', 'b', 'c']);
  });

  test('maybePrefetch triggers loadMore when remaining <= 3', () async {
    final fake = _PagedMonoFeedRepo(
      first: PageResult(
        items: [
          _row('a'),
          _row('b'),
          _row('c'),
          _row('d'),
          _row('e'),
          _row('f'),
          _row('g'),
        ],
        hasMore: true,
        nextCursor: 'c1',
      ),
      second: PageResult(
        items: [_row('h')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(monoFeedPagerProvider.notifier);
    await notifier.loadFirstPage();

    // index=3 => remaining=7-3-1=3 => should prefetch
    notifier.maybePrefetch(3);
    await Future<void>.delayed(Duration.zero);

    expect(fake.feedCalls, 2);
    expect(fake.requests.last.cursor, 'c1');
  });

  test('maybePrefetch does not loadMore when remaining > 3', () async {
    final fake = _MutableMonoFeedRepo(
      PageResult(
        items: List.generate(7, (i) => _row('id_$i')),
        hasMore: true,
        nextCursor: 'c1',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(monoFeedPagerProvider.notifier);
    await notifier.loadFirstPage();

    // index=0 => remaining=6 (>3) => no prefetch
    notifier.maybePrefetch(0);
    await Future<void>.delayed(Duration.zero);

    expect(fake.feedCalls, 1);
  });

  test('maybePrefetch does not re-request same cursor repeatedly', () async {
    final fake = _PagedMonoFeedRepo(
      first: PageResult(
        items: List.generate(7, (i) => _row('id_$i')),
        hasMore: true,
        nextCursor: 'c1',
      ),
      second: PageResult(
        items: [_row('x')],
        hasMore: true,
        nextCursor: 'c1',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(monoFeedPagerProvider.notifier);
    await notifier.loadFirstPage();

    notifier.maybePrefetch(3);
    notifier.maybePrefetch(3);
    notifier.maybePrefetch(3);
    await Future<void>.delayed(Duration.zero);

    expect(fake.feedCalls, 2);
  });
}
