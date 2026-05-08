import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/published_mono_learn_snapshot_parser.dart';

/// Public catalog mono detail — **one fetch per** [monoId] until [autoDispose] drops it.
///
/// Reused by [learnPublishedSnapshotProvider] so Learn routes do not duplicate `GET /v1/mono/:id`.
/// Does **not** require authentication.
final catalogPublishedMonoDetailProvider =
    FutureProvider.autoDispose.family<PublishedMonoDetailDto, String>(
  (ref, monoId) async {
    final id = monoId.trim();
    if (id.isEmpty) {
      throw ArgumentError('monoId is empty');
    }
    final repo = ref.watch(remoteMonoFeedRepositoryProvider);
    return repo.fetchMonoDetail(id);
  },
);

/// Parsed `content.learn` for catalog Mono [monoId], derived from [catalogPublishedMonoDetailProvider].
///
/// Returns [AsyncData] with **null** snapshot when `content.learn` is absent or unsupported
/// (see [learnPublishedSnapshotFromPublishedMonoDetail]).
///
/// Empty [monoId] yields [AsyncData] null without calling the API.
final learnPublishedSnapshotProvider =
    Provider.autoDispose.family<AsyncValue<LearnPublishedSnapshot?>, String>(
  (ref, monoId) {
    if (monoId.trim().isEmpty) {
      return const AsyncData(null);
    }
    return ref.watch(catalogPublishedMonoDetailProvider(monoId)).when(
          data: (detail) => AsyncData(
            learnPublishedSnapshotFromPublishedMonoDetail(detail),
          ),
          loading: () => const AsyncLoading(),
          error: (err, stack) => AsyncError(err, stack),
        );
  },
);
