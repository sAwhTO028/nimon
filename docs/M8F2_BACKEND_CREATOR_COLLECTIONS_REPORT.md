# M8f2 Backend Creator Collections Report

## Files Changed

| Path | Purpose |
|------|---------|
| `nimon-backend/prisma/schema.prisma` | `CreatorMonoCollection`, `CreatorMonoCollectionItem` models; relations on `User` and `PublishedMono`. |
| `nimon-backend/prisma/migrations/20260507130000_creator_mono_collections/migration.sql` | SQL migration (tables, indexes, FKs, `ON DELETE CASCADE`). |
| `nimon-backend/src/modules/creator-collections/creator-collections.dto.ts` | DTOs / response types for collections and mono pages. |
| `nimon-backend/src/modules/creator-collections/creator-collections.service.ts` | Owner + public business logic, catalog-visible counts and mono listing. |
| `nimon-backend/src/modules/creator-collections/me-creator-collections.controller.ts` | Owner routes under `/v1/me/creator-collections` with `JwtAuthGuard`. |
| `nimon-backend/src/modules/creator-collections/public-creator-collections.controller.ts` | Public routes under `/v1/users/:userId/...`. |
| `nimon-backend/src/modules/creator-collections/creator-collections.module.ts` | Nest module wiring. |
| `nimon-backend/src/modules/creator-collections/creator-collections.service.spec.ts` | Unit tests (mocked Prisma). |
| `nimon-backend/src/app.module.ts` | Registers `CreatorCollectionsModule`. |

## Prisma Models / Migration

- **`CreatorMonoCollection`**: `id`, `ownerId` → `users.id` (cascade), `title`, optional `description` / `coverImageUrl`, `visibility` default **`public`**, `sortOrder` default `0`, timestamps. Index `@@index([ownerId, sortOrder, createdAt])`. `@@map("creator_mono_collections")`.
- **`CreatorMonoCollectionItem`**: `id`, `collectionId` (cascade), `publishedMonoId` (cascade), `sortOrder`, `createdAt`. `@@unique([collectionId, publishedMonoId])`, `@@index([publishedMonoId])`. `@@map("creator_mono_collection_items")`.
- **Trash / permanent delete:** Deleting a `PublishedMono` **cascades** collection item rows via FK `onDelete: Cascade`. Deleting a collection **cascades** its item rows.

**Apply migration (dev/prod):** `prisma migrate dev` or `prisma migrate deploy` as appropriate.  
**Status at report time:** `prisma migrate status` reported **one pending** migration (`20260507130000_creator_mono_collections`) on the local datasource (not applied in this task run).

## Owner APIs

All require **`Authorization: Bearer`** and **`JwtAuthGuard`**.

| Method | Path | Body / notes |
|--------|------|----------------|
| GET | `/v1/me/creator-collections` | Lists all collections for the current user (public + private). |
| POST | `/v1/me/creator-collections` | `CreateCreatorMonoCollectionDto` — `title` required (trim, non-empty); optional `description`, `coverImageUrl`, `visibility` (`public` \| `private`), `sortOrder`. |
| PATCH | `/v1/me/creator-collections/:id` | Partial `UpdateCreatorMonoCollectionDto`. **404** if not owner. |
| DELETE | `/v1/me/creator-collections/:id` | **204**; **404** if not owner. |
| POST | `/v1/me/creator-collections/:id/items` | `{ "publishedMonoId": "<uuid>" }` — **403** `not_owner_of_published_mono` if the mono is missing or not owned. **Idempotent:** if the pair already exists, returns `{ created: false, itemId }`. |
| DELETE | `/v1/me/creator-collections/:id/items/:publishedMonoId` | **204**; **404** if collection not owned or item missing. |
| POST | `/v1/me/creator-collections/:id/items/bulk` | `{ "publishedMonoIds": ["uuid", ...] }` — dedupes input. Inserts only monos **owned** by the user; **skips** duplicates already in the collection. Response: `{ inserted, skippedDuplicates, skippedNotOwnedOrMissing }`. |

## Public APIs

No JWT required.

| Method | Path | Behavior |
|--------|------|----------|
| GET | `/v1/users/:userId/creator-collections` | Only collections with **`visibility === 'public'`** for that user. |
| GET | `/v1/users/:userId/creator-collections/:collectionId/monos` | **404** unless collection exists, **`visibility === 'public'`**, and **`ownerId === userId`** (profile owner matches path). Monos filtered by **`PUBLISHED_MONO_CATALOG_VISIBLE`** (not trashed; no dirty linked draft). Query: `limit` (default 20, max 50), `cursor` (optional — previous page’s last **collection item** `id`). Response: `{ items: PublishedMonoListItemDto[], nextCursor }` aligned with existing published list mapping (`publishedMonoListItemFromRow`). |

