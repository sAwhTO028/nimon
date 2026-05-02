# Pagination Foundation Report

**Purpose:** Introduce shared, UI-agnostic pagination types aligned with `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`, `docs/NIMON_API_QUERY_CONTRACT.md`, and performance/cache docs—**without** wiring into `StoryRepo`, screens, or routing.

---

## Files Created

| Path | Role |
|------|------|
| `lib/core/pagination/pagination_defaults.dart` | Central numeric defaults (limits, debounce). |
| `lib/core/pagination/page_request.dart` | Immutable cursor request + `toQueryParameters` + `copyWith`. |
| `lib/core/pagination/page_result.dart` | Immutable generic page envelope + `empty`, `map`, `append`. |
| `lib/core/pagination/paginated_state.dart` | Immutable generic list UI state + helpers + `copyWith`. |
| `test/core/pagination/page_request_test.dart` | Unit tests for `PageRequest`. |
| `test/core/pagination/page_result_test.dart` | Unit tests for `PageResult`. |
| `test/core/pagination/paginated_state_test.dart` | Unit tests for `PaginatedState`. |

---

## Public Types Added

- **`PaginationDefaults`** — `abstract final class` with `const` static fields (`defaultPageLimit`, `minPageLimit`, `maxPageLimit`, `searchDebounceMs`, `feedFirstPageLimit`, `profilePageLimit`, `workspacePageLimit`).
- **`PageRequest`** — immutable request: `cursor`, clamped `limit`, non-null `sort` (default **`latest`**), optional filters, `updatedAfter`; **`toQueryParameters()`**; **`copyWith`** with null-safe cursor clearing.
- **`PageResult<T>`** — `items`, `nextCursor`, `hasMore`, `totalCount`; **`PageResult.empty()`**, **`map`**, **`append`**.
- **`PaginatedState<T>`** — list + cursor + loading flags + `error` + **`requestEpoch`**; **`PaginatedState.initial()`**; **`copyWith`**; getters **`canLoadMore`**, **`isBusy`**, **`isEmpty`**, **`hasError`**.

---

## Behavior Covered

| Area | Behavior |
|------|------------|
| **Limits** | Default limit from **`PaginationDefaults.defaultPageLimit`**; constructor clamps to **[min, max]** inclusive. |
| **Sort** | Non-null **`String`**, default **`latest`**. |
| **Query map** | Omits null / empty string values; always emits **`limit`** and **`sort`**; **`updatedAfter`** as **UTC ISO-8601**. |
| **PageResult** | **`append`** concatenates items, adopts trailing **`nextCursor`** / **`hasMore`**, prefers **`next.totalCount`** when set. |
| **PaginatedState** | **`canLoadMore`** requires **`hasMore`** and no busy / initial-load / refresh / error blocking; **`isEmpty`** is empty items and not initial loading. |

---

## Tests Added

**17** new tests across three files (defaults, clamping, query omission, ISO date, `copyWith`, `PageResult.empty` / `map` / `append`, `PaginatedState.initial`, `canLoadMore`, `isBusy`, `isEmpty`, `hasError`, `requestEpoch`).

**Full suite:** **`flutter test`** → **53** tests, **all passed** (36 existing + 17 new).

---

## Flutter Analyze Result

| Metric | Result |
|--------|--------|
| **Error-severity issues** | **0** |
| **Total issues** | **225** (project baseline; no warning sweep) |

---

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test` | **All tests passed** (**53**). |

---

## Risk Notes

- **`PageResult.append`** returns a **new** unmodifiable list; callers must not assume in-place mutation of the original **`items`** reference.
- **`PageRequest.copyWith`** uses a private sentinel for nullable fields so **`cursor: null`** clears the cursor.
- **`PaginatedState.copyWith`** uses a sentinel for **`nextCursor`** and **`error`** so explicit **`null`** can clear them.

---

## Recommended Next Step

- Add **`fetch*Page(PageRequest)`**-style methods on **remote** repositories when backends are ready, mapping **`toQueryParameters()`** to HTTP; keep **`StoryRepo`** legacy **`List<T>`** until a migration tranche is approved.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Files created** | **4** library files + **3** test files + **`docs/PAGINATION_FOUNDATION_REPORT.md`**. |
| **Tests added** | **17** (in `test/core/pagination/`). |
| **`flutter analyze` 0 errors?** | **Yes** |
| **`flutter test` passed?** | **Yes** (**53**/53) |
| **Recommended next step** | Wire repositories / notifiers to **`PageRequest` / `PageResult` / `PaginatedState`** in a dedicated migration PR after API contracts are fixed per surface. |
