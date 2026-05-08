# M7a Backend Bookmark React Report

## Files Changed
- `nimon-backend/prisma/schema.prisma`
- `nimon-backend/src/app.module.ts`
- `nimon-backend/src/modules/auth/auth.module.ts`
- `nimon-backend/src/modules/auth/optional-jwt-user.guard.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.controller.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts`
- `nimon-backend/src/modules/mono-social/**`

## Prisma Models / Migration
- Added `MonoBookmark` (`mono_bookmarks`)
  - `@@unique([userId, publishedMonoId])`
  - `@@index([userId, createdAt])`, `@@index([publishedMonoId])`
  - FK `onDelete: Cascade` for `User` and `PublishedMono`
- Added `MonoReaction` (`mono_reactions`)
  - V1 `kind` default `'heart'`
  - `@@unique([userId, publishedMonoId])`
  - `@@index([publishedMonoId])`
  - FK `onDelete: Cascade` for `User` and `PublishedMono`

## API Endpoints
- **Bookmark**
  - `POST /v1/mono/:monoId/bookmark` (JWT required, idempotent)
  - `DELETE /v1/mono/:monoId/bookmark` (JWT required, idempotent)
  - Response: `{ publishedMonoId, isBookmarkedByMe }`
- **React**
  - `POST /v1/mono/:monoId/react` (JWT required, V1 heart, idempotent upsert)
  - `DELETE /v1/mono/:monoId/react` (JWT required, idempotent delete)
  - Response: `{ publishedMonoId, likesCount, myReaction }`
- **My bookmarks**
  - `GET /v1/me/bookmarks?cursor=&limit=` (JWT required, paged)

## Auth / Visibility Rules
- Mutations require `JwtAuthGuard`.
- All bookmark/react writes require the mono to satisfy `PUBLISHED_MONO_CATALOG_VISIBLE`:
  - `trashedAt == null`
  - not hidden by dirty linked draft
- Public feed/detail remain public; optional JWT is handled by `OptionalJwtUserGuard` (guest requests never 401).

## Feed / Detail Enrichment
- `GET /v1/mono/feed` now returns:
  - `likesCount` (server-derived)
  - `isBookmarkedByMe` (false for guests)
  - `myReaction` (`'heart' | null`, null for guests)
  - `shareUrl` (computed)
- `GET /v1/mono/:monoId` now returns the existing detail shape plus:
  - `likesCount`, `isBookmarkedByMe`, `myReaction`, `shareUrl`
- `hasAudio` is now derived (low-risk) from `content.learn.audio.storyAudio.sourceUrl`.

## GET Me Bookmarks
- Returns paged list ordered by `MonoBookmark.createdAt desc, id desc`.
- Filters to `PUBLISHED_MONO_CATALOG_VISIBLE` to avoid returning invisible/trashed monos.
- Each row includes:
  - `likesCount`, `myReaction`, `shareUrl`
  - `isBookmarkedByMe: true`

## Permanent Delete Interaction
- Both `mono_bookmarks` and `mono_reactions` reference `published_monos` with `onDelete: Cascade`,
  so P3 permanent delete of a `PublishedMono` will cascade and remove social rows.

## Tests Added
- `nimon-backend/src/modules/mono-social/mono-social.service.spec.ts`
  - bookmark/react idempotency and visibility 404 coverage
- Updated `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` for new DTO fields.

## Prisma Generate / Migration Result
- Run commands in §13 to generate client and apply migration.

## Backend Test Result
- Run commands in §13 (Jest suites).

## Backend Build Result
- Run `nest build` per §13.

## Remaining Risks
- Feed enrichment currently uses a few extra queries per page for personalization (bookmark/reaction sets).
  This is OK for V1, but can be optimized later with joins/subqueries if needed.
- `/v1/me/bookmarks` currently excludes now-invisible bookmarked monos (policy choice).

## Recommended Next Step
- **M7b (Flutter)**: wire optimistic bookmark/react UX to these endpoints and replace local-only `ValueNotifier` state.

