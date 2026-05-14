# M14J-A10 Public Profile Hero Overlay Visibility Hotfix

## Problem

Negative `Positioned` bottom on the hero row still allowed **FlexibleSpaceBar** / sliver paint bounds to **clip** avatar and stats at the cover seam. The flexible cover slot was also still taller than desired on phone.

## Scope

UI only: `public_profile_screen.dart`, `public_profile_remote_nested_scroll.dart` (cover height constant), hero/header widget tests.

## Fix

1. **Overlay inside cover:** `Positioned(bottom: 12)` (no negative inset). Row key **`publicProfileHeroOverlayRow`** (replaces **`publicProfileStatsRow`** on that widget).
2. **Stack** `clipBehavior: **Clip.hardEdge**` so children stay within paint bounds.
3. **Cover image slot:** `kRemotePublicCoverImageHeight` **168 → 146** (`kRemotePublicCoverExpandedTotal` = **202**).
4. **Backdrop key:** `publicProfileCoverBackdrop` on the `ClipRRect` wrapping `_CoverImage` for height assertions (render box matches flexible header height ≈ expanded total; constant encodes the shorter image band under the toolbar).
5. **Identity spacer:** **`kPublicProfileIdentityBelowHero` 104 → 52** — large spacer was for clearing a row that extended **below** the cover; with an in-cover overlay, a smaller value keeps the headline clear under `NestedScrollView` rects without a giant gap before the TabBar.

## Tests

- `public_profile_header_hero_composition_test.dart` — inside-cover bounds; new overlay key.
- `public_profile_hero_overlay_tuning_test.dart` — backdrop + constant checks; identity gap band.

## Commands

- `dart format` on touched files  
- `flutter analyze` on touched `lib` paths  
- `flutter test` on the four profile files listed in the M14J-A10 task (not full suite)
