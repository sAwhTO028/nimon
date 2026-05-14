# M12b8 Reader Footer Action Column Overlap Fix Report

## Problem

M12b7 used a `Stack` with More at `Positioned(top: 0)` and React `Align(bottomRight)`. On real devices, short footer / tight constraints made the heart and three-dots feel colliding or visually cramped.

## Blueprint Target

- One horizontal footer group: **`[ Expanded(meta) ][ fixed action column ]`**, then the bottom dock unchanged below.
- Action column is a distinct block: **More at the top**, **React lower in the column** with explicit vertical gap — no shared/overlapping vertical space.

## Action Column Layout

`class _MonoFooterSideActions` now uses:

- `static const columnWidth = 72.0` (matches `_MonoGroupedBackgroundContent` via `_railW = _MonoFooterSideActions.columnWidth`).
- `ConstrainedBox(minHeight: _moreTap + _moreToReactGap + _reactSlotH)` (106px) so the column always reserves space for More + gap + React slot.
- `Column(mainAxisSize: min, crossAxisAlignment: end)` with `SizedBox(height: _moreToReactGap)` (10) between More and React.

## More Placement

`_MonoFooterMoreIconButton` is the first child of the column, end-aligned: transparent material, 44×44 tap target, `Icons.more_horiz`, `textSecondary`, semantics `'More actions'`, same `onMore` → More sheet.

## React Placement

Single `_RailActionSlot` below the gap: slot height 52px, same heart/count semantics and colors as before; width matches `columnWidth`.

## Overlap Prevention

No `Stack`/`Positioned` pairing in the action column; vertical separation is structural (`Column` + `SizedBox`), not z-order. No negative offsets.

## Meta Preservation

`_PostFooterMeta` unchanged (avatar, username + follow, title, status chip; no handle/description).

## Tests Added

`test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart` asserts:

- `_MonoFooterSideActions` uses `Column`, `CrossAxisAlignment.end`, `SizedBox(height: _moreToReactGap)`, and **no** `Stack`/`Positioned`.
- `columnWidth = 72`, single `_RailActionSlot`, single `Icons.more_horiz` in the file, More semantics unchanged, More sheet + compact meta tests preserved.
- Footer row ties `_railW` to `_MonoFooterSideActions.columnWidth`.

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart` — no issues
- `flutter test test/features/mono` — 68 tests passed
- `flutter test` — 447 tests passed

## Manual Verification

- Footer: meta block left, 72px action column right; three-dots clearly above the heart; gap visible at common text scales.
- More sheet and React tap behavior unchanged; dock still below the footer group.

## Remaining Risks

- Very large text scale may still feel tight in the 72px column; follow up with responsive width if needed.
- `_RailActionSlot` still uses a fixed slot height; extreme counts could theoretically crowd the slot (same class as pre-M12b8).

## Recommended Next Step

Optional golden or widget test on `_ReadingFeedPost` footer at multiple `MediaQuery.textScaler` values; inline Learn CTA remains out of scope.

## M12b9 follow-up

M12b9 replaced `_MonoFooterMoreIconButton` + `_RailActionSlot` with a shared `_FooterReaderIconActionButton` (equal 44×44 slots, 24px icons) and narrowed the column to 52px. See [M12B9_READER_FOOTER_EQUAL_ACTION_BUTTONS_REPORT.md](M12B9_READER_FOOTER_EQUAL_ACTION_BUTTONS_REPORT.md).
