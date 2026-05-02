# Draft Summary Metadata Enhancement Plan

**Status:** PLAN ONLY — no implementation in this change.  
**Context:** Profile Workspace and Create Add tab already render from `DraftListSummaryDto` / `GET /v1/story-drafts` without per-row `loadDraft`. This plan extends **summary metadata** so duration, step/progress, Editing visibility, and processing hints are accurate without shipping full story payloads.

---

## 1. Current Gaps

| Area | What users see today | Why it is wrong or coarse |
|------|----------------------|----------------------------|
| **Duration** | Profile Workspace duration chip is **`—`**. Create Add uses **`—`** for duration. | `listDrafts` `select` omits `targetDurationBandKey`; DTO has no field. |
| **Step / progress label** | Create Add featured card: **`stepLabel` empty** → UI falls back to generic “continue” style copy. | No `lastEditingStep` (or resume module) in API; resume metadata is **client-local** only today. |
| **Readiness summary** | Create Add: **`N sentences`** or **`Draft`**. | No module/basics completion signal in summary; cannot mirror `computeFullLearnReady` / checklist without full draft. |
| **Editing vs published-clean** | Workspace: **`publishState == draft` → Drafts**; **any published row → Editing** (`workspaceStateFromDraftSummary` in `lib/features/profile/profile_screen.dart`). | Cannot detect “published but in sync with Read Only / no local delta” without backend flag or full draft + mono diff (previous local implementation used signature diff). **Over-includes** published rows in Editing. |
| **`processingStatus`** | Always **`null`** in [`mapDraftListSummary`](nimon-backend/src/modules/story-drafts/story-drafts.service.ts). | No processing pipeline populates it; DTO allows string but server hard-codes `null`. |

---

## 2. Proposed Summary Fields

Recommendations (all **scalar / small JSON** — no sentence bodies, vocab, grammar, quiz, or audio blobs):

| Field | Purpose |
|------|---------|
| **`targetDurationBandKey`** | Drive duration chip + filters; already in `StoryDraft` basics. |
| **`workspaceState`** | Explicit list partition: e.g. `draft` \| `editing` \| `synced` (or `published_unchanged`) so UI does not guess from `publishState` alone. |
| **`hasUnpublishedCoreChanges`** | Boolean: draft differs from last published Read Only snapshot (or “dirty” since publish). Unblocks correct **Published tab hide** and **Editing** section. |
| **`lastEditingStep`** | Single string enum for UX: e.g. `basics` \| `sentences` \| `vocabulary_kanji` \| `grammar` \| `quiz` \| `audio` — maps to “Continue in …” without full `CreatorStoryV1`. |
| **`completionPercent` *or* `completedRequiredFieldsCount` / `requiredFieldsTotal`** | Coarse progress bar or checklist line; cheap if derived from non-blob columns + `moduleWorkflowStatuses`. |
| **`learnModeEnabled`** | Whether learn track is “on” for this story (may equal “any module not `not_started`” or a stored flag). |
| **`enabledLearnModules` *or* reuse `moduleWorkflowStatuses`** | Already JSON on row; expose **counts** or **per-key status** in summary (subset of keys only). |
| **`processingStatus`** | Pipeline phase when async jobs exist (`queued`, `processing`, `failed`, …). |
| **`updatedReason`** (optional) | Debug/analytics: `user_edit` \| `publish` \| `system` — **only if** cheap to set on write; else omit. |

---

## 3. Backend Availability

Mapping each proposed field to Prisma / cost (see [`schema.prisma`](nimon-backend/prisma/schema.prisma) `StoryDraft`).

| Field | Already stored | Computable cheaply (same query / O(1) JSON) | Requires full story comparison | Requires new persisted column | Defer |
|-------|----------------|--------------------------------------------|--------------------------------|------------------------------|-------|
| **`targetDurationBandKey`** | Yes (`StoryDraft.targetDurationBandKey`) | N/A — **extend `select`** | No | No | **Ship early** |
| **`moduleWorkflowStatuses`** (or summary projection) | Yes (`Json`) | Yes — parse JSON, no relation fan-out | No | No | **Ship early** |
| **`completionPercent` / required-field counts** | Partially | Yes — derive from basics fields + sentence `_count` + module statuses (mirror existing readiness helpers without loading sentence **content**) | No | Optional: only if you want to avoid recomputing in SQL | **Ship early** (derived in `mapDraftListSummary`) |
| **`processingStatus`** | No live workflow | Return `null` until Processing module exists | No | Optional column later | **Defer** meaningful values |
| **`lastEditingStep`** | Not in DB | N/A | No | **Yes** — e.g. `lastActiveModuleKey` (+ optional `lastActiveSubPage`) **or** derive only from `moduleWorkflowStatuses` heuristics (weaker) | **Either** new columns updated on `updateDraft` **or** heuristic-only v1 |
| **`learnModeEnabled`** | Not explicit | **Heuristic:** any module ≠ `not_started` OR RO/FL publish state | No | Optional boolean | **Ship** as derived first |
| **`enabledLearnModules`** | Embedded in `moduleWorkflowStatuses` | Yes | No | No | **Ship** with module JSON |
| **`hasUnpublishedCoreChanges`** | No | **Not** without comparing draft to `PublishedMono.content` or stored hash | **Yes** if computed on the fly per row | **Recommended:** boolean **or** pair of hashes | **Defer** full diff; **prefer** maintained flag/hash on write |
| **`workspaceState`** | No single column | Can **derive** from `publishState` + `hasUnpublishedCoreChanges` once flag exists | — | Optional stored enum for clarity | **Phase 2** after flag |

