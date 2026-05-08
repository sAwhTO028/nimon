# M3c MonoScreen Remote Feed Report

**Date:** 2026-05-03  
**Scope:** Wire Mono Home **For You** to **`monoFeedPagerProvider`** when **`NIMON_USE_REMOTE_MONO_FEED=true`**. Mock feed unchanged when flag is **false**. Backend unchanged.

---

## Files Changed

| Path | Change |
|------|--------|
| `lib/features/mono/mono_feed_models.dart` | **New** — `MonoContentType`, `MonoCoverCategory`, **`MonoFeedItem`** (moved from `mono_screen.dart`) + **`needsRemoteDetailHydration`**. |
| `lib/features/mono/mono_screen.dart` | Remote For You wiring: pager load/refresh/load-more, level → **`setFilters`**, loading/error/empty UI, refresh icon, detail hydration via **`remoteMonoFeedRepositoryProvider`**. |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | Import **`mono_feed_models`** instead of `mono_screen`. |
| `lib/features/profile/data/published_mono_reader_mapper.dart` | Import **`mono_feed_models`** instead of `mono_screen`. |
| `test/features/mono/mono_feed_item_mapper_test.dart` | **New** — summary + detail merge tests. |

---

## Remote Feed Flag Behavior

| Condition | Behavior |
|-----------|----------|
| **`RemoteBackendConfig.useRemoteMonoFeed == false`** | Identical to previous mock Mono Home (**`_mockItems`**, client JLPT filter). |
| **`useRemoteMonoFeed == true`** and **`showTopControls`** and **no** `initialItemOverride` / `initialItemsOverride` | **For You** uses **`GET /v1/mono/feed`** via **`monoFeedPagerProvider`**. |
| Reader-only **`MonoScreen`** (`showTopControls == false`) | Unchanged — uses overrides / mock path only (remote catalog not applied here). |

---

## MonoFeedSummary Mapping

- **`mono_feed_item_mapper.dart`**: **`monoFeedItemFromMonoFeedSummary`**, **`monoFeedItemMergePublishedDetail`** (uses **`published_mono_detail_parser`** helpers for core text / **`MonoContent`**).
- Summary rows set **`needsRemoteDetailHydration: true`** until detail merge.

---

## MonoScreen Loading / Error / Empty States

- **Initial load** (`isInitialLoading && items empty`): centered **`CircularProgressIndicator`**.
- **Error with empty items**: message + **Retry** → **`loadFirstPage()`**.
- **Success with empty items**: **“No published stories yet.”** (or JLPT-specific empty line when filtered).

---

## Level Filter Wiring

- JLPT **`PopupMenuButton`** updates **`_selectedLevel`**.
- When remote: **`_clearRemoteHydration()`**, **`setFilters(level: …)`** where **`All` → `null`**, then **`loadFirstPage()`**.

---

## LoadMore / Refresh Behavior

- **`loadMore()`** when **`PageView`** index ≥ **`length - 2`** and pager **`hasMore`** (near end).
- **Refresh** icon (For You + remote): clears hydration cache + **`monoFeedPagerProvider.refresh()`**.
- Pull-to-refresh **not** added (no existing **`RefreshIndicator`**); refresh control is the toolbar icon.

---

## Reader Detail Fetch Behavior

- **`GET /v1/mono/:id`** via **`remoteMonoFeedRepositoryProvider.fetchMonoDetail`** (public catalog — **not** **`/v1/published-monos`**).
- Runs when the visible item has **`needsRemoteDetailHydration`** (scheduled after feed ready / on page change).
- Success: merge with **`monoFeedItemMergePublishedDetail`** into **`_hydratedRemoteItems`**.
- Failure: **`SnackBar`** with error text.

---

## Following Tab Behavior

- **Unchanged** — still uses **`_followingMockItems`** / existing empty widget when applicable.

---

## Tests Added

| File | Notes |
|------|--------|
| `test/features/mono/mono_feed_item_mapper_test.dart` | Summary mapping + detail merge + hydration flag cleared. |

Full **`MonoScreen`** widget tests **deferred** (heavy UI surface).

---

## Flutter Analyze Result

Command: `flutter analyze` on **`mono_screen.dart`**, **`mono_feed_models.dart`**, **`mono_feed_item_mapper.dart`**, mapper test.

**Result:** Reports **infos/warnings** on `mono_screen.dart` (pre-existing style debt: unnecessary `const`, deprecated `withOpacity`, etc.) plus **`characters` import** infos; **no compile errors**. Mapper test unused-import warning **resolved**.

---

## Flutter Test Result

| Scope | Result |
|-------|--------|
| `flutter test test/features/mono/` | **All passed** (**14** tests including mapper) |
| `flutter test` (full suite) | **All passed** (**115** tests) |

---

## Risks

| Risk | Mitigation |
|------|------------|
| **`build`** schedules detail prefetch when current row still needs hydration | Deduped by **`_detailInflight`** / **`_hydratedRemoteItems`**; may schedule redundant **post-frame** work until hydrated. |
| **Large `mono_screen.dart`** | Logic kept localized; **`MonoFeedItem`** extracted to **`mono_feed_models.dart`** to avoid mapper ↔ screen circular imports. |

---

## Recommended Next Step

**M3d:** Reader polish — sentence-window loading, golden tests on parser, optional pull-to-refresh if product wants gesture parity.

---

## Output Summary

| Question | Answer |
|----------|--------|
| Remote MonoScreen feed wired? | **Yes** (For You + `showTopControls` + flag) |
| Mock path preserved? | **Yes** |
| Level filter wired? | **Yes** (`All` → null) |
| Detail fetch on open wired? | **Yes** (`/v1/mono/:id` + merge) |
| Following tab unchanged/deferred? | **Unchanged mock** |
| Tests passed? | **Yes** |
| `flutter test` passed? | **Yes** (**115**) |
| Next step M3d or fixes? | **M3d** reader verification / UX polish |
