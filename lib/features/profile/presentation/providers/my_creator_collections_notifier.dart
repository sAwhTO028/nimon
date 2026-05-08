import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/data/bulk_add_creator_collection_result.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';

final remoteCreatorCollectionsRepositoryProvider =
    Provider<RemoteCreatorCollectionsRepository>((ref) {
  return RemoteCreatorCollectionsRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

class MyCreatorCollectionsState {
  const MyCreatorCollectionsState({
    this.collections = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CreatorMonoCollection> collections;
  final bool isLoading;
  final Object? error;

  MyCreatorCollectionsState copyWith({
    List<CreatorMonoCollection>? collections,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return MyCreatorCollectionsState(
      collections: collections ?? this.collections,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final myCreatorCollectionsNotifierProvider = StateNotifierProvider<
    MyCreatorCollectionsNotifier, MyCreatorCollectionsState>(
  (ref) => MyCreatorCollectionsNotifier(
    ref.watch(remoteCreatorCollectionsRepositoryProvider),
  ),
);

class MyCreatorCollectionsNotifier
    extends StateNotifier<MyCreatorCollectionsState> {
  MyCreatorCollectionsNotifier(this._repo)
      : super(const MyCreatorCollectionsState());

  final RemoteCreatorCollectionsRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repo.fetchMyCollections();
      state = state.copyWith(collections: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() => load();

  Future<CreatorMonoCollection> createCollection(String title) async {
    final trimmed = title.trim();
    final created = await _repo.createCollection(title: trimmed);
    await load();
    return created;
  }

  Future<BulkAddCreatorCollectionResult> bulkAddToCollection({
    required String collectionId,
    required List<String> publishedMonoIds,
  }) async {
    final result = await _repo.bulkAddItems(collectionId, publishedMonoIds);
    await load();
    return result;
  }

  Future<void> renameCollection({
    required String collectionId,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw StateError('Title is required.');
    }
    await _repo.updateCollection(collectionId, title: trimmed);
    await load();
  }

  Future<void> deleteCollection(String collectionId) async {
    await _repo.deleteCollection(collectionId);
    await load();
  }
}
