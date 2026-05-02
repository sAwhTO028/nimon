# Paginated Repository Migration Plan

**Status:** PLAN ONLY — no Dart, backend, routing, or screen refactors in this document.  
**Inputs:** `docs/NIMON_API_QUERY_CONTRACT.md`, `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`, `docs/NIMON_CACHE_AND_REFRESH_POLICY.md`, `docs/NIMON_PERFORMANCE_BUDGETS.md`, `docs/PAGINATION_FOUNDATION_REPORT.md`, `lib/core/pagination/*.dart`, `lib/features/profile/data/remote_published_mono_repository.dart`, `lib/features/create/data/remote_story_draft_repository.dart`, `lib/features/profile/profile_screen.dart`, `lib/features/mono/mono_screen.dart`.

**Foundation types:** `PageRequest`, `PageResult<T>`, `PaginatedState<T>`, `PaginationDefaults` (`lib/core/pagination/`).

---

## 1. Current Data Loading Surfaces

| Surface | Current loading model | Notes |
|---------|------------------------|--------|
| **Mono feed** (`/mono`, `/mono-reader`) | **UI-only / in-widget:** `MonoFeedItem` lists built inside `mono_screen.dart` (For You / Following / Saved segments); **not** `StoryRepo` today. | High churn, image precache, tab pager — pagination belongs in a **future** feed notifier, not first migration. |
| **Mono search** (`/mono/search`) | **Placeholder:** `MonoSearchScreen` — static copy only; **no** repository or network list. | Lowest coupling today; pagination is **spec-only** until search API exists. |
| **Profile — Published tab** | **Remote:** `RemotePublishedMonoRepository.list({int limit = 50})` → `GET /v1/published-monos?limit=…` (`profile_screen.dart` uses `limit: 80`). | Single HTTP list; DTOs already split list vs detail (`published_mono_dto.dart`). **Strong first candidate.** |
| **Profile — Saved tab** | **UI mock:** static folder / `_OneShortItem` structures in `profile_screen.dart` (not remote list). | Later: real saved API + `PaginatedState`; today **no** backend list to page. |
| **Profile — Workspace (drafts)** | **Remote + local:** `storyDraftRepositoryProvider` → `RemoteStoryDraftRepository` implements `StoryDraftRepository` (`listDraftIds`, `loadAllDrafts`, `loadDraft`, …). | List is **ID-heavy** / full-draft loads; pagination strategy may be **summary index** endpoint first. |
| **Profile — Collections** | **UI mock:** folder rows and collection naming sheets in `profile_screen.dart`. | No shared repository list yet. |
| **Create — “Continue” / add flow** | **Draft session:** `story_creator_provider` / `CreateScreen` / routes to sentences with `draftId`; persistence via `StoryDraftRepository`. | “Continue working” is **draft-centric**, not a classic infinite list; paginate **draft index** or **recent** list when API supports it. |
| **Drafts in progress** | Same as **Workspace** (Profile tab 1): `listDraftIds` / `loadAllDrafts` patterns. | See Workspace row. |
| **Learn — Vocabulary list** | **Static mock:** `VocabKanjiListScreen.mockItems` const list. | No repository; future `fetchVocabularyPage(contentId, PageRequest)` when backend owns learn rows. |
| **Learn — Grammar list** | **Static mock:** `GrammarPatternListScreen.mockPatterns`. | Same as vocabulary. |
| **Learn — Quiz** | Hub + `QuizSetupScreen` / play flows tied to `contentId`; list surfaces are mostly **session** scoped in V1. | Treat **browse-scale** quiz item lists as future paged API; current screens are not backed by a paginated repo. |
| **Learn — Listening** | `ListeningPronunciationScreen` — audio/transcript init; not a long **repository-backed** list in V1. | Pagination if transcript segments or library lists grow. |

---

## 2. Current Repository Methods

