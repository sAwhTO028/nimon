# Draft Dirty State Design Plan

**Status:** PLAN / AUDIT ONLY — no implementation in this change.  
**Constraint:** List endpoints must not load full drafts or run full document-vs-`PublishedMono` diffs per row.

---

## 1. Current Problem

`PublishState` (Prisma: `draft` | `reading_only_published` | `full_learn_published`) answers **“what tier the story is published to”**, not **whether the working `StoryDraft` still differs** from the last content pushed to the user’s **Read Only** (or learn) published snapshot.

| Need | What `publishState` gives you |
|------|------------------------------|
| **draft** | Only `draft` — correct. |
| **editing with unpublished changes** | **Not distinguishable** from *published and already aligned* if both are `reading_only_published` (or `full_learn_published`). |
| **published and synced** | **Not detectable** — a row can stay `reading_only_published` after a successful “Update Read Only” with no further edits, or it can have local draft changes not yet re-published. |

The Flutter app previously used **full `loadDraft` + local signature** to hide “clean” published stories from Workspace; after summary pagination, **`publishState` alone** forces this rule: **every published summary row is treated as “Editing”** (`workspaceStateFromDraftSummary` in `profile_screen.dart`), which **over-includes** published-but-synced rows and confuses **Published tab duplicate hiding** (`_workspaceEditingDraftIdsForPublishedHide` keys off the same coarse “editing” set).

---

## 2. Product Behavior Needed

**Workspace (Processing)**

1. **Drafts** — Rows that are still unpublished work (`publishState === draft`). Always visible (subject to filters/pagination).
2. **Editing** — Published rows **with** pending core changes relative to what users see as the published Read Only story (and/or learn snapshot policy). User expects “continue editing / update publish.”
3. **Synced** — Published rows **without** unpublished core changes: either **hidden** from Workspace (preferred for a compact list) or shown in a **minimal “Up to date”** lane — product choice must be explicit.

**Published tab**

- Hide the **duplicate** loose/mock row for a story **only when** the linked draft is genuinely **editing** (unpublished delta), not merely because `sourceDraftId` exists.
- Backend-published rows already skip aggressive hide rules (`_hidePublishedItemForWorkspaceEditing`); the fix must integrate with **`hasUnpublishedCoreChanges`** so mock/local rows don’t flip incorrectly.

---

## 3. Backend Options

| Option | Idea | Correctness | Query cost | Implementation cost | Migration | Verdict |
|--------|------|-------------|------------|---------------------|-----------|---------|
| **A. `hasUnpublishedCoreChanges` boolean** | Single flag on `StoryDraft`, maintained on writes + cleared on successful publish of the relevant slice. | **Good** if write paths are exhaustive; **bad** if one path forgets to set `true`. | **O(1)** in list `select` | **Medium** — many code paths | Add column + backfill policy | **Recommended** as primary UX switch |
| **B. `coreContentHash` + `publishedCoreHash`** | Compare hashes in **application** (not in list query): list returns hashes; client/server derives dirty **without** loading blobs in SQL. | **Strong** if hash canonicalization is stable; sensitive to JSON key order / whitespace unless normalized. | **O(1)** extra columns in list | **High** — define canonical serialization + hash algorithm + bump rules | Backfill compute once per row (batch) | **Recommended** as **optional audit / reconciliation** paired with A |
| **C. `contentVersion` / `publishedVersion` integers** | Bump draft version on edit; set `publishedVersion` on publish; dirty iff `contentVersion > publishedVersion`. | **Good** if every mutating path increments; **fragile** if a path skips bump. | **O(1)** | **Medium–high** — discipline on all mutations | Initialize `publishedVersion = contentVersion` at first publish | **Viable**; similar discipline to A |
| **D. `updatedAt` vs `readingOnlyPublishedAt` heuristic** | Dirty if `draft.updatedAt > lastSuccessfulPublishTime`. | **Weak** — metadata-only updates, clock skew, imports, or saves that don’t change “core” still flip dirty; **false positives**. | **Cheapest** (existing columns) | **Low** | None | **Not recommended** as sole signal |
| **E. List-time full diff** | For each row, load draft + `PublishedMono.content` and diff. | **High** if diff matches product | **Unacceptable** for large lists (CPU + I/O) | **High** | N/A | **Rejected** for list (allowed **offline** for admin repair or one-off job) |

---

## 4. Recommended Design

**Primary:** Persisted **`hasUnpublishedCoreChanges: boolean`** on **`StoryDraft`**, maintained on **every** mutation that can diverge from the last published Read Only core snapshot.

**Secondary (optional but valuable):** Persist **`draftCoreContentHash`** and **`publishedCoreContentHash`** (or `lastPublishedCoreHash` stored on the draft at publish time):

