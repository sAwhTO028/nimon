# P2 Flutter Published Mono Trash UX Report

## Files Changed

| Area | Paths |
|------|--------|
| DTO | `lib/features/profile/data/published_mono_dto.dart` (`trashedAt`, `PublishedMonoTrashMutationResult`) |
| Repository | `lib/features/profile/data/remote_published_mono_repository.dart` (`fetchTrashedPage`, `trashPublishedMono`, `restorePublishedMono`, friendly HTTP errors; `notifyIfStrictUnauthorized401` on failures) |
| Refresh | `lib/features/profile/profile_processing_refresh.dart` (`profileTrashListRefreshProvider`, `bumpPublishedTrashListRefresh`, `bumpPublishedMonoTrashSurfacesRefresh`) |
| Pager | `lib/features/profile/presentation/providers/profile_trashed_published_mono_pager.dart` |
| Screen | `lib/features/profile/profile_trash_screen.dart` |
| Drawer | `lib/features/profile/profile_navigation_drawer.dart` (`Trash` action) |
| Router | `lib/main.dart` (route `/profile/trash`; shell/nav visibility) |
| Reader options | `lib/ui/bottom_sheets/mono_story_options_sheet.dart` (Move to Trash + confirmation; **`_DismissibleDockPanel` AnimationController eager `initState` init**) |
| Tests | `test/features/profile/profile_published_mono_trash_repository_test.dart`, `test/features/profile/profile_trashed_published_mono_pager_test.dart`, `test/features/profile/profile_navigation_drawer_trash_test.dart`, `test/features/profile/profile_trash_screen_gate_test.dart`, `test/features/mono/mono_story_options_trash_test.dart` |

## Product Decision

- Profile tabs remain **Workspace / Published / Saved** only; Trash is **not** a fourth tab.
- Trash is reachable from the **profile push-drawer Actions** row **Trash**.
- **Permanent delete**: no UI (P2); no client call to non-existent endpoints.

## Move To Trash Flow

- Published reader options (**Uploaded**, not Saved) replaces **Delete** with **Move to Trash**.
- Confirmation: title **Move to Trash?**, body and **Cancel** / **Move to Trash**.
- Uses catalog id [`MonoFeedItem.monoIdForLearnRoutes`](lib/features/mono/mono_feed_models.dart).
- Success: **`bumpPublishedMonoTrashSurfacesRefresh`**, **`profilePublishedMonoPagerProvider.refresh()`**, snackbar **Moved to Trash.**, closes sheet/dialog.
- **401**: existing `notifyIfStrictUnauthorized401` bridge on repository errors.

## Profile Drawer Trash Entry

- Drawer **Actions**: **Trash** with `Icons.delete_outline_rounded` → **`/profile/trash`**.

## Trash List Screen

- [`ProfileTrashScreen`](lib/features/profile/profile_trash_screen.dart): `GET /v1/published-monos?trashed=true` via trash pager; cover, title, moved line from `trashedAt` (fallback `updatedAt`), **Restore**, empty copy, **Load more** when `hasMore`.
- When `RemoteBackendConfig.useRemoteDrafts` is false: explains remote gate (default in tests / many local runs).

## Restore Flow

- Confirm: **Restore story?** / copy per spec; **POST** `.../restore`.
- **`bumpPublishedMonoTrashSurfacesRefresh`** then snackbar **Restored.**
- **`GET /v1/published-monos/:id`**: if [`PublishedMonoHiddenWhileEditingException`](lib/features/profile/data/published_mono_catalog_visibility_exception.dart), second snackbar: **Restored. It will appear after you update the published version.**

## Refresh Behavior

- **`bumpPublishedMonoTrashSurfacesRefresh`**: increments `profileProcessingListRefreshProvider` (Mono Home feed + Profile workspace/published per existing listeners) and `profileTrashListRefreshProvider` (Trash screen `listenManual` refresh when mounted).

## Permanent Delete Policy

- Hidden in P2; no repository method for hard delete.

## Tests Added

- Repository: trashed query, `trashedAt` parse, trash/restore POST paths, friendly `published_mono_not_trashed`.
- Trashed pager smoke (stub `fetchTrashedPage`).
- Drawer: **Trash** row.
- Trash screen: remote-off gate + **no “Permanently delete”** copy.
- Mono options: **Move to Trash** label + **no “Permanently delete”**; stub repo unit for id capture.
- **Deferred**: full widget E2E for dialog confirm over dock overlay (stacking/hit-test); dialog confirm + POST is covered by repository tests and production wiring in `mono_story_options_sheet.dart`.

## Flutter Analyze Result

Command:

`flutter analyze lib/features/profile/data/published_mono_dto.dart lib/features/profile/data/remote_published_mono_repository.dart lib/features/profile/profile_processing_refresh.dart lib/features/profile/presentation/providers/profile_trashed_published_mono_pager.dart lib/features/profile/profile_trash_screen.dart lib/features/profile/profile_navigation_drawer.dart lib/main.dart lib/ui/bottom_sheets/mono_story_options_sheet.dart`

Result: **no errors**; **8 info** issues, all **pre-existing deprecations** in `mono_story_options_sheet.dart` (`withOpacity`, `surfaceVariant`), not introduced by Trash copy.

## Flutter Test Result

Commands run:

- `flutter test test/features/profile` (implicit in full run)
- `flutter test test/features/mono` (implicit in full run)
- `flutter test` (full suite)

Result: **All tests passed** (293 tests at time of run).

## Manual Verification Steps

1. Sign in with remote drafts + API enabled (`NIMON_USE_REMOTE_DRAFTS=true`, valid backend).
2. Open a **Published** story in the reader from Profile; open options → **Move to Trash** → confirm; confirm it disappears from **Published** and Mono Home remote feed; snackbar **Moved to Trash.**
3. Profile drawer → **Trash**; see row; **Restore** → confirm; **Restored.**; row leaves Trash; story reappears in **Published** / feed when catalog-visible.
4. With a linked draft that has unpublished edits, after restore confirm the **second** snackbar about republish when `GET .../:id` still hides the row.

## Remaining Risks

- Trash list **date** depends on API including `trashedAt` on list items; UI falls back to `updatedAt`.
- **`useRemoteDrafts` false**: Trash screen is gated; product expects remote mode for real Trash.
- Dialog + dock overlay **widget E2E** not automated (see Tests Added).