| Boundary | Representative methods | Paginated today? | Local / remote / mock |
|----------|-------------------------|------------------|------------------------|
| **`StoryRepo` / `StoryRepoMock`** | `listStories`, `getStories`, `getStoryById`, `getEpisodesByStory`, `getStoriesBySection`, `getFilteredStories`, `fetchQuickOneShots`, `addEpisode`, `getQuizByStory` | **No** — `Future<List<…>>` only; **not** called from live Mono/Profile (`docs/STORY_REPO_LIVE_DEPENDENCY_MAP.md`). | **Mock**; legacy callers archived under `archive/`. |
| **`RemotePublishedMonoRepository`** | `list({int limit})`, `get(String id)` | **Partial** — server returns `items` JSON; **no** `nextCursor` / `hasMore` in Dart DTO today. | **Remote** |
| **`StoryDraftRepository` / `RemoteStoryDraftRepository`** | `listDraftIds`, `loadAllDrafts`, `loadDraft`, `saveDraft`, … | **No** — bulk / by-id operations. | **Remote + local** fallback |
| **Mono feed** | (none at repo layer) | **N/A** | **UI-only** |
| **Mono search** | (none) | **N/A** | **UI-only** |
| **Learn vocab / grammar lists** | (none) | **N/A** | **UI-only mocks** |

**Rule for migration:** Add **new** `fetch*Page(PageRequest) → Future<PageResult<…>>` (or adapter wrappers) **alongside** existing methods until all call sites switch; **do not** delete `StoryRepo` signatures in the same tranche.

---

## 3. Target Paginated Methods (proposed)

Naming aligns with `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md` and `PageRequest` / `PageResult` (`docs/PAGINATION_FOUNDATION_REPORT.md`).

| Method | Returns | Purpose |
|--------|---------|---------|
| `fetchMonoFeedPage(PageRequest req)` | `Future<PageResult<MonoFeedSummaryDto>>` | For You / Following / Saved when feed moves off static lists. |
| `searchMonoPage(PageRequest req)` | `Future<PageResult<MonoFeedSummaryDto>>` | Mono search once API exists (`query` from `req`). |
| `fetchProfilePublishedPage(PageRequest req)` | `Future<PageResult<PublishedMonoListItemDto>>` | Published tab infinite scroll. |
| `fetchSavedMonoPage(PageRequest req)` | `Future<PageResult<SavedMonoSummaryDto>>` | Saved tab when backend exists (DTO name TBD). |
| `fetchWorkspaceDraftPage(PageRequest req)` | `Future<PageResult<DraftListSummaryDto>>` | Workspace rows without loading full `CreatorStoryV1` each time (summary DTO TBD). |
| `fetchCollectionItemsPage(PageRequest req)` | `Future<PageResult<CollectionItemSummaryDto>>` | Collection detail when product ships collections API. |
| `fetchVocabularyPage(PageRequest req)` | `Future<PageResult<VocabKanjiSummaryDto>>` | Learn vocab list per `contentId` (likely `ownerId` or path param + `PageRequest`). |
| `fetchGrammarPage(PageRequest req)` | `Future<PageResult<GrammarPatternSummaryDto>>` | Learn grammar list per story. |
| `fetchQuizPage(PageRequest req)` | `Future<PageResult<QuizBrowseSummaryDto>>` | Future browse-scale quiz lists. |

**Parameter mapping:** Reuse `PageRequest.toQueryParameters()` for HTTP query building; add endpoint-specific path keys (e.g. `contentId`) at the repository boundary where needed.

---

## 4. Summary DTO vs Detail DTO Mapping

Aligned with **`docs/NIMON_API_QUERY_CONTRACT.md`** §4 (summary excludes heavy payloads).

| **Summary (list row / card)** | **Detail-only (separate fetch)** |
|------------------------------|----------------------------------|
| Stable ids (`monoId`, `draftId`, pattern id, quiz id) | Full **reader** payload: sentences, furigana tokens, full audio binaries |
| Title, cover/thumbnail URL, level, category slugs | Full **quiz bank** / question bodies |
| Short description / teaser | Grammar tree / full examples blob beyond list teaser |
| `likesCount` / badges / `publishedAt` / `updatedAt` (ISO strings) | `content` / `contentSummary` **large** objects — load on open |
| `writerHandle`, `displayPublishKind`, processing label | Transcript segments for entire episode |
| `contentSummary` **only if** bounded size contract met | Anything over **performance budget** per `docs/NIMON_PERFORMANCE_BUDGETS.md` |

