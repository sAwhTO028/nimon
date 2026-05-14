# M14J-A Public Profile Nested Layout Report

## Problem

The remote public creator profile (`?userId=`) used a single `CustomScrollView` where the header, `TabBar`, and tab content scrolled as one block. That layout does not match the Instagram-style pattern: a collapsing hero header, a **pinned** top toolbar (back + contextual title), a **pinned** tab strip under the toolbar, and **independently scrolling** tab bodies.

## Scope

- **Changed:** Remote `PublicProfileScreen` branch only (`_useRemoteProfile` with loaded `PublicCreatorProfile`).
- **Unchanged:** Backend, public profile APIs, follow logic, mono row cards, pagination loaders, owner `ProfileScreen`, legacy mock `NestedScrollView` path, private Published/Workspace/Saved.

## Layout Architecture

- **`RefreshIndicator`** wraps **`NestedScrollView`** (`ValueKey('publicProfileNestedScrollView')`, same `_publicProfileScrollController` as before for scroll coordination).
- **`headerSliverBuilder`** returns:
  - **`SliverOverlapAbsorber`** + **`SliverAppBar`** (`pinned: true`, **`stretch: false`** since M14J-A8 — Flutter `NestedScrollView` does not support outer `SliverAppBar.stretch`), theme `surface` colors):
    - **`leading`:** `NimonBackButton` (always).
    - **`title`:** `AnimatedOpacity` keyed `publicProfileToolbarUsername` — shows `effectiveDisplayName` when `innerBoxIsScrolled` is true (Flutter `NestedScrollView` inner-body scroll signal).
    - **`flexibleSpace`:** `FlexibleSpaceBar` (`parallax`) — keyed `publicProfileCoverHeader`: **cover image** (`publicProfileCoverBackdrop`) + bottom **`Positioned`** row **`publicProfileHeroOverlayRow`** (**`publicProfileAvatar`** + stats chips). **M14J-A10:** overlay fully **inside** the cover (`bottom: 12`, no negative inset); cover slot **146** px.
    - **`bottom`:** omitted; tabs are not in `SliverAppBar.bottom`.
  - **`SliverToBoxAdapter`** (`ValueKey('publicProfileProfileInfoSliver')`) — compact top spacer for hero clearance (**M14J-A10: 52** px; was **104** in M14J-A9 when overlay extended below cover), identity block, preview or Follow/Share (`publicProfileActionRow` key on the outer action `Padding`).
  - **`SliverPersistentHeader`** (`ValueKey('publicProfilePinnedTabBarHeader')`, `pinned: true`) — **`PublicProfileTabBarHeaderDelegate`** + **`TabBar`** (`ValueKey('publicProfileTabBar')`, same `_tabController`, same `onTap` → collections load on index `1`).
- **`body`:** `TabBarView` with two **`CustomScrollView`** tabs:
  - Each tab: **`SliverPadding`** + **`SliverToBoxAdapter`** wrapping existing **`monoSection()`** / **`collectionsSection()`** (same widgets as M14I; keys `publicProfileMonosList` / `publicProfileCollectionsList`). **`SliverOverlapInjector` removed in M14J-A7** (see follow-up): with profile + pinned `TabBar` **outside** the `SliverOverlapAbsorber` (which wraps only `SliverAppBar`), the injector’s toolbar obstruction stacked spurious top inset (~56 px) on top of intentional padding (~8 px).

Implementation split: `lib/features/profile/public_profile_remote_nested_scroll.dart` holds **`PublicProfileRemoteNestedScroll`**; `public_profile_screen.dart` builds **`coverFlexibleBackground`**, **`profileInfoPanel`**, and tab bodies.

## Toolbar Collapse Behavior

- Collapse is driven by **`NestedScrollView`’s `innerBoxIsScrolled`** flag passed into `headerSliverBuilder`, wired to **`AnimatedOpacity`** on the toolbar title (200 ms ease-out).
- **`expandedHeight`** (M14J-A6 / M14J-A10): **`PublicProfileRemoteNestedScroll.kRemotePublicCoverExpandedTotal`** = **toolbar (56) + cover slot (146)** only (was **168** in M14J-A9, **196** before A9). Profile identity height is **not** part of `SliverAppBar` expansion. Do **not** add `MediaQuery.padding.top` into `expandedHeight` (Flutter already folds status bar into sliver extent).

