import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';

/// Default [RemotePublishedMonoRepository] for profile published paging (override in tests).
final remotePublishedMonoRepositoryForProfileProvider =
    Provider<RemotePublishedMonoRepository>((ref) {
  return RemotePublishedMonoRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

final profilePublishedMonoPagerProvider = StateNotifierProvider<
    ProfilePublishedMonoPager, PaginatedState<PublishedMonoListItemDto>>((ref) {
  return ProfilePublishedMonoPager(
    ref.watch(remotePublishedMonoRepositoryForProfileProvider),
  );
});

class ProfilePublishedMonoPager
    extends StateNotifier<PaginatedState<PublishedMonoListItemDto>> {
  ProfilePublishedMonoPager(this._repo)
      : super(
          const PaginatedState<PublishedMonoListItemDto>(
            items: <PublishedMonoListItemDto>[],
          ),
        );

  final RemotePublishedMonoRepository _repo;

  Future<void> loadFirstPage() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isInitialLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      error: null,
    );
    try {
      final result = await _repo.fetchPage(
        PageRequest(limit: PaginationDefaults.profilePageLimit),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isInitialLoading: false,
        error: null,
        totalCount: result.totalCount,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        isInitialLoading: false,
        error: e,
      );
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isInitialLoading: false);
      }
    }
  }

  Future<void> refresh() async {
    final myEpoch = state.requestEpoch + 1;
    state = state.copyWith(
      requestEpoch: myEpoch,
      isRefreshing: true,
      isInitialLoading: false,
      isLoadingMore: false,
      nextCursor: null,
      error: null,
    );
    try {
      final result = await _repo.fetchPage(
        PageRequest(limit: PaginationDefaults.profilePageLimit),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isRefreshing: false,
        error: null,
        totalCount: result.totalCount,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        isRefreshing: false,
        error: e,
      );
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isRefreshing: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchPage(
        PageRequest(
          cursor: cursor,
          limit: PaginationDefaults.profilePageLimit,
        ),
      );
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        error: null,
        totalCount: result.totalCount ?? state.totalCount,
      );
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(error: e);
    } finally {
      if (state.requestEpoch == myEpoch) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  void removeItemsByIds(Set<String> ids) {
    if (ids.isEmpty) return;
    state = state.copyWith(
      items: [
        for (final e in state.items)
          if (!ids.contains(e.id)) e,
      ],
      totalCount: null,
    );
  }
}
