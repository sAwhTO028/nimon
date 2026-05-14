# M14J-A7 Public Profile Vertical Gap Final Fix Report

## Problem

After M14J-A6 split the remote public profile header into separate slivers (cover-only `SliverAppBar`, profile `SliverToBoxAdapter`, pinned `TabBar` `SliverPersistentHeader`, `TabBarView` bodies), the phone layout still showed **large vertical dead zones**:

1. Too much space between the **Follow/Share** row and the **Monos / Collections** `TabBar`.
2. Too much space between the **`TabBar`** and the **first mono row**.

The screen felt vertically stretched despite the overall architecture being correct.

## Scope

- **In scope:** UI layout only in the remote public profile branch (`PublicProfileRemoteNestedScroll`, `PublicProfileScreen` remote `profileInfoPanel`, monos/collections tab `CustomScrollView` slivers), widget tests under `test/features/profile/`, and M14J documentation.
- **Out of scope (unchanged):** Backend, providers, collection loading, `TabController` listener, swipe-to-Collections loading fix, pagination, routes, follow/share logic, mono/collection row data, owner `ProfileScreen`, validation/localization, unrelated create-shell tests.

## Gap Sources Found

### 1. Action row bottom → TabBar top

| Source | Role |
|--------|------|
| `Padding` on `publicProfileActionRow` (`fromLTRB(16, 12, 16, 8)`) | Bottom inset on the action row. |
| **Missing** explicit spacer after the profile column | With adjacent slivers, `getRect(actionRow).bottom` could sit flush with `TabBar` top (`gap` ≈ 0 vs tests requiring ≥ 8 px). |
| M14J-A6 **`Transform.translate(0, -40)`** on the whole avatar/stats row | Reserved **full row height** in the column while painting the row 40 px higher, leaving a **non-visual band** (~52 px) between avatar bottom and headline in layout metrics. |

### 2. TabBar bottom → first mono row top

| Source | Role |
|--------|------|
| **`SliverOverlapInjector`** in each tab `CustomScrollView` | Injects overlap from the paired `SliverOverlapAbsorber` on **`SliverAppBar` only**. The handle reports **`maxScrollObstructionExtent`** of the pinned toolbar (~56 px). The inner list already starts **below** the outer header (profile + pinned `TabBar`), so this behaved like **extra** top inset. |
| `SliverPadding` `top: 8` on the tab body | Intended breathing room; stacked on top of injector → ~**64 px** total on a 390×844 surface. |
| **`SliverMainAxisGroup`** (absorber wrapped AppBar + profile + TabBar) | Corrected overlap accounting for the TabBar gap in theory, but on Flutter 3.41.x caused the keyed **`TabBar`** to **disappear from the tree** after aggressive inner flings (regression vs `public_profile_nested_tab_layout_test`). **Reverted** for stability. |

## Root Cause (summary)

1. **Action ↔ TabBar:** Needed a small **explicit** gap after the profile column; avatar overlap should not rely on **`Transform.translate`** for the full row (layout height vs paint).
2. **TabBar ↔ first mono:** **`SliverOverlapInjector`** was **misaligned** with this header split: obstruction from the **absorbed `SliverAppBar`** did not match what actually overlaps the inner tab viewport once profile + pinned `TabBar` live **outside** the absorber, producing a large blank band.

## Action Row to TabBar Fix

- Added **`const SizedBox(height: 8)`** after the profile `Column` children (after the owner-preview / action `Padding` branch) so **action `Padding` bottom → `TabBar` top** is **8 px** of neutral spacer (within the 8–32 px target, hard max 40 px).
- Replaced **`Transform.translate`** on the avatar/stats row with a **`Stack`** (`clipBehavior: Clip.none`): a **`SizedBox(height: 40)`** sets compact stack height; **`Positioned(top: -40, …)`** draws the avatar row overlapping the cover **without** reserving 80 px of empty column space below the paint.
- Increased the spacer after the stack from **12 → 14 px** so **avatar → display name** vertical gap meets existing **≥ 8 px** tests while staying tight.

## TabBar to First Content Fix

- **Removed `SliverOverlapInjector`** from both remote tab `CustomScrollView` lists. **`SliverOverlapAbsorber`** remains on **`SliverAppBar`** only (required `NestedScrollView` wiring). Monos/collections bodies now start with **`SliverPadding`** only (`top: 8`, horizontal 16, bottom safe area + 24).
- Kept **`ValueKey('publicProfileFirstMonoRow')`** on the first mono list `Padding` (remote monos list).

