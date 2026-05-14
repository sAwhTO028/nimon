# M14H — Profile Published Monos refresh and sticky sub-tab audit

## Table

| Surface | File | Current scroll owner | Refresh behavior | Provider refresh path | Sticky tab behavior | Required fix | Status |
|--------|------|----------------------|------------------|----------------------|---------------------|--------------|--------|
| Saved tab (remote) | `lib/features/profile/presentation/profile_saved_remote_tab.dart` | `RefreshIndicator` → `ListView.separated` (full tab body) | Pull-to-refresh calls `profileSavedMonoPagerProvider.notifier.refresh()` | `ProfileSavedMonoPager.refresh()` | N/A (no Monos/Collections sub-tabs) | Reference only | OK (unchanged) |
| Saved tab (mock) | `lib/features/profile/profile_screen.dart` → `_FolderGroupList` title `Saved` | Was: `ListView` with filter row as first item | None on mock saved monos list | N/A | Sub-tab scrolled with list | Align with sticky `Column` + `Expanded` for mock folder UI | Done (shared widget) |
| Published > Monos (remote) | `profile_screen.dart` → `_FolderGroupList` | Was: single `ListView` including filter row | **Missing** `RefreshIndicator` | `profilePublishedMonoPagerProvider.notifier.refresh()` | Sub-tab scrolled away | Add `RefreshIndicator`; pin sub-tab outside list | Done |
| Published > Monos (mock) | Same | Was: `ListView` + filter in list | None (compile-time remote off) | N/A | Sub-tab scrolled away | Sticky layout | Done |
| Published > Collections (remote) | `_FolderGroupList` remote branch | `Column` + `Expanded(ListView)` | Retry on error via notifier `load()`; no PTR | `myCreatorCollectionsNotifierProvider` | Already sticky | Keys + sub-tab key for tests | Done |
| Published > Collections (mock folders) | `_FolderGroupList` collections + non-remote | Was: `ListView` + filter in list | None | N/A | Sub-tab scrolled away | Sticky `Column` + `Expanded` | Done |

## Comparisons

### 1. Saved tab list refresh (remote)

- `ProfileSavedRemoteTab` wraps the list in `RefreshIndicator` with `onRefresh` → `profileSavedMonoPagerProvider.notifier.refresh()`.
- Initial load via `_ensureLoaded` → `loadFirstPage()`.
- Loading more at list end.

### 2. Published > Monos refresh (before M14H)

- No `RefreshIndicator`; only `onLooseListNearEnd` → `loadMore()` on the pager notifier.
- `refresh()` existed on `ProfilePublishedMonoPager` and was used from `profileProcessingListRefreshProvider` / other call sites, but not from the Published Monos UI.

### 3. Published > Collections refresh

- Remote: empty/error states offer **Retry** → `myCreatorCollectionsNotifierProvider.notifier.load()`.
- No pull-to-refresh on collections (not required by M14H; avoids refetching collections on every mono refresh).

### 4. Monos / Collections sub-tab scroll placement (before M14H)

- **Monos** and **mock collections**: `_buildFilterOrSelectionBar()` was the first item inside the same `ListView` as rows, so the pill row scrolled away.
- **Remote collections**: already used `Column([filter, Expanded(list)])`, so the row stayed fixed.

## Keys (for tests)

| Key | Widget |
|-----|--------|
| `profilePublishedSubTabRow` | `KeyedSubtree` around Published filter / selection chrome |
| `profilePublishedMonosList` | `KeyedSubtree` around Published Monos scroll stack |
| `profilePublishedCollectionsList` | `KeyedSubtree` around Published collections `ListView` |
| `profilePublishedMonosRefreshIndicator` | `RefreshIndicator` when `onLooseListRefresh` is set and `title == 'Published'` |

## Notes

- `RemoteBackendConfig.useRemoteDrafts` is compile-time; default CI/tests use `false`, so widget tests assert refresh chrome **absent** unless built with `--dart-define=NIMON_USE_REMOTE_DRAFTS=true`.
- Pager `refresh()` behavior under failure is covered by existing `ProfilePublishedMonoPager` tests (`profile_published_pagination_test.dart`).
