# Nimon Performance Budgets

**Purpose:** Numeric and behavioral budgets so lists, reader, Learn, and Create stay smooth on mid-tier phones. Targets are **goals**, not assertions about current codebase (several mega-widgets exist today—align refactors gradually).

---

## 1. Global Targets

| Item | Budget | Notes |
|------|--------|--------|
| Feed first page item count (`limit`) | **15** default, **max 30** | Override only with instrumentation. |
| Next page (`limit`) | Same as above | Maintain consistent skeleton row height during append. |
| Max uncompressed JSON payload (single list response) | **512 KB** | Split endpoints if exceeded—never stream full learn trees in summary. |
| Max list thumbnail longest edge | **512 px** prefetched decoded target | Use resized CDN params when available; avoid decoding 4k in list. |
| Search debounce | **250 ms** nominal (**200–350 ms** tolerance) | `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`. |
| Loading skeleton minimum display | Avoid **\< 120 ms flash** unless instant cache hit | Helps perceived stability. |
| Global refresh prohibition | Lists must **never** implicitly `invalidate` **all providers** root on micro-mutations | Patch rows or scopes only. |

---

## 2. Screen-Level Budgets

| Screen / tab | Time / size budget | Behavioral budget |
|--------------|--------------------|--------------------|
| **Mono feed** | First paint summaries ≤ **150–300 ms CPU** parsing after gzip (goal) after bytes arrive | No episode/quiz/learn fetch per row bind. |
| **Mono reader** | Keep **≤ 2 adjacent** sentence pages hot; decode images lazily | No audio init until Listening route. |
| **Profile published** | Page size mirror feed defaults | Separate detail fetch on drill-in only. |
| **Profile saved** | Same paging | Optimistic bookmark sync (cache policy doc). |
| **Workspace tab** | Prioritize freshest draft sort; tolerate stronger refetch **post-save** only | Debounce autosave bursts (creator existing logic respected). |
| **Add Story / drafts picker** | **≤ 50** summaries default cap per page unless editor needs more | Detail still lazy. |
| **Learn hub** | Module tiles **summaries only** | Details on navigation. |
| **Vocabulary list** | Default **50**/page | Virtualize list (builder). |
| **Grammar list** | Default **50**/page | No inline pattern trees in cells. |
| **Quiz list** | Default **30**/page previews | Questions load inside quiz play route. |
| **Listening module** | **Zero** prefetch of audio before route | Stream after open; backoff retry on stall. |

---

## 3. Anti-Patterns (Explicitly Forbidden)

1. **Full table scan endpoints** powering client swipe feeds.
2. **Fetching all rows** (`SELECT * LIMIT none`) mocked as “fine” in production backends.
3. **Nested sentences** for **every feed item** in Mono list JSON.
4. **Calling AI** during passive feed pagination or idle scroll prefetch.
5. **Loading audio metadata** (`duration`, waveform) into every mono row payload.
6. **Rebuilding whole feed** notifier because one mono `likesCount` changed—patch item state.
7. **Invalidating all Riverpod ancestors** (`ref.invalidate(providerThatRebuildsWholeApp)`), after localized mutation—see cache matrix.

---

## 4. Mega-Widget Note (Technical Debt Awareness)

Screens such as **`mono_screen.dart`**, **`profile_screen.dart`**, **`story_creator_sentences_screen.dart`** consolidate heavy logic—these files **amplify** violation cost of improper invalidation/parsing inside build paths. Incremental decomposition should respect performance budgets (`docs/NIMON_ARCHITECTURE_CONSTITUTION.md`).

---

## Related

- `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`
- `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`
