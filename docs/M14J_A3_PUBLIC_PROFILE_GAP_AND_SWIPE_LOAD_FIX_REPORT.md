# M14J-A3 Public Profile Gap and Swipe Load Fix Report

## Problem

Two issues remained on device after M14J-A / M14J-A2:

1. **Large vertical gap** between the Follow/Share action row and the Monos / Collections `TabBar`, unlike tighter Instagram-style spacing.
2. **Swipe vs tap on tabs:** Tapping “Collections” loaded public collections, but **swiping** the `TabBarView` to Collections showed “No collections yet.” because the fetch was only triggered from `TabBar.onTap`, not when `TabController.index` changed from a swipe.

## Scope

- Remote public profile (`PublicProfileScreen` + `PublicProfileRemoteNestedScroll`) only.
- No backend, pagination, owner profile, follow/share behavior, routes, or tab body content redesign.

## Header Gap Root Cause

Two factors:

1. **`SliverAppBar.expandedHeight` semantics:** `maxExtent` is `MediaQuery.padding.top + expandedHeight` for a primary app bar (see Flutter `app_bar.dart`). The pre–M14J-A3 formula **added status bar padding into `expandedHeight` again**, inflating the flexible region and leaving empty space above the pinned `TabBar`.
2. **Loose height budget:** The previous `top + 406` style clamp still overshot the real flexible header column height, so the `FlexibleSpaceBar` background slot stayed taller than the header content.

## Header Gap Fix

- **Correct `expandedHeight`:** It must **not** include `MediaQuery.padding.top`; only toolbar + flexible header column + `TabBar` preferred height (+ small tail slack).
- **Analytic flex height:** `_estimatedRemoteFlexColumnHeight(bio)` sums cover stack, spacing, name/handle block, estimated bio height, optional owner-preview bump, and action row — aligned with the actual `Column` children.
- **Tighter chrome:** Slightly reduced padding under the name block and above the action row (`publicProfileActionRow` keyed row).
- **Clamp:** `expandedHeight` clamped to `[toolbar + tabBar + 260, 560]` to avoid overflow on small phones while removing the large blank band.

## Swipe Tab Load Root Cause

`RemotePublicProfile` collections were loaded only from `onTabBarTap` in `PublicProfileRemoteNestedScroll`. A horizontal swipe updates `TabController.index` without necessarily firing `onTap` the same way, so `_loadPublicCollections()` never ran.

## Swipe Tab Load Fix

- In `_onPublicProfileTabTick` (already registered on `_tabController`), when `_useRemoteProfile && _remoteProfile != null` and `!indexIsChanging && index == 1`, call `unawaited(_loadPublicCollections())` — same path as tap, after the swipe animation settles.

## Loading vs Empty State

- Added `_publicCollectionsLoaded` set to `true` only after a **successful** `fetchPublicCollections`.
- `_loadPublicCollections({bool force = false})` skips duplicate fetches when already loaded unless `force` (pull-to-refresh / retry).
- `collectionsSection()` while `!_publicCollectionsLoaded`: shows **spinner** (or error + retry), never “No collections yet.” until the first successful load completes with an empty list.
- Profile reload clears collections state and `loaded` flag so a new `userId` refetches cleanly.
- Retry / `RefreshIndicator` use `force: true`.

## Tests Added

- `test/features/profile/public_profile_gap_and_swipe_load_test.dart`
  - Action row → `TabBar` gap bound (`publicProfileActionRow` vs `publicProfileTabBar`).
  - Swipe to Collections with data: `fling` on `TabBarView`, no premature “No collections yet.”, then title visible.
  - Tap Collections still loads.
  - Swipe with empty mock: empty copy after settle.

## Commands Run

- `dart format` on touched Dart files
- `flutter analyze` / `dart analyze` on `lib/features/profile/public_profile_screen.dart`
- `flutter test test/features/profile` (pass)
- `flutter test` (full suite: **581 passed, 1 failed** — `test/create_shell_parent_child_flow_test.dart` “Quiz module strict verification A…”, documented as unrelated)

## Manual Verification

1. Open public profile (`userId`): cover to top edge (M14J-A2), no extra line above tabs (M14J-A2).
2. Confirm Follow/Share sit closer to Monos / Collections than before M14J-A3.
3. Swipe Monos → Collections: collections load; no false empty state while loading.
4. Swipe back; tap Collections: same data behavior.
5. Profile with no collections: after load, “No collections yet.” only after spinner.
6. Pull refresh still reloads collections with `force: true`.
7. Dark / light quick pass on tab labels.

## Remaining Risks

- `expandedHeight` is **modelled**, not measured at runtime; very long bios or future header widgets may need constant tweaks or a safe remeasurement strategy that respects `SliverAppBar`’s `topPadding + expandedHeight` contract.
- Full `flutter test` still reports one unrelated failure in the create shell suite.
