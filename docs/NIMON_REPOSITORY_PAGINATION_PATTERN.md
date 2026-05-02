# Nimon Repository Pagination Pattern

**Purpose:** Unified **Dart repository + Riverpod** pattern for infinite lists compatible with backend contract (`docs/NIMON_API_QUERY_CONTRACT.md`).  
**Note:** Current `StoryRepo` returns **`Future<List<T>>`** without paging—implementations should **adapt** mocks and remote repos toward this shape without breaking existing call sites until migration tranche lands.

---

## 1. Core Types

### 1.1 `PageRequest`

```dart
/// Conceptual — exact file location TBD when coding.
class PageRequest {
  const PageRequest({
    this.cursor,
    this.limit = 20,
    this.sort,
    this.level,
    this.category,
    this.query,
    this.ownerId,
    this.status,
    this.accessType,
    this.updatedAfter,
  });

  final String? cursor;
  final int limit;
  final String? sort;
  final String? level;
  final String? category;
  final String? query;
  final String? ownerId;
  final String? status;
  final String? accessType;
  final DateTime? updatedAfter;
}
```

### 1.2 `PageResult<T>`

```dart
class PageResult<T> {
  const PageResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
    this.totalCount,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final int? totalCount;
}
```

---

## 2. Repository Naming Conventions

| Pattern | Example |
|---------|---------|
| **Initial + more** | `fetchXxxPage(PageRequest req)` returns `Future<PageResult<XxxSummary>>` |
| **Search** | `searchXxxPage(PageRequest req)` — same shape, may hit different index |
| **Detail** | `getXxxDetail(String id)` — **not** paged unless sentence windowing applies |

**Concrete examples (target API):**

- `fetchMonoFeedPage`
- `fetchProfilePublishedPage`
- `fetchSavedPage`
- `fetchWorkspaceDraftPage`
- `fetchCollectionItemsPage`
- `searchMonoPage`

---

## 3. Riverpod Notifier State Shape

```dart
/// Conceptual state for a paged list
class PagedListState<T> {
  const PagedListState({
    this.items = const [],
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
    this.nextCursor,
    this.hasMore = true,
  });

  final List<T> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;
  final String? nextCursor;
  final bool hasMore;
}
```

Transitions:

| Action | Guards |
|--------|--------|
| `refresh()` | Skip if **initial** loading; optionally allow parallel **refresh epoch** ignoring stale completions |
| `loadMore()` | Require `hasMore && !isLoadingMore && !isInitialLoading` |
| `search(q)` | Reset `items`, `cursor`, **bump epoch** |

---

## 4. In-Flight Request Guard

```text
Key = hash(featureName, serialized(PageRequest without cursor?) + cursor + epoch)
```

- Coalesce: if same key **in flight**, return existing `Future` **or** drop duplicate.
- On filter change: increment **epoch**; ignore completions where `epoch` \< current.

---

## 5. Refresh Behavior

- **Pull-to-refresh:** `isRefreshing = true`, **preserve** prior items until success (optional **stale-while-revalidate**—`docs/NIMON_CACHE_AND_REFRESH_POLICY.md`), then replace.
- **Global tab reselect:** avoid full refetch unless TTL expired or explicit user action.

---

## 6. Load More Behavior

- Trigger at **~70%** scroll extent (tune per list).
- Append only when `hasMore` and no error or user taps **Retry**.

---

## 7. Empty / Error States

| State | UX |
|-------|-----|
| **Initial empty** | Skeleton then empty illustration + CTA per wireframe |
| **Load more empty** | Silent stop (`hasMore = false`) |
| **Error** | Inline banner + retry; keep prior items if not initial |

---

## 8. Search Debounce

- Input stream debounced **200–350 ms** before repository call.
- Cancel previous debounce timer on dispose.
- Each accepted query triggers **new** `PageRequest` with `cursor: null`.

---

## 9. Cancellation / Stale Strategy

**Options (pick one per feature, document in code):**

1. **`CancelToken` / `http.Client` cancel** (if supported end-to-end).
2. **Epoch counter** on notifier—drop completion if `token != currentEpoch` (simplest with `http` package).

Do **not** rely on `BuildContext` alone for cancellation.

---

## Related

- `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`
- `docs/NIMON_CACHE_AND_REFRESH_POLICY.md`
- `ai_prompts/ADD_PAGINATED_LIST_PROMPT.md`