## Pinned TabBar

- **`TabBar`** is a **separate pinned `SliverPersistentHeader`** after the **`SliverToBoxAdapter`** profile panel, not in **`SliverAppBar.bottom`** (M14J-A5 / A6).
- **Do not** wrap app bar + profile + tabs in **`SliverMainAxisGroup` inside one `SliverOverlapAbsorber`**: that pattern caused the keyed **`TabBar`** to disappear after aggressive inner flings; **sibling slivers** (absorber + app bar, then profile box, then tab header) remain stable.

## Body Scroll Behavior

- Monos / Collections each use **`CustomScrollView`** + **`AlwaysScrollableScrollPhysics`** (with `BouncingScrollPhysics` parent) for pull-to-refresh friendliness and **`PageStorageKey`** per tab.
- **M14J-A7:** Tab bodies **omit** **`SliverOverlapInjector`**; outer **`SliverOverlapAbsorber`** stays on **`SliverAppBar`** only. **`SliverMainAxisGroup`** inside one absorber was **not** used: it tightened overlap math but caused the keyed **`TabBar`** to vanish after aggressive inner flings on Flutter 3.41.x.

## Owner Profile Safety

- No edits to `ProfileScreen` or owner tabs; `m14i_owner_profile_tab_bar_isolation_test.dart` extended to assert absence of **`publicProfileNestedScrollView`** and **`publicProfileTabBar`** on owner profile.

## Tests Added

- `test/features/profile/public_profile_nested_tab_layout_test.dart` — keys, toolbar opacity after inner scroll (tall surface), monos fling smoke, tab switching, dark theme TabBar visibility.
- `test/features/profile/public_profile_nested_visual_regression_test.dart` (M14J-A2) — cover top gap guard, back visibility, transparent TabBar divider + indicator preserved, combined toolbar/tab smoke.
- `test/features/profile/public_profile_gap_and_swipe_load_test.dart` (M14J-A3) — action row vs TabBar spacing, swipe/tap collections load, empty swipe path.
- `test/features/profile/public_profile_header_spacing_test.dart` (M14J-A4) — avatar vs display name spacing, action row vs TabBar gap bounds.
- `test/features/profile/public_profile_header_final_spacing_test.dart` (M14J-A5) — legacy gap / avatar checks (still run).
- `test/features/profile/public_profile_header_final_layout_test.dart` (M14J-A6) — cover-only app bar, profile sliver structure, hard **≤40px** action→TabBar bound on phone surface.
- `test/features/profile/public_profile_final_vertical_gap_test.dart` (M14J-A7) — 390×844 bounds for action→TabBar and TabBar→first mono (8–40 px), scroll/swipe/owner smoke.
- `test/features/profile/public_profile_header_hero_composition_test.dart` (M14J-A8) — hero visibility, seam heuristic, gap bounds, fling TabBar, swipe Collections, owner isolation, dark theme.
- `test/features/profile/public_profile_monos_pagination_test.dart` (**M14J-B**) — public profile monos cursor pagination (limit 10, scroll prefetch, refresh, tab switch).
- `public_profile_collections_tab_test.dart` / `m14i_owner_profile_tab_bar_isolation_test.dart` — key updates to `publicProfileTabBar`.

## Commands Run

- `dart format` on touched Dart paths
- `flutter analyze` on touched paths
- `flutter test test/features/profile` (M14J-B: **196 passed**)

## Manual Verification

1. Open a public profile by `userId`.
2. Scroll monos: header collapses; back stays; display name fades into toolbar; `Monos` / `Collections` strip stays under toolbar.
3. Switch tabs: collections and monos still load as before.
4. Pull to refresh still runs profile + monos + collections reload when implemented on `RefreshIndicator`.
5. Dark / light: tab labels and indicator remain readable.

