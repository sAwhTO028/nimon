# Draft Dirty State Implementation Report

**Date:** 2026-05-02  
**Scope:** Persisted `hasUnpublishedCoreChanges`, summary `workspaceState` including **`synced`**, Profile Workspace filtering and Published duplicate-hide alignment. **No** list-time full diffs; **no** per-row `loadDraft` for lists.

---

## Files Changed

### Backend

| Path | Change |
|------|--------|
| `nimon-backend/prisma/schema.prisma` | `hasUnpublishedCoreChanges Boolean @default(false)` on `StoryDraft`. |
| `nimon-backend/prisma/migrations/20260502120000_story_draft_dirty_flag/migration.sql` | Add column + `UPDATE` published rows to `true`. |
| `nimon-backend/prisma.config.ts` | Removed `dotenv/config` import so `prisma generate` runs without extra devDependency (env via shell / Nest at runtime). |
| `nimon-backend/src/modules/story-drafts/dto/story-draft.dto.ts` | `DraftListWorkspaceState` + `synced`; `hasUnpublishedCoreChanges` on summary DTO. |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` | `createDraft` / `updateDraft` / `publishReadOnly` / `publishFullLearn` / `listDrafts` select + `mapDraftListSummary`; `listSummaryWorkspaceState`; `resolvePublishStateFilter` return type fix for Prisma 7. |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.spec.ts` | List mapping tests for `synced` / dirty / draft. |

### Flutter

| Path | Change |
|------|--------|
| `lib/features/create/data/dto/draft_list_summary_dto.dart` | `hasUnpublishedCoreChanges`, `effectiveDraftListWorkspaceState`, `fromJson` conservative rules, `_rowLooksIdOnly` hint. |
| `lib/features/profile/profile_screen.dart` | Filter synced summaries from Workspace list; Published hide set uses `effectiveDraftListWorkspaceState == 'editing'`. |
| `test/features/create/draft_list_summary_dto_test.dart` | Synced parse, legacy published default, `effectiveDraftListWorkspaceState` test. |

---

## Prisma / DB Changes

- Column **`hasUnpublishedCoreChanges`** `BOOLEAN NOT NULL DEFAULT false`.
- **Post-add migration SQL:** set **`true`** for all rows where **`publishState <> 'draft'`** so legacy published stories stay **dirty until the next publish** clears the flag.

---

## Backend Behavior

- **`GET /v1/story-drafts`:** each item includes **`hasUnpublishedCoreChanges`** and **`workspaceState`** derived as:
  - `draft` if `publishState === draft`
  - `editing` if published **and** flag **`true`**
  - `synced` if published **and** flag **`false`**
- **No** draft-vs-`PublishedMono` comparison in the list handler.

---

## Write Path Rules

| Path | Behavior |
|------|----------|
| **`createDraft`** | Sets **`hasUnpublishedCoreChanges: false`**. |
| **`updateDraft`** | If current **or** next `publishState` is not `draft`, sets **`hasUnpublishedCoreChanges: true`** (any save while published = dirty). Pure draft saves set **`false`**. |
| **`publishReadOnly`** | On successful draft row update, **`hasUnpublishedCoreChanges: false`**. |
| **`publishFullLearn`** | Same **`false`** after successful publish (aligned with RO “clean” snapshot for V1). |

---

## Flutter DTO Changes

- **`hasUnpublishedCoreChanges`**: `bool?`; published + missing → treat as dirty in **`effectiveDraftListWorkspaceState`**.
- **`workspaceState`**: supports **`synced`**; parsing prefers explicit API `workspaceState` when valid.

---

## Profile Workspace Behavior

- Rows with **`effectiveDraftListWorkspaceState == 'synced'`** are **excluded** from the Processing list (V1: no synced lane).
- Draft / Editing sections unchanged for remaining rows (`_ProcessingDraftManagerTab`).

---

## Profile Published Hide Behavior

- **`_workspaceEditingDraftIdsForPublishedHide`** and the Published tab **`editingIds`** set use **`effectiveDraftListWorkspaceState(s) == 'editing'`** only — **synced** drafts no longer force-hide duplicate loose rows.

---

## Backward Compatibility

- Old JSON without `hasUnpublishedCoreChanges` / `workspaceState`: published rows still resolve to **editing** (conservative).
- **`prisma.config.ts`:** teams relying on `import "dotenv/config"` should load `.env` via the shell before `prisma migrate` or add **`dotenv`** locally.

---

## Tests Added

- **Backend:** extended **`story-drafts.service.spec.ts`** (draft / dirty published / synced / full_learn dirty).
- **Flutter:** **`draft_list_summary_dto_test.dart`** cases for synced JSON, legacy published, explicit `workspaceState` in **`effectiveDraftListWorkspaceState`**.

*(Heavy `updateDraft` / `publishReadOnly` transaction tests deferred — behavior verified by code review + `nest build`.)*

---

## Flutter Analyze Result

- **`dart analyze`** on touched Dart files: run in CI/workspace (project-wide may still report existing info/warnings).

---

## Flutter Test Result

- **`flutter test`:** all tests passed (**+87** at last run).

---

## Backend Test Result

- **`jest src/modules/story-drafts/story-drafts.service.spec.ts`:** **10 passed**.
- **`nest build`:** **success** (after `Prisma.EnumStoryDraftFilter` → `{ in: PublishState[] }` typing fix).

---

## Risks

- **`updateDraft`** marks dirty for **any** published save, including no-op retries — acceptable V1 tradeoff.
- **`publishFullLearn`** clearing dirty may not match a future split RO vs FL dirty model — revisit if product requires FL-only deltas.
- **Prisma config** without `dotenv`: local `migrate` must supply **`DATABASE_URL`** in the environment.

---

## Recommended Next Step

- Run **`prisma migrate deploy`** (or `migrate dev`) against real DBs.
- Optional: add **`dotenv`** devDependency and restore `import "dotenv/config"` if the team prefers config-loaded env for Prisma CLI only.
