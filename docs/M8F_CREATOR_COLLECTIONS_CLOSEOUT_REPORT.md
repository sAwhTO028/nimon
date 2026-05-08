# M8f Creator Collections Closeout Report

**Milestone:** M8f5 — end-to-end smoke verification, small polish bounds, documentation.  
**Scope:** No new product features unless required to unblock smoke (none required in this pass).

---

## Scope Completed

| Track | Status |
|-------|--------|
| M8f1 Published bulk Delete removed | Confirmed in prior milestone (`docs/M8F1_PROFILE_PUBLISHED_MULTISELECT_SAFETY_REPORT.md`). |
| M8f2 Backend APIs + Prisma | Module present under `nimon-backend/src/modules/creator-collections/**`; DTO documents catalog `itemCount` semantics. |
| M8f3 Flutter owner Add to collection | Wired (`add_to_collection_sheet.dart`, `remote_creator_collections_repository.dart`, tests). |
| M8f4 Public profile Collections + detail | Wired (`public_profile_screen.dart`, `public_creator_collection_detail_screen.dart`, route in `main.dart`). |
| M8f5 Verification | This report: migration file confirmation, automated Flutter runs, backend commands **documented for local execution** (Node/npm unavailable in the automation shell used for this write-up). |

---

## Backend Migration Status

### Required migration file

- **Present:** `nimon-backend/prisma/migrations/20260507130000_creator_mono_collections/migration.sql`  
  - Creates `creator_mono_collections` and `creator_mono_collection_items`, indexes, and FKs.

### Companion migration

- **Also present:** `nimon-backend/prisma/migrations/20260507045402_creator_mono_collections/migration.sql`  
  - Alters column defaults on the same tables (`DROP DEFAULT` on `id` / `updatedAt`).

### Lexicographic apply order

Prisma applies migrations in **directory name order**. Because `20260507045402_*` sorts **before** `20260507130000_*`, a **brand-new** database would attempt the **ALTER** migration **before** the **CREATE** migration. That ordering is risky for empty databases.

**Actions for the team:**

1. On **existing** environments that already applied migrations in historical order, `prisma migrate status` should reflect the real state — no duplicate migrations were added in M8f5.
2. On **fresh** deploys, run `npx prisma migrate deploy` (or `migrate dev`) against a **throwaway** DB and fix ordering if the ALTER step fails (e.g. consolidate history in a controlled way **outside** this Flutter-only closeout doc).

### Commands to run locally (Node/npm required)

```bash
cd nimon-backend
npx prisma generate
npx prisma migrate status
```

**Automation note (2026-05-07):** In the environment used to produce this report, `npm` / `npx` were **not** on `PATH`; Prisma CLI was **not** executed here. Treat backend CLI results below as **pending until run on a developer machine or CI with Node installed**.

---

## Backend API Smoke

**Status:** Not executed in the reporting environment (no live Postgres + no npm to script). **Recommended manual / scripted checklist** aligned with `docs/M8F2_BACKEND_CREATOR_COLLECTIONS_REPORT.md`:

1. Register/sign in a **creator** (JWT).
2. Ensure **≥ 2** published monos for that user (existing publish flow).
3. `POST /v1/me/creator-collections` — create collection `{ "title": "Smoke" }`.
4. `POST /v1/me/creator-collections/:id/items/bulk` — `{ "publishedMonoIds": ["uuid1","uuid2"] }`.
5. `GET /v1/me/creator-collections` — expect `itemCount` matches visible published members (per DTO: catalog-visible count).
6. `GET /v1/users/:userId/creator-collections` — expect **public** collection listed (guest OK).
7. `GET /v1/users/:userId/creator-collections/:collectionId/monos` — only rows where `publishedMono` satisfies `PUBLISHED_MONO_CATALOG_VISIBLE` (see `creator-collections.service.ts` `listPublicCollectionMonos`).
8. **Trash:** move one member mono to trash via existing trash API; re-fetch public collection monos — trashed mono **must not** appear. **Restore** after verification.

**Automated backend coverage:** `creator-collections.service.spec.ts` includes `listPublicCollectionMonos applies catalog visibility filter` (`PUBLISHED_MONO_CATALOG_VISIBLE`).

---

## Flutter Owner Add To Collection Smoke

**Recommended manual path:**

1. Profile → **Published** → multi-select **2** monos.
2. **Add to collection** → bottom sheet lists collections / **Create** flow.
3. On success, confirm **snackbar** (sheet implementation in `add_to_collection_sheet.dart`).
4. `GET /v1/me/creator-collections` refresh path exercised via notifier reload after bulk add.

**Automated:** `test/features/profile/add_to_collection_sheet_test.dart`, `remote_creator_collections_repository_test.dart`, `profile_published_multiselect_m8f1_test.dart`.

