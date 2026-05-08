# M8f3 Flutter Owner Creator Collections Report

## Files Changed

| Path | Purpose |
|------|---------|
| `lib/features/profile/data/creator_mono_collection.dart` | `CreatorMonoCollection` model + JSON parsing. |
| `lib/features/profile/data/bulk_add_creator_collection_result.dart` | Bulk-add counters from backend. |
| `lib/features/profile/data/remote_creator_collections_repository.dart` | HTTP client for `/v1/me/creator-collections` (+ items/bulk) with auth headers and friendly errors. |
| `lib/features/profile/presentation/providers/my_creator_collections_notifier.dart` | `remoteCreatorCollectionsRepositoryProvider`, `myCreatorCollectionsNotifierProvider`, load/create/bulkAdd. |
| `lib/features/profile/presentation/add_to_collection_sheet.dart` | Bottom sheet UI: list collections, create name field, bulk add + snackbars. |
| `lib/features/profile/profile_screen.dart` | `_publishedAddToCollectionLoose`, `_FolderGroupList.onPublishedAddToCollection`; Published multi-select + overflow **Add to collection** wired when remote + signed-in. |
| `test/features/profile/creator_mono_collection_parse_test.dart` | Model / bulk-result parsing tests. |
| `test/features/profile/remote_creator_collections_repository_test.dart` | Repository URLs, payloads, 401/403 mapping. |
| `test/features/profile/add_to_collection_sheet_test.dart` | Sheet loads collections + tap runs bulk API (mock HTTP). |

## Repository / Models

- **`RemoteCreatorCollectionsRepository`**: `fetchMyCollections`, `createCollection`, `updateCollection`, `deleteCollection`, `addItem`, `removeItem`, `bulkAddItems` — uses `authHeaderBuilder` like published-monos repo.
- **Errors**: `401` → `Sign in required.`; `403` + `not_owner_of_published_mono` → `You can only add your own published stories.`; `404` / `collection_not_found` → `Collection not found.`; otherwise generic `Could not …` messages.
- **`CreatorMonoCollection`**: Aligns with backend DTO (`id`, `ownerId`, `title`, `description`, `coverImageUrl`, `visibility`, `itemCount`, `createdAt`, `updatedAt`).
- **`BulkAddCreatorCollectionResult`**: `inserted`, `skippedDuplicates`, `skippedNotOwnedOrMissing`.

## Provider

- **`remoteCreatorCollectionsRepositoryProvider`**: `@nimon` API base + `authHeaderBuilderProvider`.
- **`myCreatorCollectionsNotifierProvider`** (`MyCreatorCollectionsState`): `load` / `refresh`, `createCollection`, `bulkAddToCollection` (refreshes list after mutations).

## Add To Collection Sheet

- **`showAddToCollectionSheet(context, publishedMonoIds)`** → `Future<bool>` (`true` after a successful bulk add path).
- Title **Add to collection**, subtitle **`N selected`**, loading / error / empty states, **Create new collection** (inline name + Create), **Cancel**.
- Lists collections with title + visible **itemCount** line.

## Create Collection Flow

- Inline **Collection name** field + **Back** / **Create**.
- Calls **`createCollection`** then **`bulkAddToCollection`** into the new collection id so selected monos attach immediately.

## Bulk Add Flow

- Choosing a collection calls **`bulkAddToCollection`** with all **`publishedMonoIds`** from the sheet.
- Snackbars (sequenced): **Added to collection.** when `inserted > 0`; **Already in collection.** when `skippedDuplicates > 0`; **Some stories could not be added.** when `skippedNotOwnedOrMissing > 0`.
- Profile **multi-select** clears only when the sheet returns **`true`** (successful completion).

## Single Item Add Flow

- Published row overflow **Add to collection** pops the same sheet with **`{ row id }`** (no placeholder snackbar when remote + signed-in).

## Delete / Trash Preservation

- Published bulk **Delete** remains removed (still **Add to collection** only).
- Per-item trash / Move to Trash flows untouched.

## Tests Added

- DTO parse + bulk result parse.
- Repository: GET list, POST create, POST bulk body, 403/401 friendly errors.
- Widget: sheet opens, shows collection row, tap triggers bulk + **Added to collection.** snackbar.
- Existing **`profile_published_multiselect_m8f1_test`**: still validates remote-off placeholder snackbar + no **Delete** button.

## Flutter Analyze Result

Command: `flutter analyze` on touched paths.

**Result:** No analyzer **errors** on new files; `profile_screen.dart` reports existing **warnings/info** (deprecated `withOpacity`, unused private helpers, etc.) unchanged in substance.

## Flutter Test Result

| Scope | Result |
|-------|--------|
| `flutter test test/features/profile/` | **All passed** |
| `flutter test` (full suite) | **364 tests passed** |

## Remaining Risks

- **Remote off / guest**: Sheet not shown; snackbars **Collections are coming soon.** / **Sign in required.** — expected until remote drafts + auth.
- **Shared notifier state**: `MyCreatorCollectionsNotifier` is global per app; opening the sheet refreshes list — acceptable for V1.
- **Strict remote 401**: Still triggers `notifyIfStrictUnauthorized401` before throwing.

## Recommended Next Step

**M8f4 — Public profile Collections tab**: consume **`GET /v1/users/:userId/creator-collections`** and **`.../:collectionId/monos`** (see `docs/M8F_CREATOR_COLLECTIONS_PLAN.md`).

---

## Output Summary

| Question | Answer |
|----------|--------|
| Owner collection repo added? | **Yes** — `RemoteCreatorCollectionsRepository` + provider. |
| Add to collection sheet wired? | **Yes** — `showAddToCollectionSheet` + Profile Published integration. |
| Create collection works? | **Yes** — POST + auto bulk add to new id. |
| Bulk add works? | **Yes** — POST bulk + snackbars + notifier refresh. |
| Single item add works? | **Yes** — overflow uses same sheet with one id. |
| Delete still removed? | **Yes** — no bulk Delete on Published. |
| Tests passed? | **Yes** — profile suite + full **364**. |
| Full `flutter test` passed? | **Yes** |
| Next step M8f4? | **Yes** — public profile Collections UI + APIs. |
