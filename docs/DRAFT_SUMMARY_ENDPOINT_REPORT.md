# Draft Summary Endpoint Report

**Date:** 2026-05-02  
**Scope:** Backend-ready draft summary pagination + Flutter repository foundation (Profile UI **not** wired).

---

## Backend Current Shape (before this change)

- **Route:** `GET /v1/story-drafts`
- **Response:** `{ "items": [...], "nextCursor": null }` only — **no** `hasMore`, **no** `totalCount`.
- **Items:** Already carried **more than `draftId`**: `draftId`, `title`, `updatedAt`, `publishState` (`ProcessingListItemResponseDto`).
- **DB:** `StoryDraft` has `title`, `category`, `level`, `description`, `coverImageUrl`, `publishState`, `updatedAt`; sentence **count** available via `DraftSentence` relation (`_count`).
- **Gap:** No cursor pagination; list used `limit` only (default 50, max 100); no filters.

---

## Backend Changes

- **Same route** `GET /v1/story-drafts` extended (no new path).
- **Query params:** `limit`, `cursor`, `sort`, `status`, `publishState`, `updatedAfter`.
- **Envelope:** `{ items, nextCursor, hasMore, totalCount: null }` per `docs/NIMON_API_QUERY_CONTRACT.md` §1.
- **Item shape:** `DraftListSummaryResponseDto` — summary metadata + `sentenceCount` from `_count.sentences`; **no** sentence bodies or learn blobs.
- **Limits:** Server **max `limit` = 50**; **default `limit` = 50** when omitted (preserves prior default breadth for clients that only call `GET /v1/story-drafts` without `limit`; note prior **max was 100**, now capped at **50**).
- **Cursor:** Opaque **base64url(JSON `{ u: updatedAt ISO, i: draft id })**); stable ordering `(updatedAt desc|asc, id desc|asc)` matching sort (`latest` vs `oldest`).
- **Filters:** `publishState` (exact enum) takes precedence over coarse `status` (`draft` | `published`). `updatedAfter` filters `updatedAt > value`. Invalid `updatedAfter` → `400`; invalid `cursor` → `400`.

**Files**

- `nimon-backend/src/modules/story-drafts/story-drafts.controller.ts`
- `nimon-backend/src/modules/story-drafts/story-drafts.service.ts`
- `nimon-backend/src/modules/story-drafts/dto/story-draft.dto.ts`
- `nimon-backend/src/modules/story-drafts/story-drafts.service.spec.ts`

---

## Flutter Files Changed

- `lib/core/pagination/page_request.dart` — optional `publishState`; included in `toQueryParameters()`.
- `lib/features/create/data/dto/draft_list_summary_dto.dart` — **`DraftListSummaryDto`**, **`DraftListPageDto.parseEnvelope`** (parses list envelope + **interim id-only** path).
- `lib/features/create/data/story_draft_repository.dart` — **`fetchWorkspaceDraftPage(PageRequest)`**.
- `lib/features/create/data/remote_story_draft_repository.dart` — implementation (`GET /v1/story-drafts` + query mapping).
- `lib/features/create/data/local_story_draft_repository.dart` — interim offset cursor (`nimon_local_o_<n>`), bounded page size.
- `test/core/pagination/page_request_test.dart`
- `test/features/create/draft_list_pagination_test.dart`

---

## Public API Added

**Dart**

- `StoryDraftRepository.fetchWorkspaceDraftPage(PageRequest request)` → `Future<PageResult<DraftListSummaryDto>>`
- `DraftListSummaryDto` / `DraftListPageDto.parseEnvelope`
- `PageRequest.publishState`

**HTTP**

- `GET /v1/story-drafts?limit=&cursor=&sort=&status=&publishState=&updatedAfter=`

---

## Backward Compatibility

- Clients that only read **`items[].draftId`** remain valid; items still include **`draftId`**.
- **`listDraftIds()`**, **`loadDraft()`**, **`loadAllDrafts()`** unchanged.
- **Breaking nuance:** Requests that previously used `limit` **> 50** are now clamped to **50** (was **100**).

---

## Pagination Behavior

- **Backend:** Keyset on `(updatedAt, id)`; `take = limit + 1` to derive `hasMore` / `nextCursor`.
- **Flutter remote:** Maps `PageRequest.toQueryParameters()` to the query string (includes `publishState`, `updatedAfter`, etc.).
- **Flutter interim id-only:** If every row is **only** `{ "draftId": "…" }`, parser caps to **`PaginationDefaults.workspacePageLimit` (20)**, sets **`hasMore: false`** and **`nextCursor: null`** (cannot safely continue without summary-capable API). Documented in code (`docs/WORKSPACE_DRAFT_PAGINATION_AUDIT.md` §6).

---

## Tests Added

- **Flutter:** `test/features/create/draft_list_pagination_test.dart` — DTO parse, id-only envelope, full envelope, query mapping, `PageResult` typing.
- **Backend:** `story-drafts.service.spec.ts` — mocked Prisma `findMany` for envelope + cursor continuation.

---

## Flutter Analyze Result

- **`flutter analyze`:** **No analyzer entries with severity `error`** for this workstream (repo still reports many `info`/hint-level issues elsewhere).

---

## Flutter Test Result

- **`flutter test`:** **All tests passed** (suite included **66** passing tests at last run, including new draft pagination tests).

---

## Backend Test Result

- **`jest src/modules/story-drafts/story-drafts.service.spec.ts`:** **2 passed** (run via Node + local `node_modules/jest`).

---

## Risks

- **`listDraftIds()`** still performs a single `GET` without `limit`; server default is now aligned to **50** summary rows — sufficient for prior default breadth; users with **> 50** drafts only see the first page of ids until callers pass **`cursor`** / **`limit`** or migrate UI to **`fetchWorkspaceDraftPage`**.
- **Local `fetchWorkspaceDraftPage`** does not apply `publishState` / `updatedAfter` filters (index-only interim behavior).
- **`processingStatus`** is always **`null`** until backend workflow state exists.

---

## Recommended Next Step

- Add a Riverpod **`PaginatedState<DraftListSummaryDto>`** notifier for Workspace / Processing and switch row rendering off **`fetchWorkspaceDraftPage`** while keeping **`loadDraft`** for open/resume (per `WORKSPACE_DRAFT_PAGINATION_AUDIT.md` §7).
