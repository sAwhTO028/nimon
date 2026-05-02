# Nimon Query Performance Guide

**Audience:** Flutter + backend implementers working on Nimon **V1** and beyond.  
**Authority:** Product flow follows the **PDF wireframe**. Engineering follows `docs/NIMON_ARCHITECTURE_CONSTITUTION.md` and `docs/NIMON_WIREFRAME_SCOPE_LOCK.md`.  
**Scope:** Guidance for networking, payloads, pagination, caching co-design—**does not supersede** API contracts (`docs/NIMON_API_QUERY_CONTRACT.md`).

---

## 1. Performance Goals for V1

| Goal | Target behavior |
|------|-----------------|
| **Perceived responsiveness** | First meaningful paint for Mono feed and Profile tabs \< **1s** on mid-tier device under normal network (excluding cold start). |
| **Bounded memory** | List screens must not retain unbounded collections of **detail** payloads. |
| **Predictable networking** | No duplicate overlapping calls for the same `(screen, filters, cursor)` while a response is **in-flight**. |
| **Future-proofing** | Every list path should be shaped for **pagination** before backend ships at scale—even if mock/local returns one page today. |

---

## 2. Core Principle

**Fetch only what the screen needs, when it needs it.**

- **List surfaces** consume **summary** rows (identifiers, titles, thumbnails, badges, counters).
- **Detail surfaces** load **heavy** payloads (sentences + furigana, learn payloads, quiz items, signed audio URLs).

---

## 3. Mandatory Rules

### 3.1 Never load full story / mono detail for feed rows

- Feed cards must bind to **`MonoFeedSummary`-class shapes** only (server or local façade).
- **Bad:** Returning `Story` + nested `Episode` + blocks for each row “because mock is faster.”  
- **Good:** `GET …/mono/feed?page=…` returning **thin** summaries; open reader triggers `GET …/mono/{id}/reader` or equivalent.

### 3.2 Never load Learn modules inside Mono feed prefetch

Learn hub, grammar, vocab, quiz, listening **load after** explicit user navigation to Learn (or creator panel)—not during vertical feed idle scroll.

### 3.3 Never load audio / quiz detail in list views

- Listening: defer **manifest** until module screen opens; stream after tap.
- Quiz: list shows **titles/counts/progress dots**—not MCQ payloads.

### 3.4 Separate summary from detail data

Maintain **distinct DTO layers** (`docs/NIMON_API_QUERY_CONTRACT.md`). Sharing one giant JSON for feed + draft + learn is forbidden at API level.

---

## 4. Lazy Loading Checklist

| Surface | Lazy-load target |
|---------|-------------------|
| **Mono reader** | Current + adjacent sentences; prefetch next page of sentences—not full corpus. |
| **Story sentences (Create)** | Per-draft panels; vocab/grammar embeds scoped to sentence selection. |
| **Learn hub** | Module cards summaries first; grammar/vocab/quiz/detail on drill-in. |
| **Profile published / saved / workspace** | Paged summaries; mono detail opened on navigate. |

---

## 5. Duplicate Request Prevention

- Use an **in-flight guard** keyed by `{route|tab, normalizedQuery, cursor}` (`docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`).
- Cancel or **ignore stale** completions when filters change (token / epoch counter).

---

## 6. Search Debounce

- Client-side search input: debounce **200–350 ms** typical (budget in `docs/NIMON_PERFORMANCE_BUDGETS.md`).
- Fire **abort** or ignore previous query when query string changes mid-flight.

---

## 7. Pagination

All primary lists (Mono feed, profile tabs, drafts, collections, vocab/grammar/quiz browse) use **cursor + limit**—see contracts doc. Never “give me everything” endpoints for production scales.

---

## 8. Build / Isolate Hygiene

- **Never** heavy `jsonDecode`, large list transforms, or `http.get` directly inside `build()`, `didUpdateWidget` hot paths, or synchronous `listen` firing every frame without throttle.
- **Prefer** repositories + `Future`/`async`/`compute` for large parses.
- Avoid **invalidate roots** causing whole-tree refetch (`docs/NIMON_PERFORMANCE_BUDGETS.md`).

---

## 9. Good vs Bad Examples

### Example A — Mono feed row

**Good:**
```dart
// Pseudocode — repository owns fetch
monoFeedNotifier.loadInitial(); // fills List<MonoFeedSummary>
MonoFeedCard(summary: summaries[i]); // thumbnails + badges only
```
**Bad:**
```dart
MonoFeedCard(storyFull: repo.getEverything(id)); // in itemBuilder
FutureBuilder(fetch entire draft + sentences for 20 IDs on scroll)
```

### Example B — Search

**Good:** Debounced `searchMonoPage(limit, cursor, query)`.  
**Bad:** `onChanged:` → immediate `repository.search(trimmed)` spam without cancel.

### Example C — Reaction / bookmark toggle

**Good:** optimistic local patch + PATCH + rollback on failure; **do not** `ref.invalidate(entireMonoFeedProvider)`.  
**Bad:** Toggle → `invalidate` every provider referencing `StoryRepo`.

---

## 10. AI Integration Performance Note

AI calls **never** tied to passive feed scroll/load (`docs/NIMON_AI_FEATURE_PLAN.md`). Any batch generation is async job + explicit user gesture.

---

## Related Docs

- `docs/NIMON_API_QUERY_CONTRACT.md`
- `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`
- `docs/NIMON_CACHE_AND_REFRESH_POLICY.md`
- `docs/NIMON_PERFORMANCE_BUDGETS.md`
- `ai_prompts/ADD_PAGINATED_LIST_PROMPT.md`