**Existing alignment:** `PublishedMonoListItemDto` vs `PublishedMonoDetailDto` (`published_mono_dto.dart`) already mirrors this split — extend list response with **`nextCursor` / `hasMore` / `totalCount?`** without moving detail fields into the list envelope.

---

## 5. Provider / Notifier Migration Order (lowest risk first)

1. **Profile — Published tab** — Single remote repository; narrow UI surface; DTOs exist; easy to feature-flag or dual-path behind same tab.  
2. **Profile — Workspace draft list** — Introduce **summary** paged fetch before refactoring `loadAllDrafts` consumers; keep **`loadDraft`** for open-row.  
3. **Mono search** — After search API + debounce (`PaginationDefaults.searchDebounceMs`); still placeholder UI today.  
4. **Profile — Saved** — When saved API exists; depends on product.  
5. **Profile — Collections** — When collections API exists.  
6. **Learn — Vocab / Grammar / Quiz browse** — Replace static mocks with repositories + notifiers per `contentId`.  
7. **Mono feed** — Last: largest UX/state footprint (`mono_screen.dart`), precache, tabs, and unsaved reader flows.

**Do not** start with **Mono feed** first — regression blast radius exceeds Profile published.

---

## 6. Backend Endpoint Requirements

| Endpoint area | Request | Response | Index / ops notes |
|---------------|---------|----------|-------------------|
| **Published monos** | `GET /v1/published-monos` with `limit`, `cursor`, optional `sort`, `updatedAfter` (delta) | `{ items, nextCursor, hasMore, totalCount? }` per API contract | Index on `(ownerId, updatedAt DESC, id)` for stable cursor; cap `limit` server-side (e.g. ≤ 50). |
| **Draft index (workspace)** | `GET /v1/story-drafts` summary list with cursor | Same envelope; items are **summary** DTOs | Avoid full JSON blobs in list; etag per row for detail GET. |
| **Saved monos** | TBD product path | Same envelope | Likely user-scoped + bookmark time cursor. |
| **Search** | `GET /v1/monos/search` or consolidated search index | Same envelope | Debounced client; server may require min query length. |
| **Learn lists** | Per-`contentId` sub-resources | Same envelope | Rate-limit and cap payload per performance budgets. |

**If backend is not yet cursor-paged:** Use **adapter-first** approach: one HTTP call returns full current list → client wraps in `PageResult` with synthetic `nextCursor` / `hasMore` (e.g. single page) **or** slices in memory for dev — **clearly marked** `DevPagedAdapter` to avoid production reliance.

---

## 7. Cache / Refresh Rules Per Surface

| Surface | TTL / SWR | Refresh trigger | Invalidation |
|---------|-----------|-----------------|--------------|
| **Published list** | Medium (2–10 min guideline); SWR on tab focus | Pull-to-refresh; publish success | On publish / unpublish / delete affecting that row (`docs/NIMON_CACHE_AND_REFRESH_POLICY.md` §8) |
| **Workspace drafts** | Strong consistency after mutations | After `saveDraft` / processing update | Save, delete, publish events — scoped lists only |
| **Mono feed** | Short (30–120 s) when remote-backed | Pull; dock tab switch optional soft refresh | Publish/bookmark events — **first page** or row-level patch preferred |
| **Saved** | Medium + optimistic bookmark | Pull; bookmark toggle | Bookmark / unbookmark — patch row, avoid global feed invalidate |
| **Learn lists** | Session cache after first load | Language / explanation setting change | Per §6 cache doc — reload summaries when learn language policy requires |
| **Search** | No long TTL; debounce input | New query resets cursor | N/A per query session |

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| **Over-fetching** | Enforce summary DTOs + server `limit` cap; client `PageRequest` clamp already in foundation types. |
| **Duplicate in-flight requests** | `PaginatedState.requestEpoch` + cancel / ignore stale responses; document in notifier. |
| **Stale cursor** after mutation | Invalidate cursor on write paths or reset to first page for affected filters. |
| **Global invalidation** | Avoid “clear everything” on small events; use matrix in cache policy §8. |
| **Query count / cost** | Debounce search; avoid per-frame `PageRequest` rebuilds. |
| **Large JSON** | Enforce envelope size budget; omit `totalCount` on hot paths if expensive. |
| **Dual API during migration** | Keep legacy `list()` until UI + tests migrated; deprecation window. |