## Remaining Risks

- **`innerBoxIsScrolled`** reflects inner scroll activity, not pure “pixels of flexible space hidden”; title may appear slightly before/after the visual hero fully clears — acceptable for V1.
- Very long bios: profile panel grows in **`SliverToBoxAdapter`** without fighting **`SliverAppBar.expandedHeight`** (M14J-A6).
- Automated “TabBar Y unchanged while scrolling” checks proved flaky with `NestedScrollView` handoff; tests assert presence + toolbar fade instead of strict geometry.

## M14J-A2 follow-up (visual regression)

Follow-up work removed the large blank band above the public profile cover (flexible header was bottom-aligned in a tall `FlexibleSpaceBar` region) and removed the extra line above the Monos / Collections strip (flexible-header `Divider` + M3 `TabBar` divider / app-bar elevation tint). Details, root causes, and regression tests: [M14J_A2_PUBLIC_PROFILE_VISUAL_REGRESSION_FIX_REPORT.md](./M14J_A2_PUBLIC_PROFILE_VISUAL_REGRESSION_FIX_REPORT.md).

## M14J-A3 follow-up (header gap + swipe load)

Tightened `SliverAppBar.expandedHeight` so it **does not double-count** status bar padding (Flutter already adds `topPadding` to `maxExtent`), modelled the flexible header height to match the real column, added `publicProfileActionRow` for tests, and triggered `_loadPublicCollections()` from the `TabController` listener when the Collections index settles so **swipe** matches **tap**. Loading vs empty state uses `_publicCollectionsLoaded`. Report: [M14J_A3_PUBLIC_PROFILE_GAP_AND_SWIPE_LOAD_FIX_REPORT.md](./M14J_A3_PUBLIC_PROFILE_GAP_AND_SWIPE_LOAD_FIX_REPORT.md).

## M14J-A4 follow-up (header spacing polish)

Final spacing pass: larger gap between cover stack and name block, name column indented past the overlapping avatar, slightly tighter action-row top padding, and a lower `expandedHeight` ceiling so the TabBar sits closer to actions. Keys: `publicProfileAvatar`, `publicProfileNameBlock`, `publicProfileDisplayName`. Report: [M14J_A4_PUBLIC_PROFILE_HEADER_SPACING_FIX_REPORT.md](./M14J_A4_PUBLIC_PROFILE_HEADER_SPACING_FIX_REPORT.md).

## M14J-A5 follow-up (TabBar decoupled from app bar bottom)

Moved **`Monos` / `Collections`** out of **`SliverAppBar.bottom`** into a **pinned `SliverPersistentHeader`** (`PublicProfileTabBarHeaderDelegate`), retuned **`expandedHeight`** to exclude tab height and match the flexible **`Column`**, regrouped identity under the avatar (`publicProfileIdentityBlock`), and added **`public_profile_header_final_spacing_test.dart`**. Swipe-to-Collections loading and owner **`ProfileScreen`** isolation unchanged. Report: [M14J_A5_PUBLIC_PROFILE_HEADER_LAYOUT_FINAL_FIX_REPORT.md](./M14J_A5_PUBLIC_PROFILE_HEADER_LAYOUT_FINAL_FIX_REPORT.md).

## M14J-A6 follow-up (header split — no flex slack)

Moved **avatar / identity / actions** out of **`SliverAppBar`** into a **`SliverToBoxAdapter`** so **`expandedHeight`** models **cover only**; overlap into the cover used **`Transform.translate`** on the avatar row in A6. **`publicProfileActionRow`** key moved to the outer action **`Padding`** for accurate gap tests. Report: [M14J_A6_PUBLIC_PROFILE_HEADER_LAYOUT_REBUILD_REPORT.md](./M14J_A6_PUBLIC_PROFILE_HEADER_LAYOUT_REBUILD_REPORT.md).

## M14J-A7 follow-up (vertical gap final)

