# M7e3b Flutter Public Creator Profile Report

## Files Changed
- `lib/features/profile/data/remote_public_creator_profile_repository.dart` (new)
- `lib/features/profile/data/profile_public_providers.dart` (new)
- `lib/features/profile/public_profile_screen.dart`
- `lib/main.dart`
- `lib/features/mono/mono_feed_models.dart`
- `lib/features/mono/data/mono_feed_item_mapper.dart`
- `lib/features/mono/mono_screen.dart`
- `test/features/profile/remote_public_creator_profile_repository_test.dart` (new)
- `test/features/mono/mono_feed_item_mapper_test.dart`

## Public Profile Repository
Added `RemotePublicCreatorProfileRepository`:
- `fetchPublicCreatorProfile(userId)` → `GET /v1/users/:userId/public-profile` (optional auth headers)
- `fetchCreatorMonoPage(userId, cursor, limit)` → `GET /v1/mono/feed?writerId=<userId>` (optional auth headers)

## Route / Navigation
- Added route support for canonical `userId`:
  - `/profile/public?userId=<uuid>`
- Kept legacy handle route (`?creator=<handle>`) using the existing mock screen path.

## Public Profile Screen
`PublicProfileScreen` now has remote-backed mode when `userId` is present:
- loading
- error + retry
- header (avatar, display name, handle, bio)
- follower/following counts
- creator stories list loaded via `writerId` feed filter
- empty: “No published stories yet.”

## Follow Button Behavior
- Guest tap: snackbar “Sign in to follow creators.”
- Self profile: follow button hidden (requires auth session user id)
- Optimistic follow/unfollow:
  - toggles immediately
  - adjusts followersCount locally
  - rolls back on failure
  - on success refreshes:
    - `followingMonoFeedPagerProvider`
    - `profileFollowingPagerProvider`

## Creator Monos List
- Uses `GET /v1/mono/feed?writerId=<userId>` with paging (load more button).
- Items mapped via `monoFeedItemFromMonoFeedSummary`.

## Refresh Behavior
- Follow/unfollow triggers refresh of Following feed/list surfaces.
- Pull-to-refresh reloads profile + stories.

## Tests Added
- `remote_public_creator_profile_repository_test.dart`
- Updated mapper test to assert `writerId` plumbing.

## Flutter Analyze Result
- `flutter analyze` on touched paths (PASS)

## Flutter Test Result
- `flutter test test/features/profile` (PASS)
- `flutter test test/features/mono` (PASS)
- `flutter test` (PASS)

## Remaining Risks
- Legacy public profile mock still exists for handle routes until Flutter switches Mono tap to userId everywhere.
- Public profile UI currently uses a simpler layout than the existing mock NestedScrollView header (acceptable for V1).

## Recommended Next Step
Proceed to **M7e3c**: remove legacy handle route usage by ensuring all entry points supply `writerId` (including any non-feed surfaces), then do a manual smoke pass.

