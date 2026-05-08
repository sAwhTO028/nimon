# M7e2 Flutter Follow Following Report

## Files Changed
- `lib/features/mono/data/remote_following_mono_feed_repository.dart`
- `lib/features/mono/data/mono_feed_providers.dart`
- `lib/features/mono/mono_screen.dart`
- `lib/features/profile/data/remote_user_follow_repository.dart`
- `lib/features/profile/presentation/providers/profile_following_pager.dart`
- `lib/features/profile/profile_connections_screen.dart`
- `test/features/mono/remote_following_mono_feed_repository_test.dart`
- `test/features/profile/remote_user_follow_repository_test.dart`

## Repository Methods
Added `RemoteUserFollowRepository`:
- `followUser(String userId)` → `POST /v1/users/:userId/follow`
- `unfollowUser(String userId)` → `DELETE /v1/users/:userId/follow`
- `fetchFollowingPage(PageRequest request)` → `GET /v1/me/following?cursor=&limit=`

Error mapping:
- `401` / missing auth headers → `StateError('Sign in required.')`
- `400 cannot_follow_self` → `StateError('You can’t follow yourself.')`
- `404` → `StateError('User not found.')`

Added `RemoteFollowingMonoFeedRepository`:
- `fetchFeedPage(...)` calls `GET /v1/mono/feed?following=true` and **requires auth**.

## Following Feed
`MonoScreen` Following tab now uses backend feed when:
- `RemoteBackendConfig.useRemoteMonoFeed == true`
- user is authenticated

Behavior:
- Guest: shows **“Sign in to see stories from people you follow.”**
- Authed + empty: shows **“Follow creators to see their Mono in this feed.”**
- Supports pagination (loads more near end)
- For You feed remains unchanged and continues to use `monoFeedPagerProvider`.

## Auth / Guest Behavior
- Following feed and `/profile/following` list are auth-gated in UI.
- Feed detail hydration reuses existing detail fetch and still benefits from optional auth enrichment.

## Follow Button Behavior
- **Deferred**: there is no stable public creator profile surface with a reliable `userId` entry point to place a follow button without inventing new UI/route conventions.
- Repository support is implemented so a follow button can be added later with optimistic behavior.

## Mock Replacement
- `/profile/following` (`ProfileConnectionsScreen` with `kind=following`) is now backed by `GET /v1/me/following` (paged).
- `/profile/followers` remains mock/static (no backend endpoint exists yet).
- `lib/data/following_repository.dart` remains unused legacy mock (safe to remove later).

## Tests Added
- `test/features/mono/remote_following_mono_feed_repository_test.dart`
  - ensures `following=true` query param and auth required
- `test/features/profile/remote_user_follow_repository_test.dart`
  - follow/unfollow endpoints + following list paging + error mapping

## Flutter Analyze Result
- (run) `flutter analyze` on touched paths

## Flutter Test Result
- (run) `flutter test test/features/mono`
- (run) `flutter test test/features/profile`
- (run) `flutter test`

## Remaining Risks
- Following feed assumes auth token presence; session transitions (sign-in/out) will require pager refresh/invalidation if UX needs immediate update.
- Public profile + follow button UX depends on a future public creator surface that provides `userId`.

## Recommended Next Step
- **M7e3**: add a creator/profile surface (or enrich existing) that yields `userId`, then implement an optimistic Follow button using `RemoteUserFollowRepository`.

