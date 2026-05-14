# M14J-A6 Public Profile Header Layout Rebuild Report

## Problem

After M14J-A5, the **Monos / Collections** tab strip was no longer in `SliverAppBar.bottom`, but phone screenshots still showed a **large vertical gap** between **Follow / Share** and the **TabBar**.

## Final Root Cause

The **profile identity block** (avatar, stats, name, handle, bio, actions) still lived inside **`SliverAppBar` → `FlexibleSpaceBar`**. `SliverAppBar` always allocates a **flexible region** sized by **`expandedHeight`**. Any mismatch or excess reserved height creates a **blank band** before the next header sliver—even when the TabBar is already outside `bottom`.

## Scope

- **UI only:** `PublicProfileRemoteNestedScroll` + remote branch of `PublicProfileScreen`.
- **Unchanged:** backend, providers, collection loading, `TabController` listener, swipe behavior, pagination, routes, follow/share logic, mono/collection rows, owner `ProfileScreen`, Published/Workspace/Saved, validation/l10n.

## Architecture Change

**Before (A5):**  
`NestedScrollView` → `SliverOverlapAbsorber` → `SliverAppBar` (flexible = cover + avatar + identity + actions) → `SliverPersistentHeader` (TabBar).

**After (A6):**  
`NestedScrollView` → `SliverOverlapAbsorber` → `SliverAppBar` (**flexible = cover image only**, `expandedHeight` = toolbar + cover) → **`SliverToBoxAdapter`** (avatar, stats, identity, actions) → **`SliverPersistentHeader`** (TabBar).

Removed the old **`_estimatedRemoteFlexColumnHeight` / `_remoteProfileExpandedHeightForAppBar`** model.

## Cover SliverAppBar

- **`flexibleSpace`:** `FlexibleSpaceBar` + `Stack` keyed `publicProfileCoverHeader` with **`SizedBox.expand`** clipped cover (`_CoverImage`).
- **`expandedHeight`:** `PublicProfileRemoteNestedScroll.kRemotePublicCoverExpandedTotal` (= **56** toolbar + **196** cover slot). No identity/action height.
- **`pinned`**, **`stretch`**, back **`leading`**, **`AnimatedOpacity`** toolbar title unchanged.
- **No** `SafeArea` around the cover; **no** `TabBar` in `bottom`.

## Profile Info Sliver

- **`SliverToBoxAdapter`** keyed `publicProfileProfileInfoSliver`.
- **`Transform.translate(Offset(0, -40))`** pulls the avatar row up so it **visually meets** the cover (Flutter **`Padding`** cannot use negative insets—asserts `padding.isNonNegative`).
- **`publicProfileActionRow`** key sits on the **outer `Padding`** around the button row so layout metrics include **bottom** inset (tighter **action → TabBar** gap in tests).

## Pinned TabBar Sliver

- Unchanged delegate pattern: **`PublicProfileTabBarHeaderDelegate`**, `dividerColor: Colors.transparent`, surface background, zero elevation.
- **`_kVerticalPadding`** set to **0** so the pinned strip height matches the **TabBar** (~48px) and does not add dead space.

## Spacing Measurements

- Target: action block bottom → TabBar top **≤ 40px** on phone-sized surface (**390×844**) — enforced in `public_profile_header_final_layout_test.dart`.
- Avatar → identity: **14px** spacer after avatar row; name/handle/bio rhythm **4 / 12** px.

## Behavior Preserved

1. Cover to status/top (M14J-A2 guard).
2. Back button.
3. Toolbar username on scroll.
4. Pinned TabBar.
5. Monos / Collections; swipe and tap collection load (M14J-A3).
6. Owner profile has no public TabBar keys.

## Tests Added

- `test/features/profile/public_profile_header_final_layout_test.dart` — gap, avatar/identity, structure (identity **not** under `FlexibleSpaceBar`), cover top, divider, swipe load, owner isolation.

## Commands Run

- `dart format` on touched Dart paths  
- `flutter analyze` on touched paths  
- `flutter test test/features/profile`  
- `flutter test` (full suite; see below)

## Manual Verification

Same checklist as M14J-A5 Part G: public profile on device, cover + avatar continuity, tight action→tabs, scroll pin, swipe collections, light/dark.

## Remaining Risks

- **`Transform.translate`** does not shrink layout height; overlap is **visual** only—very small screens should be checked for accidental clip if we add `ClipRect` later.
- **`expandedHeight`** is still a **constant**; extreme aspect ratios might need a follow-up tweak.

## Full Flutter test result

Latest run: **593 passed, 1 failed** — failure is **`test/create_shell_parent_child_flow_test.dart`** (create shell / quiz flow); **unrelated** to public profile layout.
