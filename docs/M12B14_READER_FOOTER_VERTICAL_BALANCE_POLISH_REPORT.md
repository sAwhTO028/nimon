# M12b14 Reader Footer Vertical Balance Polish Report

## Problem

After M12b13 (fully transparent footer), feedback indicated the **meta block felt compressed toward the bottom** relative to the **More + React** column — partly because the footer **`Row`** used **`CrossAxisAlignment.end`**, pinning both columns to the baseline bottom.

## Design Goal

- Meta and actions read as **one balanced horizontal pair**.
- **Username / title / status** feel **evenly distributed** vertically, not collapsed downward.
- Clear **typographic hierarchy** without enlarging the whole footer.
- Remain **compact** and **transparent** (no card restore).

## Layout adjustments

1. **`_buildReadingFooterRow`**: **`CrossAxisAlignment.end` → `CrossAxisAlignment.center`** so the meta subtree **centers vertically** against the transparent action column when heights differ.

2. **`_PostFooterMeta`** outer **`Row`** (avatar + text): **`CrossAxisAlignment.start` → `CrossAxisAlignment.center`** so the avatar aligns with the vertical center of the text column.

## Typography hierarchy changes

| Role | Change |
|------|--------|
| **Username** | **15** px, **`FontWeight.w800`**, slight negative letterSpacing — strongest |
| **Story title** | **12.5** px, **`w600`**, ink **0.88** alpha — secondary, still one line + ellipsis |
| **Status chip** | **`w600`** (was **w700**), letterSpacing **0.08** — calmer tertiary |

## Vertical spacing constants

Renamed and tuned in **`_PostFooterMeta`**:

- **`_metaColumnTopInset`**: **4 → 6** (more air above username).
- **`_metaNameToTitleGap`**: **6** (was **`_metaNameTitleGap` 4**).
- **`_metaTitleToChipGap`**: **5** (was **`_metaTitleStatusGap` 4**).

No extra **`SizedBox`** after the status chip; chip remains last in the column.

## Footer balance result

Center-aligned **`Row`** removes bottom-heavy anchoring; increased internal gaps spread the three text bands without a **`minHeight`** hack or taller action column.

## Tests

`m12b_mono_reader_actions_rail_more_sheet_test.dart` updated for **`CrossAxisAlignment.center`** on the footer row and **`_PostFooterMeta`**, new spacing constant names/values, and username/title style anchors (**15** / **12.5** / **w800**).

## Commands run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze` on those paths — no issues
- `flutter test test/features/mono` — 69 tests passed
- `flutter test` — 448 tests passed

## Manual verification

- Footer row: meta and actions sit at a shared vertical middle.
- Username reads clearly primary; title and chip step down cleanly.

## Remaining risks

On very short screens, added vertical spacing slightly increases footer height; **`_MeasureSize`** continues to drive **`contentH`**.

## Recommended next step

Optional snapshot/golden at **`textScaleFactor` 1.0 / 1.3** for footer density.

## M12b15 follow-up

The **Following** control now uses the same **surface / border / textSecondary** family as the level · Read-only chip via shared **`_MonoStatusChip.kSurfaceAlpha` / `kBorderAlpha`**. See [M12B15_FOLLOWING_BUTTON_STATUS_COLOR_REPORT.md](M12B15_FOLLOWING_BUTTON_STATUS_COLOR_REPORT.md).
