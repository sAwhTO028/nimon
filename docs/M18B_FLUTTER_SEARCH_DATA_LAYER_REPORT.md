# M18B — Flutter search data layer and pagination state (report)

This report documents the **M18B** client work: models, `GET /v1/search/monos` repository, Riverpod notifier + state, and tests. **No full search UI** (M18C).

---

## Endpoint (backend recap)

`GET /v1/search/monos?q=&level=&category=&sort=latest&limit=20&cursor=`

Response envelope:

```json
{
  "items": [],
  "hasMore": true,
  "nextCursor": "...",
  "totalCount": 0
}
```

---

## Data model

| Piece | Location | Notes |
|--------|----------|--------|
| **Row DTO** | `lib/features/search/data/mono_search_result.dart` | Wraps `PublishedMonoListItemDto` from `published_mono_dto.dart` (same JSON as catalog list rows) plus `likesCount`, `isBookmarkedByMe`, `myReaction`. Getters expose `id`, `ownerId`, `title`, `category`, `level`, `description`, `coverImageUrl`, `targetDurationLabel`, writer fields, `shareUrl`. |
| **Remote contract** | `lib/features/search/data/mono_search_remote.dart` | Abstract `searchMonos` for tests and DI. |
| **Paginated alias** | `lib/core/pagination/page_result.dart` | `typedef PaginatedPage<T> = PageResult<T>` for naming parity with the API spec. |

---

## Repository

| Item | Detail |
|------|--------|
| **Class** | `RemoteMonoSearchRepository` in `lib/features/search/data/remote_mono_search_repository.dart` |
| **Implements** | `MonoSearchRemote` |
| **HTTP** | `GET {apiBaseUrl}/v1/search/monos` with query params: `q`, `level`, `category`, `sort`, `limit`, `cursor` (omitted when empty). |
| **Auth** | Optional `authHeaderBuilder` merged into headers; `nimonSendWithOptional401Recovery` when `sendWithAuth401Recovery` is supplied (same pattern as profile published repo). Guests omit `Authorization`. |
| **Limit** | Clamped to `PaginationDefaults.minPageLimit`–`maxPageLimit` (1–50). |
| **Parsing** | Reads `items`, `hasMore` / `has_more`, `nextCursor` / `next_cursor`, `totalCount` / `total_count`; maps each item with `MonoSearchResult.fromBackendJson`. |
| **Errors** | Non-2xx → `StateError`; on thrown errors, if `RemoteBackendConfig.strictRemoteDrafts` is false, returns `PaginatedPage.empty()` (aligned with other remote list repos). |

---

## Provider / notifier

| Item | Detail |
|------|--------|
| **State** | `MonoSearchState` in `mono_search_state.dart`: `query`, `selectedLevel`, `selectedCategory`, `sort`, `items`, `isLoadingFirstPage`, `isLoadingMore`, `error`, `hasMore`, `nextCursor`, `totalCount`, `requestEpoch`. |
| **Notifier** | `MonoSearchNotifier` in `mono_search_notifier.dart` |
| **Providers** | `remoteMonoSearchRepositoryProvider`, `monoSearchNotifierProvider` (`StateNotifierProvider.autoDispose`) in `mono_search_providers.dart` |
| **Debounce** | `setQuery` uses `PaginationDefaults.searchDebounceMs` (default 250 ms). `setQueryAndReload` applies text and loads immediately. |
| **Filters** | `setLevel`, `setCategory`, `setSort` cancel debounce and reload the first page. |
| **Pagination** | `refresh` / first load clear `items`, `nextCursor`, `hasMore`, `totalCount`, then fetch. `loadMore` uses current cursor; appends items **deduped by mono `id`**. |
| **`canLoadMore`** | `hasMore` and non-empty `nextCursor`, not loading, no `error` (matches conservative “no load-more while errored” behavior). |
| **Spinners** | `isLoadingFirstPage` / `isLoadingMore` cleared in `finally` where applicable so errors do not leave loaders stuck. |

---

## Tests

| Suite | Path |
|--------|------|
| Repository | `test/features/search/remote_mono_search_repository_test.dart` — query string, parsing, guest, auth header, limit clamp. |
| Notifier | `test/features/search/mono_search_notifier_test.dart` — first load, query/level/category resets, `loadMore` append/dedupe, error + spinner, `hasMore=false` no extra call, debounce, viewer fields. |

**Commands run:** `dart format` on touched files; `flutter test test/features/search`; `flutter test test/features/mono`; `flutter test` (full suite).

---

## Remaining work (M18D+)

- **Polish:** IME / keyboard search action, analytics, empty-state art.
- **Optional:** Retain search state across pops (notifier lifecycle).

~~**M18C — Search UI:**~~ **Done** — see `docs/M18C_SEARCH_SCREEN_UI_REPORT.md`.
- **Sort:** V1 backend is latest-only; client `setSort` exists for forward compatibility if the API adds sorts later.
- **Deep links / analytics:** optional, out of M18B scope.

---

## Related docs

- `docs/M18A_BACKEND_SEARCH_ENDPOINT_REPORT.md`
- `docs/M18_V1_SEARCH_AND_FILTER_PLAN.md`
