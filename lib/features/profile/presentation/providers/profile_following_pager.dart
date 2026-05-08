import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/profile/data/remote_user_follow_repository.dart';

final profileFollowingPagerProvider = StateNotifierProvider<
    ProfileFollowingPager, PaginatedState<MeFollowingUser>>(
  (ref) => ProfileFollowingPager(ref.watch(remoteUserFollowRepositoryProvider)),
);

class ProfileFollowingPager
    extends StateNotifier<PaginatedState<MeFollowingUser>> {
  ProfileFollowingPager(this._repo)
      : super(
            const PaginatedState<MeFollowingUser>(items: <MeFollowingUser>[]));

  final RemoteUserFollowRepository _repo;

  Future<void> loadFirstPage() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isInitialLoading: true,
      isLoadingMore: false,
      error: null,
    );
    try {
      final result = await _repo.fetchFollowingPage(
        PageRequest(
          limit: PaginationDefaults.defaultPageLimit,
          sort: 'recent',
        ),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isInitialLoading: false,
        error: null,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(isInitialLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchFollowingPage(
        PageRequest(
          cursor: cursor,
          limit: PaginationDefaults.defaultPageLimit,
          sort: 'recent',
        ),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        error: null,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(error: e);
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
