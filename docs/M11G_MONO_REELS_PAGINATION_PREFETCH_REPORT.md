# M11g Mono Reels Pagination Prefetch Report

## Scope

Align Mono Reels pagination with the M11 decision spec:

- Initial page size: **7**
- Next page size: **10**
- Prefetch when remaining items \(<= 3\)
- Cursor pagination
- Deduplicate by `monoId`
- Do **not** refresh the whole feed on normal swipe

Non-goals:

- No feed ranking/recommendation changes
- No changes to M11e content locale filtering behavior
- No Mono UI redesign

## Current Pagination Audit

### Pager layer (`MonoFeedPager` / `FollowingMonoFeedPager`)

Before M11g:

- `loadFirstPage`, `refresh`, and `loadMore` all used the same limit: `PaginationDefaults.monoFeedPageLimit` \(15\)
- `loadMore` appended without deduplication
- No cursor-level guard existed to prevent re-requesting the same cursor repeatedly

### UI trigger layer (`MonoScreen`)

Before M11g:

- On vertical `PageView.onPageChanged`, `loadMore()` triggered when `i >= data.length - 2`
  - This is effectively “prefetch when remaining \(<= 1\)”, not \(<= 3\)
- No `refresh()` was triggered on normal swipe (good)
- Detail hydration runs per-item (`_ensureDetailLoaded`) and is guarded by:
  - `needsRemoteDetailHydration`
  - `_detailInflight`
  - `_hydratedRemoteItems`

## Final Pagination Policy

Implemented M11 policy:

- **Initial** requests use limit **7**
- **Load more** requests use limit **10**
- Prefetch when remaining items \(<= 3\)
- Dedupe by `monoId` when appending pages
- Cursor-guard prevents redundant repeated loadMore calls for the same `nextCursor`

## State Shape

Pager state continues to use `PaginatedState<T>` with:

- `items`
- `nextCursor`
- `hasMore`
- `isInitialLoading`
- `isLoadingMore`
- `error`

## Prefetch Threshold

Added `maybePrefetch(currentIndex)` on both pagers.

Logic:

- `remaining = items.length - currentIndex - 1`
- if `remaining <= 3` and `canLoadMore` and `nextCursor != null` and cursor not already requested:
  - trigger `loadMore()`

`MonoScreen` now calls `maybePrefetch(i)` on index change (instead of hardcoding `i >= data.length - 2`).

## Deduplication

When appending:

- Maintain a `seen` set of `monoId` from current `state.items`
- Append only items whose `monoId` has not been seen yet
- Preserve original order: existing items first, then new unique items

## Refresh Policy

Confirmed:

- Normal swipe index changes do **not** call `refresh()`
- Refresh remains reserved for:
  - pull-to-refresh (existing behavior)
  - settings changes (M11e already triggers pager refresh)
  - filter changes / profile propagation hooks (existing patterns)

## Tests Added

Updated `test/features/mono/mono_feed_pager_test.dart` to cover:

- Initial load uses limit **7**
- Load more uses limit **10**
- Prefetch triggers when remaining \(<= 3\)
- Prefetch does not trigger when remaining \(> 3\)
- Cursor guard prevents repeated requests for the same cursor
- Append dedupes by `monoId` and preserves order

## Commands Run

Flutter:

- `dart format` on touched files
- `flutter test test/features/mono/mono_feed_pager_test.dart`
- `flutter test test/features/mono`

## Manual Verification

- Swipe through Mono Reels:
  - Near-end prefetch happens earlier (remaining \(<= 3\)) rather than at the last item.
  - No full-feed refresh occurs on normal swipe.

## Remaining Risks

- `maybePrefetch` is triggered from UI index changes; if future UI changes introduce multiple index callbacks per item, cursor-guard will be important to prevent request storms.
- Backend can still return overlapping items across cursors; dedupe mitigates client duplication but does not resolve potential ordering inconsistencies if content updates mid-scroll.

## Recommended Next Step

- Consider adding lightweight telemetry/debug logging (dev-only) around prefetch decisions to make feed performance tuning easier without changing UX.

