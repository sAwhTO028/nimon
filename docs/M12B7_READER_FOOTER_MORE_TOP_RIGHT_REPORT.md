# M12b7 Reader Footer More Top Right Report

## Problem

M12b6 placed React and More in a single vertical rail (stacked peers). Product direction is to separate **utility** (More) from **engagement** (React): More reads as a lightweight overflow control, while React stays the primary visible action anchored to the footer baseline.

## Design Decision

- **More** (three dots): icon-only, transparent hit target, **top-right** of the narrow footer action column (not stacked under React).
- **React**: unchanged one-tap behavior and count treatment; **bottom-right** of that column, aligned with the bottom of the footer row / meta block.
- **No** changes to the More bottom sheet contents, Learn/Save/Share wiring, follow logic, or share URLs.

## More Top-Right Placement

Implemented as `_MonoFooterMoreIconButton`: 44×44 minimum tap target, `Semantics(label: 'More actions')`, `Icons.more_horiz` with `theme.colors.textSecondary`, `Material` color transparent, `NoSplash.splashFactory` plus a very light `highlightColor` derived from `textPrimary` alpha to avoid a heavy ink splash.

## React Footer Placement

React remains a `_RailActionSlot` (same icon semantics, active `react` vs inactive `textPrimary`, compact count under the heart when `likesCount > 0`), wrapped in `Align(alignment: Alignment.bottomRight, …)` inside the footer `Stack`.

## Old Rail Removal

`class _BottomActionRail` (two-slot `Column` with `_slotH * 2` height contract) was removed. The footer right column is now `class _MonoFooterSideActions` with a single `_RailActionSlot` (React only) plus the separate More button widget.

## Meta Group Preservation

`_PostFooterMeta` was not modified. Layout continues to use `Row` + `Expanded(metaGroup)` + gap + fixed-width side column; only the side column implementation changed.

## Theme / Accessibility

Colors use theme tokens only (`textPrimary`, `textSecondary`, `react`, etc.) via `Theme.of(context).colors`. More uses transparent material; no hardcoded RGB for surfaces.

## Tests Added

`test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart` was updated to assert:

- `_MonoFooterSideActions` contains a `Stack`, `Positioned` (More), and bottom-right React alignment.
- `_MonoFooterMoreIconButton` holds the only `Icons.more_horiz` and `'More actions'` semantics.
- Exactly one `_RailActionSlot` in the side-actions block (React only).
- No `_BottomActionRail`, no `_slotH * 2` rail contract.
- More sheet and compact meta tests preserved.

A source-level test ensures only one `Icons.more_horiz` exists in `mono_screen.dart` (no duplicate More).

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart` — no issues
- `flutter test test/features/mono` — 67 tests passed
- `flutter test` — 446 tests passed

## Manual Verification

- Open Mono reader: More appears top-right of the right footer column; React sits lower-right with count when applicable.
- Tap More: same “Mono actions” sheet as before (Learn / Save / Share per existing rules).
- Tap React: like toggles as before.

## Remaining Risks

- Very short footer meta + large text scale could still crowd the right column; `minColumnHeight` on the side stack mitigates overlap between More and React.
- If future actions are added to the footer column, the `Stack` will need another layout pass.

## Recommended Next Step

M12b follow-up: optional inline Learn CTA (explicitly out of scope here) or golden tests for footer density across text scales.

## M12b8 follow-up

M12b8 replaced the `Stack` + `Positioned` / `Align` layout with a non-overlapping fixed `Column` in the action strip. See [M12B8_READER_FOOTER_ACTION_COLUMN_OVERLAP_FIX_REPORT.md](M12B8_READER_FOOTER_ACTION_COLUMN_OVERLAP_FIX_REPORT.md).
