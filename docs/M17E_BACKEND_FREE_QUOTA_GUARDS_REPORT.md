# M17E — Backend free quota guards (implementation report)

## Summary

V1 free-tier **ownership quotas** are enforced on mutating NestJS paths. Blocked requests return **HTTP 403** with a JSON body:

```json
{
  "code": "quota_exceeded",
  "key": "<specific_limit_key>",
  "limit": <number>,
  "current": <number>
}
```

Flutter handling is **M17F** (out of scope for this PR).

---

## Quota constants

**File:** `src/common/limits/free-tier-quotas.ts`

| Key | Limit |
|-----|------:|
| `publishedMonos` | 30 |
| `savedMonos` | 50 |
| `collections` | 10 |
| `collectionItems` | 30 (per collection) |
| `draftStories` | 50 |

**API `key` strings:** `FREE_TIER_QUOTA_KEYS` — `published_mono_limit_reached`, `saved_mono_limit_reached`, `collection_limit_reached`, `collection_item_limit_reached`, `draft_story_limit_reached`.

---

## Exception helper

**File:** `src/common/limits/quota-exceeded.exception.ts` — `QuotaExceededException` extends Nest `HttpException` with status **403** and the contract body above (no extra internal-only message field).

---

## Enforcement points

| Quota | Where | Rule |
|-------|--------|------|
| **Published monos (30)** | `StoryDraftsService.publishReadOnly`, `publishFullLearn`, `deleteDraft` (discard staging) | **M17E-7:** **`countOwnerPublishedTabVisibleMonos`** + **`assertCanRevealOnePublishedTabMono`** — same predicate as owner Published tab (`PUBLISHED_MONO_CATALOG_VISIBLE`). Block when **`visiblePublishedCount + 1 > 30`** for actions that **add or reveal** one tab row (draft first publish, read-only / full-learn publish that reveals a hidden edit-staged mono, cancel editing discard, trash restore). Read-only / full-learn updates that **do not** change tab visibility (mono already catalog-visible) skip the +1 assert. Non-prod logs: **`[M17E-7 publish-quota]`**, **`[M17E-7 cancel-edit]`**. Mono resolution: **`resolvePublishedMonoIdForReadOnlyPublish`** (M17E-5). |
| **Published restore** | `PublishedMonosService.restorePublishedMono` | **M17E-7:** **`assertCanRevealOnePublishedTabMono`** with tag **`restore-quota`**; **`current`** in **`quota_exceeded`** is tab-visible count before restore. |
| **Saved monos (50)** | `MonoSocialService.bookmark` | If no existing bookmark row: **`monoBookmark.count({ userId })`**; block at **50**. Existing row → upsert still allowed (idempotent). |
| **Collections (10)** | `CreatorCollectionsService.create` | **`creatorMonoCollection.count({ ownerId })`** before insert. |
| **Collection items (30)** | `CreatorCollectionsService.addItemMine` | Count items in **target** `collectionId` before a move/create that increases that count; noop when mono already in target. |
| **Collection items (bulk)** | `CreatorCollectionsService.bulkAddItemsMine` | Same per-target projection inside the transaction (skips duplicates in target; increments for moves/creates). |
| **Draft stories (50)** | `StoryDraftsService.createDraft` | **`storyDraft.count({ ownerId })`** before **`storyDraft.create`**. |

**Published quota count (M17E-7):** Owner Published tab **catalog-visible** rows only — **`countOwnerPublishedTabVisibleMonos`** (`published-mono-published-tab-quota.ts`). Deprecated alias: **`countPublishedTabVisibleMonos`**. Historical slot-union helpers in **`published-mono-quota-counts.ts`** remain for diagnostics / other callers but **do not enforce** the V1 published mono cap.

**Draft count:** All **`story_drafts`** rows for **`ownerId`** (no separate trashed flag on draft in schema).

---

## M17E-7 Published tab visible count + delta

V1 **source of truth** for the published mono free-tier cap is the **same row set** as Own Profile → **Published** tab: **`{ ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE }`**.

