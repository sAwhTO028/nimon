# Workspace Draft Pagination Audit

**Status:** AUDIT / PLAN ONLY — no application or backend code changes in this document.  
**Scope:** How story drafts are loaded today for Profile Workspace / Processing, Create “Continue working” / “Drafts in progress”, editor resume, and repository boundaries (`StoryDraftRepository` / `RemoteStoryDraftRepository`).

---

## 1. Current Draft Loading Surfaces

| Surface | Where | How drafts enter memory | Notes |
|--------|--------|-------------------------|--------|
| **Profile — Workspace tab (“Processing”)** | `lib/features/profile/profile_screen.dart` → `_loadLocalCreatorDraftIntoProcessing` | `listDraftIds()` then **one `loadDraft(id)` per id**; `loadResumeMeta(id)`; `loadReadOnlyPublishedCoreSignature(id)` for read-only core diff | Builds `_ProcessingDraftItem` list (draft vs “editing” rules). Refreshed on tab focus to Workspace (`_onTabChanged`), `profileProcessingListRefreshProvider`, and after some sheet actions. |
| **Create — Continue working** | `lib/features/create/story_creator_add_tab_screen.dart` → `_LocalDraftsSnapshot.load` | Same: **`listDraftIds()` + `loadDraft` per id** + `loadResumeMeta` | UI shows **one** featured draft + up to **three** “Drafts in progress” rows, but the snapshot **loads every id** returned by the index. Filters to `StoryPublishState.draft` only for the Add-tab list. |
| **Create — Drafts in progress** | Same `StoryCreatorAddTabScreen` block as above | Same loop | “View all drafts in Processing” jumps to Profile; no separate paged list in Create. |
| **Editing content (creator)** | `lib/features/create/story_creator_provider.dart` → `StoryCreatorDraftNotifier.loadDraftById` | **`loadDraft(id)`** once for the active session | Correct use of **full** draft: in-memory session + `CreatorStoryV1`. |
| **Story creator sentences (and routed editor)** | `lib/features/create/story_creator_sentences_screen.dart` | Reads **`storyCreatorDraftDataProvider`** (notifier state); hydration via **`loadDraftById`** from route / resume | No bulk list load here; risk is **upstream** list over-fetch, not this screen. |
| **Create screen (basics entry)** | `lib/features/create/create_screen.dart` | **`storyCreatorDraftProvider.notifier.reset`** / `applyBasics`; navigates with `draftId` | No enumeration of all drafts. |
| **Resume flow** | `lib/features/create/creator_resume_draft.dart` | **`loadDraft`** (Published “Edit” probe) + **`loadDraftById(..., forceReloadFromDisk: true)`** via `_restoreDraftState` | Needs **full** draft for `_inferLearnModeFromDraft` and resume routing. |
| **Profile — Saved sheet / processing interactions** | `profile_screen.dart` (e.g. `loadDraft` for sheet content) | **Per-row `loadDraft`** when opening detail flows | Appropriate for detail; not a list scan. |

**`loadAllDrafts`:** Implemented on `LocalStoryDraftRepository` / `RemoteStoryDraftRepository` (`listDraftIds` + sequential `loadDraft`). **No grep hits** in `lib/` for call sites beyond the repository itself — **current UI paths use `listDraftIds` + `loadDraft` directly**, not `loadAllDrafts`.

---

## 2. Current Repository Methods

