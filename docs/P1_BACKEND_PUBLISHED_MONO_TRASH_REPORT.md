# P1 Backend Published Mono Trash Report

Implementation follows [PUBLISHED_EDIT_DELETE_POLICY_PLAN.md](PUBLISHED_EDIT_DELETE_POLICY_PLAN.md) §7 / §8 / §13 (backend Trash only — **no** Flutter in this milestone).

---

## Files Changed

| Area | Paths |
|------|--------|
| Prisma | `nimon-backend/prisma/schema.prisma`, `nimon-backend/prisma/migrations/20260505183000_published_mono_trash/migration.sql` |
| Visibility | `nimon-backend/src/modules/published-monos/published-mono-visibility.ts` |
| Published monos | `published-monos.dto.ts`, `published-monos.service.ts`, `published-monos.controller.ts`, `published-monos.service.spec.ts` |
| Story drafts | `story-drafts.service.ts`, `story-drafts.service.owner-scope.spec.ts` |
| Mono feed | `mono-feed.service.spec.ts` (visibility assertion) |

**Note:** `mono-feed.service.ts` and `published-mono-public` flows only import `PUBLISHED_MONO_CATALOG_VISIBLE`; they pick up **`trashedAt: null`** automatically.

---

## Prisma Migration

- **Column:** `PublishedMono.trashedAt` nullable `DateTime`.
- **Index:** `published_monos_ownerId_trashedAt_idx` on `(ownerId, trashedAt)` for Trash list queries.
- **Migration folder:** `prisma/migrations/20260505183000_published_mono_trash/migration.sql`

**Apply (dev/prod operators):**

```bash
cd nimon-backend
node ./node_modules/prisma/build/index.js migrate deploy   # prod
# or
node ./node_modules/prisma/build/index.js migrate dev     # dev
```

---

## Visibility Predicate

`PUBLISHED_MONO_CATALOG_VISIBLE` now requires:

1. **`trashedAt == null`** (active, not in Trash).
2. **Existing M5 rule:** no linked `StoryDraft` with **`hasUnpublishedCoreChanges === true`**.

Applied anywhere this constant is merged into Prisma `where`:

- **`GET /v1/mono/feed`** → `MonoFeedService.listFeed`
- **`GET /v1/mono/:id`** → `MonoFeedService.getPublicMonoById`
- **`GET /v1/published-monos`** (default) → `PublishedMonosService.listPublishedMonos`
- **`GET /v1/published-monos/:id`** → `PublishedMonosService.getPublishedMonoById`

Trashed rows therefore **omit from feed/detail/default owner list** → public/owner APIs return **404** where they already did for hidden-by-edit (`published_mono_not_found`).

---

## Trash Endpoint

- **`POST /v1/published-monos/:id/trash`**
- **Auth:** `JwtOrDevOwnerFallbackGuard` (same as existing published-monos GET — **JWT bearer** maps to owner; optional **dev owner fallback** when enabled in non-production).
- **Owner-scoped:** row must belong to `req.user.userId`.
- **Idempotent:** if `trashedAt` already set, returns `{ id, trashedAt }` without error.
- **Response:** `{ "id": "<uuid>", "trashedAt": "<ISO8601>" }`
- **HTTP:** `200 OK`

---

## Restore Endpoint

- **`POST /v1/published-monos/:id/restore`**
- **Auth / owner:** same as trash.
- **Behavior:** clears `trashedAt` (**`null`**).
- **`400 published_mono_not_trashed`** — chosen when the mono exists for the owner but **`trashedAt` is already `null`** (active catalog row). Caller should rely on **default owner list**, not restore.
- **Response:** `{ "id": "<uuid>", "trashedAt": null }`
- **HTTP:** `200 OK`
- After restore, visibility still follows **`PUBLISHED_MONO_CATALOG_VISIBLE`** (example: restored mono + **`hasUnpublishedCoreChanges`** on linked draft → still **hidden** until republish).

---

## Trash List

- **`GET /v1/published-monos?trashed=true`** (query **`trashed`** also accepts **`1`** or **`yes`**).
- **Auth / owner:** same guard.
- **Where:** `{ ownerId, trashedAt: { not: null } }` — **does not** apply dirty-draft predicate (everything in Trash is listed).
- **Default** `GET /v1/published-monos` (no/`false` **`trashed`**) → active catalog only (**`...PUBLISHED_MONO_CATALOG_VISIBLE`**).

---

## Draft Delete Orphan Prevention

**Policy (recommended, implemented):** **`DELETE /v1/story-drafts/:draftId`** **rejects with `409`** when:

- Draft has **`publishedMonoId`** set **and**
- **`PublishedMono.trashedAt` is `null`** (still “active catalog” semantics).

**Error:** `Conflict` · code **`published_draft_must_be_trashed_first`** · message advises moving the published story **to Trash** first.

**Allowed:** Draft delete proceeds when **`publishedMonoId`** is **`null`/empty**, mono row is **missing**, or linked mono is **already trashed** (`trashedAt != null`). **Permanent delete** of `PublishedMono` / combined cleanup remains **future (P3/P4)**.

---

## Tests Added

| Suite | Coverage |
|--------|-----------|
| `published-monos.service.spec.ts` | Default list uses **`PUBLISHED_MONO_CATALOG_VISIBLE`**; **`?trashed=true`** uses **`trashedAt: { not: null}`**; trash (set + **idempotent**); restore; **404** trash; **400** restore-not-trashed |
| `mono-feed.service.spec.ts` | **`trashedAt: null`** in catalog visibility constant |
| `story-drafts.service.owner-scope.spec.ts` | Delete **requires** **`findFirst`**; **409** if linked mono active; delete **allowed** if linked mono **trashed** |

---

## Prisma Generate / Migration Result

```text
node ./node_modules/prisma/build/index.js generate
# Success — client includes PublishedMono.trashedAt

node ./node_modules/prisma/build/index.js migrate status
# Pending until applied locally: 20260505183000_published_mono_trash
```

---

## Backend Test Result

```text
node ./node_modules/jest/bin/jest.js src/modules/published-monos --no-cache
# Test Suites: 1 passed — Tests: 9 passed

node ./node_modules/jest/bin/jest.js src/modules/mono-feed --no-cache
# Test Suites: 1 passed — Tests: 12 passed

node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts --no-cache
# Test Suites: 1 passed — Tests: 17 passed

node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.owner-scope.spec.ts --no-cache
# Test Suites: 1 passed — Tests: 5 passed
```

---

## Backend Build Result

```text
node ./node_modules/@nestjs/cli/bin/nest.js build
# Exit code 0
```

---

## Remaining Risks

- **DB drift:** Migrate must be deployed before relying on **`trashedAt`** in production.
- **404 vs “trashed”:** Owner/public detail responses do not yet distinguish **trashed** vs **hidden-editing** vs **missing** (optional Flutter copy in later milestone).
- **Draft delete after trash:** Leaves a **trashed** `PublishedMono` without a linking draft allowed — **no** orphan **re-appearance** (mono stays trashed).

---

## Recommended Next Step

1. Deploy migration + Nest build.
2. **P2 Flutter:** Mono “Coming soon” → **Move to Trash** / **Trash** tab / **`?trashed=true`** list wiring + refresh parity with M5e.
3. **P3:** Trash screen + **permanent delete** confirmation + transactional cleanup ([PUBLISHED_EDIT_DELETE_POLICY_PLAN.md](PUBLISHED_EDIT_DELETE_POLICY_PLAN.md) §9–§11).
