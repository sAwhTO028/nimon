# M14J-B Public Profile Monos Pagination — Audit

## Backend

| Question | Answer |
|----------|--------|
| **Endpoint** | `GET /v1/mono/feed` (`MonoFeedController.listFeed` → `MonoFeedService.listFeed`) |
| **Supports writerId?** | **Yes** — query `writerId`; filters `publishedMono.ownerId` |
| **Supports limit?** | **Yes** — `parseLimit(limitStr)` (bounded, max 30 in service) |
| **Supports cursor?** | **Yes** — opaque cursor; `decodeCursor` + `updatedAt`/`id` keyset |
| **Response shape** | `{ items, nextCursor, hasMore }` (`MonoFeedListResponseDto`) |
| **Ordering** | `updatedAt` desc, `id` desc (newest first) |
| **Visibility** | `PUBLISHED_MONO_CATALOG_VISIBLE` + locale filters; published catalog only |

## Flutter (pre–M14J-B)

| Area | Behavior |
|------|----------|
| **Repository** | `RemotePublicCreatorProfileRepository.fetchCreatorMonoPage(userId, {cursor, limit})` → `GET /v1/mono/feed` with `writerId`, `limit`, `sort=recent`, optional `cursor`; parses `items`, `nextCursor`, `hasMore` |
| **`public_profile_screen.dart`** | Local state `_creatorMonos`, `_creatorNextCursor`, `_creatorHasMore`, `_loadingCreatorMonos`; `_loadCreatorMonosFirstPage` used **limit 15**; `_loadCreatorMonosMore` with cursor; **manual “Load more” button** (no scroll prefetch) |
| **`public_profile_remote_nested_scroll.dart`** | Monos tab = `CustomScrollView` + `SliverToBoxAdapter` only; no change required for pagination wiring |

## Audit table

| Layer | Detail | Status |
|-------|--------|--------|
| Endpoint | `/v1/mono/feed` | OK |
| writerId | Supported | OK |
| limit | Supported | OK |
| cursor | Supported | OK |
| Response | `items`, `nextCursor`, `hasMore` | OK |
| Current Flutter | Single first fetch 15 + button load more | **Change**: page size **10**, scroll-triggered load more, Riverpod notifier |

## Required change (Flutter)

- Dedicated **paginated notifier** (cursor, `hasMore`, separate initial / refresh / load-more flags, `loadMoreError`).
- **UI**: remove “Load more” button; **NotificationListener** (or equivalent) on Monos `CustomScrollView` when `extentAfter <= 600` (and guards in notifier).
- **Repository**: no API change; pass `limit: 10` from notifier.

## Backend change

**None** — cursor pagination for `writerId` already implemented and covered by `mono-feed.service.spec.ts`.
