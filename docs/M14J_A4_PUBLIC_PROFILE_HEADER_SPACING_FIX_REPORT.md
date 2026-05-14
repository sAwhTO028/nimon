# M14J-A4 Public Profile Header Spacing Fix Report

## Problem

After M14J-A through A3, two spacing issues remained on device:

1. **Action row → TabBar:** Too much empty vertical space between the Follow/Share row and the Monos / Collections strip.
2. **Avatar ↔ name block:** The display name and handle felt cramped against the overlapping hero avatar (same horizontal band as the avatar without enough vertical separation).

## Scope

- UI-only changes under `lib/features/profile/public_profile_screen.dart` (remote public profile `flexibleHeader` and height estimates).
- No changes to backend, data loading, `TabController` listener, collections swipe logic, `PublicProfileRemoteNestedScroll`, routes, owner profile, or nested scroll architecture.

## Avatar/Name Spacing Fix

- Added **`ValueKey('publicProfileAvatar')`** on a `KeyedSubtree` wrapping `_Avatar`.
- Added **`ValueKey('publicProfileNameBlock')`** on the name/handle/bio `Column` and **`ValueKey('publicProfileDisplayName')`** on the headline `Text` (for tests and future tooling).
- **Vertical:** Increased the spacer between the cover `Stack` and the name block from **8px → 36px** so the headline clears the avatar’s painted extent (avatar overlaps the cover with `bottom: -40`).
- **Horizontal:** Indented the name block with `EdgeInsets.fromLTRB(116, 6, 20, 2)` so copy starts **past** the avatar (row inset 20 + diameter 80 + **16px** gap), avoiding the “text under the circle” look while keeping full-width flow for handle/bio below.

## Action Row to TabBar Gap Fix

- Tightened **`_estimatedRemoteFlexColumnHeight`** to match the shorter header (smaller action top padding **6**, no trailing slack under the action row in the estimate).
- **`_remoteProfileExpandedHeightForAppBar`:** removed extra tail constants, capped upper clamp to **508** so the `SliverAppBar` flexible region does not reserve a half-screen dead zone above the pinned `TabBar`.
- Kept the M14J-A3 rule: **`expandedHeight` must not include status bar padding** (Flutter adds `topPadding` in `maxExtent`).

## Height Calculation

`_estimatedRemoteFlexColumnHeight` now tracks:

- `coverStack` 172 + 40 (avatar overlap),
- `afterCover` **36** (spacer under stack),
- `nameChrome` 6 + 6 + 36 + 24 (padding + inner gap + headline/handle fudge),
- bio estimate (`_estimatePublicBioBlockHeight`),
- optional owner-preview bump,
- actions **6 + 50**.

`_remoteProfileExpandedHeightForAppBar` returns  
`clamp(toolbar + tabBar + 248, 508, toolbar + flex + tabBar)`.

## Behavior Preserved

- Cover remains top-aligned in the flexible column (no `Align(bottomCenter)` regression).
- `publicProfileCoverHeader` / `publicProfileFlexibleHeader` keys unchanged.
- `publicProfileActionRow` / `publicProfileTabBar` unchanged in wiring.
- `PublicProfileRemoteNestedScroll` TabBar divider / elevation / swipe + listener behavior unchanged.

## Tests Added

- `test/features/profile/public_profile_header_spacing_test.dart`
  - Display name vs avatar: vertical gap ≥ 8, horizontal start ≥ avatar right − 8.
  - Action row → TabBar gap: **8 ≤ gap ≤ 104** (blocks the old large blank band while allowing normal TabBar chrome).

## Commands Run

- `dart format` on touched Dart files
- `flutter analyze` / `flutter test test/features/profile` (pass)
- `flutter test` (full suite: **583 passed, 1 failed** — `test/create_shell_parent_child_flow_test.dart`, unrelated)

## Manual Verification

1. Public profile: cover to status edge, back usable.
2. Name/handle/bio start to the **right** of the avatar with clear vertical separation from the hero overlap.
3. Follow/Share sits under bio; TabBar sits closer than pre–A4.
4. Scroll: toolbar title fades; TabBar pins.
5. Swipe Monos → Collections: data still loads (A3).
6. Light/dark quick pass on headline and tabs.

## Remaining Risks

- The **116px** left inset assumes the same avatar geometry as the hero row (80px wide + 16px gap from the 20px row inset). If avatar size or row padding changes, update the inset or derive it from layout constants.
- Full `flutter test` still reports one unrelated failure in the create shell suite.
