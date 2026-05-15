# M18 — V1 Mono search and filter (plan only)

**Milestone status**

| Milestone | Status |
|-----------|--------|
| **M18A** — Backend `GET /v1/search/monos` | **Done** — see `docs/M18A_BACKEND_SEARCH_ENDPOINT_REPORT.md` |
| **M18B** — Flutter client + data layer (no full UI) | **Done** — see `docs/M18B_FLUTTER_SEARCH_DATA_LAYER_REPORT.md` |
| **M18C** — Search UI + shell entry | **Done** — see `docs/M18C_SEARCH_SCREEN_UI_REPORT.md` |

This document is a **product and engineering plan** for lightweight published-mono search in V1. **No implementation** is specified at the code level beyond proposals and acceptance criteria.

---

## 1. Product goals

- Let readers **find published monos** quickly from a single entry point (search icon → dedicated screen).
- Support **plain keyword** matching across **title**, **description**, **creator display name**, and **creator handle** so results feel relevant without NLP.
- Offer a **small, predictable filter set** (JLPT **level**, **category**) and a **simple sort** so the feed is scannable on mobile.
- Reuse **existing mono list/card UI** where possible for consistency and velocity.
- Behave well on **slow networks**: loading, empty, error, and **cursor pagination** (“load more”) must be clear and non-destructive.

---

## 2. V1 scope

| Area | V1 |
|------|-----|
| **Corpus** | **Published monos** only (public catalog aligned with home/discovery expectations). |
| **Query** | Single **`q`** string: keyword search over **title**, **description**, **creator display name**, **creator handle** (case-insensitive, substring or tokenized prefix—**implementation detail left to backend**; must be documented in API spec). |
| **Filters** | **`level`**: `N5` \| `N4` \| `N3` \| `N2` \| `N1` (optional; omit = any). **`category`**: single value from existing app category vocabulary (same as create/catalog). |
| **Sort** | **`latest`** (default): recency by publish or catalog “updated” field as defined by backend. **`popular`**: only if **like count and/or view/impression count** exists on indexed documents; **otherwise see §9 (V1.1)** — V1 may ship **latest-only** or **popular** behind a feature flag if metrics exist. |
| **Pagination** | **Cursor-based** (`limit`, `cursor`, `hasMore`, `nextCursor`) consistent with existing mono feed / profile list patterns. |
| **UI** | Mobile-first: **search field** at top, **level chips**, **category chips**, **sort control**, **scrollable results** using **existing mono row/card** components, **empty / loading / error** states, **load more** at list end. |

---

## 3. Out of scope (explicit)

- **Semantic / vector / embedding** search.
- **AI**-generated answers, summaries, or query expansion.
- **Typo correction**, fuzzy phonetic matching, transliteration magic (e.g. romaji ↔ kana) beyond whatever the DB naturally supports.
- **Saved searches**, search history sync, or named filters.
- **Complex tags**, arbitrary multi-tag AND/OR builders, or **multi-select** advanced filters (single level + single category in V1).
- **Dedicated “search creators”** hub or cross-entity search **unless** the mono search query already matches creator fields cheaply (in scope only as fields on **mono** documents).
- **Full-text relevance tuning** beyond a simple ordering contract (e.g. no BM25 product requirement in V1—backend may still use DB FTS).

---

## 4. Backend endpoint proposal

**`GET /v1/search/monos`**

| Query param | Required | Description |
|-------------|----------|-------------|
| `q` | No | Keyword string; empty or omitted = “browse” mode with filters/sort only (optional product choice: require min length, e.g. 2 chars—decide at implementation). |
| `level` | No | One of `N5`, `N4`, `N3`, `N2`, `N1`. |
| `category` | No | Single category slug or id aligned with existing mono taxonomy. |
| `sort` | No | `latest` (default). `popular` only if metrics exist (see §5). |
| `limit` | No | Default **20**, max cap (e.g. 50) enforced server-side. |
| `cursor` | No | Opaque cursor for next page. |

**Response shape (proposal):**

```json
{
  "items": [],
  "hasMore": true,
  "nextCursor": "...",
  "totalCount": 0
}
```

- **`items`**: Same **published mono list item** DTO shape as existing feed/list endpoints (or strict subset + `shareUrl` / learn ids as today) to minimize Flutter mapping.
- **`hasMore` / `nextCursor`**: Same semantics as other paginated list APIs in the app.
- **`totalCount`**: Optional for V1 if expensive; if omitted, document and have Flutter hide “X results” or show “many results” only when cheap. **Recommendation:** return `totalCount` when query is bounded (e.g. capped estimate) or omit and use `hasMore` only.

**Non-goals for the endpoint:** cross-indexing bookmarks, drafts, or private monos.

---

## 5. Query, filter, and sort behavior

**Keyword (`q`):**

- Match against **title**, **description**, **creator display name**, **creator handle** (normalized: trim, casefold; `@` stripped for handle match if stored with prefix).
- **AND** semantics across tokens (simple): all whitespace-separated tokens must match somewhere in the union of fields unless product prefers **OR**—**recommend AND** for precision on mobile.
- No minimum relevance score API in V1; **sort** defines order among matches.