| Method | Role | Typical payload | Summary vs full |
|--------|------|-----------------|-----------------|
| **`listDraftIds`** | `GET /v1/story-drafts` (remote); parses `items[].draftId` | **Index only** (ids from list envelope) | **Summary-capable** if backend extended `items[]` with row metadata without full story JSON. |
| **`loadDraft`** | `GET /v1/story-drafts/:id` → `_dtoFromJson` → `StoryDraftMapper.toDomain` | **Full** `CreatorStoryV1` (basics, sentences, vocab, grammar, quiz, audio, …) | **Full draft** — correct for editor / publish / conflict resolution. |
| **`loadAllDrafts`** | Remote: ids + **N × `loadDraft`**; Local: storage read-all | **Full** list of `CreatorStoryV1` | **All full drafts** — highest blast radius if used at scale. |
| **`saveDraft` / `saveDraftNow`** | Remote: PUT (+ publish POST branches); local persist | **Full** body on wire after mapping | Mutations; must invalidate **list summaries** for that `draftId` (cache policy). |
| **`flushDraftToProcessing`** | Flush active draft to persistence | Same family as save | Triggers Profile refresh signals today. |
| **`deleteDraft`** | Remote DELETE + local cleanup | N/A | Remove id from any **paged draft notifiers** + optimistic row removal. |
| **`createNewDraft`** | POST shell / local create | Partial then grows | New id appears on **first page** of draft index after sync. |
| **Publish / update publish** | Inside `saveDraft` path: `POST …/publish/read-only`, `POST …/publish/full-learn` | Server-driven state transitions | **Workspace + Published** caches affected (`NIMON_CACHE_AND_REFRESH_POLICY.md` §8). |
| **`loadResumeMeta` / `saveResumeMeta` / …** | Small sidecar for last module / subpage | **Meta only** | Already lighter than `loadDraft`; keep separate from list pagination. |
| **`_tryFetchRemoteEtag` / conflict retry helpers** | GET for etag / 409 handling | Full parse today | Operational; not a list concern. |

---

## 3. Over-fetch Risks

1. **N+1 full document fetch (primary risk)**  
   After `listDraftIds()`, **every** Workspace refresh and **every** Add-tab `FutureBuilder` pass loads **`loadDraft`** for **each** id. Remote implementation even documents: *“V1 remote list is lightweight; use ids + loadDraft”* — lightweight **only** for the first HTTP call; **total bytes and parse cost scale linearly with draft count** and include **sentences + learn modules** not needed for a row card.

2. **Add tab loads all drafts but displays ≤ 4**  
   Sorting and filtering (`publishState == draft`) happen **after** full loads, so unpublished-only UX still pays for **published** drafts in the id list unless the index API filters server-side.

3. **Workspace tab: per-draft signature I/O**  
   `loadReadOnlyPublishedCoreSignature(id)` adds **extra reads** per draft (local/tracking) on top of `loadDraft` — acceptable only while N is small; pagination should still prefer a **server-provided “editing vs clean”** flag or summary field to avoid client-side full-story hashing at scale.

4. **`RemoteStoryDraftRepository.loadDraft` side effect**  
   Successful remote GET **writes through to local** (`_local.saveDraft(domain)`), amplifying disk and JSON work for **list-driven** refreshes.

5. **Performance budget alignment**  
   `docs/NIMON_PERFORMANCE_BUDGETS.md` calls for **≤ ~50 summaries per page** for Add/draft picker–style surfaces and **512 KB** max list JSON — **full `CreatorStoryV1` per row** violates the **“no nested sentences for every list row”** anti-pattern in spirit.

---

## 4. Target Summary DTO (`DraftListSummaryDto`)

Row-only fields (no sentences, no quiz bank, no grammar trees, no audio blobs). Names are illustrative; align with `docs/NIMON_API_QUERY_CONTRACT.md` §4.

| Field | Purpose |
|--------|---------|
| **`draftId`** | Stable row key |
| **`title`** | Card title |
| **`coverImageUrl`** | Thumbnail (optional) |
| **`level`** | JLPT / level slug |
| **`category`** | Category label or slug |
| **`status`** | Coarse lifecycle: `draft` / `processing` / `published_archived` (product enum TBD) |
| **`publishState`** | Mirror `StoryPublishState` for filters (Continue vs Workspace) |
| **`processingStatus` or `workspaceState`** | Machine value for “draft” vs “editing” vs remote job state if/when backend owns it |
| **`updatedAt`** | ISO-8601 for sort + cursor |
| **`sentenceCount`** | Integer; cheap signal of progress without sentence text |
| **`publishType` / `displayPublishKind`** | Read-only vs full learn intent for badges |
| **`previewText`** | Short teaser (description or first sentence **truncated server-side** to a byte cap) — optional if description is always small |
| **`etag` or `contentVersion`** | Optional; enables list→detail upgrade without blind PUT |

