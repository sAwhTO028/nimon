# M8f Collection Persistence And Menu Create Fix Report

## Problem

Creator collections are partially working but not persisting/appearing correctly because some Profile -> Published collection surfaces still use legacy/local `_StoryFolder` state instead of the backend-backed M8f3 repository/notifier.

## Expected Behavior

Remote signed-in owner mode (`NIMON_USE_REMOTE_DRAFTS=true`):

- Create collection: `POST /v1/me/creator-collections`
- Add to collection: `POST /v1/me/creator-collections/:id/items/bulk`
- Owner Profile -> Published -> Collections shows backend collections
- Public profile -> Collections shows the created collection after refresh (public visibility)

## Actual Behavior

- Profile -> Published -> Collections can create a collection visually, but it may not appear on public profile (local-only state).
- Add to collection sheet can still show "No collections yet." if collections were created via local-only UI.

## Flow Audit: Published Collections Tab Add

- **Before fix:** used `_openCreateFolderDialog` to append to `_uploadedFolders` (local mock folders).
- **After fix (remote mode):** Add creates a backend creator collection via `myCreatorCollectionsNotifierProvider.createCollection`.

## Flow Audit: Mono Row Menu Add To Collection

- Uses `showAddToCollectionSheet` (backend-backed) and now blocks non-backend rows in remote mode (syncing snackbar).

## Flow Audit: Multi-select Add To Collection

- Uses `showAddToCollectionSheet` (backend-backed) with UUIDv4 sanitization and blocks non-backend rows in remote mode.

## Backend Persistence Audit

- Backend owner routes are `/v1/me/creator-collections` (+ bulk items route).
- Public profile reads `/v1/users/:userId/creator-collections`.

## Root Cause

Profile -> Published -> Collections tab was still wired to legacy/local `_StoryFolder` collection creation and list source, so new collections were not persisted and were invisible to public profile.

## Fix Applied

- Remote mode: Published Collections tab now reads from `myCreatorCollectionsNotifierProvider` and Add creates backend collections.
- Remote mode: local published folders are hidden (empty list) to avoid showing non-persisted collections.

## Tests Added

Note: `RemoteBackendConfig.useRemoteDrafts` is compile-time (`bool.fromEnvironment`), so widget tests cannot flip it at runtime. Coverage remains on repository/sheet + sanitizer logic.

## Commands Run

- `dart format lib/features/profile/profile_screen.dart`
  - Result: formatted (no changes)
- `flutter analyze lib/features/profile/profile_screen.dart`
  - Result: existing warnings/infos in `profile_screen.dart` (pre-existing file-wide warnings); no new errors introduced by this fix
- `flutter test test/features/profile`
  - Result: **passed**
- `flutter test`
  - Result: **passed** (exit code 0)

## Manual Verification

- [ ] Backend running with migrated DB
- [ ] Profile -> Published -> Collections tab -> Add -> create collection
- [ ] Created collection persists after app refresh
- [ ] Created collection appears on public profile Collections tab after refresh
- [ ] Profile -> Published -> Monos row overflow -> Add to collection -> Create new collection -> Save works
- [ ] New collection contains that mono
- [ ] Multi-select -> Add to collection -> existing collection works
- [ ] Public collection detail shows added monos
- [ ] No local/mock collection appears in remote signed-in owner path

## Remaining Risks

- If remote published list is still initial-loading, mock rows cannot be added (intentional; shows syncing snackbar).
- Owner Profile Published -> Collections is now backend-backed in remote mode; local folder rename/delete UX remains demo-only for remote-off mode.

## Regression: Add Button Hidden

### Root cause

The remote-mode Published -> Collections UI returned a bare `Center(...)` widget for loading/error/empty states, which unintentionally omitted `_FilterRow` (the Monos/Collections chips + **Add** button). That made Add disappear and blocked collection creation (no POST sent).

### Fix

Always render `_buildFilterOrSelectionBar()` (contains the Add button when `onCreateFolder` is provided), and render loading/error/empty/content below it.

### Tests

Covered by existing repository/sheet tests; this regression is in a remote-mode-only branch guarded by `RemoteBackendConfig.useRemoteDrafts` (compile-time), so it is primarily verified via manual smoke + logs (GET + POST visible).

### Commands (post-regression fix)

- `dart format lib/features/profile/profile_screen.dart` -> OK
- `flutter analyze lib/features/profile/profile_screen.dart` -> warnings/infos only (pre-existing)
- `flutter test test/features/profile` -> **passed**
- `flutter test` -> **passed** (exit code 0)

## Regression: Create Button No-op

### Exact root cause

The Add-to-collection sheet's create flow had multiple early returns and no explicit submission state/logs, so runtime failures could appear as a no-op (especially when selected ids were empty/invalid or an async error occurred before any visible feedback).

### Fix applied

- Refactored Create logic into one explicit async path: `_submitCreateAndMaybeAdd()`.
- Added `AddToCollectionSheetMode`:
  - `createAndAdd` (default): create collection then bulk add selected PublishedMono ids
  - `createOnly`: create empty collection (no bulk add)
- Added debug logs in debug mode so Create taps cannot be silent.
- Added loading state (`Creating…`) and disables Back/Create while submitting.
- Added explicit snackbar validation for:
  - empty name
  - empty ids in `createAndAdd` ("Stories are still syncing. Please try again.")
- Unified Published -> Collections -> Add to use the same sheet in `createOnly` mode.

### Tests

- Updated `test/features/profile/add_to_collection_sheet_test.dart`:
  - createAndAdd: POST create then POST bulk
  - createOnly: POST create, no bulk

## Regression: DTO Payload Mismatch

### Error

- Backend toast/error: **\"property title should not exist\"**

### Root cause

`MeCreatorCollectionsController` imported DTO classes with a **type-only import** (`import type { ... }`). With the global `ValidationPipe` configured as `whitelist: true` and `forbidNonWhitelisted: true`, this can break runtime DTO metadata and make valid request properties appear non-whitelisted.

### Fix

- Switched to a **value import** in:
  - `nimon-backend/src/modules/creator-collections/me-creator-collections.controller.ts`
- Flutter payload unchanged: it continues to send `{ "title": "..." }`.

### Tests / build

- `jest src/modules/creator-collections --runInBand` -> **2 suites, 13 tests passed**
- `jest --runInBand` -> **16 suites, 128 tests passed**
- `nest build` -> **passed**

