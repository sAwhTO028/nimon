# Profile Published Pagination Report

## Files Changed

- `lib/features/profile/data/published_mono_dto.dart` — optional pagination fields on list response DTO.
- `lib/features/profile/data/remote_published_mono_repository.dart` — shared list JSON parsing, `fetchPage(PageRequest)`.
- `lib/features/profile/presentation/providers/profile_published_mono_pager.dart` — new Riverpod providers and `ProfilePublishedMonoPager` notifier.
- `lib/features/profile/profile_screen.dart` — Published tab only: pager wiring, scroll `loadMore`, bulk delete / sheet delete sync with notifier.
- `test/features/profile/profile_published_pagination_test.dart` — new tests for parsing, `fetchPage`, and notifier behavior.

## Public API Added

- `PublishedMonoListResponseDto`: optional `nextCursor`, `hasMore` (default `false`), `totalCount` (default `null`).
- `RemotePublishedMonoRepository.fetchPage(PageRequest request)` → `Future<PageResult<PublishedMonoListItemDto>>`.
- `remotePublishedMonoRepositoryForProfileProvider` — `Provider<RemotePublishedMonoRepository>` (tests may override).
- `profilePublishedMonoPagerProvider` — `StateNotifierProvider<ProfilePublishedMonoPager, PaginatedState<PublishedMonoListItemDto>>`.
- `ProfilePublishedMonoPager`: `loadFirstPage()`, `refresh()`, `loadMore()`, `removeItemsByIds(Set<String> ids)`.

## Backward Compatibility

- `RemotePublishedMonoRepository.list({int limit})` is unchanged in signature and behavior (still `GET /v1/published-monos` with `limit` only); responses now populate optional envelope fields when present.
- JSON with only `{ "items": [...] }` maps to `nextCursor: null`, `hasMore: false`, `totalCount: null` on both `list()` and `fetchPage()`.
- Detail-only fields remain on `PublishedMonoDetailDto` only.

## Provider Behavior

- `PaginatedState<PublishedMonoListItemDto>` with `requestEpoch`: `loadFirstPage` and `refresh` bump the epoch before the network call; completions with a mismatched epoch are ignored. `loadMore` uses the epoch captured at start so a concurrent `refresh` drops stale append results.
- `loadMore` returns immediately when `!canLoadMore` (includes guards for `isLoadingMore`, `hasMore`, `isRefreshing`, `isInitialLoading`, and error).
- `refresh` sets `isRefreshing`, clears `nextCursor` in state before the first-page request, and replaces `items` on success while prior rows remain visible until the response arrives.
- `loadFirstPage` sets `isInitialLoading`; `loadMore` sets `isLoadingMore` and clears it in `finally` so superseded loads do not stick the flag.
- Initial notifier state uses an explicitly typed empty `PaginatedState<PublishedMonoListItemDto>` so `copyWith(items: …)` does not hit `List<Never>` from an untyped `PaginatedState.initial()`.

## ProfileScreen Changes

- When `RemoteBackendConfig.useRemoteDrafts` is true, Published loose rows come from `profilePublishedMonoPagerProvider` (mapped to `_OneShortItem` as before). While the first request is in flight and the pager has no items yet, the existing mock `_uploadedLooseItems` is still shown (same short-lived behavior as pre-pager mock-then-replace).
- `initState` triggers `loadFirstPage()` instead of calling `list(limit: 80)` inline; first page size uses `PaginationDefaults.profilePageLimit` (20) via `PageRequest`.
- Published `_FolderGroupList` receives `onLooseListNearEnd` → `loadMore()` when remote is on (scroll notification ~220 px from end).
- Bulk delete and detail-sheet delete for backend-published rows call `removeItemsByIds` on the notifier when remote is on.

## Tests Added

- File: `test/features/profile/profile_published_pagination_test.dart`.
- `RemotePublishedMonoRepository.fetchPage`: legacy `items`-only JSON; full envelope JSON; query parameter mapping for `cursor` / `limit` / `sort`.
- `ProfilePublishedMonoPager` (direct `ProfilePublishedMonoPager(stub)` for deterministic wiring): `loadFirstPage`, `loadMore` append, `loadMore` no-op when `hasMore` is false, `refresh` replaces data and clears cursor, stale `loadMore` after `refresh` does not append.

## Flutter Analyze Result

- Ran `flutter analyze` (project-wide). **No analyzer entries with severity `error`** (exit code may still be non-zero due to existing `info` / `warning` issues elsewhere per project policy).

## Flutter Test Result

- Ran `flutter test`: **All tests passed** (61 total after this change; prior baseline was 53).

## Risk Notes

- Scroll-based `loadMore` can fire multiple times near the bottom; the notifier and `canLoadMore` prevent overlapping fetches, but the HTTP client may still see redundant near-end triggers if the user oscillates around the threshold.
- `PageRequest.toQueryParameters()` always sends `sort=latest`; the backend is expected to ignore unknown query keys if it does not yet support `sort`/`cursor` (per API query contract).
- `profilePublishedMonoPagerProvider` is a long-lived `StateNotifierProvider` (not `autoDispose`), so pager state survives until app/process teardown unless invalidated explicitly; this avoids `PaginatedState.initial()` typing pitfalls and matches a single global “profile published” surface.

## Recommended Next Step

- Wire pull-to-refresh on the Published tab to `ref.read(profilePublishedMonoPagerProvider.notifier).refresh()` when product wants explicit refresh UX, and align backend `GET /v1/published-monos` with cursor + envelope fields when the API is ready.
