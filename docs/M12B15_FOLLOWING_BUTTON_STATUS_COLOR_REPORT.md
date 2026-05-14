# M12b15 Following Button Status Color Report

## Problem

The **Following** state reused the same dark filled treatment as **Follow** (`textPrimary` fill + `appBackground` label), so it did not read as the softer **level/status chip** family used beside it.

## Product Decision

When **`isFollowing`**, the control should look like the status chip: **translucent surface**, **border**, **`textSecondary`** label — not the primary inverted Follow pill.

## Following Button Color

- **`OutlinedButton`** with **`elevation: 0`**, same **height / padding / radius / minWidth / fontSize** as before.
- **Fill**: `surface` @ **`_MonoStatusChip.kSurfaceAlpha`** (0.55).
- **Border**: `border` @ **`_MonoStatusChip.kBorderAlpha`** (0.7), matching **`_MonoStatusChip`** `Border.all`.
- **Label**: `textSecondary` (same ink role as chip text).
- **Disabled** (loading): muted **`surface`** @ 0.35 and **`textSecondary`** @ 0.45 alpha.

Shared **`static const`** **`kSurfaceAlpha`** / **`kBorderAlpha`** live on **`_MonoStatusChip`**; **`_PostFooterMeta`** passes chip **`background`** using **`kSurfaceAlpha`**.

## Follow Button Preservation

**Follow** (non-following) stays **`FilledButton`** with **`followBg`** / **`followFg`** (**`textPrimary` @ 0.88** + **`appBackground`**) — unchanged intent.

## Layout Preservation

No changes to footer **`Row`**, meta typography, action column, or follow sizing constants (**28** height, **68**/**84** min widths, **10** radius, **12** label size).

## Tests Added

`m12b_mono_reader_actions_rail_more_sheet_test.dart` asserts **both** **`OutlinedButton`** (Following) and **`FilledButton`** (Follow), chip **`kSurfaceAlpha` / `kBorderAlpha`** references, and **`followingFg` / `followingBg`** vs **`followBg` / `followFg`**.

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze` on those paths — no issues
- `flutter test test/features/mono` — 69 tests passed
- `flutter test` — 448 tests passed

## Manual Verification

Toggle Follow → Following: button becomes chip-like outline/fill; toggle back → dark filled Follow.

## Remaining Risks

**OutlinedButton** vs **FilledButton** may have slightly different minimum tap semantics; **`shrinkWrap`** preserved.