**Note:** `listDrafts` currently selects only `id`, `title`, `category`, `level`, `description`, `coverImageUrl`, `publishState`, `updatedAt`, `_count.sentences`. Adding **`targetDurationBandKey`** and **`moduleWorkflowStatuses`** (and optionally small new columns) keeps **one round-trip** and avoids N+1.

---

## 4. API Contract

**Proposed** extension of `DraftListSummaryResponseDto` / Flutter `DraftListSummaryDto` (additive JSON keys — old clients ignore unknowns):

```typescript
// Conceptual — align names with Nimon API snake_case or camelCase convention already used in list items.
type DraftListSummaryResponseDto = {
  // --- existing ---
  draftId: string;
  title: string;
  coverImageUrl: string | null;
  level: string;
  category: string;
  status: string;
  publishState: PublishState;
  processingStatus: string | null;
  updatedAt: string;
  sentenceCount: number;
  publishType: string;
  previewText: string;

  // --- proposed (no blobs) ---
  targetDurationBandKey: string | null;

  /** Derived or stored; see §3 */
  workspaceState: 'draft' | 'editing' | 'synced';

  hasUnpublishedCoreChanges: boolean;

  /** Creator-facing step hint */
  lastEditingStep: string | null;

  /** 0–100 or null if not computed */
  completionPercent: number | null;

  learnModeEnabled: boolean;

  /** Subset of module keys → status (same strings as ModuleTaskStatus) */
  moduleWorkflowStatuses: Record<string, string>;
};
```

**Note:** `processingStatus` remains in the existing contract; keep **`null`** until a processing pipeline defines enums.

**Explicitly excluded** from this DTO: `sentences[]`, vocabulary/grammar/quiz entries, audio content, full `PublishedMono` payloads.

**Open naming:** Flutter today uses string keys for `publishState` (`storageKey`); keep parity with existing [`DraftListSummaryDto.fromJson`](lib/features/create/data/dto/draft_list_summary_dto.dart).

---

## 5. Flutter Mapping Plan

| UI surface | Today | After metadata |
|------------|-------|----------------|
| **Profile Workspace duration chip** | Hard-coded **`—`** in `_ProcessingDraftItem.fromSummary` | Map `targetDurationBandKey` through existing duration label helper (same as full-draft cards use for `targetDurationText` if present elsewhere). |
| **Profile Workspace Draft vs Editing** | `workspaceStateFromDraftSummary` → **draft** iff `publishState == draft` | Use API **`workspaceState`** + **`hasUnpublishedCoreChanges`**: e.g. hide Published-tab duplicate only when `synced` or `!hasUnpublishedCoreChanges` (product rule). |
| **Create Add featured card step copy** | Empty **`stepLabel`** → fallback | Map **`lastEditingStep`** to short labels (“Basics”, “Sentences”, “Vocab & Kanji”, …). |
| **Create Add readiness summary** | Sentence count only | Prefer **`completionPercent`** or a string built from **`moduleWorkflowStatuses`** + basics completeness (mirror backend-derived string for consistency). |
| **`CreatorProcessingCopy.secondaryLineSummaryOnly`** | Generic per `publishState` | Optionally branch on **`learnModeEnabled`** / module summary for RO rows (“2 of 4 modules started”) — keep strings centralized in `creator_processing_copy.dart`. |

**Parser:** extend `DraftListSummaryDto.fromJson` with **optional** new keys and defaults (`workspaceState` fallback to current derivation; `hasUnpublishedCoreChanges` default `true` for published rows if absent to avoid false “synced”). Document defaults in code comments.

---

## 6. Migration Order

1. **Backend — widen `findMany` select** for fields already on `StoryDraft`: `targetDurationBandKey`, `moduleWorkflowStatuses`; extend `mapDraftListSummary` to emit new keys; keep **`processingStatus` null** until pipeline exists.
2. **Backend — derived fields only:** `completionPercent`, `learnModeEnabled`, first-pass **`workspaceState`** (still publishState-based until flag lands).
3. **Flutter — DTO + tolerant parse** with defaults; replace **`—`** duration and coarse readiness where data exists.
4. **Backend — persist `hasUnpublishedCoreChanges` (and/or content hashes)** on `updateDraft` / publish paths; then expose **`workspaceState: synced`** when appropriate.
5. **Backend — `lastEditingStep`** via new columns updated on save, or ship heuristic from module statuses first.
6. **UI — Published tab hide / Editing bucket** once `hasUnpublishedCoreChanges` / `workspaceState` trustworthy.
7. **Defer** expensive per-request **full document diff**; avoid loading `PublishedMono` for list rows.

