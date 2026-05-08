# P0 Profile Pager Publish Visibility Fix Report

## Files Changed

| File | Change |
|------|--------|
| `lib/features/profile/presentation/providers/profile_workspace_draft_pager.dart` | Pager race fix: mutual exclusion of loading flags, `try/finally` for first page / refresh / conditional `loadMore` cleanup. |
| `lib/features/profile/presentation/providers/profile_published_mono_pager.dart` | Same pager pattern as workspace. |
| `lib/features/profile/profile_screen.dart` | Deferred remote Published `loadFirstPage` to next frame after Workspace first load (cold-open ordering). |
| `lib/features/create/data/remote_story_draft_repository.dart` | `kDebugMode` diagnostics when publish POST is skipped (missing etag); comments that HTTP failures propagate (strict mode). |
| `test/features/profile/profile_workspace_draft_pager_test.dart` | New race regression test. |
| `test/features/profile/profile_published_pagination_test.dart` | New race regression test. |

## Root Cause

1. **Stuck `isInitialLoading`:** `loadFirstPage()` could complete **after** a newer `refresh()` had bumped `requestEpoch`. The stale completion returned early without clearing `isInitialLoading`, while `refresh()` never cleared `isInitialLoading` on entry — leaving the Workspace tab (and similar Published UI) thinking the first load never finished.

2. **Stuck `isRefreshing`:** Symmetric risk when a newer request superseded an in-flight `refresh()` (mitigated by `finally` when epoch still matches).

3. **`loadMore` finally:** Unconditionally clearing `isLoadingMore` could theoretically fight a newer epoch; now cleared only when `requestEpoch` still matches the started operation. Superseding **`refresh()`** clears `isLoadingMore` at start.

4. **Cold-open races:** Workspace and Published `loadFirstPage()` ran back-to-back in `initState`; combined with tab / publish refresh listeners, duplicate epoch contention was more likely. Published first load is deferred one frame.

## Pager Race Fix

- **`loadFirstPage`:** Sets `isRefreshing: false` when starting; **`finally`** clears `isInitialLoading` **only if** `state.requestEpoch == myEpoch` (safe stale completion).
- **`refresh`:** Sets `isInitialLoading: false` when starting (supersedes initial load); **`finally`** clears `isRefreshing` when epoch matches.
- **`loadMore`:** **`finally`** clears `isLoadingMore` only when epoch matches (aligned with superseding `refresh` clearing `isLoadingMore` at refresh start).

## ProfileScreen Refresh Behavior

- **`profileProcessingListRefreshProvider`:** Unchanged — still refreshes Workspace and Published after publish-related bumps (no removal).
- **`_onTabChanged`:** Unchanged logic; pager fixes make tab-triggered refresh safe while an initial load is in flight.
- **Published remote first load:** Scheduled via `WidgetsBinding.instance.addPostFrameCallback` so Workspace `loadFirstPage()` runs first in the first frame, reducing paired races with refresh listeners.

## Published Visibility Verification

- **`RemoteStoryDraftRepository.saveDraft`:** Publish branches already call `await _throwIfNotOk(roResp)` / `flResp` — HTTP failures throw before local domain merge; outer `catch` uses `_fallbackOrThrow`, so **`strictRemoteDrafts`** still surfaces errors instead of treating remote publish as success.
- **Missing If-Match before publish POST:** **Strict:** throws `StateError` (unchanged). **Non-strict:** returns local `persisted` without POST — now emits a **`kDebugMode` only** `developer.log` (draft id + strict flag, no secrets).
- **If-Match / etag retry paths:** Not altered.

## Tests Added

- `ProfileWorkspaceDraftPager`: **`stale loadFirstPage does not leave isInitialLoading true after refresh`**
- `ProfilePublishedMonoPager`: **`stale loadFirstPage does not leave isInitialLoading true after refresh`**

## Flutter Analyze Result

Command:

```bash
flutter analyze lib/features/profile/presentation/providers/profile_workspace_draft_pager.dart lib/features/profile/presentation/providers/profile_published_mono_pager.dart lib/features/profile/profile_screen.dart lib/features/create/data/remote_story_draft_repository.dart
```

**Pager + `remote_story_draft_repository`:** No new issues reported for those files.

**`profile_screen.dart`:** Analyzer reports existing warnings/infos in that large file (e.g. unused imports, deprecated `withOpacity`, unused private helpers). These were **not** addressed in this P0 scope.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/profile` | **Passed** |
| `flutter test test/features/create` | **Passed** |
| `flutter test` (full suite) | **Passed** |

## Remaining Risks

- **Hung HTTP:** If `fetch` never completes, loading flags remain until the request resolves — not addressed (needs timeouts at HTTP layer if desired).
- **Concurrent `loadMore`:** Epoch does not increment on `loadMore`; overlapping `loadMore` calls for the same epoch remain unsupported by design (`canLoadMore` / UX).
- **Non-strict remote:** Skipping publish when etag is missing still returns local success by design; only observability improved via debug logs.

## Recommended Next Step

- **P1:** Furigana / translation pipeline per `docs/M3D_READER_AND_PROFILE_REGRESSION_AUDIT.md` (out of scope for this P0 task).
