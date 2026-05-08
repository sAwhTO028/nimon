# P3 Flutter Permanent Delete UI Report

## Files Changed

- `lib/features/profile/data/remote_published_mono_repository.dart`
- `lib/features/profile/profile_trash_screen.dart`
- `lib/features/profile/presentation/permanent_delete_confirm_dialog.dart`
- `test/features/profile/profile_published_mono_permanent_delete_repository_test.dart`
- `test/features/profile/permanent_delete_typed_confirm_dialog_test.dart`

## Repository Method

- Added `RemotePublishedMonoRepository.permanentlyDeletePublishedMono(String publishedMonoId)`
  - Calls `DELETE /v1/published-monos/:id/permanent`
  - Body: `{ "confirm": "DELETE" }`
  - Auth: uses existing auth header merge
  - Error mapping:
    - `missing_delete_confirm` → “Something went wrong. Please try again.”
    - `published_mono_must_be_trashed_first` → “Move this story to Trash first.”
    - `404 published_mono_not_found` → “This story was already deleted.”

## Trash Screen UI

- In `ProfileTrashScreen`, each row now shows:
  - **Restore** (primary)
  - **Permanently delete** (secondary, destructive red TextButton)

## Double Confirmation UX

1) Dialog 1: **Permanently delete story?** → Cancel / Continue  
2) Dialog 2: typed confirm dialog requiring exact **DELETE** before enabling **Permanently delete**.

## Success / Error Behavior

- Success:
  - Calls repository delete
  - `bumpPublishedMonoTrashSurfacesRefresh`
  - Snackbar: **Deleted permanently.**
  - No Undo
- 404 already deleted:
  - Refresh bump
  - Snackbar: **This story was already deleted.**
- Other errors:
  - Snackbar with friendly message from repository

## Refresh Behavior

- Uses existing `bumpPublishedMonoTrashSurfacesRefresh` to refresh:
  - Trash list (when mounted)
  - Profile Published + Workspace
  - Mono feed (when mounted, per existing M5/P2 refresh wiring)

## Tests Added

- Repository tests for `DELETE .../permanent` and friendly error mapping.
- Dialog widget test verifies typed `DELETE` enables the final destructive button.

## Flutter Analyze Result

Run:

`flutter analyze lib/features/profile/profile_trash_screen.dart lib/features/profile/data/remote_published_mono_repository.dart lib/features/profile/presentation/permanent_delete_confirm_dialog.dart`

Result: **No issues found.**

## Flutter Test Result

- `flutter test test/features/profile` — **passed**
- `flutter test` — **passed**

## Manual Verification Steps

1. Open Profile drawer → Trash.
2. On a trashed row, tap **Permanently delete**.
3. Confirm first dialog → Continue.
4. Type `DELETE` → button enables → Permanently delete.
5. Verify row disappears from Trash and snackbar **Deleted permanently.**

## Remaining Risks

- Trash screen is gated when `RemoteBackendConfig.useRemoteDrafts` is false; permanent delete is therefore only reachable in remote mode (expected).
- Media/object-store cleanup remains deferred; DB delete succeeds even if media remains stored.

