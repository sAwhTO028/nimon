# M12b9 Reader Footer Equal Action Buttons Report

## Problem

After M12b8, More and React no longer overlapped, but the column still felt uneven: the three-dots control looked lighter than the heart, widths/heights differed (`_MonoFooterMoreIconButton` vs `_RailActionSlot`), and the 72px column added loose horizontal space.

## Design Target

- One compact **right action column** beside meta: **two equal visual-weight controls**.
- **Same** square tap target, **same** icon size, **same** transparent / minimal ink treatment.
- **Tight** vertical gap (about 4–6px) between the two slots; like count stays **centered** under React only.

## Shared Action Button Slot

Introduced **`_FooterReaderIconActionButton`** with:

- `static const kSlotSize = 44.0` (tap target)
- `static const kIconSize = 24.0`
- Transparent `Material`, `NoSplash.splashFactory`, light `highlightColor` from `textPrimary` alpha
- `Semantics(label: semanticsLabel)` for screen readers

Both More and React use this widget; no raw `Icon` for More outside the slot.

## More Button Polish

More is `_FooterReaderIconActionButton(semanticsLabel: 'More actions', icon: Icons.more_horiz, foregroundColor: textSecondary, onPressed: onMore)` — no visible text label, same sheet behavior.

## React Button Polish

React uses the **same** `_FooterReaderIconActionButton` with `monoReactRailSemanticsLabel`, filled/outline heart, `foregroundColor: react` when active else `textPrimary`. Optional count is a separate `Text` row **below** the React slot (`fontSize: 11`, `textSecondary`, centered), with 2px top padding — not inside the 44px hit target.

## Action Column Spacing

- **`_MonoFooterSideActions.columnWidth = 52`**
- **`_betweenActions = 5`**
- **`Column` + `mainAxisSize: min` + `crossAxisAlignment: center`**
- Removed **min-height `ConstrainedBox`** from M12b8; spacing is intrinsic to the column.

`_MonoGroupedBackgroundContent` still uses `_railW = _MonoFooterSideActions.columnWidth`.

## Meta Preservation

`_PostFooterMeta` unchanged (avatar, username + follow, title, status chip; no handle/description).

## Tests Added

`m12b_mono_reader_actions_rail_more_sheet_test.dart` now asserts:

- `_MonoFooterSideActions` uses centered `Column`, `_betweenActions` gap, **no** `Stack`/`Positioned`/`ConstrainedBox`/`minColumnHeight`
- **Two** `_FooterReaderIconActionButton(` call sites, `columnWidth = 52`
- Shared button: `kSlotSize` 44, `kIconSize` 24, `NoSplash`
- **`_RailActionSlot`** and **`_MonoFooterMoreIconButton`** removed from `mono_screen.dart`
- More sheet + compact meta tests preserved

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart` — no issues
- `flutter test test/features/mono` — 69 tests passed
- `flutter test` — 448 tests passed

## Manual Verification

- More and heart appear as **matching** square controls, centered in a **narrow** column.
- Count sits under the heart, centered; dock unchanged below the footer row.

## Remaining Risks

- At very large text scale, the 52px column may feel tight; consider responsive width later.
- Like counts with many digits rely on ellipsis in the count line.

## Recommended Next Step

Optional widget/golden tests across `textScaler`; inline Learn CTA still out of scope.

## M12b10 follow-up

M12b10 increased meta row gaps and compacted the footer Follow / Following control (smaller min size, `BorderRadius.circular(10)`). See [M12B10_READER_FOOTER_META_SPACING_FOLLOW_POLISH_REPORT.md](M12B10_READER_FOOTER_META_SPACING_FOLLOW_POLISH_REPORT.md).
