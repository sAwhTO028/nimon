import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/remote_mono_social_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_saved_mono_pager.dart';

class _FakeSocialRepo extends RemoteMonoSocialRepository {
  _FakeSocialRepo(this._page)
      : super(apiBaseUrl: 'http://x', authHeaderBuilder: () async => {});

  PageResult<MonoFeedItem> _page;
  int calls = 0;
  String? lastCursor;

  set page(PageResult<MonoFeedItem> v) => _page = v;

  @override
  Future<PageResult<MonoFeedItem>> fetchBookmarkedPage(
      PageRequest request) async {
    calls++;
    lastCursor = request.cursor;
    return _page;
  }
}

void main() {
  test('saved pager loadFirstPage loads items', () async {
    final fake = _FakeSocialRepo(
      PageResult(
        items: const [
          MonoFeedItem(
            id: 'm1',
            writerName: 'W',
            writerHandle: '@w',
            level: 'N5',
            contentType: MonoContentType.article,
            bodyText: 'D',
            isBookmarkedByMe: true,
          ),
        ],
        hasMore: false,
        nextCursor: null,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoSocialRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(profileSavedMonoPagerProvider.notifier)
        .loadFirstPage();
    final s = container.read(profileSavedMonoPagerProvider);
    expect(s.items, hasLength(1));
    expect(s.items.single.id, 'm1');
    expect(fake.calls, 1);
  });

  test('saved pager loadMore appends and clears isLoadingMore', () async {
    final fake = _FakeSocialRepo(
      PageResult(
        items: const [
          MonoFeedItem(
            id: 'm1',
            writerName: 'W',
            writerHandle: '@w',
            level: 'N5',
            contentType: MonoContentType.article,
            bodyText: 'D',
            isBookmarkedByMe: true,
          ),
        ],
        hasMore: true,
        nextCursor: 'c1',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoSocialRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(profileSavedMonoPagerProvider.notifier)
        .loadFirstPage();
    fake.page = PageResult(
      items: const [
        MonoFeedItem(
          id: 'm2',
          writerName: 'W',
          writerHandle: '@w',
          level: 'N5',
          contentType: MonoContentType.article,
          bodyText: 'D',
          isBookmarkedByMe: true,
        ),
      ],
      hasMore: false,
      nextCursor: null,
    );

    await container.read(profileSavedMonoPagerProvider.notifier).loadMore();
    final s = container.read(profileSavedMonoPagerProvider);
    expect(s.items, hasLength(2));
    expect(s.items.map((e) => e.id).toList(), ['m1', 'm2']);
    expect(s.hasMore, false);
    expect(s.isLoadingMore, false);
    expect(fake.lastCursor, 'c1');
    expect(fake.calls, 2);
  });
}