**Explicitly exclude from list DTO:** `sentences[]`, `vocabularyKanji.entries[]`, `grammar.entries[]`, `quiz.entries[]`, full `audio`, large `content` blobs.

---

## 5. Target Paginated Methods (proposed)

Add **alongside** existing `StoryDraftRepository` methods (`PAGINATED_REPOSITORY_MIGRATION_PLAN.md` §2 rule).

| Method | Returns | Intended consumers | Query dimensions (examples) |
|--------|---------|-------------------|-----------------------------|
| **`fetchWorkspaceDraftPage(PageRequest request)`** | `PageResult<DraftListSummaryDto>` | Profile Workspace / Processing tab | `sort=latest`, `cursor`, `limit`; optional `includeEditing=true` or server-derived `workspaceState` |
| **`fetchContinueWorkingPage(PageRequest request)`** | `PageResult<DraftListSummaryDto>` | Create Add tab: “Continue working” + “Drafts in progress” | Filter **`publishState=draft`** (or equivalent) so published rows never load here |
| **`fetchEditingDraftPage(PageRequest request)`** | `PageResult<DraftListSummaryDto>` | Optional **narrow** surface: drafts with **post-publish core diff** or “active editing” — *or* collapse into `fetchWorkspaceDraftPage` with `filter=editing` | Same envelope; avoids a third HTTP contract if one indexed query suffices |

**Implementation note:** Three Dart names can map to **one** HTTP resource with query flags (`scope=workspace|continue|editing`) until product needs separate indexes.

**Detail unchanged:** `loadDraft(id)` remains for editor, publish, resume, and conflict flows.

---

## 6. Backend Endpoint Requirements

**Recommend** a cursor-paged draft **index** separate from full document GET:

- **`GET /v1/story-drafts`** (or `GET /v1/story-drafts/summaries`)  
  - **Query:** `limit`, `cursor`, `sort` (e.g. `latest`), optional `publishState`, `workspaceScope`, `updatedAfter` (delta).  
  - **Response envelope (mandatory shape):** `{ "items": [ DraftListSummaryDto… ], "nextCursor": string | null, "hasMore": boolean, "totalCount"?: number }` per `docs/NIMON_API_QUERY_CONTRACT.md` §1.

**Items** must be **summary DTOs** only (§4 of query contract).

**Full body** remains:

- **`GET /v1/story-drafts/:id`** — unchanged contract for `loadDraft`.

**Adapter-only phase (no backend yet):**  
Client can call existing `GET /v1/story-drafts` if the server already returns richer `items[]` maps — **map each item to `DraftListSummaryDto` without calling `loadDraft`** when the list payload already includes `title`, `updatedAt`, `publishState`, etc. If today’s list items are **id-only**, the only adapter without backend change is **chunked `loadDraft` with a hard cap** (still over-fetch, but bounded) — label such a path **dev-only / interim** in code comments per migration plan §6.

---

## 7. Migration Order (lowest risk first)

1. **Introduce `DraftListSummaryDto` + `PageResult` mapping** in the data layer **without** switching Profile UI — unit tests for JSON shapes (legacy list vs future envelope), mirroring Published mono migration style.  
2. **Add `fetchWorkspaceDraftPage`** to `StoryDraftRepository` + **Remote** implementation: prefer **real summary index** from backend; if not ready, **strictly bounded** adapter (cap N) with explicit TODO.  
3. **Wire Profile Workspace / Processing** to a **`PaginatedState<DraftListSummaryDto>`** notifier (same pattern as Profile Published): `loadFirstPage` / `refresh` / `loadMore`; keep **`loadDraft`** only when opening a row, sheet, or resume. **Recompute `editing` vs `draft`** from summary fields once server exposes them; until then, optionally **one targeted `loadDraft`** only for rows that need `hasCoreDiff` (reduced from “all rows”).  
4. **Wire Create Add tab** to `fetchContinueWorkingPage` (or shared pager with `publishState=draft` filter).  
5. **Deprecate or narrow `loadAllDrafts` usage** — document “internal / migration only”; no new call sites.  
6. **`fetchEditingDraftPage`** — only if product splits “editing” inbox from main workspace; else skip as a separate HTTP route.