- **Guard:** **`assertCanRevealOnePublishedTabMono`** — block when **`visiblePublishedCount + 1 > 30`**.
- **+1 actions (when they reveal a hidden row):** draft first publish; read-only / full-learn publish when **`isOwnerPublishedMonoTabVisible`** is false; **cancel editing** (`deleteDraft` when `hasUnpublishedCoreChanges`); **restore from trash**.
- **No +1:** read-only / full-learn publish when the mono is **already** tab-visible (non-production still logs **`[M17E-7 publish-quota]`** with **`nextVisibleCount` = `visiblePublishedCount`**, **`willBlock=false`**).
- **`quota_exceeded`:** **`key: published_mono_limit_reached`**, **`limit: 30`**, **`current`** = visible count before the action.
- **Not counted:** drafts, trashed monos, edit-staged hidden rows, **`PUBLISHED_MONO_QUOTA_CONSUMING`** for this limit.
- **Supersedes:** slot-union **`throwIfPublishedMonoQuotaFull`** on these paths.

**Tests:** `story-drafts.service.quota.spec.ts`, `story-drafts.service.owner-scope.spec.ts`, `published-monos.service.spec.ts` (restore), `published-mono-published-tab-quota.spec.ts`.

**Flutter:** `discardPublishedEditStagingWithBlockingOverlay`, **`profile_screen`** cancel-edit, **`creator_drawer_publish`**, **`profile_trash_screen`** (single overlay dismiss before quota dialog). **`discard_published_edit_staging_overlay_flow_test.dart`**.

---

## M17E-9 Runtime quota block resolution

**DB evidence (operator):** A direct SQL check on the database used for investigation showed **`published_monos`** **`count(*) = 29`** for owner **`1cf3efd7-804d-4802-87bd-deb1e4ed665a`** (owner-scoped `published_monos` rows as counted in SQL at that time).

**V1 rule vs. symptom:** With a **tab-visible / quota `current` count of 29**, first publish must be **allowed**, because **29 + 1 = 30** and the cap is **30**. The Flutter “free limit reached” (`published_mono_limit_reached`) alert **before** a clean restart was therefore **not** explained by the inspected row count alone.

**Root cause (runtime):** The **running API process** was **stale** — it had **not** been restarted after deploying the latest quota logic (M17E-7 / M17E-9). The live process was still enforcing older behavior, so the client saw a quota block even though the DB showed **29** rows for that owner.

**After clean backend restart:** Upload / first publish **worked correctly** against the same data expectation (**29 → allow**).

**Final rule confirmed (V1, Published-tab–aligned visible `current`):**

- **`current` 28 or 29** → **upload / first publish allowed** (next visible count **29** or **30**, both **≤ 30**).
- **`current` 30** → **upload / first publish blocked** (next would be **31** **> 30**).

**M17E-9 diagnostics (for any future incident):**

- **`[M17E-9 db-target]`** — logged at **`PrismaService`** startup: parsed **`DATABASE_URL`** **host** and **database name** only (no credentials). Confirms **which database instance** the API is connected to.
- **`[M17E-9 quota-block]`** — logged **only on the throw path** for **`published_mono_limit_reached`**: includes **`publishedMonosTotal`**, **`publishedMonosActiveNonTrashed`**, **`publishedTabVisibleCount`** (the quota `current`), **`storyDraftRows`** (diagnostic only; **not** part of the cap), **`nextCount`**, **`limit`**, **`actionName`**, etc.

**If the issue appears again, compare before changing code:**

1. **DB query** — owner-scoped **`published_monos`** counts (and, if needed, active vs. trashed) from the **same** DB you intend the API to use.
2. **`[M17E-9 db-target]`** — from a **fresh** API boot: host + database name must match (1).
3. **`[M17E-9 quota-block]`** (only if a block still occurs) — **`publishedTabVisibleCount`** vs. your SQL; mismatches indicate wrong DB, wrong owner, or **visible** predicate vs. raw row count drift.

**Release / operations note:** **Quota behavior and diagnostics depend on deploying the new build and performing a clean backend restart** so the running process loads the current quota implementation and emits **`[M17E-9 db-target]`** on boot. Skipping restart after a quota deploy can reproduce “wrong” client-side limit alerts that do not match DB counts.

### M17E-9 Implementation (reference)

- **Single throw site** for **`published_mono_limit_reached`:** **`assertCanRevealOnePublishedTabMono`** (`published-mono-published-tab-quota.ts`).
- **Tab-visible count:** Prefer **`$queryRaw`** SQL when the scope is a real Prisma client / transaction — same semantics as **`PUBLISHED_MONO_CATALOG_VISIBLE`** (non-trashed `published_monos` with no linked **`story_drafts`** row where **`hasUnpublishedCoreChanges === true`**). Falls back to Prisma **`count`** in tests / if raw fails.
- **On block (including production):** **`[M17E-9 quota-block]`** line as above; draft totals are **diagnostic only** — not used in the quota formula.
- **Tests:** `story-drafts.service.quota.spec.ts` (M17E-9 first publish with **29** visible monos + **32** drafts → allowed), `published-monos.service.spec.ts` (restore mock totals aligned with M17E-9 log).

