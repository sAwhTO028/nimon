# M7c Profile Saved List Report

## Files Changed
- `lib/features/mono/data/remote_mono_social_repository.dart`
- `lib/features/profile/profile_processing_refresh.dart`
- `lib/features/profile/presentation/providers/profile_saved_mono_pager.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/mono/mono_screen.dart`
- `test/features/mono/remote_mono_social_repository_test.dart`
- `test/features/profile/profile_saved_mono_pager_test.dart`

## Repository Method
- Implemented `RemoteMonoSocialRepository.fetchBookmarkedPage(PageRequest request)`
  - Calls `GET /v1/me/bookmarks?cursor=&limit=`
  - Requires auth header (JWT)
  - Maps rows into `MonoFeedItem` with social fields: `likesCount`, `isBookmarkedByMe`, `myReaction`, `shareUrl`

## Saved Pager
- Added `profileSavedMonoPagerProvider` (`ProfileSavedMonoPager`)
  - `loadFirstPage`, `refresh`, `loadMore` with cursor pagination
  - `removeItemsByIds` for unsave removal

## Profile Saved Tab
- When `RemoteBackendConfig.useRemoteDrafts == true`:
  - Saved tab uses backend-backed list.
  - Loading / error / empty states added.
  - Tap row opens `/mono-reader` with `MonoReaderMenuOrigin.profileSaved`.
  - Row has an **Unsave** button (bookmark remove).
- When remote drafts are off: legacy mock Saved UI remains (unchanged).

## Auth / Guest Behavior
- Signed out: Saved tab shows:
  - “Sign in to see saved stories.”
  - “Save stories from Mono to find them here.”

## Unsave / Refresh Behavior
- Added `profileSavedListRefreshProvider` + `bumpProfileSavedListRefresh`.
- `MonoScreen` now bumps this signal after successful bookmark/unbookmark.
- Profile Saved tab listens and refreshes pager when authenticated + remote mode.

## Tests Added
- Repository test covers `/v1/me/bookmarks` request + mapping.
- Pager test covers `loadFirstPage`.

## Flutter Analyze Result
- Run per command section.

## Flutter Test Result
- Run per command section.

## Remaining Risks
- Saved tab currently uses a simple list tile UI (not the folder UI) in remote mode.
- If bookmark state changes from other surfaces while Saved is visible, refresh is signal-driven (no polling).

## Recommended Next Step
- M7d: Share UX polish (copy `shareUrl` everywhere + share sheet) and optionally show `likesCount` in UI.

