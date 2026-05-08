# M3a Mono Feed Backend Report

**Date:** 2026-05-03  
**Scope:** Backend-only public Mono catalog (`nimon-backend`). Flutter unchanged; `story-drafts` and owner-scoped **`/v1/published-monos`** unchanged.

---

## Files Changed

| Path | Role |
|------|------|
| `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts` | Feed summary list types (`MonoFeedSummaryItemDto`, `MonoFeedListResponseDto`). |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` | Cursor pagination, filters, mapping (slim response; `content` read only for teaser fields). Public detail via `publishedMonoDetailFromRow`. |
| `nimon-backend/src/modules/mono-feed/mono-feed.controller.ts` | `GET /v1/mono/feed`, `GET /v1/mono/:monoId` — **no auth guards**. |
| `nimon-backend/src/modules/mono-feed/mono-feed.module.ts` | Nest module wiring. |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | Unit tests for `MonoFeedService`. |
| `nimon-backend/src/app.module.ts` | Registers `MonoFeedModule`. |

---

## Endpoints Added

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/v1/mono/feed` | **Public** | Cursor-paged catalog over `published_monos` only. Query: `limit`, `cursor`, `sort` (`recent` only), `level`, `category`. |
| `GET` | `/v1/mono/:monoId` | **Public** | Full published mono detail (same mapper shape as owner `GET /v1/published-monos/:id`). |

**Deferred:** `query` full-text search — not implemented in M3a (low-risk scope); see [M3_MONO_FEED_BACKEND_INTEGRATION_PLAN.md](M3_MONO_FEED_BACKEND_INTEGRATION_PLAN.md).

---

## Public vs Owner Route Separation

- **`/v1/published-monos`** — unchanged; remains **`JwtOrDevOwnerFallbackGuard`**; **owner-scoped** list + detail for Profile.
- **`/v1/mono/feed`** + **`/v1/mono/:monoId`** — **no JWT**; global catalog + reader detail by id (any published row).

---

## Feed Summary DTO

Each list item includes: `monoId`, `title`, `coverUrl` (from `content.core.coverImageUrl` only — not echoed as raw `content`), `level`, `category`, `categories`, `description`, `writerId`, `writerHandle`, `writerDisplayName`, `publishedAt`, `updatedAt`, `likesCount` (always `0`), `hasAudio` (always `false`), `publishKind` (from `content.publishKind`), `accessType` (`'public'`).

The HTTP response **does not** include the full `content` JSON blob.

---

## Detail DTO

`GET /v1/mono/:monoId` returns **`PublishedMonoDetailDto`** via shared **`publishedMonoDetailFromRow`** (`published-mono-common.ts`) — compatible with existing Flutter reader / Profile parsers.

---

## Pagination Strategy

- **Order:** `updatedAt` **desc**, `id` **desc** (stable tie-break).
- **Cursor:** Base64url-encoded JSON `{ "u": "<ISO updatedAt>", "i": "<uuid>" }` of the **last** row returned when `hasMore` is true.
- **Page size:** `limit + 1` fetched; if more than `limit`, trim to `limit`, set `hasMore: true`, emit `nextCursor`.
- **Defaults:** `limit` default **15**, max **30** (via `parseLimit`).
- **Invalid cursor:** `400` with `invalid_cursor`.

---

## Filters

- **`sort`:** only **`recent`** accepted (default); other values → **`400 unsupported_sort`**.
- **`level`:** exact match on `published_monos.level`.
- **`category`:** exact match on `published_monos.category`.

---

## Performance Notes

- List endpoint **does not** serialize full `content` in JSON responses.
- Prisma **`select`** still loads **`content`** for each feed row to derive **`coverUrl`** and **`publishKind`** until scalar columns or a materialized teaser exist — acceptable for M3a per plan; monitor payload size at scale ([NIMON_QUERY_PERFORMANCE_GUIDE.md](NIMON_QUERY_PERFORMANCE_GUIDE.md), [NIMON_PERFORMANCE_BUDGETS.md](NIMON_PERFORMANCE_BUDGETS.md)).
- **`user_profiles`** joined via `owner.profile` for writer display fields only.

---

## Tests Added

`src/modules/mono-feed/mono-feed.service.spec.ts` — **10** cases: slim summary (no `content` in output), default/max limit behavior, level/category filters, cursor/`hasMore`, empty list, bad cursor, unsupported sort, detail success, detail `404`.

---

## Prisma Generate Result

Command: `node ./node_modules/prisma/build/index.js generate`  
**Result:** **Success** — Prisma Client v7.7.0 generated (schema unchanged; no migration).

---

## Mono Feed Test Result

Command: `node ./node_modules/jest/bin/jest.js src/modules/mono-feed/mono-feed.service.spec.ts`  
**Result:** **Pass** — **10** tests.

---

## Existing Test Result

| Suite | Result |
|-------|--------|
| `src/modules/auth/auth.service.spec.ts` | **Pass** — **7** tests |
| `src/modules/published-monos/published-monos.service.spec.ts` | **Pass** — **2** tests |

---

## Backend Build Result

Command: `node ./node_modules/@nestjs/cli/bin/nest.js build`  
**Result:** **Success** (exit code **0**).

---

## Risks

| Risk | Mitigation |
|------|------------|
| **DB still reads `content` per feed row** | Future: denormalize `coverUrl` / `publishKind` to scalars or JSON path projection. |
| **All `published_monos` are discoverable** | Matches current schema (no visibility column); product may add flags + migration later. |
| **UUID `id` tie-break** | Uses string `<` as Prisma filter — consistent with Postgres UUID ordering for pagination. |

---

## Recommended Next Step

**M3b:** Flutter `MonoFeedRepository`, pager, compile flag, and **`MonoScreen`** wiring to **`GET /v1/mono/feed`** per [M3_MONO_FEED_BACKEND_INTEGRATION_PLAN.md](M3_MONO_FEED_BACKEND_INTEGRATION_PLAN.md).

---

## Output Summary

| Question | Answer |
|----------|--------|
| Feed endpoint added? | **Yes** — `GET /v1/mono/feed` |
| Detail endpoint added? | **Yes** — `GET /v1/mono/:monoId` |
| `/v1/published-monos` unchanged owner-scoped? | **Yes** |
| Cursor pagination added? | **Yes** |
| Full content excluded from feed list? | **Yes** (response items have no `content`; DB may still read JSON for teaser derivation) |
| Tests passed? | **Yes** — mono-feed (**10**), auth (**7**), published-monos (**2**) |
| Backend build passed? | **Yes** |
| Next step M3b or fixes? | **M3b** Flutter integration |
