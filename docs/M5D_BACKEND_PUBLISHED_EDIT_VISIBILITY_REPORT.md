# M5d Backend Published Edit Visibility Report

## Files Changed

| Path | Purpose |
|------|---------|
| `nimon-backend/src/modules/published-monos/published-mono-visibility.ts` | **New** — shared Prisma fragment `PUBLISHED_MONO_CATALOG_VISIBLE`: exclude `published_monos` that have **any** linked `StoryDraft` with `hasUnpublishedCoreChanges === true`. |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` | Public feed `findMany` adds visibility as first `AND` predicate; cursor/level/category unchanged; `getPublicMonoById` merges visibility into `where`. |
| `nimon-backend/src/modules/published-monos/published-monos.service.ts` | Owner list and detail merge the same visibility into `where`. |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | Expectations updated for `AND` + visibility; public detail `findFirst` includes visibility. |
| `nimon-backend/src/modules/published-monos/published-monos.service.spec.ts` | List/detail `where` expectations include `PUBLISHED_MONO_CATALOG_VISIBLE`. |

**Prisma schema:** unchanged.

## Root Cause / Policy

**Problem:** Published catalog APIs treated every `PublishedMono` row as visible whenever the row existed, even when the creator’s linked draft had **unpublished edits** (`hasUnpublishedCoreChanges`), contradicting M5 product rules (hide from Mono Home + Profile Published while editing in Workspace).

**Policy:** Derive visibility from **`StoryDraft.hasUnpublishedCoreChanges`** for drafts linked via **`publishedMonoId`**. Do **not** delete `PublishedMono`. When the creator **republishes**, existing flows set **`hasUnpublishedCoreChanges: false`**, so the row **reappears** without extra flags.

**Owner detail:** **Conservative** — `GET /v1/published-monos/:id` uses the **same** visibility filter as the list. If the draft is dirty, the owner receives **`404` `published_mono_not_found`** (same as public detail), avoiding a split UX where the row is missing from the list but still fetchable by id.

## Mono Feed Filtering

`GET /v1/mono/feed` — `listFeed` builds `where: { AND: [ PUBLISHED_MONO_CATALOG_VISIBLE, … ] }` with existing **level**, **category**, and **cursor** predicates appended. Ordering (`updatedAt` desc, `id` desc) and `take = limit + 1` are unchanged for stable pagination.

## Public Detail Filtering

`GET /v1/mono/:monoId` — `getPublicMonoById` uses `where: { id, …PUBLISHED_MONO_CATALOG_VISIBLE }`. If a dirty linked draft exists, **no row matches** → **`404`** with message **`published_mono_not_found`** (no extra error code).

## Owner Published List Filtering

`GET /v1/published-monos` — `where: { ownerId, …PUBLISHED_MONO_CATALOG_VISIBLE }`.

`GET /v1/published-monos/:id` — same visibility as list (see policy above).

## Republish Restore Behavior

Existing publish paths clear the dirty flag:

- **`publishReadOnly`** (read-only republish): `hasUnpublishedCoreChanges: false` on successful draft update (`story-drafts.service.ts`).
- **`publishFullLearn`**: same on successful `updateMany`.

After republish, **`PUBLISHED_MONO_CATALOG_VISIBLE`** matches again and the mono appears in feed + owner list.

## Tests Added

| Area | Coverage |
|------|----------|
| **mono-feed** | Feed `findMany` always includes catalog visibility; level/category `AND` includes visibility; public detail `findFirst` uses visibility in `where`. |
| **published-monos** | List `where` includes `ownerId` + visibility; detail `findFirst` includes `id`, `ownerId`, and visibility. |

**story-drafts.service.spec.ts** — unchanged behavior; full suite still passes (republish / dirty flag tests already present).

## Backend Test Result

Commands (from `nimon-backend`):

```bash
node ./node_modules/jest/bin/jest.js src/modules/mono-feed
node ./node_modules/jest/bin/jest.js src/modules/published-monos
node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts
```

**Results:** mono-feed **11** tests, published-monos **3** tests, story-drafts.service **13** tests — all passed.

## Backend Build Result

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** Succeeded (exit code **0**).

## Remaining Risks

- **Data anomaly:** multiple `StoryDraft` rows pointing at one `publishedMonoId` — if **any** has `hasUnpublishedCoreChanges`, the mono stays hidden (intentional “any dirty link hides”).
- **No link:** `PublishedMono` with no linked draft is always visible (no `drafts` with `hasUnpublishedCoreChanges`).
- **Owner 404 while editing:** deep links to published mono id return **404** until republish — clients should rely on **Workspace / draft** UX (Flutter M5e+).

## Recommended Next Step

**M5e (Flutter / product):** align **Profile Published** and **Mono Home** with this backend (lists already hide when API omits rows); ensure **Workspace “Editing”** remains the source of truth for in-progress published edits; optional copy or navigation when a hidden id is opened.

---

## Output Summary

| Check | Result |
|-------|--------|
| Mono feed hides dirty published rows? | **Yes** |
| Public detail hides dirty rows? | **Yes** (**404**) |
| Owner published list hides dirty rows? | **Yes** |
| Republish restores visibility? | **Yes** (existing `hasUnpublishedCoreChanges: false` on publish) |
| Tests passed? | **Yes** |
| Backend build passed? | **Yes** |
| Next step M5e? | **Flutter / client alignment** + UX for hidden ids (see above) |
