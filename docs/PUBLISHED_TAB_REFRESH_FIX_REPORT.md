# Published Tab Refresh Fix Report

**Date:** 2026-05-02  
**Issue:** Profile → Published stayed stale after remote publish until reload/restart.  
**Reference:** [PUBLISHED_TAB_MISSING_AFTER_PUBLISH_DEBUG_REPORT.md](PUBLISHED_TAB_MISSING_AFTER_PUBLISH_DEBUG_REPORT.md)

## Files Changed

| File | Change |
|------|--------|
| `lib/features/profile/profile_screen.dart` | On `profileProcessingListRefreshProvider`, also **`refresh()`** `profilePublishedMonoPagerProvider` when `RemoteBackendConfig.useRemoteDrafts`. On **`_onTabChanged`**, when Published tab (**index 0**) is selected and remote drafts on, **`refresh()`** published pager if not **`isInitialLoading`** / **`isRefreshing`**. |
| `README.md` | Clarified **`NIMON_DEV_OWNER_ID`** vs backend **`DEV_OWNER_ID`** for Published list visibility. |
| `docs/DEV_RUN_COMMANDS.md` | Short subsection: owner id alignment for **`GET /v1/published-monos`**. |
| `docs/PUBLISHED_TAB_REFRESH_FIX_REPORT.md` | This report. |

## Root Cause

`profileProcessingListRefreshProvider` (bumped after publish via `StoryCreatorDraftNotifier`) only triggered **`profileWorkspaceDraftPagerProvider.refresh()`**. **`profilePublishedMonoPagerProvider`** was loaded once in `initState` and never refreshed on that signal, so the Published list did not refetch **`GET /v1/published-monos`** after a new **`PublishedMono`** was created.

## Fix Applied

1. **Same listener** as Workspace: after each processing-list refresh tick, if **`useRemoteDrafts`**, **`unawaited(ref.read(profilePublishedMonoPagerProvider.notifier).refresh())`**.
2. **Tab focus:** When the user selects the Published tab (**TabController index 0**), **`refresh()`** the published pager unless it is already doing **initial load** or **refresh** (avoids stacking requests with `initState`’s `loadFirstPage`).

Workspace tab behavior (**index 1** refresh) is **unchanged**.

## Published Pager Refresh Behavior

- **After publish:** Processing refresh runs → Workspace + Published pagers both **`refresh()`** (Published only in remote mode).
- **On Published tab tap:** Extra **`refresh()`** when not busy, so returning to the tab picks up server changes even if the listener was missed.

## Tab Focus Refresh Behavior

- **Index 0 (Published):** Conditional **`refresh()`** as above.
- **Index 1 (Workspace):** Existing **`profileWorkspaceDraftPagerProvider.refresh()`** only — **unchanged**.

## Tests Added

**No new tests.** `ProfilePublishedMonoPager.refresh()` is already covered in **`test/features/profile/profile_published_pagination_test.dart`** (`refresh resets and replaces items`, epoch behavior). **`ProfileScreen`** wiring is not unit-tested here (would require pumping the full Profile shell or extracting the listener; out of scope for this targeted fix).

## Flutter Analyze Result

- **`flutter analyze`:** Completed with **227** issues (mostly existing `info` / `warning`). **No `error`-severity diagnostics** in the analyzer output for this run (exit code **1** due to non-zero issue count).

## Flutter Test Result

- **`flutter test`:** **All tests passed** (**87** tests, exit code **0**).

## Risks

1. **Extra GETs:** Selecting Published tab may trigger **`refresh()`** more often; acceptable tradeoff for correctness.
2. **Double refresh** after publish (listener + possible tab event) may cause duplicate **`GET /v1/published-monos`** in quick succession; low impact.
3. **Owner mismatch** still yields an empty list; documented in README / `DEV_RUN_COMMANDS.md` (not a code bug).

## Recommended Next Step

Manual smoke: remote draft mode → publish Read Only → confirm Published tab shows the new row **without** app restart. Optionally add an integration test later if a lightweight Profile harness is introduced.