- On successful **Read Only publish**, set `publishedCoreContentHash := draftCoreContentHash` and `hasUnpublishedCoreChanges := false`.
- On **any** draft mutation that affects “core” parity, recompute `draftCoreContentHash` and set `hasUnpublishedCoreChanges := (draftCoreContentHash !== publishedCoreContentHash)` (or simply `true` until publish if recomputation is deferred).

The **boolean** drives fast list UX; **hashes** catch drift from bugs or manual DB edits and support a future **reconciliation job** without comparing blobs in `GET /v1/story-drafts`.

**`workspaceState` derivation (list mapper, no diff):**

| `publishState` | `hasUnpublishedCoreChanges` | `workspaceState` |
|----------------|----------------------------|------------------|
| `draft` | * | `draft` |
| `reading_only_published` \| `full_learn_published` | `true` | `editing` |
| `reading_only_published` \| `full_learn_published` | `false` | `synced` |

**Filtering:** Optionally support `?workspaceState=` or `?hasUnpublishedCoreChanges=` on `GET /v1/story-drafts` later so Workspace requests **exclude synced** server-side (reduces payload). Not required for v1 if Flutter filters client-side.

---

## 5. Write-path Updates

Exact places to set **`hasUnpublishedCoreChanges`** (and optionally recompute **`draftCoreContentHash`**):

| Event | Set dirty? | Notes |
|-------|------------|------|
| **Create draft** | `false` (nothing published yet) | N/A for RO parity until first publish. |
| **Update draft** (`PUT` story draft — basics, sentences, modules, audio, etc.) | **`true`** if `publishState !== draft` *and* mutation touches **core parity scope** (see below). If still pure `draft`, flag irrelevant or always `false`. | Single **`updateDraft`** transaction in `story-drafts.service.ts` is the main funnel. |
| **Save draft** (same as update from API POV) | Same as update | Flutter `saveDraft` hits same endpoint in remote mode. |
| **Publish Read Only** | **`false`** after successful write to `PublishedMono` + draft publish fields | Atomically align “published snapshot” with draft at commit time. |
| **Publish Full Learn** | **`false`** only if product defines “synced” as including FL parity; else keep **`true`** until RO/FL cores match policy | Clarify whether FL publish clears RO dirty — typically **yes** for same draft revision. |
| **Update published content** (if a distinct API updates `PublishedMono` without draft) | Usually **N/A** for Workspace draft row; if draft exists, may need **`true`** on draft when mono updated externally | Rare in V1; document if added later. |
| **Delete draft** | Row gone | — |
| **Restore / resume** | **No server change** unless restore imports content via `updateDraft` | Client-only resume loads full draft then saves → dirty rules apply on save. |

**Core parity scope (must be documented in code):** fields that flow into Read Only published `core` (per existing `publishReadOnly` path): basics + sentence ordering/content as currently serialized; optionally **exclude** pure client metadata if not part of published mono. **Learn modules** may or may not affect “Read Only core” — align with product: if RO publish only snapshots story core, module edits might still set **`hasUnpublishedCoreChanges`** if Full Learn or RO update is expected.

---

## 6. API Contract

**Prisma / REST additions**

| Field | Type | Purpose |
|-------|------|---------|
| `hasUnpublishedCoreChanges` | `boolean` | Source of truth for list UX + Published hide logic. |
| `workspaceState` | `'draft' \| 'editing' \| 'synced'` | **Derived** in `mapDraftListSummary` from `publishState` + boolean — avoid client recomputing divergent rules. |
| `lastReadOnlyPublishedAt` | `string \| null` (ISO) | Optional UX (“Published … ago”); already have `readingOnlyPublishedAt` on `StoryDraft` — **expose in summary** if needed. |
| `draftCoreContentHash` / `lastPublishedCoreHash` | `string \| null` (optional) | Debugging, reconciliation, future prove-before-hide. **Do not** require client to interpret for V1. |

**`DraftListSummaryResponseDto` / Flutter `DraftListSummaryDto`**

- Add **`hasUnpublishedCoreChanges`** (required on new servers; default **`true`** for published rows in old clients when key missing — **conservative**: never false-hide Editing).
- Extend **`workspaceState`** union with **`synced`**.
- Keep blobs out of list JSON.

---

## 7. Flutter Mapping

**Workspace sections**

- **Drafts:** `publishState == draft` (unchanged).
- **Editing:** `publishState != draft` **and** `hasUnpublishedCoreChanges == true` (or unknown defaults to **true** for published).
- **Synced / hidden:** `publishState != draft` **and** `hasUnpublishedCoreChanges == false` — **omit** from Editing list (and optionally from entire Workspace if product chooses “hide synced”).

Replace coarse logic in **`workspaceStateFromDraftSummary`**: trust API **`workspaceState`** when present (`draft` | `editing` | `synced`); derive only when fields missing.

**Published tab hide set**

Update **`_workspaceEditingDraftIdsForPublishedHide`** to include only draft IDs where:

