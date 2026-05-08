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

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    feedCalls++;
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

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    feedCalls++;
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
}
