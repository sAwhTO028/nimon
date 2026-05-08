# M7 Social Profile Polish Closeout Report

## Completed Scope
M7 shipped social persistence + profile polish across backend + Flutter in thin vertical slices:
- **M7a** backend: persisted **bookmark** + **react** + DTO enrichment + optional JWT on public feed/detail
- **M7b** Flutter: optimistic bookmark/react wiring to backend
- **M7c** Flutter: Profile **Saved** tab backed by `GET /v1/me/bookmarks`
- **M7d** Flutter: canonical share UX using `shareUrl`
- **M7e1** backend: follow graph + following feed support
- **M7e2** Flutter: Following feed wired + `/profile/following` list backed by API
- **M7e3a** backend: public creator profile endpoint + `writerId` feed filter
- **M7e3b** Flutter: public creator profile (userId route) + optimistic Follow button
- **M7e3c** Flutter: entry-point cleanup to prefer userId and avoid legacy mock from real content
- **M7e3d** manual smoke: **PASS**

## Bookmark / React
**Backend (M7a)** added persisted models and endpoints:
- `MonoBookmark` (`mono_bookmarks`) and `MonoReaction` (`mono_reactions`) with `onDelete: Cascade`
- Mutations (JWT required, idempotent, catalog-visible enforcement):
  - `POST/DELETE /v1/mono/:monoId/bookmark`
  - `POST/DELETE /v1/mono/:monoId/react`
- Paged bookmarks:
  - `GET /v1/me/bookmarks?cursor=&limit=` (JWT required)
- Public feed/detail enrichment (guest-safe defaults, optional JWT):
  - `likesCount`, `isBookmarkedByMe`, `myReaction`, `shareUrl`, `hasAudio`

**Flutter (M7b)** wired:
- DTO/model parsing for social fields
- `RemoteMonoSocialRepository` methods for bookmark/react
- Optimistic toggles + rollback + auth gates:
  - “Sign in to save stories.”
  - “Sign in to react.”

## Saved Tab
**Flutter (M7c)** shipped a real backend-backed Saved list:
- `RemoteMonoSocialRepository.fetchBookmarkedPage()`
- `profileSavedMonoPagerProvider` (cursor pagination)
- Profile Saved tab states:
  - auth gate (“Sign in to see saved stories.”)
  - loading / error / empty (“No saved stories yet.”)
- Unsave behavior + refresh signal (`profileSavedListRefreshProvider`)

## Share
**Flutter (M7d)** centralized share behavior:
- `shareMonoLink(BuildContext, MonoFeedItem)` copies canonical `shareUrl`
- Consistent snackbar copy:
  - “Link copied.”
  - “Share link is not available yet.”
- Removed body-text copy fallback

## Follow / Following
**Backend (M7e1)**:
- `user_follows` model (composite PK, indices, cascade deletes)
- Follow endpoints (JWT required, idempotent):
  - `POST/DELETE /v1/users/:userId/follow`
  - self-follow → `400 cannot_follow_self`
  - missing user → `404 user_not_found`
- Me following list:
  - `GET /v1/me/following?cursor=&limit=` (JWT required)
- Following feed:
  - `GET /v1/mono/feed?following=true` (auth required, catalog-visible)

**Flutter (M7e2)**:
- `RemoteUserFollowRepository` (follow/unfollow + following list)
- Mono Following tab uses `following=true` feed (auth-gated + empty state)
- `/profile/following` backed by `GET /v1/me/following`

## Public Creator Profile
**Backend (M7e3a)**:
- Public creator profile:
  - `GET /v1/users/:userId/public-profile` (public, optional JWT)
  - returns profile fields + follow counts + `isFollowingByMe`
- Writer feed filter:
  - `GET /v1/mono/feed?writerId=<userId>` (public, catalog-visible)
  - rejects `writerId` + `following=true` with `400 invalid_feed_filter_combo`

**Flutter (M7e3b/c)**:
- Canonical route:
  - `/profile/public?userId=<uuid>`
- Remote-backed public profile screen for `userId` route:
  - profile header + counts + creator stories list + follow button
- Optimistic Follow/Following button:
  - guest gate “Sign in to follow creators.”
  - self profile hides follow
  - follow/unfollow refreshes Following feed and `/profile/following`
- Entry-point cleanup:
  - real content prefers `userId`; missing writerId shows “Creator profile is not available yet.”
  - legacy handle route retained only for mock/demo surfaces

## Smoke Result
Manual smoke (M7e3d): **PASS**
- public profile opens via userId
- follow/unfollow works
- followersCount updates
- Following feed and `/profile/following` reflect follow state
- guest/self states correct

## Tests Summary
Highlights added/updated across M7:
- **Backend Jest**
  - `mono-social` service tests (visibility + idempotency)
  - `mono-feed` service tests (enrichment fields + writerId filter)
  - `user-follow` service tests
  - `users` public profile service tests
- **Flutter tests**
  - DTO parsing + mappers for social fields and `writerId`
  - remote repositories for mono social, follow, public profile
  - share helper widget tests
  - pagers for saved and following surfaces
  - routing policy test for creator profile location
- Full Flutter suite run at the end of M7e3 work: **PASS**

## Remaining Risks
- Following feed backend currently materializes followed IDs; large follow graphs may need a more query-efficient approach later.
- Public profile surface is now real, but some legacy/mock routes still exist until fully removed.
- Social counts UI is functional but not yet polished everywhere (product choice).

## Deferred Scope
- **legacy handle route cleanup**: remove `?creator=` completely once all surfaces supply `writerId`
- **collections**: named bookmark folders/collections are still deferred (default Saved only)
- **followers backend list**: `/profile/followers` UI remains mock; backend endpoint not implemented
- **social count UI polish**: richer presentation/placement of counts (likes/followers) across surfaces
- **share sheet / localization**: system share sheet integration and string localization layer

## Final Verdict
**M7 is closed.** Social persistence (bookmark/react), Saved list, share UX, follow/following, public creator profile, and manual smoke are complete and passing.

## Recommended Next Milestone
**M8 (Discovery + polish)**:
- remove legacy handle route and canonicalize to userId everywhere
- add Followers list backend + UI
- decide on Collections v1.1 (folders) vs Saved-only
- optional: UI polish for follower counts/likes and share sheet integration + localization
