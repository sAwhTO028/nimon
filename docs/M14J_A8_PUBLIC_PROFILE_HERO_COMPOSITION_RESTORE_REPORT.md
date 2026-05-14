# M14J-A8 Public Profile Hero Composition Restore Report

## Problem

M14J-A7 fixed vertical gaps (Follow/Share → TabBar, TabBar → first mono) but left **avatar + stats** in `profileInfoPanel` via `Stack` + `Positioned(top: -40)`, pulling them into the cover from a **separate** `SliverToBoxAdapter`. That broke the **single hero** feel: possible seam/clipping mismatch with `FlexibleSpaceBar` parallax, and layout metrics that did not match the original “avatar on cover” composition.

## Research/Audit Basis

- Prior audit (M14J-A8 research): widgets still existed; **composition** was wrong — Option **B** recommended: avatar + stats in **`FlexibleSpaceBar.background`** with identity/actions in **`SliverToBoxAdapter`**.
- Flutter [NestedScrollView](https://api.flutter.dev/flutter/widgets/NestedScrollView-class.html): outer **`SliverAppBar.stretch`** with `NestedScrollView` is **not supported** — `stretch` set to **false** on the remote public `SliverAppBar` to avoid overscroll quirks.

## Scope

- **UI only:** `PublicProfileScreen` remote branch (`coverFlexibleBackground`, `profileInfoPanel`), `PublicProfileRemoteNestedScroll` (`stretch`), profile layout tests, M14J docs.
- **Unchanged:** backend, providers, collection loading, `TabController` listener, swipe-to-Collections, pagination, routes, follow/share handlers, mono/collection row bodies, owner `ProfileScreen`, Published/Workspace/Saved, validation/l10n, **`SliverOverlapInjector`** (still omitted per M14J-A7).

## Root Cause

Avatar/stats were **not** laid out in the same scroll layer as the cover image; negative offset from the profile sliver created **fragile** overlap and confusing **test vs paint** geometry relative to the headline.

## Architecture Decision

**Option B (implemented):**

1. **`FlexibleSpaceBar.background`:** `Stack` (`publicProfileCoverHeader`) = cover image + **`Positioned(left: 20, right: 20, bottom: -40)`** row with **`publicProfileAvatar`** + **`publicProfileStatsRow`** (`_StatChip` Monos / Followers / Following).
2. **`SliverToBoxAdapter` (`profileInfoPanel`):** top **`SizedBox`** clearance for hero paint into the profile band, then **`publicProfileIdentityBlock`** (display name, optional **`publicProfileHandle`**, optional **`publicProfileBio`**), then preview or **`publicProfileActionRow`**, then **`SizedBox(height: 8)`** before the pinned TabBar.
3. **`SliverPersistentHeader`:** unchanged pinned `TabBar` (no `SliverAppBar.bottom`).
4. Tab bodies: unchanged compact top padding; **no** `SliverOverlapInjector` reintroduction.

## Cover Hero Overlay

- Keys: `publicProfileCoverHeader`, `publicProfileAvatar`, `publicProfileStatsRow`.
- `clipBehavior: Clip.none` on the hero `Stack` only; cover remains `ClipRRect`.
- Stat chips keep **surface-tinted** backgrounds (`_StatChip`) for contrast on photos.

## Profile Info Sliver

- **`kPublicProfileHeroOverlapDown = 40`** — matches `Positioned` bottom inset (row extends below flex stack bottom).
- **`kPublicProfileIdentityBelowHero = 120`** — layout clearance so the **headline** rect sits **below** the avatar rect under `NestedScrollView` + `SliverOverlapAbsorber` geometry (tuned with widget tests; larger than the ideal 40+24 px band from the spec because **global rects** reserve more overlap than the nominal 40 px paint).
- **`SizedBox(height: 14)`** between identity block and actions (bio → actions band).
- No `Transform.translate` / negative `Padding` on the hero row.

## Spacing Measurements

- **Action row → TabBar:** still **≤ 40 px** (`public_profile_final_vertical_gap_test`, `public_profile_header_hero_composition_test`).
- **TabBar → first mono:** still **≤ 40 px** (unchanged `SliverPadding` top **8**).
- **Avatar ↔ display name:** headline vs avatar rects **≥ 8 px** vertical separation (updated M14J-A4/A5/A6 tests use headline + **≤ 40** upper bound).

## Behavior Preserved

1. Cover to status/top; back button; toolbar username fade.
2. Pinned TabBar; transparent TabBar divider.
3. Swipe / tap Collections load; owner profile key isolation.
4. A7 gap wins (no `SliverOverlapInjector` duplicate inset).

## Tests Added

- **`test/features/profile/public_profile_header_hero_composition_test.dart`:** avatar/stats visibility, identity + handle + bio + Follow/Share, hero seam heuristic, gap bounds, fling TabBar, swipe Collections, owner isolation, dark theme smoke.
- **Updated:** `public_profile_header_final_layout_test.dart`, `public_profile_header_spacing_test.dart`, `public_profile_header_final_spacing_test.dart` for **headline vs avatar** metrics (full-width identity `Rect.overlaps` is misleading after A8).

## Commands Run

- `dart format` on touched Dart paths
- `flutter analyze` on touched paths
- `flutter test test/features/profile`
- `flutter test` (see below)

## Manual Verification

Use Part F checklist from the M14J-A8 task brief (phone: hero continuity, gaps, scroll pin, swipe Collections, light/dark).

## Remaining Risks

- **`kPublicProfileIdentityBelowHero` (120)** is **conservative** — may read as extra blank under the hero on some devices; future work could **measure** avatar `RenderBox` bottom vs profile sliver top in a post-frame callback to shrink the spacer without breaking tests.
- **`SliverOverlapInjector`** still omitted; floating header changes would need overlap re-audit.
- Parallax on cover (`CollapseMode.parallax`) still moves the image relative to the overlay row — acceptable for V1; switch to `pin` only if QA reports drift.

## Full Flutter test result

Latest run: **608 passed, 1 failed** — failure is `test/create_shell_parent_child_flow_test.dart` (`creator_progress_drawer` not found in “Quiz module strict verification …”); **unrelated** to public profile (per project norm).
