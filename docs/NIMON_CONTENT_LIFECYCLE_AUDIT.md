# Nimon Content Lifecycle Audit

**Date:** 2026-05-02  
**Type:** Product + engineering audit (read-only). **No code changes** in this task.

## 1. Intended Standard (Reference)

| Layer | Role |
|--------|------|
| **Draft** | Creator working copy; not public; recoverable; readers never see it. May be local-first or remote-backed by configuration. |
| **PublishedMono** | Public reader snapshot on server; stays visible until creator updates or deletes it; **not** hidden merely because the creator opens an editor. |
| **Editing published** | Same `StoryDraft` row as working copy; `PublishedMono` remains the live reader surface until an explicit publish/update; `hasUnpublishedCoreChanges` signals drift; successful publish/update clears the flag. |

---

## 2. Current Flutter Draft Storage Behavior

### Mode switch

- **`RemoteBackendConfig.useRemoteDrafts`** is **`false` by default** (`bool.fromEnvironment('NIMON_USE_REMOTE_DRAFTS', defaultValue: false)` in `remote_backend_config.dart`).
- **`storyDraftRepositoryProvider`** returns **`LocalStoryDraftRepository`** when that flag is `false`; otherwise **`RemoteStoryDraftRepository`**.

### Persistence implementation (local path)

- **`LocalStoryDraftRepository`** delegates to **`StoryCreatorDraftStorage`**, which persists draft JSON in **SharedPreferences** (per-draft keys + index), not PostgreSQL.
- **`StoryCreatorDraftNotifier`** holds the **in-memory** `StoryCreatorDraftState`; edits mark `dirty` and route persistence through **`persistLocalNow`**, **`persistLocalDebounced`**, or **`flushDraftToProcessing`**.

### Story Basics

- **`StoryCreatorBasicsScreen`** calls **`applyBasicsDebounced`** on field changes (after form is dirty) and **`applyBasics`** + navigation on **Next**.
- **`applyBasicsDebounced`** updates draft fields in the notifier then **`persistLocalDebounced`** (~450ms).
- **`applyBasics`** (confirm path) calls **`persistLocalNow`** immediately.
- **Where saved:** Riverpod state first; then **`StoryDraftRepository.saveDraft`** → **local: SharedPreferences** (and **remote: local first, then HTTP**, if remote repo is active).

### Story Sentences

- **`applySentences`** updates sentences + `basics.updatedAt`, marks dirty, **`persistLocalDebounced`**.
- **`_saveDraft`** / **`globalSaveDraftNow`** on sentences screen → **`persistLocalNow`** (snackbar: *“All changes saved locally.”*).
- **Where saved:** same stack as basics (local prefs by default).

### Creator resume (`creator_resume_draft.dart`)

- **`CreatorDraftResumeFlow`** resolves **where to open** the creator (basics vs sentences, optional `?panel=`) from **`loadResumeMeta`** via **`storyDraftRepositoryProvider`** and in-memory draft.
- It is **navigation + resume metadata** only; it does **not** define a separate persistence layer for basics/sentences. Saves still go through **`StoryCreatorDraftNotifier`** + **`StoryDraftRepository`** as above.

### Who calls `saveDraft` / `saveDraftNow` / `flushDraftToProcessing`

| Mechanism | Call path |
|-----------|-----------|
| **`saveDraft` / `saveDraftNow`** | **`StoryCreatorDraftNotifier.persistLocalNow`** → `_drafts.saveDraft`; **`globalSaveDraftNow`** → `persistLocalNow`; **`flushDraftToProcessing`** (dirty branch) → `_drafts.flushDraftToProcessing` → **`saveDraftNow`**; remote **`RemoteStoryDraftRepository.saveDraft`** always **`_local.saveDraft` first**, then optional API. |
| **`flushDraftToProcessing`** | **`creator_back_policy`** (`_flushMeaningfulDraftStateForExit`) on back/exit; notifier flushes when `state.dirty` or updates resume meta only when clean. |

