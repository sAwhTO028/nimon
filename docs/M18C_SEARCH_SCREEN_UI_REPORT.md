# M18C — V1 Search screen UI and shell entry (report)

This report documents **M18C**: the Mono **Search** screen wired to `monoSearchNotifierProvider`, shell entry from the Mono top bar, localization, and widget tests.

---

## Route and entry

| Item | Detail |
|------|--------|
| **Route** | `GET` path in app router: **`/mono/search`** (existing `GoRoute` in `lib/main.dart`). |
| **Screen widget** | `MonoSearchScreen` in `lib/features/mono/mono_search_screen.dart`. |
| **Entry** | Mono home top bar **search** icon (`Icons.search_rounded`) → `context.push('/mono/search')` (`lib/features/mono/mono_screen.dart`). Tooltip uses `AppLocalizations.searchTitle` when l10n is available, else **`Search`**. |

---

## Layout

- **AppBar:** title `searchTitle` (**Search**), back via `NimonBackButton`, optional **clear all** (`Icons.clear_all_rounded`) when query or any filter is active.
- **Search field:** `TextField` with `searchInputHint`, debounced via notifier `setQuery`.
- **Level row:** label `searchLevelLabel`; horizontal `FilterChip`s — **All** + `N5`…`N1` from `MonoSearchCatalogFacets.jlptLevels` (`lib/features/search/mono_search_catalog_facets.dart`, aligned with `CreateStoryBasicsForm`).
- **Category row:** label `searchCategoryLabel`; **All** + story categories from the same facet list.
- **Sort:** read-only **`Latest`** chip (`Chip` + `searchLatest`) — no Popular in V1.
- **Results:** `ListView.separated` with `RefreshIndicator`; rows use **`MonoStoryListRow`** + a compact writer / **♥ likes** line; tap opens **`/mono-reader`** with `MonoReaderMenuOrigin.publicCreatorProfile` and the **full current result set** as `MonoFeedItem`s via **`monoFeedItemFromMonoSearchResult`** (`lib/features/mono/data/mono_feed_item_mapper.dart`).

---

## Behavior

| Topic | Behavior |
|--------|------------|
| **Idle / marketing** | If **trimmed `q` is empty** and **no level/category**, the notifier **does not call** the API (`MonoSearchNotifier._shouldFetchRemote`); `hasEverFetched` stays false → marketing copy (`searchInitialTitle` / `searchInitialBody`). |
| **Latest with filters only** | Choosing **level** or **category** (or non-empty `q`) triggers **`GET /v1/search/monos`** with `sort=latest` (and optional empty `q` when only filters). |
| **Clear** | Clears text field + `clearFilters()` on notifier. |
| **Pagination** | `NotificationListener` + near-end threshold (same pattern as Saved tab); `loadMore` debounced; footer `CircularProgressIndicator` only while `isLoadingMore`; hidden when `hasMore` is false. |
| **Double dispose** | Removed redundant `ref.onDispose(notifier.dispose)` from `monoSearchNotifierProvider` (Riverpod already disposes `StateNotifier`); avoids **double `dispose`** in tests and at runtime. |

---

## Localization (EN / JA / MY)

New ARB keys in `lib/l10n/app_en.arb`, `app_ja.arb`, `app_my.arb`:

`searchTitle`, `searchInputHint`, `searchInitialTitle`, `searchInitialBody`, `searchNoResultsTitle`, `searchNoResultsBody`, `searchRetry`, `searchAll`, `searchLatest`, `searchClearFiltersTooltip`, `searchErrorTitle`, `searchLevelLabel`, `searchCategoryLabel`.

Regenerate: `flutter gen-l10n`.

---

## Tests

| Area | File |
|------|------|
| Search UI | `test/features/search/mono_search_screen_test.dart` — debounce, chips, marketing / empty / error+retry, reader navigation, guest, dark theme contrast, scroll `loadMore`, no spinner when `hasMore` false. |
| Shell entry | `test/ui/shell/mono_search_shell_entry_test.dart` — push `/mono/search`, marketing copy visible. |
| Mapper | `test/features/mono/mono_feed_item_mapper_test.dart` — `monoFeedItemFromMonoSearchResult` social fields. |
| Reader tests | `m14i_mono_reader_creator_footer_navigation_test.dart` — `MaterialApp` now includes **AppLocalizations** so `MonoScreen` can use l10n safely. |
| Static grep | `mono_screen_refresh_icon_removed_test.dart` — asserts search tooltip references **`searchTitle`**. |

**Commands:** `dart format` on touched files; `flutter test test/features/search`, `test/features/mono`, `test/ui/shell`, full `flutter test` — all **passed**.

---

## Phone acceptance (manual)

1. Open **Mono** → tap **search** → land on **Search** with marketing copy.  
2. Type a keyword → after debounce, results or empty state.  
3. Tap **N5** / **Horror** → list reloads from page 1.  
4. Tap a row → **reader** opens; swipe within reader uses the pushed list.  
5. Scroll to bottom → more rows load when `hasMore`.  
6. Guest: no sign-in wall on Search.  
7. Dark mode: titles and body copy remain readable.

---

## Follow-ups (optional)

- Wire **clear** icon behavior with OS **IME clear** if needed.  
- Consider **non–autoDispose** search notifier if product wants to **retain** last query when popping (trade-off vs memory).

---

## Related

- `docs/M18A_BACKEND_SEARCH_ENDPOINT_REPORT.md`  
- `docs/M18B_FLUTTER_SEARCH_DATA_LAYER_REPORT.md`  
- `docs/M18_V1_SEARCH_AND_FILTER_PLAN.md`