---

## Public Profile Collections Smoke

**Recommended manual path:**

1. Open public profile with `?userId=<creator uuid>`.
2. **Collections** segment → list shows row with **title** + **N monos** / **1 mono**.
3. Tap row → **collection detail** loads monos.
4. Tap mono → **`/mono-reader`** opens.

**Automated:** `test/features/profile/public_profile_collections_tab_test.dart`.

---

## Reader Origin Regression Check

- Collection detail and public profile Monos tab pass **`MonoReaderMenuOrigin.publicCreatorProfile`** (owner-facing reader chrome suppressed; product intent per M8f4 report).
- **Add Mono** affordance preserved per existing mono-reader policy (unchanged in M8f5).
- **Sentence body vs description:** List rows use `monoFeedItemFromPublishedMonoListItemDto` with `needsRemoteDetailHydration: true`; reader merges `GET /v1/mono/:id` detail for core text — align with existing reader tests (`mono_feed_item_mapper_test.dart`, published detail parser tests).

---

## Trash / Visibility Regression Check

- **Backend:** Public collection mono query joins `publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE` — trashed / non-catalog monos excluded at source.
- **Flutter:** Does not re-filter trash; trusts API (per M8f4).

---

## Tests / Build Results

### Flutter (executed in this pass)

| Command | Result |
|---------|--------|
| `flutter analyze` on `remote_creator_collections_repository.dart`, `public_profile_screen.dart`, `public_creator_collection_detail_screen.dart`, `add_to_collection_sheet.dart`, `mono_feed_item_mapper.dart` | **No issues found** |
| `flutter test test/features/profile` + `test/features/mono/mono_feed_item_mapper_test.dart` | **Passed** |
| `flutter test` (full suite) | **Passed** (exit code 0) |

### Backend (run locally — not executed here)

| Command | Result |
|---------|--------|
| `npx prisma generate` | **Pending** (no npm in shell) |
| `npx prisma migrate status` | **Pending** |
| `npx jest src/modules/creator-collections` | **Pending** |
| `npx jest` | **Pending** |
| `npx nest build` | **Pending** |

---

## Manual Verification Checklist

Use this for release sign-off when Node + DB are available:

- [ ] `prisma generate` succeeds  
- [ ] `prisma migrate status` reflects expected history (watch for ordering note above on **new** DBs)  
- [ ] Backend smoke checklist (§ Backend API Smoke)  
- [ ] Flutter owner Add to collection (§ Flutter Owner)  
- [ ] Public profile Collections + detail + reader (§ Public Profile & Reader)  
- [ ] Trash mono hidden from public collection monos list; restore works  

---

## Remaining Risks

1. **Migration ordering** for **empty** databases: `20260507045402` before `20260507130000` may break first-time `migrate deploy` until ordering is reconciled (no new migration added in M8f5).  
2. **itemCount** on collection list: backend computes catalog-visible counts; UI pluralization (`0 monos` / `1 mono` / `N monos`) is client-side — acceptable for V1.  
3. **Deep link** to collection detail without `extra`: still shows fallback scaffold (documented in M8f4).  

---

## Deferred Work (not V1 blockers for M8f)

- Learner **Saved** named folders / collections — still deferred per `M8C_COLLECTIONS_DECISION_SPEC.md`.  
- **Share collection URL** — explicitly out of scope for M8f5.  
- Deep-link query fallback for public collection detail without backend GET-one-collection — deferred.  

---

## V1 Release Impact

- **Creator collections** are additive: public profile gains **Collections** next to **Monos**; owner Published gains **Add to collection** bulk action (replaces bulk Delete).  
- **Learner Saved** remains a flat list; no new folder UI.  
- **Trash / visibility** remain authoritative on the server; clients must not assume collection membership implies visibility if backend rules change — current backend filters at query time.  

---

## Summary Table (M8f5 output)

| Question | Answer |
|----------|--------|
| Migration file present (`20260507130000_...`)? | **Yes** |
| `prisma generate` / `migrate status` verified in automation? | **No** — run locally (npm missing in agent shell) |
| Backend smoke passed? | **Not run here** — checklist + unit test evidence for visibility filter |
| Owner Add to collection passed? | **Tests green**; full manual pending |
| Public Collections tab passed? | **Widget tests green**; manual pending |
| Collection detail + reader passed? | **Widget tests green**; reader body = hydrate path as designed |
| Trash visibility safe? | **Backend filter** + Flutter trust model |
| Flutter tests passed? | **Yes** (profile + mapper + full) |
| Full Flutter test passed? | **Yes** |
| Backend build / jest passed? | **Pending local run** |
| M8f closeout complete? | **Documentation + Flutter automation complete**; **backend CLI smoke pending local/CI** |
