# M14J-A2 Public Profile Visual Regression Fix Report

## Problem

After M14J-A introduced the Instagram-style `NestedScrollView` public profile, two visual regressions appeared:

1. A large blank band appeared between the status bar and the cover image; the back control read as floating over empty chrome instead of over the hero header.
2. A faint full-width line appeared directly above the Monos / Collections `TabBar` (in addition to the intended tab indicator).

## Scope

- Remote public profile UI only (`PublicProfileScreen` remote branch, `PublicProfileRemoteNestedScroll`).
- No changes to data loading, pagination, backend, follow logic, routes, owner profile, or tab body content.

## Cover Top Gap Root Cause

The flexible header `Column` was wrapped in `Align(alignment: Alignment.bottomCenter, ...)`. The column uses `mainAxisSize: MainAxisSize.min`, so it only occupies the intrinsic height of the header content while the `FlexibleSpaceBar` allocates the full expanded height. Bottom alignment pinned that short column to the bottom of the flexible region, leaving the entire upper band of the flexible area empty—read as a gap above the cover and shifting perceived toolbar/back placement.

## Cover/Header Fix

- Removed the bottom-align wrapper so the header column is laid out from the **top** of the flexible background again; the cover `Stack` (`ValueKey('publicProfileCoverHeader')`) is the first child and fills from the top of the flexible region.
- Added `ValueKey('publicProfileFlexibleHeader')` on the outer flexible header container for tests and future debugging.
- Did not wrap the cover in `SafeArea(top: true)`; interactive chrome remains the standard `SliverAppBar` leading.

## TabBar Top Line Root Cause

Two sources stacked:

1. A `Divider` (and adjacent spacing) at the **end** of the flexible header sat immediately above `SliverAppBar.bottom`, visually doubling as a “line above tabs.”
2. Material 3 `TabBar` draws a default **full-width divider** when `dividerColor` is non-transparent; combined with `scrolledUnderElevation` / surface tint on the app bar, subtle extra separation could read as an unwanted rule.

## TabBar Line Fix

- Removed the trailing `Divider` / spacer from the flexible header so nothing in the hero stack draws a rule above the pinned tab strip.
- In `PublicProfileRemoteNestedScroll`: `TabBar.dividerColor: Colors.transparent`, `SliverAppBar.scrolledUnderElevation: 0`, `surfaceTintColor: Colors.transparent` (indicator colors unchanged).

## Behavior Preserved

- `NestedScrollView` + `SliverOverlapAbsorber` / injector pairing unchanged.
- Keys: `publicProfileNestedScrollView`, `publicProfileToolbarUsername`, `publicProfileTabBar`, list keys.
- Toolbar display name still fades in via `innerBoxIsScrolled`.
- Tab switching and collections lazy-load on tab tap unchanged.

## Tests Added

- `test/features/profile/public_profile_nested_visual_regression_test.dart`
  - Cover top is not pushed down with a large gap (`publicProfileCoverHeader` vs `MediaQuery.padding.top`).
  - `NimonBackButton` still present.
  - `TabBar.dividerColor` is transparent; `indicatorColor` still set.
  - Smoke: nested keys, toolbar opacity after inner scroll (`ensureVisible` + drag), Collections / Monos tab swap.

## Commands Run

- `dart format` on touched Dart files
- `dart analyze` / `flutter analyze` on touched paths
- `flutter test test/features/profile/public_profile_nested_visual_regression_test.dart`
- `flutter test` (full suite: **577 passed, 1 failed** — failure in `test/create_shell_parent_child_flow_test.dart` “Quiz module strict verification A…”, pre-existing / unrelated to public profile)

## Manual Verification

1. Open a public profile by `userId`.
2. Confirm the cover reaches the top of the hero (no large empty band under the status bar); back reads over the header.
3. Scroll monos: toolbar pins, username fades in, `TabBar` stays pinned.
4. Confirm no extra horizontal rule between the flexible header and Monos / Collections; tab underline/indicator still visible.
5. Switch Collections and back.
6. Quick pass in dark and light themes for contrast.

## Remaining Risks

- Full `flutter test` still reports one unrelated failing test in the create shell suite; profile-focused tests pass.
- `expect(coverTop, lessThan(paddingTop + 96))` is a structural guard against the bottom-align regression, not a pixel-perfect golden; device-specific safe-area differences are bounded by the slack constant.
