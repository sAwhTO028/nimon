# M12b13 Reader Footer Transparent Meta Report

## Problem

M12b12 added a **frosted meta-only** footer card (`_FooterMetaBlurCard` with `BackdropFilter` + translucent `surface`). Product now wants the **entire** reader footer to read as **fully transparent** over the story/cover so the image/sentence layer shows through behind **both** meta and actions.

## Product Decision

- **No** footer-level card, blur, border, or tinted plate behind meta.
- **Meta** and **action column** remain layout-only; colors come from existing **`readingInk`** / tokens on text and controls only.

## Meta Background Removal

- Deleted **`_FooterMetaBlurCard`** (`ClipRRect`, **`BackdropFilter`**, **`DecoratedBox`**, card padding).
- **`_buildReadingFooterRow`** uses **`Expanded(child: meta)`** with no wrapper.
- **`BackdropFilter`** is **not** used anywhere in `mono_screen.dart` after this change (cover hero still uses **`ImageFiltered`** + **`ImageFilter`** elsewhere).

## Transparent Footer Structure

Unchanged from M12b12 aside from meta wrapper:

- **`Row`** (`crossAxisAlignment: end`): **`Expanded(meta)`**, **`SizedBox(_footerMetaToActionGap)`**, **`_MonoFooterTransparentActionColumn`**.
- **`_MonoGroupedBackgroundContent`** still provides horizontal **`Padding`** (14 / 8); no extra meta-only surface.

## Readability Notes

Footer text and chips continue to use **`ink`** / **`textSecondary`** / **`surface`** (status chip only) as before. **No** new text shadows or card fills. Over busy covers, contrast is a known risk (documented here).

## Behavior Preservation

Follow, React, More sheet, Learn/Save/Share, measurement via **`_MeasureSize`** on the full footer row — unchanged.

## Tests Added

`m12b_mono_reader_actions_rail_more_sheet_test.dart` asserts **`_FooterMetaBlurCard`** and file-level **`BackdropFilter`** absent, footer **`Row`** with **`Expanded(child: meta)`**, no **`DecoratedBox`/`ClipRRect`** in `_buildReadingFooterRow`, transparent action column unchanged.

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze` on those paths — no issues
- `flutter test test/features/mono` — 69 tests passed
- `flutter test` — 448 tests passed

## Manual Verification

- Meta and actions float over the same background as the reading area; no frosted rectangle behind the username block.

## Remaining Risks

- Low contrast on light-on-light or busy imagery; mitigations would be content-side (e.g. scrim) and are out of scope for this polish-only change.

## Recommended Next Step

If contrast issues appear in QA, consider a **non-card** approach (e.g. very subtle text stroke already in design system) rather than reintroducing blur.