This order matches `PAGINATED_REPOSITORY_MIGRATION_PLAN.md` §5 (Workspace after Published) and keeps **Create editor** paths stable.

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| **Stale list after `saveDraft`** | On successful save, **patch** the summary row or **invalidate first page** of workspace + continue-working notifiers; avoid global provider nukes (`NIMON_CACHE_AND_REFRESH_POLICY.md`, `NIMON_PERFORMANCE_BUDGETS.md`). |
| **Publish / unpublish** | Row moves between Published / Workspace / Continue lists — **remove id** from prior notifier + **refresh** target first page (or optimistic insert with summary from publish response if enriched). |
| **`deleteDraft`** | Remove from paginated lists immediately; handle 404 on subsequent `loadMore`. |
| **Etag / conflict after list** | User opens detail → `loadDraft` may refresh etag; list summaries should **not** cache etag unless used for conditional list GET. |
| **Resume still needs full draft** | `CreatorDraftResumeFlow` / `loadDraftById` must stay **full**; pagination must **not** replace that path. |
| **Signature-based “editing” detection** | Until backend exposes a flag, **client may still need full story** for ambiguous rows — document as **temporary** and cap count. |
| **Strict remote mode** | Failed summary fetch must not wipe local editor truth; align with `strictRemoteDrafts` behavior on Published path. |

**Risk level:** **Medium–High** until summary index exists — **Medium** with a bounded adapter + small N; **Low** for read-only audit documentation.

---

## 9. First Implementation Prompt (ready for Cursor — do not run as part of this audit)

Copy-paste when you are ready to implement (not now):

> Implement workspace / Create draft **list pagination** per `docs/WORKSPACE_DRAFT_PAGINATION_AUDIT.md` and `docs/PAGINATED_REPOSITORY_MIGRATION_PLAN.md`. Add `DraftListSummaryDto` and `fetchWorkspaceDraftPage(PageRequest)` (+ optional `fetchContinueWorkingPage` or query flags) on `StoryDraftRepository` / `RemoteStoryDraftRepository` **without removing** `listDraftIds`, `loadDraft`, or `loadAllDrafts`. Prefer a backend summary + `{ items, nextCursor, hasMore, totalCount? }` envelope; if the list endpoint only returns ids, add a **clearly marked** dev adapter with a **hard cap** and TODO. Introduce a Riverpod pager (`PaginatedState<DraftListSummaryDto>`) for Profile Workspace / Processing and migrate `_loadLocalCreatorDraftIntoProcessing` off per-id `loadDraft` for **row display**, keeping `loadDraft` for open/resume and for editing-detection until summary fields exist. Migrate `StoryCreatorAddTabScreen` `_LocalDraftsSnapshot` the same way. Add tests for JSON parsing (legacy vs paginated envelope), query mapping, and notifier epoch / `loadMore` guards mirroring Profile Published. Do **not** refactor `mono_screen` / unrelated tabs; do **not** change backend in this task unless the prompt is extended with API work. Run `dart format` on touched files, `flutter analyze` (0 errors), `flutter test`.

---

## Output summary (executive)

| Question | Answer |
|----------|--------|
| **Current biggest over-fetch** | **`listDraftIds()` followed by `loadDraft` for every id** on Profile Workspace refresh and Create Add-tab draft list — each load pulls **full** `CreatorStoryV1` (including learn modules) though the UI only needs **summary** row data. |
| **First method to implement** | **`fetchWorkspaceDraftPage(PageRequest)`** returning `PageResult<DraftListSummaryDto>` — unlocks Profile Processing migration first; Create tab can reuse with `publishState=draft` filter. |
| **Backend required or adapter possible?** | **Ideal: backend** summary list + cursor envelope. **Adapter-only:** possible only if **`GET /v1/story-drafts` items already carry summary fields**; if items are id-only, adapter cannot avoid over-fetch without a **cap** (interim). |
| **Risk level** | **Medium–High** without summary API; **Medium** with capped interim; **Low** for documentation-only work. |