- `hasUnpublishedCoreChanges != false` **and** published link exists (same `sourceDraftId`), **or** retain temporary mock-only rules until data fully migrated.

**Defaults when API omits `hasUnpublishedCoreChanges`:** treat published rows as **`true`** (still “editing”) so users never lose visibility of work — matches enhancement plan “conservative defaults.”

---

## 8. Tests Needed

**Backend**

- Unit: after **`publishReadOnly`**, `hasUnpublishedCoreChanges === false` (with mocked Prisma).
- Unit: after **`updateDraft`** when `publishState !== draft`, flag becomes **`true`** when content-relevant fields change; **`false`** when no-op update (if implemented).
- List mapping: `workspaceState` is **`synced`** iff published + not dirty.
- Migration default: old rows without column → application treats as **editing** until backfill.

**Flutter**

- `DraftListSummaryDto.fromJson`: new fields; **missing** `hasUnpublishedCoreChanges` on published row → conservative behavior.
- Provider/pager: optional filter excluding **`synced`** if implemented client-side.
- Widget/integration (optional): Published hide uses dirty flag in fixture data.

---

## 9. Migration Strategy

1. **Add nullable boolean** default **`null`** or **`true`** for existing published rows — **safest UX:** default **`true`** (assume editing until proven synced) to **avoid hiding** Published duplicates incorrectly.
2. **Backfill job (batch):** For each `StoryDraft` with `publishState !== draft` and `publishedMonoId` set, optionally compute hash parity once and set **`hasUnpublishedCoreChanges`** — **expensive** if done for all rows; can be **lazy** on first `getDraftById` or first list response refresh.
3. **Avoid:** default **`false`** for everyone — would **hide** Editing rows and Published duplicates wrongly.
4. **Lazy migration:** On first successful **`GET`** full draft or **`publishReadOnly`**, set hashes + flag deterministically so list stabilizes without big bang.

---

## 10. Exact Cursor Prompt For Implementation

Copy-paste for a future implementation session:

---

**Goal:** Implement **`hasUnpublishedCoreChanges`** and **`workspaceState: draft | editing | synced`** without list-time full diffs or per-row `loadDraft`.

**Backend (Prisma + NestJS)**

1. Add to **`StoryDraft`**: `hasUnpublishedCoreChanges Boolean @default(true)` (or `false` for new drafts only — document); optionally `draftCoreContentHash String?`, `lastPublishedCoreHash String?`.
2. Run migration; **do not** default existing published rows to `false` without backfill.
3. In **`story-drafts.service.ts`**:
   - On **`updateDraft`**: if story is published and mutation affects core parity, set `hasUnpublishedCoreChanges = true`; recompute optional draft hash.
   - On **`publishReadOnly`** (and **`publishFullLearn`** per product): after transaction, set `hasUnpublishedCoreChanges = false` and align optional hashes to published snapshot.
4. Extend **`mapDraftListSummary`** to `select` new column(s) and emit **`hasUnpublishedCoreChanges`** and derived **`workspaceState`** (`synced` when published && !dirty).
5. Extend **`DraftListSummaryResponseDto`** and tests in **`story-drafts.service.spec.ts`**.

**Flutter**

1. Extend **`DraftListSummaryDto`** + parsers; **default** missing `hasUnpublishedCoreChanges` to **`true`** for published `publishState` (conservative).
2. Update **`workspaceStateFromDraftSummary`** and **`_workspaceEditingDraftIdsForPublishedHide`** in **`profile_screen.dart`** to use **`hasUnpublishedCoreChanges`** / three-way **`workspaceState`**.
3. Optionally filter **synced** rows from Workspace UI.
4. Add/update unit tests; run **`dart format`**, **`flutter test`**, **`flutter analyze`** (no new error severity).

**Out of scope:** list-time diff, **`loadDraft`** for list rows, Mono feed, unrelated UI refactors.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Recommended option** | **A — persisted `hasUnpublishedCoreChanges`**, with **optional B — paired hashes** for reconciliation and robust publish alignment. |
| **Fields to add** | Prisma: `hasUnpublishedCoreChanges` (+ optional `draftCoreContentHash`, `lastPublishedCoreHash`); API summary: same + **`workspaceState`** including **`synced`**. |
| **Write paths to update** | **`updateDraft`**, **`publishReadOnly`**, **`publishFullLearn`** (per policy); create/delete as documented in §5. |
| **Migration / backfill** | Default published rows **`true`** (assume dirty); optional batch hash job or lazy fix on read/publish — **never** mass-default **`false`**. |
| **Backend risk level** | **Medium–high** — correctness hinges on **every** mutation path updating the flag (or hash recompute). |
| **Flutter risk level** | **Medium** — wrong default could **over-hide** Published rows; use **conservative** “missing ⇒ dirty” for published stories until server ships the field everywhere. |