## Ownership / Visibility Rules

- Every owner mutation checks **`collection.ownerId === jwt.userId`** (via `findFirst` / `deleteMany` with both `id` and `ownerId`).
- Adding an item requires **`PublishedMono.ownerId === jwt.userId`** (same user as collection owner).
- Bulk add **never** attaches another user’s monos; those IDs are counted in **`skippedNotOwnedOrMissing`**.
- Public list endpoints enforce **`visibility === 'public'`** and **`ownerId === :userId`** for the monos sub-route.

## Trash / Delete Interaction

- **Public mono list** inside a collection uses **`PUBLISHED_MONO_CATALOG_VISIBLE`**: excludes **`trashedAt != null`** and excludes monos with a linked draft **`hasUnpublishedCoreChanges === true`** (`published-mono-visibility.ts`).
- **`itemCount`** on collection DTOs counts only items whose **`publishedMono`** satisfies that same visibility predicate (so counts match what readers see publicly).
- **Permanent delete** of a published mono removes **`creator_mono_collection_items`** rows via DB cascade.

## Tests Added

`creator-collections.service.spec.ts` covers:

- Visible **`itemCount`** via **`groupBy`** + **`PUBLISHED_MONO_CATALOG_VISIBLE`**.
- **create** / **update** / **delete** owner scoping.
- **addItem** forbidden when mono not owned; **idempotent** duplicate add.
- **bulkAdd** duplicate + not-owned skips.
- **listPublic** visibility filter; **listPublicCollectionMonos** visibility filter + catalog rule on **`findMany`**.
- **404** when public collection guard fails.

*(Cascade from deleting `PublishedMono` is enforced in schema; no DB integration test in this suite.)*

## Prisma Generate / Migration Result

| Command | Result |
|---------|--------|
| `node ./node_modules/prisma/build/index.js generate` | **Success** — Prisma Client regenerated with new models. |
| `node ./node_modules/prisma/build/index.js migrate status` | **Pending:** `20260507130000_creator_mono_collections` not applied on the connected database (expected until `migrate dev` / `deploy`). |

## Backend Test Result

| Scope | Result |
|-------|--------|
| `jest src/modules/creator-collections` | **11 tests passed** |
| `jest src/modules/published-monos` | **13 tests passed** |
| `jest` (full backend suite) | **126 tests passed** (15 suites) |

## Backend Build Result

| Command | Result |
|---------|--------|
| `nest build` | **Success** (`exit code 0`) |

## Remaining Risks

- **`cursor`** for public monos is the **collection-item row id**; malformed cursors may surface as Prisma errors — consider stricter validation later.
- **Bulk add** uses sequential **`create`** calls for stable **`sortOrder`**; large batches could be batched later.
- **`itemCount`** uses **`groupBy`**; very large lists of collections are still fine at typical profile scale.

## Recommended Next Step

**M8f3 — Flutter:** Wire **Add to collection** to owner APIs (`POST` create/list/bulk), then **M8f4** public profile Collections tab against **GET `/v1/users/:userId/creator-collections`** and monos sub-route.

---

## Output Summary

| Question | Answer |
|----------|--------|
| Prisma models added? | **Yes** |
| Migration added? | **Yes** (`20260507130000_creator_mono_collections`); apply via **`migrate dev` / `deploy`**. |
| Owner APIs added? | **Yes** (JWT-guarded `/v1/me/creator-collections` CRUD + items + bulk). |
| Public APIs added? | **Yes** (`/v1/users/:userId/creator-collections` + `/.../:collectionId/monos`). |
| Ownership enforced? | **Yes** on all owner mutations and public **`ownerId`/`visibility`** checks. |
| Public visibility rules applied? | **Yes** — `public` only + **`PUBLISHED_MONO_CATALOG_VISIBLE`** for mono lists and counts. |
| Trash / permanent delete interaction safe? | **Yes** — visibility filter + **FK cascade** on published mono delete. |
| Tests passed? | **Yes** — **126** backend Jest tests. |
| Backend build passed? | **Yes** |
| Next step M8f3? | **Yes** — Flutter owner wiring + API integration. |
