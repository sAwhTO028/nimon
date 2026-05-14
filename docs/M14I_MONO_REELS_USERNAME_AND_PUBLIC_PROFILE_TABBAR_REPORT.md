# M14I Mono Reels Username and Public Profile TabBar Report

## Problem

V1 QA requested two follow-ups: (1) Mono Reels reader footer should open the same public creator profile when tapping the writer display name as when tapping the avatar, without changing follow behavior or widening accidental taps. (2) The learner-facing public profile should use a standard Flutter `TabBar` for **Monos** / **Collections** instead of a custom segmented control, for accessibility and consistency, while preserving existing loading, empty states, and routing by `userId`.

## Scope

- **In scope:** Mono reader footer creator row (username + avatar + follow), `PublicProfileScreen` remote (`userId`) branch Monos/Collections selector, widget tests, this report.
- **Out of scope:** Backend and public profile APIs, follow/unfollow logic, owner `ProfileScreen` Published / Workspace / Saved tabs, private published Monos/Collections behavior, Mono footer layout beyond making the username tappable, legacy handle/creator query routing, `NestedScrollView` mock-only public profile path (already used `TabBar`).

## Mono Reels Username Navigation

- **Avatar:** Existing `InkWell` / `onTapCreator` path unchanged; wrapped with `Semantics` (button, “View creator profile”) and `ValueKey('monoReaderCreatorAvatar')` on the `Material` for tests.
- **Username:** Same `onTapCreator` callback; `InkWell` with minimal padding, matching text style, `Semantics` + `ValueKey('monoReaderCreatorUsername')`. When `writerId` is missing, `onTapCreator` is null (same as avatar: no navigation, no crash).
- **Follow:** `ValueKey('monoReaderFollowButton')` on the follow control container; tap handling unchanged.

Implementation: `lib/features/mono/mono_screen.dart` (`_PostFooterMeta`, `_FooterFollowButtonState`).

## Public Profile TabBar

### Audit (pre-change)

- **Selector:** Remote public profile used a `SegmentedButton` with key `public_profile_mono_collections_segments` to switch between Monos and Collections body sections.
- **Target:** Replace with `TabBar` + existing `TabController` (`length: 2`), key `publicProfileMainTabBar`, placed under the header/stats/bio block (still inside the same `CustomScrollView` / sliver structure).
- **Providers:** Unchanged — `remotePublicCreatorProfileRepositoryProvider`, `remoteCreatorCollectionsRepositoryProvider`, same `_loadPublicCollections()` trigger on Collections tab tap (`onTap` index `1`).
- **Scroll behavior:** Outer `CustomScrollView` + `ScrollController` for header measurement and pinned-tab safe area unchanged; body remains a `SliverToBoxAdapter` switching between `monoSection()` and `collectionsSection()` based on `_tabController.index`. No nested `TabBarView` in the remote path (avoids nested primary scroll conflicts with the existing pull-to-refresh architecture).

### Implementation notes

- `_tabController.addListener(_onPublicProfileTabTick)` forces rebuild on swipe/index change so the sliver body matches the selected tab.
- Theme: `labelColor` / `unselectedLabelColor` / `indicatorColor` derived from `ColorScheme` for light/dark readability.

## Scroll/Layout Notes

- Remote public profile keeps **Option A–style** composition within the existing scroll view: header slivers, then `TabBar` in a box, then one sliver that renders either monos or collections. This matches the prior segmented pattern and avoids introducing `TabBarView` + nested scrollables.
- Lists retain their internal scrolling where they already used scrollable sections.

## Tests Added

- `test/features/mono/m14i_mono_reader_creator_footer_navigation_test.dart` — username vs avatar vs follow navigation; missing `writerId`; uses `DefaultAssetBundle` + `WidgetTestPngAssetBundle` and HTTP overrides so `MonoScreen` precache does not fail in the test VM.
- `test/support/widget_test_network_and_assets.dart` — shared PNG asset bundle and PNG-returning `HttpOverrides` for widget tests.
- `test/features/profile/public_profile_collections_tab_test.dart` — updated selectors for `TabBar`; added M14I tab switching and dark-theme smoke tests.
- `test/features/profile/m14i_owner_profile_tab_bar_isolation_test.dart` — asserts owner profile does not expose `publicProfileMainTabBar`.

## Commands Run

- `dart format` on touched Dart files (`mono_screen.dart`, `public_profile_screen.dart`, M14I tests, `test/support/widget_test_network_and_assets.dart`)
- `flutter analyze` on those same paths — clean
- `flutter test test/features/mono` — all passed
- `flutter test test/features/profile` — all passed
- `flutter test` (full suite) — **569 passed, 1 failed**: `test/create_shell_parent_child_flow_test.dart` (“Quiz module strict verification A…”) — `creator_progress_open_button` was **disabled** (tap missed; drawer not opened). This failure reproduces in isolation and is **not** caused by M14I files (no shared global `HttpOverrides` with the mono M14I test; that test installs/tears down overrides in its own `setUpAll` / `tearDownAll`).

## Manual Verification

See task Part F (phone): avatar and username open the same public profile; follow toggles without navigation; public profile shows `TabBar`; Collections loads; dark/light TabBar contrast.

## Remaining Risks

- **Remote path vs mock path:** Only the remote `userId` profile uses the new `TabBar` in the sliver header; legacy mock/demo layouts differ by design.
- **Tab swipe:** Listener-based rebuild should follow finger swipes on the `TabBar`; body is not inside `TabBarView`, so coordinated swipe-to-page is not the default Material full-bleed pager behavior (same as prior segmented switch).
- **CI / full suite:** One unrelated creator-shell strict test can fail when the Progress app-bar control stays disabled (see Commands Run).