### Publish (Flutter)

- **`publishReadingOnlyToDisk` / `publishFullLearnToDisk`** (and synchronous variants) set **`publishState`** on the in-memory draft, then **`persistLocalNow`**.
- **`creator_drawer_publish`** awaits **`publishReadingOnlyToDisk`** / **`publishFullLearnToDisk`** after readiness checks.
- **Local mode:** this only updates **local JSON** + optional **read-only published core signature** (`creator_read_only_publish_tracking`); **no HTTP** to create `PublishedMono` unless remote drafts are enabled and repository runs publish endpoints.

---

## 3. Current Backend Draft Behavior

### `StoryDraft` + related tables

- **`updateDraft` (PUT)** replaces nested rows: deletes and recreates **`draft_sentences`**, vocab/grammar/quiz/audio children, then updates **`story_drafts`** (including **`publishState`** from the request body and **`hasUnpublishedCoreChanges`**).
- **`hasUnpublishedCoreChanges`** is set to **`becomesPublishedRelated`**, where  
  `becomesPublishedRelated = (current.publishState !== draft) || (body.publishState !== draft)`  
  (see `story-drafts.service.ts`). So any save while the draft is **or becomes** non-draft marks dirty, including transitions implied by the client body.

### List vs full DTO

- **Draft list summaries** expose **`hasUnpublishedCoreChanges`** and **`workspaceState`** (`draft` | `editing` | `synced`).
- **`StoryDraftResponseDto`** (full GET payload type) **does not list** `hasUnpublishedCoreChanges` in the TypeScript type; the runtime `mapFullDraft` return object matches that contract. Workspace UX primarily relies on **list** DTOs + local heuristics for offline rows.

---

## 4. Current Publish Behavior

### Backend

- **`publishReadOnly`**: In a transaction, ensures readiness, **creates `published_monos` on first publish** or **updates the same row** on later read-only publishes, snapshots **core** (title/meta + ordered sentence content) into **`published_monos.content`**, sets **`story_drafts.publishedMonoId`**, **`publishState`**, timestamps, and **`hasUnpublishedCoreChanges: false`**.
- **`publishFullLearn`**: Requires existing **`publishedMonoId`**, sets full-learn state, clears **`hasUnpublishedCoreChanges`**, updates **`published_monos`** publish metadata (learn path).

### Flutter (remote)

- **`RemoteStoryDraftRepository.saveDraft`**: After local persist, **PUT** `/v1/story-drafts/:id` with payload where **`publishState` is forced to `'draft'`** in the JSON map (“publish is done via publish endpoints”). If the **local** draft’s desired publish state is **`reading_only_published`** or **`full_learn_published`**, it then **POSTs** `/publish/read-only` or `/publish/full-learn` with **`If-Match`**.

### Flutter (local default)

- **No** `PublishedMono` row is created on the server from the device; **Prisma Studio** will not show draft body edits because they live in **SharedPreferences**.

---

## 5. Current Edit Published Behavior

### Backend

- Editing content for a published draft (via **PUT** with appropriate state transitions / remote client pattern) sets **`hasUnpublishedCoreChanges`** per **`updateDraft`** rules; **`publishReadOnly` / `publishFullLearn`** clear it to **`false`** and refresh **`published_monos`**.

### Flutter Profile / Published tab

- **`_hidePublishedItemForWorkspaceEditing`**: **`isBackendPublished == true` → never hide** the row. Duplicates are suppressed only for **non-backend** (“loose”) rows when the source draft id is in the Workspace **Editing** set (`profile_screen.dart` comments and implementation).

**Conclusion:** **Real `PublishedMono` list rows stay visible** while a linked draft is in “Editing” in Workspace; hiding applies to **mock/legacy duplicate** presentation, not server-backed monos.

### Flutter domain model note

- **`hasUnpublishedCoreChanges`** is modeled on **`DraftListSummaryDto`** (API / list); **`CreatorStoryV1`** local persistence does not carry the same field—**workspace “editing”** for local-only summaries can be **inferred** from publish state + DTO defaults (see `draft_list_summary_dto.dart` comments: missing flag on published rows treated conservatively as editing).