Tightened **Follow/Share → TabBar** (**`SizedBox(height: 8)`** after profile column; compact **`Stack`/`Positioned`** overlap instead of full-row **`Transform.translate`**), removed tab-body **`SliverOverlapInjector`** to eliminate the **~64 px** blank between **TabBar** and first mono (injector toolbar obstruction + padding), and added **`public_profile_final_vertical_gap_test.dart`** (390×844, 8–40 px bounds). Report: [M14J_A7_PUBLIC_PROFILE_VERTICAL_GAP_FINAL_FIX_REPORT.md](./M14J_A7_PUBLIC_PROFILE_VERTICAL_GAP_FINAL_FIX_REPORT.md).

## M14J-A8 follow-up (hero composition restore)

Moved **avatar + stats** into **`FlexibleSpaceBar.background`** on the same **`Stack`** as the cover; simplified **`profileInfoPanel`** to identity + actions + trailing spacer with a **layout** top spacer so the headline clears the avatar under `NestedScrollView` geometry; set remote **`SliverAppBar.stretch: false`** ([NestedScrollView](https://api.flutter.dev/flutter/widgets/NestedScrollView-class.html) + stretch caveat). M14J-A7 gap bounds preserved. **M14J-A9 / A10** later retuned overlap, in-cover overlay, cover slot, and spacer (see follow-ups). Report: [M14J_A8_PUBLIC_PROFILE_HERO_COMPOSITION_RESTORE_REPORT.md](./M14J_A8_PUBLIC_PROFILE_HERO_COMPOSITION_RESTORE_REPORT.md).

## M14J-A9 follow-up (hero overlay + cover height tuning)

Reduced **`Positioned`** overlap from **−40** to **−22** px to avoid half-clipped avatar/stats at the flexible seam; shortened **`kRemotePublicCoverImageHeight`** **196 → 168**; retuned identity top spacer to **104** px for `NestedScrollView` rect clearance. Added **`public_profile_hero_overlay_tuning_test.dart`**. Report: [M14J_A9_PUBLIC_PROFILE_HERO_OVERLAY_TUNING_REPORT.md](./M14J_A9_PUBLIC_PROFILE_HERO_OVERLAY_TUNING_REPORT.md).

## M14J-A10 follow-up (hero inside cover — visibility hotfix)

Removed **negative** `Positioned` bottom; hero row uses **`bottom: 12`** fully inside the cover **`Stack`**; **`kRemotePublicCoverImageHeight` 168 → 146**; identity top spacer **104 → 52**; row key **`publicProfileHeroOverlayRow`**; backdrop key **`publicProfileCoverBackdrop`**. Report: [M14J_A10_PUBLIC_PROFILE_HERO_VISIBILITY_HOTFIX_REPORT.md](./M14J_A10_PUBLIC_PROFILE_HERO_VISIBILITY_HOTFIX_REPORT.md).

## M14J-B follow-up (public profile Monos cursor pagination)

Remote **Monos** tab uses **`publicProfileMonosProvider`** (`StateNotifierProvider.autoDispose.family`): **limit 10** initial + load more, **`NotificationListener`** prefetch when **Monos** tab active and `extentAfter <= 600`, bottom spinner for `isLoadingMore`, **`RefreshIndicator`** calls **`refresh`** on monos after profile reload. Hero/header/collections architecture unchanged. Report: [M14J_B_PUBLIC_PROFILE_MONOS_PAGINATION_REPORT.md](./M14J_B_PUBLIC_PROFILE_MONOS_PAGINATION_REPORT.md). Audit: [M14J_B_PUBLIC_PROFILE_MONOS_PAGINATION_AUDIT.md](./M14J_B_PUBLIC_PROFILE_MONOS_PAGINATION_AUDIT.md).

## M14K note (unrelated create-shell failure)

Full-suite noise from **`test/create_shell_parent_child_flow_test.dart`** (quiz strict verification / progress drawer) was **not** caused by M14J public profile work. **M14K** stabilized that test (modal dismiss + drawer settle); see [M14K_CREATE_SHELL_TEST_STABILIZATION_REPORT.md](./M14K_CREATE_SHELL_TEST_STABILIZATION_REPORT.md). **M14J** profile files were not modified for M14K.
