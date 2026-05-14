# M12b11 Reader Footer Split Background Report

## Problem

M12b9–M12b10 treated the footer as one horizontal band: meta, React, and More read as a single surface. Product wanted **utility** (More) to read as a **floating** control over the story/cover pixels, while **meta + engagement** (React) sit on a **shared card**.

## Product Model

- **groupA**: `_PostFooterMeta` + `_MonoFooterReactColumn` (heart + count), wrapped in **`_FooterMetaReactCard`** (surface + border + radius).
- **groupB**: More (`_FooterReaderIconActionButton`), **outside** the card, **transparent**, `Positioned(top: 0, right: 0)` in a `Stack`.
- **groupC**: `_buildReadingFooterRow` + `_MonoGroupedBackgroundContent.footerRow` — composition only; **no** extra full-width footer plate. Page fill still uses `readingBg` on `_MonoGroupedBackgroundContent` (unchanged).

## Split Background Implementation

- **`_MonoGroupedBackgroundContent`** now takes a single **`footerRow`** widget (no separate `metaGroup` / `learnGroup`).
- **`_buildReadingFooterRow`** returns `AnimatedBuilder` → `Stack` with:
  - **Padding** `right: kSlotSize + _footerCardToMoreGap` so the card does not run under More.
  - **`_FooterMetaReactCard`** → `Row` (`Expanded(meta)`, gap, `_MonoFooterReactColumn`).
  - **`Positioned`** More button top-right, same sheet callback as before.

## GroupA Meta/React Card

`_FooterMetaReactCard`: `surface` at alpha **0.68**, `border` at **0.65** alpha, **12** corner radius, symmetric padding **10h / 8v**. React styling and count unchanged inside `_MonoFooterReactColumn`.

## GroupB Transparent More

More uses the existing **`_FooterReaderIconActionButton`** (`NoSplash`, transparent `Material`, `textSecondary` icon, semantics `'More actions'`). No surface behind it.

## Meta Padding Adjustment

`_PostFooterMeta`: **`_metaColumnTopInset = 3`** — `SizedBox` before the username row. Existing **4px** name→title and title→status gaps unchanged. **No** extra bottom padding after the status chip.

## Behavior Preservation

Follow, React, More sheet, Learn/Save/Share wiring unchanged. No handle or description.

## Theme / Accessibility

Card colors from **`surface`** and **`border`** tokens only. More remains token-colored; full footer height is measured via **`_MeasureSize`** wrapping the composed footer (card + overlay) so story `contentH` stays consistent.

## Tests Added

`m12b_mono_reader_actions_rail_more_sheet_test.dart` asserts `Stack` / `Positioned` / `_FooterMetaReactCard` / `_MonoFooterReactColumn`, grouped content uses `footerRow`, React column has no `Icons.more_horiz`, single `more_horiz` in file, meta top inset and no bottom padding pattern, follow polish preserved.

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze` on those paths — no issues
- `flutter test test/features/mono` — 69 tests passed
- `flutter test` — 448 tests passed

## Manual Verification

- Card sits under meta + heart only; three dots float on the reading background at the trailing edge.
- Tap targets and sheet behavior unchanged.

## Remaining Risks

- If localized “Following” grows, min widths may need tuning.
- Very small widths: reserved More column plus card may squeeze meta; monitor ellipsis.

## Recommended Next Step

Optional golden of footer over cover vs reading page; inline Learn CTA still out of scope.

## M12b12 follow-up

M12b12 replaced the meta+React card with **meta-only** **`_FooterMetaBlurCard`**, moved **React** beside **More** in **`_MonoFooterTransparentActionColumn`**, and dropped **`Stack`/`Positioned`**. See [M12B12_READER_FOOTER_META_BLUR_ACTION_COLUMN_REPORT.md](M12B12_READER_FOOTER_META_BLUR_ACTION_COLUMN_REPORT.md).