---

## 6. Local vs Remote Mode

| Aspect | **Default (`useRemoteDrafts == false`)** | **`useRemoteDrafts == true`** |
|--------|------------------------------------------|----------------------------------|
| Active repository | **`LocalStoryDraftRepository`** | **`RemoteStoryDraftRepository`** |
| Draft body | **SharedPreferences** | **Local +** Nest **`story_drafts` / `draft_*`** via PUT + conditional publish POSTs |
| **`strictRemoteDrafts`** | N/A | If `true`, remote failures **throw** instead of silent local fallback |
| **Prisma Studio** | Shows DB state **unchanged** by normal creator edits | Shows rows **after** successful remote sync |

**Mixed behavior:** Remote repository is explicitly **local-first** (“remote sync: if it fails, local remains source of truth”). That is a **deliberate hybrid**, not a pure remote-only mode.

---

## 7. Database Tables Per Action

Assumptions: **remote** path + successful HTTP. **Local-only** path: **no** `story_drafts` / `draft_*` / `published_monos` updates from the Flutter creator.

| User action (intent) | `story_drafts` | `draft_sentences` (and other `draft_*`) | `published_monos` |
|----------------------|----------------|----------------------------------------|---------------------|
| Type in Basics / Sentences (debounced save) | **No** (local prefs only) if local mode | **No** | **No** |
| Same, remote success | **Yes** (PUT: columns + version; dirty flag per rules) | **Yes** (replace children) | **No** until publish |
| Publish Read Only (first time) | **Yes** (state, `publishedMonoId`, timestamps, `hasUnpublishedCoreChanges` false) | Read from draft for snapshot | **INSERT** |
| Publish Read Only (update) | **Yes** | Same | **UPDATE** same id |
| Publish Full Learn | **Yes** | Included in readiness | **UPDATE** metadata / kind |
| Local-only publish in Flutter | **No** DB writes | **No** | **No** |

---

## 8. Mismatches / Risks

1. **Operator expectation vs default mode:** With **`useRemoteDrafts: false`**, Postgres / Prisma Studio **will not** reflect creator edits—**by design**, not a bug. Risk: confusion between “app saved” and “DB saved.”
2. **Remote PUT always sends `publishState: 'draft'`** before conditional re-publish. Backend must tolerate this sequence; it differs from a mental model of “never downgrade publish state on save.” Document and regression-test.
3. **Full-draft GET DTO** omits **`hasUnpublishedCoreChanges`** in the declared response type—clients using only GET-full for editor chrome may not see server dirty state without list endpoint or schema extension.
4. **Local `CreatorStoryV1` vs server dirty flag:** Drift signaling is **stronger on the server** when remote mode is on; local-only uses **publish state + DTO heuristics** for Workspace chips.
5. **Dual source of truth in remote + fallback:** Strict mode off → failed PUT may leave **Postgres stale** while **device** shows latest; readers on another device see old server state.

---

## 9. Recommended V1 Standard

1. **Declare a single “authoring source of truth” per build flavor:** e.g. **dev/staging** → `NIMON_USE_REMOTE_DRAFTS=true` so Studio and API match creator edits; **optional offline** profile keeps local-first with clear UX (“not synced”).
2. **Keep PublishedMono visible** during draft edits; **continue** current rule: hide duplicates only for **non-backend** Published rows when Workspace shows **Editing**.
3. **Treat `hasUnpublishedCoreChanges` as server-owned** for remote lists; align full GET DTO and Flutter domain if the editor needs the same flag without list roundtrip.
4. **Publish** remains an **explicit** user action: creates/updates **`published_monos`** and clears dirty on success (already true on backend).
5. **Document** the remote repository’s **PUT `publishState: draft` + publish POST** sequence for maintainers.

---

## 10. Required Changes (If Product Chooses Full Alignment)