---

## M17E-2 Published edit staging quota leak fix

**Problem:** First-publish quota used **`PUBLISHED_MONO_CATALOG_VISIBLE`**, which hides published monos while a linked draft has **`hasUnpublishedCoreChanges`**. Owners at 30 published could “free” a visible slot by editing, then first-publish a **new** `PublishedMono`, then finish the staged edit — ending with **> 30** active published monos.

**Fix:**

- Introduced **`PUBLISHED_MONO_QUOTA_CONSUMING`** (`published-mono-visibility.ts`): **`trashedAt: null`** only — includes edit-staged / catalog-hidden rows.
- Added **`countCatalogVisiblePublishedMonos`** (`published-mono-quota-counts.ts`) and **`PUBLISHED_MONO_QUOTA_CONSUMING`** so quota vs list counts are not confused.
- **`publishReadOnly`** and **`restorePublishedMono`** originally switched to **active row** counts only — superseded by **M17E-3 union slots** (see below).

**Product rules:**

- Quota = **active owned published slots** (non-trashed). Hidden edit-staging still consumes a slot.
- Slots free only on **trash** / **permanent delete** per existing policy.
- **Republish** / update when **`publishedMonoId`** is already set does **not** run the first-publish quota branch.
- **Restore** at quota cap is blocked when **quota-consuming** count is already **30**.

**Tests:** `story-drafts.service.quota.spec.ts` (M17E-2 A/B/C), `published-monos.service.spec.ts` (restore D), `published-mono-visibility.spec.ts` (predicate shape).

---

## M17E-3 Real published edit staging leak fix

### Part A — DB / runtime model (repro lens)

Schema-backed state for the phone repro (no device in CI; operator confirms on hardware):

1. **Before Edit**  
   - **`published_monos`**: one row per published mono; **`ownerId`**; **`trashedAt`** null while active; **`content`** JSON includes **`sourceDraftId`**.  
   - **`story_drafts`**: **`publishedMonoId`** links the workspace row to that mono when published; **`hasUnpublishedCoreChanges`** false when in sync; **`publishState`** in `reading_only_published` / `full_learn_published` when published.  
   - **Catalog-visible** count: active rows **excluding** those with a linked draft **`hasUnpublishedCoreChanges === true`** (`PUBLISHED_MONO_CATALOG_VISIBLE`).  
   - **Quota slots** (M17E-3): not equal to catalog-visible; see formula below.

2. **After tapping Edit (linked published draft)**  
   - **`published_monos`**: same row, still **`trashedAt: null`** (unless the user explicitly trashed — backend does not auto-trash on edit).  
   - **`story_drafts`**: same **`publishedMonoId`**; **`hasUnpublishedCoreChanges`** becomes **true** on core PUT; **`publishState`** preserved for linked monos.  
   - **Catalog-visible** count can drop by 1 while **active row count** stays 30.

3. **Before brand-new first publish**  
   - Non-production: **`[M17E-4 quota]`** (extended diagnosis; see M17E-4 §Part A).

### Parts B–D — Quota definition and guards

- **Quota slots** = **published ownership slots**, not catalog-visible count.  
- Includes: all **active** (`trashedAt == null`) **`PublishedMono`** for the owner (includes catalog-hidden edit-staging).  
- Also includes: **distinct** mono ids **not** among active rows reserved by (a) dirty **`StoryDraft`** with non-null **`publishedMonoId`** when that mono is **trashed or missing** (any **`publishState`**, including **`draft`**), and (b) **trashed** **`PublishedMono`** whose **`content.sourceDraftId`** equals the id of a dirty **`StoryDraft`** with **`publishedMonoId == null`** (M17E-5).  
- Also includes: each **orphan** published draft (**published** `publishState`, **`publishedMonoId` null**).  
- **Dedup**: the reserved-id set dedupes overlaps between (a) and (b) and with active-row ids.  
- **Intentional trash**: trashed mono **without** a staging draft holding its id does not add an active row; trashed **with** staging link still contributes via the reserved branch until resolved.

**Guards:** **`StoryDraftsService.publishReadOnly`**: resolve mono id (FK trim, then **`content.sourceDraftId`**); only if unresolved run quota breakdown + throw, then **`publishedMono.create`**. **`PublishedMonosService.restorePublishedMono`**: **`getPublishedMonoQuotaSlotBreakdown`** + **`throwIfPublishedMonoQuotaFull`**. Republish with existing id unchanged; trash/delete unchanged; restore still blocked at cap.

