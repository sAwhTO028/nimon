# M12b10 Reader Footer Meta Spacing + Follow Polish Report

## Problem

After M12b9, the right action column looked balanced, but the **meta block** still felt vertically tight (2px after the name row before the title). The **Follow / Following** control read as an oversized pill (`BorderRadius.circular(999)`, 30px min height, wide min widths).

## Meta Spacing Polish

In `_PostFooterMeta`:

- Added `static const _metaNameTitleGap = 4.0` and `static const _metaTitleStatusGap = 4.0`.
- Replaced the previous **2px** spacer after the username + Follow row with **`_metaNameTitleGap`** (name → title).
- Kept **4px** between title and status chip via **`_metaTitleStatusGap`** (explicit constants for clarity).

No extra outer padding; footer stays compact.

## Follow Button Size Polish

In `_FooterFollowButtonState.build`:

- **Height**: `minimumSize` from `Size(0, 30)` → **`Size(0, 28)`**.
- **Min width**: Follow **68**, Following **84** (was 74 / 92).
- **Horizontal padding**: **11** for both states (was 10 / 12).
- **Label**: `fontSize: 12` on the base text style (readable, slightly denser).

Colors unchanged (`textPrimary` fill, `appBackground` label, explicit disabled colors).

## Follow Button Radius Polish

- Replaced stadium **`BorderRadius.circular(999)`** with **`const followRadius = 10.0`** and **`BorderRadius.circular(followRadius)`** on both FilledButton shapes.

## Behavior Preservation

Follow / unfollow logic, repositories, and semantics labels unchanged. More/React column untouched (`_MonoFooterSideActions` still 52px, dual `_FooterReaderIconActionButton`). No handle or description.

## Theme / Accessibility

Tokens only for colors (`textPrimary`, `appBackground`, etc.). `MaterialTapTargetSize.shrinkWrap` retained (compact visual); no new 44px wrapper to avoid growing the meta row height.

## Tests Added

`m12b_mono_reader_actions_rail_more_sheet_test.dart`:

- Meta block asserts `_metaNameTitleGap` / `_metaTitleStatusGap` and named `SizedBox` spacers.
- New test on `_FooterFollowButtonState`: no `999` radius, `followRadius` 10, min widths 68/84, height 28, `fontSize: 12`, labels **Follow** / **Following** still present.

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart` — no issues
- `flutter test test/features/mono` — 70 tests passed
- `flutter test` — 449 tests passed

## Manual Verification

- Name, title, and status chip have a bit more air; Follow reads as a **rounded rectangle**, not a capsule.
- Labels remain legible; username still ellipsizes first (`Flexible` + `ellipsis`).

## Remaining Risks

- `shrinkWrap` tap targets may feel small for some users; can revisit with padded tap target without changing visual size.

## Recommended Next Step

Optional `MediaQuery.textScaler` snapshot of the footer row; inline Learn CTA still out of scope.

## M12b11 follow-up

M12b11 split the footer visually: **meta + React** on **`_FooterMetaReactCard`**, **More** transparent and `Positioned` outside the card. See [M12B11_READER_FOOTER_SPLIT_BACKGROUND_REPORT.md](M12B11_READER_FOOTER_SPLIT_BACKGROUND_REPORT.md).

## M12b12 follow-up

M12b12 narrowed the card to **meta only** (blur glass) and put **More + React** in one **transparent** column — [M12B12_READER_FOOTER_META_BLUR_ACTION_COLUMN_REPORT.md](M12B12_READER_FOOTER_META_BLUR_ACTION_COLUMN_REPORT.md).
