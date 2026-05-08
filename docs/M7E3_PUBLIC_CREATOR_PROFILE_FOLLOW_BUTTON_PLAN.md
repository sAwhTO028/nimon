# M7e3 Public Creator Profile Follow Button Plan

## 1. Executive Summary

M7e1+M7e2 shipped the backend follow graph and a real Following feed, but **Flutter still cannot render a real Follow button** in the reader/feed because the “public creator profile” surface is currently **mock** and is navigated to by **handle string only** (no stable `userId` contract).

**Goal of M7e3:** make a single, stable “creator identity” contract that all entry points can route to (prefer `userId`), add a minimal **public creator profile API** on the backend that returns profile fields + follow counts + viewer follow state (optional JWT), then wire Flutter to use it and implement an optimistic Follow / Following button that refreshes the Following feed.

## 2. Current Surfaces Audit

### Mono feed card
- Uses `MonoFeedItem` rows produced from `GET /v1/mono/feed`.
- DTO (`MonoFeedSummaryDto`) includes `writerId`, `writerHandle`, `writerDisplayName`.
- `MonoFeedItem` **does not** currently persist `writerId`.

### Mono reader
- Creator tap is already a surfaced interaction:
  - `MonoScreen` uses `onTapCreator` that routes to `'/profile/public?creator=<handle>'`.
- There is currently **no follow CTA** in the reader itself.