### Part E — Regression tests

- **`story-drafts.service.quota.spec.ts`**: M17E-3 cases — **29** active **`PublishedMono`** + **1** staging slot on trashed/missing mono ⇒ **`quotaSlots = 30`**, first publish **403** `quota_exceeded` / `published_mono_limit_reached` / **`current: 30`**; **29 + 1 orphan** published draft same; whitespace-only **`publishedMonoId`** uses first-publish path.  
- **Republish** at cap with real **`publishedMonoId`**: no **`publishedMono.create`**.  
- **`published-monos.service.spec.ts`**: restore mocks updated for multi-query quota; **29 active + 1 orphan** ⇒ restore blocked.

### Part F — Debug log

Superseded by **M17E-4** (`[M17E-4 quota]` with extended diagnosis). M17E-3 one-liner removed.

---

## M17E-4 Real published edit-staging quota leak (diagnosis + `sourceDraftId` resolution)

### Part A — Runtime diagnosis (non-production only)

- **`[M17E-4 edit-stage]`** — `createDraft`; **`getDraftById`** when `publishState !== draft` or draft has **`publishedMonoId`**; **`updateDraft`** when linked mono + **`hasUnpublishedCoreChanges`**. Fields: `ownerId`, `publishedMonoId`, `sourceDraftId` (from **`published_monos.content`** when joined), `workspaceDraftId`, `createdDraftId`, draft flags, **`publishedMono.trashedAt`**. There is **no** `StoryDraft.sourcePublishedMonoId` column in Prisma (logged as `n/a`).
- **`[M17E-4 publish-entry]`** — **`publishReadOnly`** and **`publishFullLearn`**: `methodName`, `ownerId`, `draftId`, draft publish flags, **`isFirstPublish`**, **`resolutionVia`** (`story_draft_publishedMonoId` \| `mono_content_sourceDraftId` \| `none` \| `n/a_full_learn_no_row_create`).
- **`[M17E-4 quota]`** — same breakdown object: `visibleCatalogCount`, `activePublishedMonoRows`, `trashedPublishedMonoRows`, `draftsWithPublishedMonoId`, `draftsWithSourceDraftIdMatchingPublishedMono`, `dirtyPublishedDrafts`, `orphanPublishedDrafts`, `quotaSlots`, `limit=30`, `willBlock`.

### Part B — Operator repro

Run steps 1–6 from phone smoke on **non-production** backend; capture all three log prefixes plus raw **403** when blocked.

### Part C — Schema-backed linking (actual field)

- **`StoryDraft`**: only **`publishedMonoId`** (FK, `onDelete: SetNull`).
- **`PublishedMono.content`**: JSON includes **`sourceDraftId`** (workspace draft id at publish time).  
**`resolvePublishedMonoIdForReadOnlyPublish`**: if FK empty after trim, **`publishedMono.findFirst`** where **`content.sourceDraftId == draft.id`**, **`trashedAt: null`**, same **`ownerId`**. Prevents a mistaken first-publish from inserting a **duplicate** row when the draft row lost the FK but the snapshot still points at that draft id.

### Part D — Create guard centralization

- **`publishedMono.create`** exists only in **`StoryDraftsService.publishReadOnly`** (repo-wide `rg`).  
- **`assertCanCreatePublishedMonoSlot`** / **`throwIfPublishedMonoQuotaFull`** in **`published-mono-slot-guards.ts`** — use **`getPublishedMonoQuotaSlotBreakdown`** + log + **`throwIfPublishedMonoQuotaFull`** before create when **`resolutionVia === 'none'`**.

### Part E — Tests

- **`blocks_new_publish_when_one_published_mono_is_edit_staged_and_hidden`** — **30** active rows, **29** catalog-visible, first publish blocked (`quota_exceeded`, **`current: 30`**).  
- **`publishReadOnly resolves existing mono via PublishedMono.content.sourceDraftId...`** — no **`publishedMono.create`** when JSON link hits.

### Part F — Phone acceptance

Non-prod logs: **`[M17E-4 quota] quotaSlots=30 willBlock=true`** on blocked brand-new publish; **`[M17E-5 quota] quotaSlots=30 willBlock=true`** (compact duplicate for grep); **`resolutionVia=mono_content_sourceDraftId`** when the JSON path saved the slot on republish.

---

