import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// One HTTP page: 1 “Continue working” + up to 3 “Drafts in progress” rows.
const int kStoryCreatorAddTabDraftSummaryLimit = 4;

@immutable
class CreateAddTabDraftSummaryState {
  const CreateAddTabDraftSummaryState({
    this.items = const <DraftListSummaryDto>[],
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<DraftListSummaryDto> items;
  final bool isInitialLoading;
  final bool isRefreshing;
  final Object? error;
}

final storyCreatorAddTabDraftSummaryProvider =
    StateNotifierProvider.autoDispose<StoryCreatorAddTabDraftSummaryNotifier,
        CreateAddTabDraftSummaryState>((ref) {
  final notifier = StoryCreatorAddTabDraftSummaryNotifier(
    ref.watch(storyDraftRepositoryProvider),
  );
  Future.microtask(notifier.loadInitial);
  return notifier;
});

/// Loads unpublished-draft summaries for the Create Add tab (no full [CreatorStoryV1] bodies).
class StoryCreatorAddTabDraftSummaryNotifier
    extends StateNotifier<CreateAddTabDraftSummaryState> {
  StoryCreatorAddTabDraftSummaryNotifier(this._repo)
      : super(const CreateAddTabDraftSummaryState());

  final StoryDraftRepository _repo;
  int _requestEpoch = 0;

  Future<void> loadInitial() => _fetch(isRefresh: false);

  Future<void> refresh() => _fetch(isRefresh: true);

  Future<void> _fetch({required bool isRefresh}) async {
    final myEpoch = ++_requestEpoch;
    state = CreateAddTabDraftSummaryState(
      items: state.items,
      isInitialLoading: !isRefresh && state.items.isEmpty,
      isRefreshing: isRefresh,
      error: null,
    );
    try {
      final result = await _repo.fetchWorkspaceDraftPage(
        PageRequest(
          limit: kStoryCreatorAddTabDraftSummaryLimit,
          sort: 'latest',
          publishState: StoryPublishState.draft.storageKey,
        ),
      );
      if (myEpoch != _requestEpoch) return;
      final items = result.items
          .take(kStoryCreatorAddTabDraftSummaryLimit)
          .toList(growable: false);
      state = CreateAddTabDraftSummaryState(
        items: items,
        isInitialLoading: false,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      if (myEpoch != _requestEpoch) return;
      state = CreateAddTabDraftSummaryState(
        items: state.items,
        isInitialLoading: false,
        isRefreshing: false,
        error: e,
      );
    }
  }
}
