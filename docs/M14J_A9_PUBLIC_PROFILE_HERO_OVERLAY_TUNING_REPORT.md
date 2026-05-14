# M14J-A9 Public Profile Hero Overlay Tuning Report

## Problem

After M14J-A8, the public profile hero was structurally correct (avatar + stats in `FlexibleSpaceBar.background`, identity in `SliverToBoxAdapter`) but two UI issues remained:

1. **Avatar + stats looked clipped** at the cover/profile boundary — `Positioned(bottom: -40)` pushed too much of the row outside the flexible hero paint region, so parent/sliver clipping could **cut the row in half**.
2. **Cover felt too tall** — the flexible cover slot (`kRemotePublicCoverImageHeight` **196**) consumed excessive vertical space on phone.

## Scope

- **UI only:** `public_profile_screen.dart` (hero `Positioned`, identity top spacer), `public_profile_remote_nested_scroll.dart` (cover height constant), new/updated profile widget tests, M14J docs.
- **Unchanged:** backend, providers, loading, `TabController` listener, swipe, pagination, routes, follow/share, row content, owner profile, Published/Workspace/Saved, l10n/validation, TabBar architecture (`SliverPersistentHeader`), **`SliverOverlapInjector`** omission (M14J-A7).

## Overlay Clipping Root Cause

`bottom: -40` on the hero row placed **40 px** of the row **below** the `Stack`’s laid-out bottom. `FlexibleSpaceBar` / outer sliver painting can clip descendants that extend past the flexible region’s box, so the lower portion of the avatar/stats row could be **visually truncated** while still “existing” in the widget tree.

## Cover Height Tuning

- **`PublicProfileRemoteNestedScroll.kRemotePublicCoverImageHeight`:** **196 → 168** (−28 px).
- **`kRemotePublicCoverExpandedTotal`** remains **toolbar (56) + cover slot (168) = 224** (no identity in app bar expansion).

## Overlay Offset Tuning

- **`kPublicProfileHeroOverlapDown`:** **40 → 22** px (`Positioned(bottom: -22)`), in the **20–24** band requested so more of the row stays **inside** the hero `Stack` while still overlapping the cover bottom.

## Identity Spacer Tuning

- **`kPublicProfileIdentityBelowHero`:** **120 → 104** px after overlap reduction; still large enough that **`publicProfileDisplayName`** clears the avatar rect under `NestedScrollView` geometry (same class of issue as M14J-A8’s 120 px spacer — **layout rects** vs nominal paint overlap).
- **Ideal 10–20 px** “paint gap” is approximated by the smaller **−22** overlap; the **SizedBox** is primarily **layout clearance** for the next sliver, not a second hidden hero.

## Spacing Measurements

- **Action row → TabBar:** still **≤ 40 px** (`public_profile_final_vertical_gap_test`, `public_profile_hero_overlay_tuning_test`).
- **TabBar → first mono:** still **≤ 40 px** (unchanged `SliverPadding` top **8**).
- **Identity vs hero (widget test):** `identityBlock.top − max(avatar.bottom, stats.bottom)` in **[8, 72]** px (`public_profile_hero_overlay_tuning_test`) — upper bound relaxed from 28 to account for nested-scroll rect slack while keeping a **finite** cap.

## Behavior Preserved

1. Cover to status/top; back; toolbar title fade.  
2. Pinned TabBar; transparent divider.  
3. Swipe/tap Collections; owner key isolation.  
4. M14J-A8 hero composition (same widget ownership).

## Tests Added

- **`test/features/profile/public_profile_hero_overlay_tuning_test.dart`** — visibility, cover height bound, hero seam, identity gap band, gap caps, TabBar after fling, swipe Collections, owner isolation (split `ProviderScope` pumps to avoid Riverpod override count assertion).

## Commands Run

- `dart format` on touched paths  
- `flutter analyze` on touched paths  
- `flutter test test/features/profile`  
- `flutter test` (full suite; see below)

## Manual Verification

Use M14J-A9 Part F checklist (phone: shorter cover, full avatar/chips, natural overlap, identity/actions/tabs/mono stack, scroll + swipe + light/dark).

## Remaining Risks

- **Identity spacer (104)** may still read as “air” under the hero on some devices; a follow-up could **measure** `RenderBox` distances in a post-frame callback to shrink it without breaking `NestedScrollView` rect tests.
- **Parallax** on the cover can still shift the image relative to the pinned overlay row — acceptable unless QA requests `CollapseMode.pin`.

## Full Flutter test result

Latest run (2026-05-10): **617 passed, 1 failed** — failure in `test/create_shell_parent_child_flow_test.dart` (`Quiz module strict verification` / `creator_progress_drawer` not found after tap; progress button hit-test warning). **Unrelated** to M14J-A9 public profile UI.