## M17E-5 Live quota snapshot (phone + local DB)

### Part A — Dev-only snapshot script

**File:** `nimon-backend/scripts/m17e5-published-quota-snapshot.ts`  
**npm:** `npm run quota:snapshot:m17e5 -- <ownerUuid>` (from `nimon-backend/`; forwards args on Unix; on Windows use `npx ts-node scripts/m17e5-published-quota-snapshot.ts <ownerUuid>` with env set as below.)

**Gate:** refuses **`NODE_ENV=production`**. Requires **`M17E5_QUOTA_SNAPSHOT=1`** or **`NODE_ENV=development`** (or **`test`**).

**Output:** JSON with per-row **`PublishedMono`** / **`StoryDraft`** fields, catalog vs quota flags, and **`summary`** including **`quotaSlots`** and **`quotaSlotsSourceSummary`**.

### Part B — Operator: paste three snapshots here

| Snapshot | When | Status |
|----------|------|--------|
| **Snapshot 1** | Before tapping Edit; 30 visible published monos | _Operator: paste JSON from script_ |
| **Snapshot 2** | Immediately after Edit; Published tab shows 29 | _Operator: paste JSON_ |
| **Snapshot 3** | Immediately before brand-new read-only publish | _Operator: paste JSON_ |

### Part C — Analysis from Snapshot 2 (missing link)

**This agent session did not run a physical phone against your DB**; the checklist below is filled from the **regression harness** that mirrors the leaked shape (`blocks_brand_new_publish_when_visible_29_but_one_slot_reserved_by_edit_stage` in `story-drafts.service.quota.spec.ts`).

| Question | Answer (synthetic Snapshot 2) |
|----------|-------------------------------|
| Did the original **`PublishedMono`** row remain? | **Yes** — row still exists (here **trashed**). |
| Is **`trashedAt`** null or not? | **Not null** (trashed while edit workspace exists). |
| Did **`publishedMonoId`** remain on the edit draft? | **No** — **`null`** on the dirty workspace draft. |
| Is the edit draft dirty? | **Yes** — **`hasUnpublishedCoreChanges: true`**. |
| Does **`PublishedMono.content.sourceDraftId`** match the edit draft id? | **Yes** — JSON still points at the workspace **`draft.id`**. |
| Which row represents the reserved published slot? | The **trashed `PublishedMono`** id (slot not in the 29 active rows but still reserved). |
| Why **`quotaSlots`** was not 30 under M17E-3 / M17E-4 only? | Staging query required **`publishState` ≠ `draft`**, so the dirty workspace in **`draft`** was ignored; trashed mono was excluded from **active** count; **no** extra slot for **`content.sourceDraftId`** + dirty **`publishedMonoId: null`** — **`quotaSlots` dropped to 29** and first-publish was allowed → **31** rows after new create + republish. |

### Part D — Patch (smallest rule change)