**Filters:**

- **`level`**: Exact JLPT band on mono; incompatible with “no level” monos—**define**: either filter excludes null level or maps “unset” to a bucket; document in OpenAPI.
- **`category`**: Single-select; invalid category → `400` with validation error key consistent with M13 patterns.

**Sort:**

- **`latest`**: Stable descending by published/visible timestamp (same field as home “recent”).
- **`popular`**: **Only if** `likesCount`, `viewCount`, or composite `popularityScore` exists on published mono projection. Order: e.g. descending likes, tie-break by latest. **If not available:** do not expose `popular` in V1 UI; document under **V1.1** (§9).

**Pagination:**

- Cursor encodes last item sort keys + id to avoid duplicates when new monos publish during paging.
- **Idempotent** re-fetch of first page when `q` or filters change (reset cursor client-side).

---

## 6. Flutter UI proposal

**Entry**

- **Search icon** in an agreed shell location (e.g. **Mono** tab app bar or floating header—align with navigation IA in a small M18a UX note) opens **`/mono/search`** (or `/search/monos`) as a **full-screen route** outside bottom nav if needed, or inside shell with custom app bar—prefer **full-screen** for focus.

**Layout (top → bottom)**

1. **App bar**: Back, title “Search”, optional clear on `q` non-empty.
2. **Search field**: `SearchBar` / `TextField` with search icon, debounced submit (300–500 ms) or explicit submit button—**recommend debounce + Enter** to limit API calls.
3. **Horizontal chips — Level**: `N5` … `N1`; one selected or “Any”; toggling resets cursor.
4. **Horizontal chips — Category**: scroll row; data from **existing category source** (same as create/home).
5. **Sort**: `SegmentedButton` or dropdown: **Latest** | **Popular** (hidden if backend does not support popular).
6. **Results**: `ListView` / `PagedListView` of **existing** mono list tile/card widget used on home or public profile mono tab.
7. **Footer**: “Load more” button or infinite scroll sentinel when `hasMore`; show subtle loading row.

**States**

- **Loading (initial):** centered indicator or skeleton rows consistent with app patterns.
- **Empty:** illustration or icon + short copy (“No monos match your search”) + suggestion to clear filters.
- **Error:** retry button + mapped network/validation message (M13/M16 patterns).
- **Pagination loading:** bottom progress without clearing list.

**Accessibility**

- Chips as proper toggles with labels; sort control with screen reader text.

---

## 7. Pagination behavior

- First load: `GET .../monos?q=&level=&category=&sort=latest&limit=20` (no cursor).
- Append: pass `nextCursor` from previous response when user scrolls to threshold or taps **Load more**.
- On **any** param change (`q`, `level`, `category`, `sort`): **discard** previous cursor, scroll to top, fetch page 1.
- Guard **double fetch** (single in-flight request per query key; cancel or ignore stale responses).
- **End of list:** when `hasMore == false`, hide load-more and optionally show “End of results”.

---

## 8. Tests needed

**Backend (Nest)**

- Contract tests for `GET /v1/search/monos`: empty `q` + filters; `q` with multi-token; invalid `level`/`category`/`sort`; cursor round-trip; `hasMore` edge at exactly `limit` items.
- SQL/FTS tests (if applicable): ensure indexes used; no full table scan on large seed (smoke).

**Flutter**

- **Repository / mapper:** parse response → domain list + cursor; handle missing `totalCount`.
- **Notifier / controller:** debounce, reset cursor on filter change, append on load more, error retry.
- **Widget / golden (optional):** search screen shows chips, sort, list placeholder; empty and error UI.
- **Integration (optional):** tap chip → URL/query matches mock server.

---

## 9. V1.1 / V2 future ideas

- **`popular` sort** when **view** or **impression** pipelines exist; optional **trending** window (7d).
- **Typo-tolerant** or kana-normalized search.
- **Multi-category** or tag filters; **saved searches**.
- **Semantic / vector** search for “find monos like this.”
- **Search analytics** (query logs, zero-result rate) to tune copy and defaults.
- **Creator-first** search tab if cheap index split is justified.

---

## Recommended implementation milestones

| Milestone | Deliverable |
|-----------|-------------|
| **M18A** | Backend: `GET /v1/search/monos` + OpenAPI + indexes + Nest module tests; feature flag if DB migration needed. |
| **M18B** | Flutter: `RemoteMonoSearchRepository` (or extend existing feed client), DTO alignment with published mono card, Riverpod notifier with cursor state. |
| **M18C** | UI: Search route, shell entry (icon), chips, sort, list, empty/loading/error, load more. |
| **M18D** | QA: performance on device, dark mode, localization keys, docs `M18_*_REPORT.md` closeout. |

---

## Summary table (planning)

| Topic | V1 decision |
|-------|-------------|
| Corpus | Published monos |
| API | `GET /v1/search/monos` + cursor + `items` / `hasMore` / `nextCursor` / `totalCount` |
| Search fields | Title, description, creator name, creator handle |
| Filters | Level (JLPT), category (single each) |
| Sort | Latest; popular only if metrics exist |
| UI | Search screen, chips, sort, existing cards, pagination |
