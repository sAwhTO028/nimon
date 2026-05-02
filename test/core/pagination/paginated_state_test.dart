import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/paginated_state.dart';

void main() {
  group('PaginatedState', () {
    test('initial factory defaults', () {
      final s = PaginatedState<int>.initial();
      expect(s.items, isEmpty);
      expect(s.hasMore, isFalse);
      expect(s.isInitialLoading, isFalse);
      expect(s.isLoadingMore, isFalse);
      expect(s.isRefreshing, isFalse);
      expect(s.error, isNull);
      expect(s.requestEpoch, 0);
    });

    test('isEmpty when no items and not initial loading', () {
      expect(PaginatedState<int>.initial().isEmpty, isTrue);
      const loaded = PaginatedState<int>(
        items: [1],
        hasMore: true,
      );
      expect(loaded.isEmpty, isFalse);
      const loading = PaginatedState<int>(
        isInitialLoading: true,
      );
      expect(loading.isEmpty, isFalse);
    });

    test('isBusy when any loading flag is true', () {
      expect(PaginatedState<int>.initial().isBusy, isFalse);
      expect(
        const PaginatedState<int>(isInitialLoading: true).isBusy,
        isTrue,
      );
      expect(
        const PaginatedState<int>(isLoadingMore: true).isBusy,
        isTrue,
      );
      expect(
        const PaginatedState<int>(isRefreshing: true).isBusy,
        isTrue,
      );
    });

    test('hasError', () {
      expect(PaginatedState<int>.initial().hasError, isFalse);
      expect(
        const PaginatedState<int>(error: 'x').hasError,
        isTrue,
      );
    });

    test('canLoadMore', () {
      expect(PaginatedState<int>.initial().canLoadMore, isFalse);
      const ready = PaginatedState<int>(
        items: [1],
        hasMore: true,
      );
      expect(ready.canLoadMore, isTrue);
      const blocked = PaginatedState<int>(
        items: [1],
        hasMore: true,
        isLoadingMore: true,
      );
      expect(blocked.canLoadMore, isFalse);
      const refreshBlock = PaginatedState<int>(
        items: [1],
        hasMore: true,
        isRefreshing: true,
      );
      expect(refreshBlock.canLoadMore, isFalse);
      const err = PaginatedState<int>(
        items: [1],
        hasMore: true,
        error: 'e',
      );
      expect(err.canLoadMore, isFalse);
    });

    test('requestEpoch copyWith preserves and updates', () {
      final a = PaginatedState<int>.initial().copyWith(requestEpoch: 3);
      expect(a.requestEpoch, 3);
      final b = a.copyWith(isLoadingMore: true);
      expect(b.requestEpoch, 3);
      final c = b.copyWith(requestEpoch: 4);
      expect(c.requestEpoch, 4);
    });
  });
}
