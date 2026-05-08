# M8c1 Saved-only Polish Report

## Files Changed

- `lib/features/mono/saved_only_ux_policy.dart` (new) — central gate for mock “folder/collection” Mono bookmark UI.
- `lib/features/profile/saved_library_copy.dart` (new) — shared English strings for Saved library + Mono save snackbars.
- `lib/features/mono/mono_screen.dart` — saved-only copy/snackbars; demo seeding + collection sheet gated; rail label **Save** / **Saved**.
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart` — Profile Saved footer: flat **Remove from Saved** when demo folders off; optional test override.
- `lib/features/profile/profile_screen.dart` — `_ProfileSavedRemoteTab` guest/empty copy + list trailing tooltip via `SavedLibraryCopy`.
- `test/features/mono/saved_only_ux_policy_test.dart` (new)
- `test/features/mono/mono_story_options_saved_only_test.dart` (new)
- `test/features/profile/saved_library_copy_test.dart` (new)
- `docs/M8C1_SAVED_ONLY_POLISH_REPORT.md` (this file)

## Product Decision Applied

Aligned with `docs/M8C_COLLECTIONS_DECISION_SPEC.md`: **V1 Saved is a flat list** backed by `GET /v1/me/bookmarks`. No collections/folders APIs and **no backend changes** in this milestone. Production-style remote builds should not imply named collections for bookmarks.

## Mono Save UX

- **Bookmark control** continues to call `_toggleBookmark` (remote bookmark/unbookmark); success snackbars use **Saved.** / **Removed from Saved.**; guest prompt uses **Sign in to save stories.**; generic failure **Could not save story.**
- **Learn rail** bottom slot label is **Save** when not saved and **Saved** when saved (replacing “Bookmark”).
- **`_openBookmarkCollectionSheet`** and in-memory folder maps are **no-ops** unless `monoDemoBookmarkFoldersEnabled` is true (debug + local mock Mono + local drafts).
- **Seeded** `_seedSavedIds` / `_seedFolderByItemId` apply only under the same gate so remote sessions are not overwritten by demo bookmark state.

## Profile Saved Copy

- **Guest:** title **Sign in to see saved stories.** / body **Save stories from Mono to find them here.**
- **Empty (authed):** **No saved stories yet.** / **Save stories from Mono to build your reading list.**
- **List row** trailing control tooltip: **Remove from Saved.**

## Demo / Debug Gating

`monoDemoBookmarkFoldersEnabled` is true only when:

`kDebugMode && !RemoteBackendConfig.useRemoteMonoFeed && !RemoteBackendConfig.useRemoteDrafts`

When false (release, or either remote flag on in debug), the collection sheet does not open, demo seeds do not run, and the reader story-options panel for **Profile → Saved** shows a single **Remove from Saved** action (no **Move** stub).

For tests, `showMonoStoryOptionsPanel(..., demoBookmarkFoldersOverrideForTest: false)` forces the saved-only footer without relying on dart-defines.

## Tests Added

- `saved_only_ux_policy_test.dart` — matrix for `savedOnlyUxDemoFoldersEnabled` (debug/release × remote flags).
- `mono_story_options_saved_only_test.dart` — with override false: expects **Remove from Saved**, no **Move** / **Unsave**, no **collection** / **folder** substrings in the panel.
- `saved_library_copy_test.dart` — locks M8c1 Saved tab strings.

**Bookmark API:** existing `test/features/mono/remote_mono_social_repository_test.dart` still covers `bookmarkMono` / `unbookmarkMono` / `fetchBookmarkedPage`.

## Flutter Analyze Result

**Including** `profile_screen.dart` in the path list: `flutter analyze` exits **1** with **45 issues**, all attributable to **pre-existing** `profile_screen.dart` warnings/infos (unused members, `withOpacity` deprecation, etc.) — **no errors**, and nothing new specific to M8c1 beyond touching that file for Saved copy.

**M8c1-only paths** (policy, copy, `mono_screen`, story-options sheet, new tests — **excluding** `profile_screen.dart`):

`flutter analyze lib/features/mono/saved_only_ux_policy.dart lib/features/profile/saved_library_copy.dart lib/features/mono/mono_screen.dart lib/ui/bottom_sheets/mono_story_options_sheet.dart test/features/mono/saved_only_ux_policy_test.dart test/features/mono/mono_story_options_saved_only_test.dart test/features/profile/saved_library_copy_test.dart`

Result: **No issues found** (exit **0**).

## Flutter Test Result

Commands:

- `flutter test test/features/mono` — pass  
- `flutter test test/features/profile` — pass  
- `flutter test` — **331 tests, all passed** (run completed successfully in this workspace).

## Remaining Risks

- **Mock Profile Saved** (folder UI when remote drafts/bookmarks are off) still uses legacy “collection” language; this report only polishes the **remote** `_ProfileSavedRemoteTab` and Mono production-style paths.
- **Public profile** and other non-Saved surfaces may still say “collection” by design (`public_profile_screen.dart`, etc.).
- `_openBookmarkCollectionSheet` is currently unused; if re-wired, it remains gated to demo mode only.

## Recommended Next Step

Continue the **M8 discovery / polish** track in `docs/M8_DISCOVERY_AND_POLISH_PLAN.md` — logical follow-ups after the collections decision are **followers list parity** (§4), further **routing hygiene** (§3), or the next explicitly prioritized **M8d** item from your roadmap (social counts, share sheet, localization), depending on product ordering.