1. **`getPublishedMonoQuotaSlotBreakdown`:** Count dirty **`StoryDraft`** rows with **`publishedMonoId != null`** for **any** **`publishState`** (drop **`publishState` ≠ draft`** filter). Union reserved mono ids with **trashed** **`PublishedMono`** whose **`content.sourceDraftId`** is in the set of dirty draft ids with **`publishedMonoId == null`**.  
2. **`resolvePublishedMonoIdForReadOnlyPublish`:** If no active row matches **`sourceDraftId`**, match a **trashed** row so read-only publish updates the same snapshot instead of creating a new row.  
3. **`publishReadOnly`:** When updating a **`PublishedMono`** whose **`trashedAt`** is set, clear **`trashedAt`** on successful read-only publish (restore-from-publish path).

### Part E — Regression test

**`blocks_brand_new_publish_when_visible_29_but_one_slot_reserved_by_edit_stage`** in **`story-drafts.service.quota.spec.ts`**: asserts **`quota_exceeded`** / **`current: 30`**, **`publishedMono.create`** not called for brand-new; republish via **`sourceDraftId`** does not create; **`trashedAt: null`** on update; after slot freed (**29** active, no reservation) **create** is called.

### Part F — Phone acceptance (operator)

After backend clean restart, re-run the repro from M17E-4 smoke. Expected: **`[M17E-5 quota] quotaSlots=30 willBlock=true`**, HTTP **403** **`quota_exceeded`** / **`published_mono_limit_reached`**, brand-new publish blocked, staged update succeeds, total active published quota slots never **31**.

---

## M17E-2 phone smoke — Published edit staging quota (manual)

**Automation:** This agent session has **no** access to a physical device, emulator UI session, or your signed-in test account. **Do not treat the checklist below as “passed” until you run it on hardware** (same pattern as [M16D auth phone smoke](./M16D_AUTH_SESSION_PHONE_SMOKE_REPORT.md)).

**Setup:** One test user; **30** active non-trashed `PublishedMono` rows (quota-consuming). Remote drafts + API base pointed at the same backend as the app.

| Step | Action | Expected |
|------|--------|----------|
| 1–2 | Own Profile → Published; confirm count **30** | List/total reflects catalog rules; underlying quota rows = 30 non-trashed. |
| 3–4 | Tap **Edit** on one published mono | Row may **disappear** from Published tab if staging hides it (`hasUnpublishedCoreChanges`); **quota slot still held** (M17E-3 union model; not catalog-visible count). |
| 5–6 | Workspace → new draft → **Publish** brand-new Read Only | **HTTP 403** body: `code=quota_exceeded`, `key=published_mono_limit_reached`, `limit=30`, `current=30`. Non-prod: **`[M17E-4 quota] willBlock=true`**. Flutter: quota dialog (M17F); **no** success snack/route; draft **not** lost. |
| 7–8 | Return to staged mono → **Update / publish** same existing | **Success**; same `publishedMonoId`; **no** second `PublishedMono`; quota-consuming stays **30**. |
| 9–10 | **Trash** one published mono → publish **new** mono | **Success**; quota-consuming **29 → 30**; no duplicate `sourceDraftId` / duplicate mono id. |

**Capture (operator fills in):**

- Blocked publish: paste **raw** 403 response body (or proxy log line).
- Flutter: attach **screenshot** of quota alert (OK + Premium later where applicable).
- After step 8: DB or API proof **30** non-trashed monos, **one** `publishedMonoId` for the edited story.
- After step 10: confirm **30** non-trashed monos, **new** row is distinct from trashed id.

**Operator sign-off**

| Field | Value |
|-------|--------|
| Date / build | _pending_ |
| Phone / OS | _pending_ |
| API base used | _pending_ |
| Steps 1–6 result | _pending_ |
| Steps 7–8 result | _pending_ |
| Steps 9–10 result | _pending_ |

**Proxy verification (CI/agent):** `nimon-backend` Jest **`blocks_new_publish_when_one_published_mono_is_edit_staged_and_hidden`**, M17E-3 cases, **`publishReadOnly` `sourceDraftId` resolution** in `story-drafts.service.quota.spec.ts` + restore quota in `published-monos.service.spec.ts`. **Flutter** quota dialog contract is covered in-app by **M17F** tests (`docs/M17F_FLUTTER_FREE_QUOTA_ALERTS_REPORT.md`), not replaced by this phone checklist.

## Tests added / updated

| Area | File |
|------|------|
| Exception shape | `src/common/limits/free-tier-quota.spec.ts` |
| Draft create + publish quota | `src/modules/story-drafts/story-drafts.service.quota.spec.ts` |
| Restore quota | `src/modules/published-monos/published-monos.service.spec.ts` |
| Publish vs catalog predicates | `src/modules/published-monos/published-mono-visibility.spec.ts` |
| Bookmark quota | `src/modules/mono-social/mono-social.service.spec.ts` |
| Collection create + item quota | `src/modules/creator-collections/creator-collections.service.spec.ts` |

---

## Commands run

```text
cd nimon-backend
node node_modules/jest/bin/jest.js src/modules/published-monos --runInBand
node node_modules/jest/bin/jest.js src/modules/mono-social --runInBand
node node_modules/jest/bin/jest.js src/modules/creator-collections --runInBand
node node_modules/jest/bin/jest.js src/modules/story-drafts --runInBand
node node_modules/jest/bin/jest.js --runInBand
node node_modules/@nestjs/cli/bin/nest.js build
```

---

## Remaining work (M17F)

- Map **403** + `quota_exceeded` body in Flutter HTTP client / repositories.
- Localized alerts using **`key`**, **`limit`**, **`current`** (see `docs/M17D_V1_PRODUCT_LIMITS_STANDARD.md` §7).
- Optional prefetch of counts for UX (not required for correctness).

---

## Notes

- **`publishFullLearn`** does not create a new **`PublishedMono`**; quota for new monos remains on first **`publishReadOnly`** (or any future path that creates a row).
- **`MonoSocialService` lives under `src/modules/mono-social`** (there is no `bookmarks` folder); Jest is run on that path.