---

## 7. Tests Needed

### Backend (NestJS)

- **`story-drafts.service.spec.ts`:** list mapping includes new keys; `targetDurationBandKey` null vs string; `moduleWorkflowStatuses` empty vs populated; cursor pagination unchanged; **no** accidental include of `sentences` content in select.
- **Integration / e2e (optional):** `GET /v1/story-drafts` JSON shape matches contract.

### Flutter

- **`draft_list_pagination_test.dart` (or DTO unit tests):** parse new optional fields; backward compatibility when server omits keys.
- **`profile_workspace_draft_pager_test.dart`:** if pager filters by workspace state, add cases with mocked DTOs.
- **`story_creator_add_tab_draft_summary_provider_test.dart`:** assert duration/step fields propagate when present (optional).

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| **Query cost** | Stay on single `findMany` + existing indexes; avoid extra joins. Adding JSON + one string column to `select` is low cost. |
| **Full diff cost** | Do **not** compute draft-vs-published in list handler; use **maintained flags/hashes** on write. |
| **Stale summary** | `updatedAt` already drives sort; ensure publish/update **bumps** `updatedAt` and any derived summary fields in same transaction. |
| **Invalidation** | Flutter already refreshes workspace/add tab via **`profileProcessingListRefreshProvider`** — document that new fields rely on same bump after save/publish. |
| **Default semantics** | If older app versions receive new JSON, fine; if newer app talks to old server, **defaults** must not hide Published rows incorrectly — conservative defaults for `workspaceState`. |

---

## 9. Exact Cursor Prompt For Implementation

Copy-paste for a future implementation session:

---

**Task:** Implement draft summary metadata enhancement (backend + Flutter). Do **not** change Mono feed or unrelated create screens.

**Backend (`nimon-backend`):**

1. Extend `StoryDraft` list query in `StoryDraftsService.listDrafts` to `select` **`targetDurationBandKey`** and **`moduleWorkflowStatuses`** (already on model).
2. Extend `DraftListSummaryResponseDto` and `mapDraftListSummary` to include:
   - `targetDurationBandKey`
   - `moduleWorkflowStatuses` (pass-through or trimmed)
   - Derived: `learnModeEnabled`, `completionPercent` (document formula; align with existing `getReadOnlyReadinessUnmet` / module completion ideas without selecting sentence **content** — sentence **count** only).
   - `workspaceState`: start with `draft` vs `editing` derived from `publishState` (same as Flutter today); add `hasUnpublishedCoreChanges: boolean` only after persisted flag or v1 heuristic is agreed — if not ready, omit boolean until column exists.
   - `lastEditingStep`: either add Prisma columns and set in `updateDraft`, or omit and use heuristic from `moduleWorkflowStatuses`.
   - Keep `processingStatus: null` unless a real enum exists.
3. Add/adjust **unit tests** in `story-drafts.service.spec.ts`.
4. Run backend tests / lint.

**Flutter:**

1. Extend `DraftListSummaryDto` + `fromJson` / `==` / `hashCode` for new optional fields with **safe defaults**.
2. Update `profile_screen.dart` `_ProcessingDraftItem.fromSummary` to use **`targetDurationBandKey`** for `durationLabel` (reuse existing duration formatting if any).
3. Update `story_creator_add_tab_screen.dart` `_DraftListItemModel.fromSummary` for duration, step label, readiness from new fields; keep placeholders when null.
4. Refine `workspaceStateFromDraftSummary` **only** when API supplies `workspaceState` / `hasUnpublishedCoreChanges`; preserve backward compatibility.
5. Add DTO/pager tests; run `dart format`, `flutter analyze`, `flutter test`.

**Out of scope:** loading full drafts for list rows; removing `listDraftIds` / `loadDraft` / `loadAllDrafts`.

---

## Output Summary (planning)

| Question | Answer |
|----------|--------|
| **Fields to add now** | **`targetDurationBandKey`**, **`moduleWorkflowStatuses`** (summary projection), derived **`learnModeEnabled`**, **`completionPercent`** (or equivalent), optional first-pass **`lastEditingStep`** heuristic from modules. |
| **Fields to defer** | Meaningful **`processingStatus`**; **`hasUnpublishedCoreChanges`** until a **stored flag or hash** is implemented; precise **`workspaceState: synced`** until flag exists; **`updatedReason`**. |
| **Backend risk level** | **Low–medium** — mostly select/map changes; **medium** once you add write-path maintenance for dirty/sync flags. |
| **Flutter risk level** | **Low** — additive DTO + localized UI; **medium** for Published-tab hide if defaults are wrong — test defaults carefully. |
| **Recommended next step** | **Backend:** extend `listDrafts` select + `mapDraftListSummary` with **`targetDurationBandKey`** + **`moduleWorkflowStatuses`** + cheap derived completion/labels; **Flutter:** parse and replace duration **`—`** + improve readiness line; then iterate **persisted `hasUnpublishedCoreChanges`** for Editing/sync accuracy. |