| Priority | Change |
|----------|--------|
| **P0 – Communication** | Ship **in-app or docs** note: default authoring is **device-local**; Prisma Studio reflects **server** only when remote drafts are enabled and saves succeed. |
| **P1 – Contract parity** | Add **`hasUnpublishedCoreChanges`** (and optionally `workspaceState`) to **full** `StoryDraftResponseDto` + `mapFullDraft` if any client needs single-GET truth. |
| **P1 – Config** | CI / dev scripts set **`--dart-define=NIMON_USE_REMOTE_DRAFTS=true`** when Postgres-backed testing is required. |
| **P2 – Remote PUT semantics** | Review forcing **`publishState: 'draft'`** on every content PUT vs sending actual lifecycle state; add tests around **editing published** without accidental reader-visible regressions. |
| **P2 – Strictness** | Enable **`NIMON_STRICT_REMOTE_DRAFTS=true`** in backend integration tests to avoid silent divergence. |

*(None of the above were implemented in this audit.)*

---

## 11. Exact Cursor Prompt For Implementation

Use when you want a follow-up coding pass (paste as a single task):

> Implement Nimon V1 content lifecycle alignment per `docs/NIMON_CONTENT_LIFECYCLE_AUDIT.md` §9–§10. Goals: (1) Add `hasUnpublishedCoreChanges` to full `StoryDraftResponseDto` and `mapFullDraft` in `nimon-backend/src/modules/story-drafts` without breaking existing clients. (2) In Flutter, map the new field into `CreatorStoryV1` or a parallel session field if needed for Workspace consistency. (3) Document or gate `RemoteStoryDraftRepository` PUT `publishState: 'draft'` behavior with tests covering “edit published draft then save without republish.” (4) Add `README` or `docs` snippet listing required `--dart-define` flags for remote-draft dev. Do not remove local-first mode; do not hide backend Published rows during edit. Include unit tests for DTO mapping and Nest serialization.

---

## Appendix — Direct Answers to Audit Questions

1. **`useRemoteDrafts`:** **`false`** unless overridden at compile/runtime with **`NIMON_USE_REMOTE_DRAFTS=true`**.  
2. **Active repository (default):** **Local.**  
3. **Basics edits:** **In-memory + SharedPreferences** (default); **+ backend** when remote + successful sync.  
4. **Sentences edits:** **Same as (3).**  
5. **`saveDraft` / `saveDraftNow` / `flushDraftToProcessing`:** **`persistLocalNow`**, **`globalSaveDraftNow`**, **`flushDraftToProcessing`** (back/exit via **`creator_back_policy`**), and **`RemoteStoryDraftRepository`** internal chain.  
6. **`PublishedMono` create/update:** **Nest `publishReadOnly` / `publishFullLearn`**; Flutter triggers via **remote** `saveDraft` publish branch.  
7. **Server snapshot:** **Yes**, on successful **`publishReadOnly`** (and learn path updates **`published_monos`**).  
8. **PublishedMono visible while editing:** **Yes** for **backend** list rows per **`_hidePublishedItemForWorkspaceEditing`**.  
9. **Edit sets `hasUnpublishedCoreChanges = true`?** **On server**, when **`updateDraft`** conditions set **`becomesPublishedRelated`** to true (typical for published-draft content saves in remote flow). **Not** on Postgres in pure local mode.  
10. **Publish clears flag?** **Yes** in **`publishReadOnly`** and **`publishFullLearn`** (`hasUnpublishedCoreChanges: false`).  
11. **Mixed local/remote?** **Yes** — remote repo is **local-first** with optional strict failure mode.  
12. **Tables per action:** See **§7**.  
13. **Current vs intended:** **Intended** behavior matches **remote + backend** path and **Published tab hide rules**. **Default local-only** path intentionally **does not** mirror server DB—**gap vs naive expectation** that “Studio = app state.”  
14. **V1 standard to adopt:** **§9**.  
15. **Implementation changes:** **§10** (optional).
