# M17H — Standard mutation loading overlay (implementation report)

## Summary

Long-running owner mutations (publish, update publish, trash restore, permanent delete, cancel editing) show a **shared lightweight blocking overlay** (`lib/ui/blocking_loading_overlay.dart`) immediately after confirmation. The overlay uses a non-dismissible dialog with a **modal barrier**, **small spinner**, and a **short message**. It is dismissed in **`finally`** so success and error paths both clean up; **quota** dialogs run **after** the overlay is closed (explicit **`close()`** before **`showQuotaExceededDialog`** where needed).

## Shared helper

**File:** `lib/ui/blocking_loading_overlay.dart`

- **`showBlockingLoadingOverlay(BuildContext context, String message)`** → returns **`VoidCallback`** to dismiss.
- Idempotent close (safe if already popped / navigator not mounted).
- Uses **`rootNavigator: true`** so it stacks above nested navigators.

## Actions wired

| Action | Message | Location |
|--------|---------|----------|
| Read-only / full-learn publish or update | `Publishing…` / `Updating…` (from draft state) | `creator_drawer_publish.dart` |
| Trash restore | `Restoring…` | `profile_trash_screen.dart` |
| Permanent delete | `Deleting…` | `profile_trash_screen.dart` |
| Cancel editing (discard staging) | `Cancelling edit…` | `profile_screen.dart` (`_discardPublishedEditStagingForProcessingCard`) |

**Quota + errors:** `RemotePublishedMonoRepository` parses **`quota_exceeded`** on restore / permanent delete. `RemoteStoryDraftRepository.deleteDraft` **rethrows** **`AppQuotaExceededException`** (no local fallback delete on quota). UI paths dismiss the overlay before **`showQuotaExceededDialog`**.

**Double-submit:** Trash screen uses **`_publishedMonoMutationBusy`**; publish path keeps **`creatorPublishInProgressProvider`** plus overlay barrier.

## Tests

| Area | File |
|------|------|
| Overlay visible + dismiss; quota dialog after overlay; double-tap guard | `test/ui/blocking_loading_overlay_test.dart` |
| Restore / permanent delete quota JSON → **`AppQuotaExceededException`** | `test/features/profile/profile_published_mono_trash_repository_test.dart` |
| Discard staging DELETE 403 quota | `test/features/create/discard_published_edit_staging_test.dart` |

## Remaining risks

- **Publish overlay** is not covered by a dedicated **`performCreatorDrawerPublish`** widget test (heavy Riverpod + validation setup); behavior is covered via the **shared overlay** tests and manual wiring in **`creator_drawer_publish.dart`**.
- If a mutation completes so fast the dialog never paints, tests that **`pump`** a short delay remain valid; production UX is unchanged.
- **`Navigator.pop`** from the dismiss callback assumes the loading dialog is the top route; nested dialog flows should call **`showBlockingLoadingOverlay`** only from contexts whose root navigator owns the intended stack.
