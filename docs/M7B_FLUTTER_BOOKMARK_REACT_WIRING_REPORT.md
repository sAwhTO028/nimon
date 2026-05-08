# M7b Flutter Bookmark React Wiring Report

## Files Changed
- `lib/features/mono/data/mono_feed_summary_dto.dart`
- `lib/features/profile/data/published_mono_dto.dart`
- `lib/features/mono/mono_feed_models.dart`
- `lib/features/mono/data/mono_feed_item_mapper.dart`
- `lib/features/mono/data/remote_mono_feed_repository.dart`
- `lib/features/mono/data/remote_mono_social_repository.dart`
- `lib/features/mono/data/mono_feed_providers.dart`
- `lib/features/mono/mono_screen.dart`
- `test/features/mono/mono_feed_summary_dto_test.dart`
- `test/features/mono/mono_feed_item_mapper_test.dart`
- `test/features/mono/remote_mono_feed_repository_test.dart`
- `test/features/mono/remote_mono_social_repository_test.dart`

## DTO / Model Mapping
- `MonoFeedSummaryDto` now parses:
  - `likesCount` (default 0)
  - `isBookmarkedByMe` (default false)
  - `myReaction` (nullable)
  - `shareUrl` (nullable)
- `PublishedMonoDetailDto` now carries the same fields with safe defaults.
- `MonoFeedItem` now carries these social fields so Mono UI can hydrate immediately.
- `monoFeedItemFromMonoFeedSummary` and `monoFeedItemMergePublishedDetail` now map/merge the fields.

## Repository Methods
- Added `RemoteMonoSocialRepository`:
  - `bookmarkMono`, `unbookmarkMono`, `reactMono`, `unreactMono`
  - Uses `authHeaderBuilderProvider`
  - Friendly `StateError('Sign in required.')` on missing/401 auth
  - 404 mapped to `This story is not available right now.`

## Optimistic State
- `MonoScreen` now:
  - Hydrates local per-mono state from API fields (`isBookmarkedByMe`, `myReaction`, `likesCount`)
  - Applies optimistic toggles on tap
  - Rolls back on failure and shows a snackbar
  - Uses a touched-id set to avoid overwriting user-toggled state while the session is active

## Auth Gate
- Guest tap behavior:
  - Bookmark: “Sign in to save stories.”
  - React: “Sign in to react.”

## UI Behavior
- React:
  - optimistic toggle and likesCount +/- (clamped at 0)
  - server `likesCount` response becomes the source of truth when the call succeeds
- Bookmark:
  - optimistic toggle and server confirmation
- Collections sheet remains in code but rail tap now performs default Saved toggle (collections deferred).

## Share URL Handling
- If `shareUrl` is present, copy it.
- Otherwise, fallback to copying the story text (legacy behavior).

## Tests Added
- DTO parsing tests for new fields.
- Mapper merge test verifies social fields are preserved.
- Repository tests verify endpoints and auth header usage.

## Flutter Analyze Result
- Run in §11.

## Flutter Test Result
- Run in §11.

## Remaining Risks
- Likes count is updated locally but not currently displayed on the rail.
- Collections UX is deferred; current rail bookmark toggles default Saved only.
- No global feed invalidation is triggered per tap (by design for M7b).

## Recommended Next Step
- M7c: Profile “Saved” list backed by `GET /v1/me/bookmarks`, and unify bookmark state across Mono + Profile surfaces.

