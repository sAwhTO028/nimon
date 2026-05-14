import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
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

  /// First `/v1/published-monos` page should set [PaginatedState.totalCount] when the
  /// envelope includes `totalCount` / `total_count`; later pages may omit it.
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
        PageRequest(limit: PaginationDefaults.profilePublishedMonoPageLimit),
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
        PageRequest(limit: PaginationDefaults.profilePublishedMonoPageLimit),
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
    if (kDebugMode) {
      debugPrint(
        '[ProfilePublished loadMore] enter '
        'canLoadMore=${state.canLoadMore} hasMore=${state.hasMore} '
        'isLoadingMore=${state.isLoadingMore} isInitialLoading=${state.isInitialLoading} '
        'isRefreshing=${state.isRefreshing} error=${state.error != null} '
        'nextCursorSet=${state.nextCursor != null && state.nextCursor!.isNotEmpty} '
        'itemsLen=${state.items.length}',
      );
    }
    if (!state.canLoadMore) {
      if (kDebugMode) {
        debugPrint('[ProfilePublished loadMore] skip: !canLoadMore');
      }
      return;
    }
    final myEpoch = state.requestEpoch;
    final cursor = state.nextCursor;
    if (kDebugMode) {
      debugPrint('[ProfilePublished loadMore] start fetch cursorLen=${cursor?.length ?? 0}');
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.fetchPage(
        PageRequest(
          cursor: cursor,
          limit: PaginationDefaults.profilePublishedMonoPageLimit,
        ),
      );
      if (state.requestEpoch != myEpoch) return;
      final existingIds = state.items.map((e) => e.id).toSet();
      final appended = result.items
          .where((e) => !existingIds.contains(e.id))
          .toList(growable: false);
      state = state.copyWith(
        items: [...state.items, ...appended],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        error: null,
        totalCount: result.totalCount ?? state.totalCount,
      );
      if (kDebugMode) {
        debugPrint(
          '[ProfilePublished loadMore] done itemsLen=${state.items.length} '
          'appended=${appended.length} hasMore=${state.hasMore}',
        );
      }
    } catch (e) {
      if (state.requestEpoch != myEpoch) return;
      state = state.copyWith(error: e);
      if (kDebugMode) {
        debugPrint('[ProfilePublished loadMore] error: $e');
      }
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