## Spacing Measurements (widget tests)

- **`test/features/profile/public_profile_final_vertical_gap_test.dart`** uses **390×844** for gap tests.
- **Action row → TabBar:** `gap` in **[8, 40]** px.
- **TabBar → first mono row:** `gap` in **[8, 40]** px (no injector stack-up).
- **`flutter test test/features/profile`:** all passed after these changes.

## Behavior Preserved

1. Cover reaches the top / status area (`SliverAppBar` + `expandedHeight` unchanged).
2. Back button visible/tappable.
3. Avatar and identity block do not overlap; spacing within prior test bands.
4. Toolbar username fades in after inner scroll (`innerBoxIsScrolled`).
5. `TabBar` remains pinned; **no** `SliverMainAxisGroup` regression (TabBar survives fling).
6. Monos tab works; Collections tab works.
7. Swipe Monos → Collections still loads data (`_FakeCollRepo` in gap test).
8. Owner `ProfileScreen` does not expose public `TabBar` keys.
9. No extra divider line above the `TabBar` (`dividerColor: Colors.transparent` unchanged).

## Tests Added / Updated

- **`test/features/profile/public_profile_final_vertical_gap_test.dart`:** bounded gaps (≥ 8, ≤ 40), combined min/max, TabBar visible after fling, swipe Collections, owner isolation.
- **`ProviderScope` swipe test:** `overrides` list closed with `],` before `child:` (syntax fix).

## Commands Run

- `dart format` on touched Dart files.
- `flutter analyze lib/features/profile/public_profile_screen.dart lib/features/profile/public_profile_remote_nested_scroll.dart test/features/profile/public_profile_final_vertical_gap_test.dart`
- `flutter test test/features/profile`
- `flutter test` → **599 passed, 1 failed** — failure in `test/create_shell_parent_child_flow_test.dart` (`creator_progress_drawer` not found); **unrelated** to public profile (per project norm / user Part J).

## Manual Verification (checklist)

1. Open public profile (`userId`).
2. Follow/Share row sits close above Monos/Collections `TabBar` (~8 px spacer + padding).
3. First mono row sits close under `TabBar` (~8 px `SliverPadding` top).
4. Scroll: toolbar title appears; `TabBar` stays pinned.
5. Swipe to Collections: data loads; return to Monos: list still visible.
6. Light/dark smoke on tab labels.

## Remaining Risks

- **No `SliverOverlapInjector`:** Flutter docs note that omitting the injector can let inner content slide **under** a floating/absorbing header in some configurations. Here the inner viewport is chiefly below **pinned** outer chrome; **`flutter test`** nested-scroll coverage still passes. If a future header becomes **floating**, revisit **absorber scope** vs injector or adopt a framework-supported merged header pattern that does not break `TabBar` presence.
- **`Stack` + `Positioned`:** relies on `clipBehavior: Clip.none`; very long localized strings in the stats row could theoretically paint into neighbors (unchanged risk vs translated row).

## Part K — Output Summary

| Question | Answer |
|----------|--------|
| Action row → TabBar gap source found? | **Yes:** missing explicit spacer; action padding alone could yield 0 px; profile column structure. |
| TabBar → first content gap source found? | **Yes:** **`SliverOverlapInjector`** (~toolbar obstruction) + **`SliverPadding` top 8**; attempted **`SliverMainAxisGroup`** also broke NestedScrollView TabBar stability. |
| Action row → TabBar gap ≤ 40 px? | **Yes** (~8 px spacer + existing padding, within tests). |
| TabBar → first mono gap ≤ 40 px? | **Yes** (injector removed; 8 px top padding only). |
| Hidden transform / layout height removed? | **Yes** — **`Stack`/`Positioned`** replaces full-row **`Transform.translate`**. |
| TabBar delegate compact? | **Yes** — `minExtent == maxExtent == 48` (`PublicProfileTabBarHeaderDelegate`). |
| Mono list top padding compact? | **Yes** — `SliverPadding` top **8**. |
| Cover top preserved? | **Yes**. |
| Pinned TabBar preserved? | **Yes** (reverted unstable `SliverMainAxisGroup`). |
| Swipe Collections load preserved? | **Yes** (tests). |
| Owner profile unaffected? | **Yes** (isolation test). |
| Profile tests passed? | **Yes** (`flutter test test/features/profile`). |
| Full Flutter test result? | **599 passed, 1 failed** — `create_shell_parent_child_flow_test.dart` only (**unrelated**). |
