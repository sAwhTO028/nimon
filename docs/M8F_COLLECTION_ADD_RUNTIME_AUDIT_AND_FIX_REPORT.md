# M8f Collection Add Runtime Audit And Fix Report

## Problem

Creator collections UI exists (M8f3), but runtime usage can fail when the Published list is still loading remote rows and the UI shows temporary mock rows. Selecting those mock rows produces **non-UUID** ids; the backend bulk-add DTO requires UUIDv4, so add attempts fail (or are skipped), making "Add to collection" appear broken.

## Expected Flow

## Actual Failure

In remote mode (`NIMON_USE_REMOTE_DRAFTS=true`), Profile -> Published can show temporary/mock "loose items" while the remote published pager is still loading. If the user quickly multi-selects and presses **Add to collection**, Flutter passes those mock item ids, which are **not PublishedMono UUIDs**. Backend rejects (validation) or the add results in no inserts, so items do not appear in the collection and itemCount does not change.

## Frontend Flow Audit

- Entry points:
  - Multi-select bar bulk action calls `onPublishedAddToCollection` with `_selectedIds` (`profile_screen.dart`).
  - Overflow row menu "Add to collection" calls `onPublishedAddToCollection` with `{it.id}`.
- Sheet:
  - `showAddToCollectionSheet(publishedMonoIds: ...)` -> loads collections -> `bulkAddToCollection` -> `RemoteCreatorCollectionsRepository.bulkAddItems`.

Observation: `_selectedIds` stored `_OneShortItem.id`. When remote published pager is initial-loading and empty, the UI can temporarily display `_uploadedLooseItems` (mock ids), which are not UUIDv4.

## Backend Flow Audit

- `POST /v1/me/creator-collections/:id/items/bulk` validates:
  - `publishedMonoIds` is array
  - each entry is UUIDv4 (`@IsUUID('4', { each: true })`)
- Invalid ids will fail validation (400) or be skipped if they never match owned published ids.

## Auth / Token Audit

- Reuses `authHeaderBuilderProvider` -> `Authorization: Bearer <accessToken>` (same as other working profile remote repos).

## Published Mono ID Audit

- Backend expects **PublishedMono.id** UUIDv4.
- Fix: sanitize ids before opening the sheet; block add while syncing if ids are not UUIDv4.

## Migration / Database Audit

Not implicated in this runtime failure.

## Network Request Audit

Expected requests (unchanged):

- `GET /v1/me/creator-collections`
- `POST /v1/me/creator-collections/:id/items/bulk` with JSON `{ publishedMonoIds: [...] }`

## Root Cause

UI allowed "Add to collection" actions on **non-backend** (mock) Published rows during remote initial loading, producing invalid/non-UUID ids.

## Fix Applied

- Added `PublishedMonoIdSanitizer` to filter/dedupe UUIDv4 ids.
- In Profile Published:
  - Sanitizes ids before opening Add-to-collection sheet.
  - Blocks selection and "Add to collection" on rows that are not backend-published while remote mode is on, with a small "syncing" snackbar.

## Tests Added

- `test/features/profile/published_mono_id_sanitizer_test.dart`

## Commands Run

- `dart format lib/features/profile/data/published_mono_id_sanitizer.dart lib/features/profile/profile_screen.dart test/features/profile/published_mono_id_sanitizer_test.dart`
  - Result: formatted (no changes)
- `flutter analyze lib/features/profile/profile_screen.dart lib/features/profile/data/published_mono_id_sanitizer.dart test/features/profile/published_mono_id_sanitizer_test.dart`
  - Result: existing warnings/infos in `profile_screen.dart` (pre-existing file-wide warnings); no errors introduced by this fix
- `flutter test test/features/profile`
  - Result: **passed**
- `flutter test`
  - Result: **passed** (exit code 0)

## Manual Verification

- [ ] Signed-in creator, remote mode on.
- [ ] Wait for Published list to finish loading.
- [ ] Multi-select + Add to collection succeeds and increments itemCount.
- [ ] Try immediately after opening Published tab during loading: UI shows "syncing" snackbar and does not call backend with invalid ids.
- [ ] Single row overflow "Add to collection" works after remote rows load.
- [ ] Public profile -> Collections shows updated itemCount and detail lists the added monos.

## Remaining Risks

- If backend request fails for other reasons (auth/DB), user will see mapped repository errors; consider future polish to show status code in debug only (not done here).

## Follow-up (M8f persistence)

Profile -> Published -> Collections was previously local/demo `_StoryFolder` state. As of the persistence fix, remote mode now reads backend creator collections and creates via `POST /v1/me/creator-collections` (see `docs/M8F_COLLECTION_PERSISTENCE_AND_MENU_CREATE_FIX_REPORT.md`).

