# M7e3a Backend Public Creator Profile Report

## Files Changed
- `nimon-backend/src/modules/users/users.module.ts`
- `nimon-backend/src/modules/users/users.controller.ts` (new)
- `nimon-backend/src/modules/users/users.service.ts` (new)
- `nimon-backend/src/modules/users/users.dto.ts` (new)
- `nimon-backend/src/modules/users/users.service.spec.ts` (new)
- `nimon-backend/src/modules/mono-feed/mono-feed.controller.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts`

## Public Profile Endpoint
Added:
- `GET /v1/users/:userId/public-profile`

Behavior:
- Public endpoint (no JWT required)
- Uses optional JWT (same behavior as Mono feed/detail):
  - guest/invalid token: treated as guest (no 401)
  - valid token: sets viewer for `isFollowingByMe`
- Missing user: `404 user_not_found`
- Missing `UserProfile` row: returns profile fields as `null` (does not 404)

## Optional JWT Behavior
Implemented by applying `OptionalJwtUserGuard` on the endpoint and reading `req.user?.userId`.

Rules:
- Guest: `isFollowingByMe = false`
- Self (viewer == target): `isFollowingByMe = false`
- Otherwise: `isFollowingByMe = true` when `user_follows` edge exists from viewer → target

## Writer Feed Filter
Extended:
- `GET /v1/mono/feed?writerId=<userId>`

Behavior:
- Public
- Applies `PUBLISHED_MONO_CATALOG_VISIBLE`
- Adds `ownerId = writerId` constraint

Filter combo policy:
- `writerId` + `following=true` → `400 invalid_feed_filter_combo`

## Response Shape
Public profile response:
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

Counts:
- `followersCount`: `COUNT(user_follows where followingId = userId)`
- `followingCount`: `COUNT(user_follows where followerId = userId)`

## Tests Added
Added:
- `src/modules/users/users.service.spec.ts`
  - guest profile counts + `isFollowingByMe=false`
  - authed follower `isFollowingByMe=true`
  - self profile `isFollowingByMe=false`
  - missing user → 404
- Updated `src/modules/mono-feed/mono-feed.service.spec.ts`
  - writerId applies `ownerId` filter

## Backend Test Result
- `jest src/modules/users`: PASS
- `jest src/modules/mono-feed`: PASS

## Backend Build Result
- `nest build`: PASS

## Remaining Risks
- The writer feed filter currently only supports ownerId; if we later add “co-author” or separate writer concepts, we’ll need to revisit the filter.
- Public profile endpoint does not yet include “published monos list”; Flutter can use `GET /v1/mono/feed?writerId=...` for now.

## Recommended Next Step
Proceed to **M7e3b** (Flutter public creator profile wiring) using:
- `GET /v1/users/:userId/public-profile`
- `GET /v1/mono/feed?writerId=<userId>`

