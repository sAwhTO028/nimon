# M8b Followers List Report

## Files Changed

### Backend (`nimon-backend`)

| File | Change |
|------|--------|
| `src/modules/user-follow/user-follow.service.ts` | Added `listFollowersOfUser` — cursor paging over `user_follows` where `followingId = target`, order `createdAt desc`, `followerId desc`; reuses existing cursor encode/decode (`i` = tie-breaker id, here `followerId`). |
| `src/modules/user-follow/user-follow.controller.ts` | **Public** `GET /v1/users/:userId/followers?cursor=&limit=` (no JWT). |
| `src/modules/user-follow/user-follow.dto.ts` | Added type alias `UserFollowersListResponseDto` (= same shape as me/following). |
| `src/modules/user-follow/user-follow.service.spec.ts` | Tests: 404 when target missing; happy path + ordering assertion; empty list. |

### Flutter (`nimon`)

| File | Change |
|------|--------|
| `lib/features/profile/data/remote_user_follow_repository.dart` | `fetchFollowersPage(targetUserId, PageRequest)` → `GET /v1/users/:id/followers` with optional auth headers (`Accept` + Bearer if signed in). |
| `lib/features/profile/presentation/providers/profile_followers_pager.dart` | **New** — `profileFollowersPagerProvider.family(targetUserId)` with `loadFirstPage`, `refresh`, `loadMore`. |
| `lib/features/profile/profile_connections_screen.dart` | **Followers:** remote-backed list (removed `kV1ProfileFollowers` mock); auth gate; error + retry; empty copy **“No followers yet.”**; row tap unchanged (`/profile/public?userId=`). **Following:** unchanged behavior; shared row widget. |
| `test/features/profile/remote_user_follow_repository_test.dart` | `fetchFollowersPage` HTTP contract test. |
| `test/features/profile/profile_followers_pager_test.dart` | **New** — pager first page + load more. |

## Backend Followers Endpoint

- **Route:** `GET /v1/users/:userId/followers?cursor=&limit=`
- **Auth:** **Public** (no guard). Rationale: public creator profile already exposes `followersCount`; listing follower identities matches that visibility. JWT may still be sent by the Flutter client for consistency but is not required.
- **Errors:** `404` with `user_not_found` when `:userId` does not exist (after trim).
- **Pagination:** Same cursor encoding as `GET /v1/me/following` (base64url JSON `{ c: ISO date, i: id }`); here `i` is **`followerId`** for stable descending order.
- **Response:** `{ items: [{ userId, handle, displayName, avatarUrl, followedAt }], nextCursor, hasMore }` — **`userId`** is the follower’s id; **`followedAt`** is `UserFollow.createdAt`.

## Flutter Repository / Provider

- **`fetchFollowersPage`** maps JSON items to existing **`MeFollowingUser`** (same fields as following list).
- **`profileFollowersPagerProvider(userId)`** — family keyed by **target** user id. Profile **Followers** screen uses the **signed-in user’s** id (my followers).

## Profile Followers UI

- **`/profile/followers`** loads **`GET .../users/<me>/followers`** when authenticated.
- States: loading spinner, error + Retry, empty (**No followers yet.**), infinite scroll via **`loadMore`** when `hasMore`.
- **Row tap:** `context.push('/profile/public?userId=' + Uri.encodeComponent(userId))` (same as following rows).

## Auth / Guest Behavior

- **Signed out:** Centered prompt — **“Sign in to see followers”** / **“Sign in to see who follows you.”**
- **Authenticated but empty user id** (defensive): **“Profile unavailable”** with recovery copy.
- **`/profile/following`** unchanged (still JWT-required API + existing gate).

## Tests Added

- **Backend:** `user-follow.service.spec.ts` — missing user, pagination shape, ordering `findMany`, empty list.
- **Flutter:** repository GET followers; pager load first / load more.

## Backend Test Result

```text
jest src/modules/user-follow
Tests: 8 passed, 8 total
```

## Backend Build Result

```text
nest build
exit code 0
```

## Flutter Analyze Result

```text
dart analyze lib/features/profile/data/remote_user_follow_repository.dart \
  lib/features/profile/presentation/providers/profile_followers_pager.dart \
  lib/features/profile/profile_connections_screen.dart
No issues found!
```

## Flutter Test Result

```text
flutter test test/features/profile   → All tests passed
flutter test                         → All tests passed (full suite)
```

## Remaining Risks

- **Privacy:** Followers list is public for any user id — align with product if private accounts are introduced later.
- **Guest + deep link** to `/profile/followers`: sees sign-in gate only (expected).
- **`users/me` vs UUID:** Literal `:userId` `me` would query user id `"me"` — clients should always pass real UUIDs.

## Recommended Next Step

**M8c — Collections decision** (spec only unless product approves folders): see `docs/M8_DISCOVERY_AND_POLISH_PLAN.md`; no schema work until the decision is locked.