---

## 9. First Implementation Candidate

**Profile — Published tab** via **`fetchProfilePublishedPage(PageRequest)`** wrapping **`RemotePublishedMonoRepository`**.

**Why safest**

- **Single** remote list and **known** endpoint shape (`/v1/published-monos`).  
- **DTOs** already separate list vs detail (`list` vs `get`).  
- **Mono feed untouched** — satisfies “do not migrate Mono first” constraint.  
- **Tests:** extend with repository/unit tests + optional widget test for tab scroll without rewriting `mono_screen.dart` in the first PR.

**Backend required?** **Not strictly** for an incremental Flutter step: an **adapter** can map today’s non-cursor JSON to `PageResult` (one page, `hasMore: false`) while server adds `nextCursor`; then flip adapter to pass through real cursors when available.

---

## 10. Exact Cursor Prompt For First Implementation

Copy-paste into a new agent task when ready to implement (still **keep** existing `list({limit})` until callers migrated):

```text
You are a senior Flutter engineer.

Constraints:
- Do NOT change GoRouter routes or MonoScreen/Create core flows beyond Profile published list loading.
- Do NOT remove RemotePublishedMonoRepository.list yet; add new API alongside.
- Preserve flutter analyze 0 errors and extend tests (no mass-deletion of tests).

Goal:
Implement fetchProfilePublishedPage(PageRequest) → Future<PageResult<PublishedMonoListItemDto>> for the Profile Published tab.

Tasks:
1. Extend PublishedMonoListResponseDto (or add PublishedMonoListPageDto) to optionally carry nextCursor, hasMore, totalCount from JSON when present; default hasMore=false and nextCursor=null when absent for backward compatibility.
2. Add RemotePublishedMonoRepository.fetchPage(PageRequest req) that builds query from req.toQueryParameters() and maps response to PageResult<PublishedMonoListItemDto>.
3. Add a Riverpod notifier (e.g. profilePublishedMonoListNotifierProvider) holding PaginatedState<PublishedMonoListItemDto> with loadFirstPage / loadMore / refresh respecting requestEpoch.
4. Wire ONLY ProfileScreen published-tab list to the notifier (minimal diff); keep strict/fallback behavior consistent with RemoteBackendConfig.strictRemoteDrafts patterns where applicable for HTTP errors.
5. Add unit tests for repository mapping (with mock http.Client) and notifier stale-response behavior.
6. Run dart format on touched files, flutter analyze, flutter test.

Out of scope:
- Mono feed, workspace drafts, backend Nest changes (unless response already includes cursor fields).
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **First surface to migrate** | **Profile — Published tab** (`RemotePublishedMonoRepository` + small `ProfileScreen` wiring + notifier). |
| **Files likely to change later** | `remote_published_mono_repository.dart`, `published_mono_dto.dart`, new `lib/features/profile/data/*_notifier.dart` (or similar), `profile_screen.dart` (published branch only), tests under `test/features/profile/` or `test/data/`; later `remote_story_draft_repository.dart`, `mono_screen.dart`, learn screens. |
| **Backend changes required?** | **Not required** for first tranche if you ship a **client adapter** for current `GET /v1/published-monos?limit=…`; **recommended** later for true `cursor` / `hasMore` in JSON per `docs/NIMON_API_QUERY_CONTRACT.md`. |
| **Risk level** | **Low–medium** — low if adapter-only + feature-flag; medium when enabling real cursors and concurrent refresh on production data. |
| **Recommended next step** | Execute **§10 prompt** in a dedicated PR; add contract tests for JSON → `PageResult`; only then widen to **workspace draft summaries**. |