### Story options sheet
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart` exists (share, etc.).
- No follow/unfollow actions in this sheet today.

### Profile public screens
- `PublicProfileScreen` (`/profile/public`) is **mock**-data backed via `PublicProfileBundle`.
- Follow state is local-only:
  - `_isFollowing` toggles between “Follow” and “Following” without persistence.
- Route is driven by `creatorHandle` query param (not a stable id).

### Following screen
- `/profile/following` is now remote-backed (M7e2) via `GET /v1/me/following`.
- Following feed is remote-backed in Mono “Following” tab via `GET /v1/mono/feed?following=true`.

## 3. Missing Data

This section answers “can we add a follow button now with the current data?” and identifies the minimal contract changes.

### What we have today
- **In feed DTO** (`MonoFeedSummaryDto`): ✅ `writerId`, ✅ `writerHandle`, ✅ `writerDisplayName`
- **In domain row** (`MonoFeedItem`): ✅ `writerHandle`, ✅ `writerName` (display), ❌ `writerId`
- **In backend feed response**: ❌ `avatarUrl`, ❌ `followersCount`, ❌ `isFollowingByMe`
- **In public profile screen**: mock bundle only; no backend contract

### What we need for a real Follow button
- **Required**
  - Stable creator identifier: **`writerId` / `userId`** (must flow into `MonoFeedItem`)
  - A way to show current follow state for the viewer:
    - either `isFollowingByMe` (optional JWT) or a profile endpoint that returns it
- **Highly recommended**
  - `avatarUrl` (for profile header and consistent identity)
  - `followersCount` and `followingCount` for social proof and navigation

## 4. Recommended UX

### Entry point: tap author from Mono reader/card
- Tap creator chip/row in `MonoScreen` should open a **Public Creator Profile** screen.
- Navigation should prefer `userId` to avoid:
  - handle changes
  - missing/duplicate handles
  - “@” formatting issues

### Public Creator Profile (learner-facing)
Header:
- avatar
- display name
- handle
- optional bio
- **Follow / Following** button
- (optional) followers/following counts as tappable chips

Body:
- Creator’s published monos list (paged)
  - Use the same summary card pattern as the Mono feed.
  - Tapping a mono opens the reader.

States:
- Guest: follow CTA shows “Sign in to follow creators.”
- Self profile: hide follow CTA entirely.
- Empty published list: “No published stories yet.”

## 5. Backend Gap

There is currently no “public users/profile” HTTP surface in `nimon-backend` (UsersModule exists but is empty); therefore M7e3 needs a minimal backend addition.

### Recommended minimal backend API (M7e3a)

**Option A (recommended):** stable-by-id endpoint
- `GET /v1/users/:userId/public-profile`
  - Public: returns creator profile + counts
  - Optional JWT: includes `isFollowingByMe`
  - 404 for missing user or missing profile (choose one behavior; recommend returning nulls when profile row missing but user exists)

Response shape (proposal):
```json
{
  "userId": "uuid",
  "handle": "@writer",
  "displayName": "Writer",
  "avatarUrl": "https://...",
  "bio": "...",
  "followersCount": 0,
  "followingCount": 0,
  "isFollowingByMe": false
}
```

Additionally, one of:
- `GET /v1/users/:userId/published-monos?cursor=&limit=` (public, catalog-visible)
  - or extend existing mono feed with `writerId` filter:
    - `GET /v1/mono/feed?writerId=<userId>` (public)

**Option B:** handle-based endpoint (only if product insists on handle URLs)
- `GET /v1/users/by-handle/:handle/public-profile`
  - Still should return `userId` so Flutter can pivot to id-based navigation after the first fetch.

### Why not “enrich feed only”?
Even though `writerId` exists in feed DTO, we still need:
- counts (`followersCount`, `followingCount`)
- follow state (`isFollowingByMe`)
- profile fields (bio, avatarUrl)
Those are better served by a profile endpoint, not inflated into every feed row.

## 6. Flutter Data Model

### Minimum fields to add
Add to `MonoFeedItem` (and mapper from DTO):
- `writerId: String` (required)
- `writerAvatarUrl: String?` (optional; depends on backend feed enrichment vs profile fetch)

### Public creator profile DTO/model (new)
Create something like:
- `PublicCreatorProfileDto` with fields listed above
- `PublicCreatorProfile` domain model

### Routing change (recommended)
- Replace `'/profile/public?creator=<handle>'` with `'/profile/public?userId=<uuid>'`.
- Keep handle query param temporarily for backward compatibility:
  - if `userId` missing, resolve via handle endpoint and then navigate to canonical `userId`.

## 7. Follow Button Behavior

### Auth gate
- Guest taps Follow:
  - show snackbar: “Sign in to follow creators.”
  - optionally deep-link to login (match existing product pattern)

### Optimistic follow/unfollow
- On tap:
  - toggle button state immediately
  - call:
    - `RemoteUserFollowRepository.followUser(userId)` or `unfollowUser(userId)`
  - update counts locally from response (`followersCount`, `followingCount`)

### Rollback on failure
- If request fails:
  - revert `isFollowingByMe`
  - revert counts
  - show friendly error message (already mapped in repository)

### Self-follow hidden
- If viewer’s `me.userId == profile.userId`, hide follow button.

### Refresh Following feed
On successful follow/unfollow:
- If user is on Mono Following tab, refresh `followingMonoFeedPagerProvider`.
- If user is on `/profile/following`, refresh `profileFollowingPagerProvider`.

## 8. Tests Needed

### Backend (M7e3a)
- `GET /v1/users/:id/public-profile`:
  - guest response includes counts but `isFollowingByMe` false (or null)
  - authed response includes correct `isFollowingByMe`
  - 404 user not found
- If adding `writerId` filter on feed:
  - `GET /v1/mono/feed?writerId=` returns only that writer’s catalog-visible monos

### Flutter (M7e3b/c)
- Profile repository parsing tests for public profile DTO
- Widget tests:
  - guest Follow CTA shows sign-in message
  - optimistic follow/unfollow toggles and rolls back
  - self profile hides button
- Integration-ish: follow triggers refresh signal for Following feed/list providers

## 9. Implementation Split

### M7e3a — Backend public profile/enrichment
- Add public creator profile endpoint (Option A)
- Add public creator monos list (writer filter or dedicated endpoint)
- Add optional JWT support for `isFollowingByMe`

### M7e3b — Flutter public profile screen
- Replace mock `PublicProfileBundle` usage with remote-backed state
- Route by `userId` (with handle fallback if needed)
- Render creator monos list via remote feed list pattern

### M7e3c — Follow button optimistic UX
- Use existing `RemoteUserFollowRepository`
- Add optimistic state + refresh of following providers

### M7e3d — Smoke
- Manual:
  - open creator from Mono
  - follow/unfollow
  - Following feed updates
  - profile following list updates

## 10. Exact Cursor Prompt For M7e3a

Copy/paste:

> You are a senior NestJS + Prisma engineer on nimon-backend. Task: Implement M7e3a — public creator profile endpoint to support Follow button UX. Do NOT modify Flutter. Do NOT run migrations unless strictly required (prefer derived counts). Goals:
> - Add `GET /v1/users/:userId/public-profile`:
>   - public response: `{ userId, handle, displayName, avatarUrl, bio, followersCount, followingCount, isFollowingByMe }`
>   - `isFollowingByMe` uses optional JWT (guest => false)
>   - 404 `user_not_found` for missing user
> - Add a public creator monos list:
>   - Either `GET /v1/mono/feed?writerId=<userId>` (preferred) or `GET /v1/users/:userId/published-monos`
>   - Must enforce `PUBLISHED_MONO_CATALOG_VISIBLE`
> - Tests:
>   - guest vs authed `isFollowingByMe`
>   - counts correctness
>   - writer feed filter correctness
> - Keep mono feed DTO shape backward compatible.

---

## Output summary

- **follow button can be added now?** Not correctly. Flutter needs a stable `userId`-based public profile contract; current public profile is mock and navigated by handle only.
- **missing backend fields**: public profile endpoint (profile fields + counts + `isFollowingByMe`), and optionally a “creator monos list” API (writer filter).
- **recommended surface**: public creator profile opened from `MonoScreen` creator tap, routed by `userId`.
- **backend endpoint needed?** Yes: `GET /v1/users/:userId/public-profile` (optional JWT) + creator monos listing (writer filter).
- **Flutter screens likely to change**: `MonoScreen` creator navigation, `PublicProfileScreen` (replace mock bundle), possibly profile connections row tap target.
- **biggest risk**: choosing handle-based routing and then needing handle resolution / handle change behavior; mitigate by canonical `userId` navigation.
- **first implementation step**: M7e3a backend public profile endpoint + writer feed filter.

