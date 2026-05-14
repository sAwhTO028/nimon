# M14J-A5 Public Profile Header Layout Final Fix Report

## Problem

On phone, the remote public profile looked correct in broad strokes (cover to status, back button, pinned tabs, collections swipe), but **spacing was wrong**:

1. A **large vertical blank band** between the **Follow/Share** row and the **Monos / Collections** tab strip.
2. The **avatar** and **display name / handle / bio** did not read as one cohesive identity block.

## Confirmed Root Cause

The **TabBar** lived in **`SliverAppBar.bottom`**. `SliverAppBar` reserves the full **`expandedHeight`** for its flexible region; when that height is **larger than the intrinsic height** of the flexible header `Column`, the **TabBar stays pinned to the bottom of that oversized sliver**, producing a **dead flex gap** between the last header widget and the tabs.

## Scope

- **UI layout only** for the remote `PublicProfileScreen` path (`PublicProfileRemoteNestedScroll` + flexible header).
- **Not changed:** backend, providers, public profile API, collection loading logic, `TabController` listener / swipe fix, pagination, routes, follow/share handlers, mono/collection row content, owner `ProfileScreen`, validation/localization.

## Architecture Change

1. **`SliverAppBar`** now has **`bottom: null`** (no embedded `TabBar`).
2. A second sliver, **`SliverPersistentHeader`** (`ValueKey('publicProfilePinnedTabBarHeader')`, `pinned: true`), follows immediately after **`SliverOverlapAbsorber` → `SliverAppBar`**, using **`PublicProfileTabBarHeaderDelegate`** to paint the same **`TabBar`** (`ValueKey('publicProfileTabBar')`) with **surface** background, **transparent** divider, **zero** elevation/shadow.
3. **`SliverMainAxisGroup`** wrapping **both** the app bar and tab header **inside one** `SliverOverlapAbsorber` was **avoided**: widget tests showed the keyed **`TabBar`** could **vanish from the tree** after an aggressive inner **`fling`**. **Sibling slivers** (absorber + app bar, then tab header) are stable with the existing **`SliverOverlapInjector`** on tab bodies.

## Header Layout Fix

- **Identity:** `publicProfileIdentityBlock` groups display name, handle, and bio under the cover/avatar flow with **horizontal alignment** to the avatar column (`padding` **20** left, same as avatar row).
- **Spacing:** `SizedBox(height: 52)` under the cover stack for overlap clearance; **4** px name→handle, **12** px handle→bio; **18** px top padding before actions / preview; **20** px bottom padding on the action row / preview block.

## TabBar Placement Fix

- Tab strip is **only** in the **pinned delegate**, not in **`SliverAppBar.bottom`**.
- Delegate **`minExtent` / `maxExtent`** track **`TabBar` height + small vertical padding** (compact strip, no top divider line).

## Spacing Measurements

- Automated bounds (see `public_profile_header_final_spacing_test.dart`):
  - **Action row → TabBar:** gap **8–40** px (after `expandedHeight` retune).
  - **Avatar → identity block:** vertical gap **8–24** px when stacked below.
- **`expandedHeight`** model: **`toolbar + (318 + bioEstimate + previewBump)`** clamped — tab height **excluded** from app bar expansion.

## Behavior Preserved

1. Cover reaches the top / status area (M14J-A2 guard).
2. Back button remains visible and tappable.
3. Toolbar username still fades in on inner scroll (`innerBoxIsScrolled`).
4. Tab strip remains pinned under the toolbar when collapsed.
5. Monos / Collections tabs and **swipe** / **tap** collection loading unchanged (M14J-A3 listener retained).
6. **TabBar** `dividerColor: Colors.transparent` unchanged.
7. Owner profile still has **no** `publicProfileTabBar` / `publicProfileNestedScrollView` keys (`m14i_owner_profile_tab_bar_isolation_test.dart`).

## Tests Added

- `test/features/profile/public_profile_header_final_spacing_test.dart` — gap, avatar/identity, pinned header + TabBar keys.

## Commands Run

- `dart format` on touched Dart paths
- `flutter analyze` on touched paths
- `flutter test test/features/profile`
- `flutter test` (full suite; see **Full Flutter test result** below)

## Manual Verification

1. Open a public profile by `userId` on a phone.
2. Confirm cover, avatar, identity block, actions, and tabs read as one column without a giant blank band.
3. Scroll monos: toolbar title appears; tabs stay under the toolbar.
4. Swipe Monos → Collections: data still loads.
5. Tap both tabs; dark and light themes: labels and indicator remain readable.

## Remaining Risks

- **`expandedHeight`** still uses a **heuristic** (`coreBelowToolbar` + bio estimate). Very long bios or large text scale may need a future **layout measurement** pass (attempted once; must be wired carefully to avoid bracket / rebuild issues).
- **TabBar outside** the single `SliverOverlapAbsorber` child: overlap math is the stock **`NestedScrollView`** pairing; if a future Flutter version changes overlap semantics, re-verify inner list top insets under the pinned tab strip.

## Full Flutter test result

- If the suite still reports a **single failure** in `test/create_shell_parent_child_flow_test.dart`, treat it as **pre-existing / unrelated** to M14J-A5 (same class of failure noted in prior M14J reports).
