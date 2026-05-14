# M14J-B Public Profile Monos Pagination Report

## Problem

Public profile **Monos** loaded a **single large first page** (limit **15**) and used a manual **“Load more”** button. Scrolling did not prefetch additional pages, so creators with many monos paid a heavier upfront cost than necessary.

## Scope

- **Remote** public profile **Monos** tab only (`PublicProfileScreen` + `GET /v1/mono/feed?writerId=…`).
- **Unchanged:** M14J-A10 hero/cover/identity layout, pinned TabBar shell, Collections tab loading/swipe, follow/share, owner profile, global Mono Reels, routes, l10n/validation.

## Audit Summary

See [M14J_B_PUBLIC_PROFILE_MONOS_PAGINATION_AUDIT.md](./M14J_B_PUBLIC_PROFILE_MONOS_PAGINATION_AUDIT.md). Backend already exposes **cursor**, **limit**, **hasMore**, **nextCursor** for `writerId` on `GET /v1/mono/feed`.

## Backend Support

**No backend changes.** Existing `MonoFeedService.listFeed` + controller already implement keyset pagination for writer-scoped feeds.

## Page Size

- **Initial:** **10**
- **Load more:** **10**

## Cursor Contract

Opaque `nextCursor` from API; client passes as `cursor` query param. Repository unchanged (`RemotePublicCreatorProfileRepository.fetchCreatorMonoPage`).

## Flutter Provider State

New **`PublicProfileMonosState`** + **`PublicProfileMonosNotifier`** + **`publicProfileMonosProvider`** (`StateNotifierProvider.autoDispose.family<String>`):

- `items`, `isInitialLoading`, `isRefreshing`, `isLoadingMore`, `hasMore`, `nextCursor`, `error`, `loadMoreError`
- `loadInitial`, `refresh`, `loadMore`, `maybePrefetchFromScroll`

Guards: no concurrent load more (`canLoadMore` + `isLoadingMore`); no load more when `hasMore` false or cursor empty; load-more failure keeps existing items and sets `loadMoreError`.

## UI Integration

- **`public_profile_screen.dart`:** `_loadRemoteProfileOnly` / `_loadRemoteIfNeeded` (profile then `loadInitial`); **`RefreshIndicator`** → `_pullRefreshPublicProfile` (profile + `refresh` monos + forced collections).
- Monos tab: **`NotificationListener<ScrollNotification>`** when **Monos tab index is 0** and `metrics.extentAfter <= 600` → `maybePrefetchFromScroll`.
- Replaced **Load more** button with bottom **`CircularProgressIndicator`** when `isLoadingMore`; optional **`loadMoreError`** line when items non-empty.
- **`didUpdateWidget`:** if `userId` changes, reload remote profile (which re-triggers monos initial load for the new family key).

## Refresh Behavior

Pull-to-refresh reloads public profile metadata, **re-fetches first monos page** via `refresh`, and **forces** collections reload.

## Load More Behavior

Scroll-near-bottom prefetch; duplicate in-flight requests blocked by notifier state.

## Tests Added

`test/features/profile/public_profile_monos_pagination_test.dart` — limit **10**, append on load more, duplicate load-more at end ignored, refresh resets list, widget smoke (first page, scroll prefetch, tab switch, TabBar after fling).

## Commands Run

- `dart format` on touched Dart paths  
- `flutter analyze` on touched `lib` paths  
- `flutter test test/features/profile` → **196 passed**

## Known Unrelated Test Failure

Full `flutter test` was not executed for M14J-B (per task scope).

## Manual Verification

Use M14J-B Part H checklist on device (many monos, scroll prefetch, tab switch, pull refresh, light/dark).

## Remaining Risks

- **Scroll notification volume:** `extentAfter` fires often; notifier guards prevent duplicate fetches; minor extra no-op work possible.
- **Short first page + `hasMore`:** if the list is not scrollable, `extentAfter` may stay **0** and still trigger prefetch — acceptable.
