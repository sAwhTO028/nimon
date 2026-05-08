# M7e1 Backend Follow Following Report

## Files Changed
- `nimon-backend/prisma/schema.prisma`
- `nimon-backend/prisma/migrations/20260505123124_m7e1_user_follows/migration.sql`
- `nimon-backend/src/app.module.ts`
- `nimon-backend/src/modules/user-follow/user-follow.module.ts`
- `nimon-backend/src/modules/user-follow/user-follow.controller.ts`
- `nimon-backend/src/modules/user-follow/user-follow.service.ts`
- `nimon-backend/src/modules/user-follow/user-follow.dto.ts`
- `nimon-backend/src/modules/user-follow/user-follow.service.spec.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.controller.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.ts`

## Prisma Model / Migration
Added `UserFollow` mapped to `user_follows` with:
- Composite primary key `@@id([followerId, followingId])`
- `createdAt` default now
- Indices:
  - `@@index([followerId, createdAt])`
  - `@@index([followingId, createdAt])`
- FK constraints to `users.id` with `onDelete: Cascade` for both follower/following edges

Migration created/applied:
- `prisma/migrations/20260505123124_m7e1_user_follows/migration.sql`

## Follow / Unfollow Endpoints
Implemented (JWT required):
- `POST /v1/users/:userId/follow`
  - Idempotent via Prisma `upsert`
  - Errors:
    - `400 cannot_follow_self`
    - `404 user_not_found`
- `DELETE /v1/users/:userId/follow`
  - Idempotent via Prisma `deleteMany`
  - Errors:
    - `400 cannot_follow_self`
    - `404 user_not_found`

Return DTO for both:
```json
{
  "userId": "uuid",
  "isFollowing": true,
  "followersCount": 0,
  "followingCount": 0
}
```

Counts are computed for the **target** user:
- `followersCount`: number of rows where `followingId = targetUserId`
- `followingCount`: number of rows where `followerId = targetUserId`

## Me Following List
Implemented (JWT required):
- `GET /v1/me/following?cursor=&limit=`

Behavior:
- Orders by `createdAt desc, followingId desc`
- Cursor is base64url JSON of `{ c: createdAtIso, i: followingId }`
- Returns:
  - `items[]`: `{ userId, handle, displayName, avatarUrl, followedAt }`
  - `nextCursor`
  - `hasMore`

## Following Feed
Extended:
- `GET /v1/mono/feed?following=true`

Behavior:
- Requires auth when `following=true` (guest receives `401`)
- Filters the existing catalog-visible feed (`PUBLISHED_MONO_CATALOG_VISIBLE`) to only include `PublishedMono.ownerId` in the set of users followed by the caller
- Keeps existing DTO shape and social enrichment fields:
  - `likesCount`, `isBookmarkedByMe`, `myReaction`, `shareUrl`, `hasAudio`

## Auth / Visibility Rules
- Follow mutations and `/v1/me/following` are guarded by `JwtAuthGuard`
- `following=true` on feed is enforced at controller level (401 when user missing), and still applies `PUBLISHED_MONO_CATALOG_VISIBLE`

## Tests Added
Added:
- `src/modules/user-follow/user-follow.service.spec.ts`
  - follow idempotent (upsert)
  - unfollow idempotent (deleteMany)
  - self-follow 400
  - missing user 404
  - me-following pagination shape (hasMore/nextCursor)

Mono-feed tests were run (no changes required to existing mono-feed test expectations).

## Prisma Generate / Migration Result
- `prisma generate`: OK
- `migrate dev --name m7e1_user_follows`: created + applied migration
- `migrate status`: “Database schema is up to date!”

## Backend Test Result
- `jest src/modules/mono-feed`: PASS
- `jest src/modules/user-follow`: PASS

## Backend Build Result
- `nest build`: PASS

## Remaining Risks
- The current following-feed implementation loads followed user ids into memory; if a user follows very large numbers of accounts, we may want a pure SQL/Prisma relational filter or join-based approach (or cap follows / add pagination-based feed strategy).
- No public profile endpoint enrichment was added because there is no existing `users` HTTP surface in this repo yet (only an empty `UsersModule`). This is deferred until a public profile endpoint exists.

## Recommended Next Step
Proceed to **M7e2** (Flutter wiring + UI for follow buttons/profile counts + following feed toggle) once product UX is defined, or add a public profile endpoint first (to expose `followersCount`, `followingCount`, and `isFollowingByMe`).

