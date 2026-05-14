# M12b12 Reader Footer Meta Blur + Transparent Action Column Report

## Problem

M12b11 put **meta and React** on one **`_FooterMetaReactCard`** and floated **More** with **`Stack`/`Positioned`**. Product wanted the **card blur only behind meta**, with **More and React** sharing a **single transparent column** over the story/cover pixels.

## Final Product Model

- **groupA**: **`_FooterMetaBlurCard`** wraps **`_PostFooterMeta` only** (avatar, username + Follow, title, status chip).
- **groupB**: **`_MonoFooterTransparentActionColumn`** — **More** above **React** + optional count; **no** `DecoratedBox` / surface on the column.
- **groupC**: **`_buildReadingFooterRow`** — **`Row`** (`Expanded` meta card, **`SizedBox(8)`**, action column); **no** `Stack`, **no** shared footer plate beyond page `readingBg`.

## Meta Blur Card

**`_FooterMetaBlurCard`**: `ClipRRect` → **`BackdropFilter`** (`ImageFilter.blur` σ=10) → **`DecoratedBox`** with **`surface`** @ **`_fillAlpha` 0.42**, **`border`** @ **0.45** alpha, radius **12**, padding **10×7**. Tokens only (`surface`, `border`).

## Transparent Action Column

**`_MonoFooterTransparentActionColumn`**: fixed width **52**, **`Column`** with two **`_FooterReaderIconActionButton`** instances (**`betweenActions` = 5**), count under React when `likesCount > 0`. No background widgets.

## React Relocation

React moved **out** of the meta card into the action column with More; behavior and semantics unchanged (`monoReactRailSemanticsLabel`, `react` / `textPrimary` colors).

## Meta Padding Adjustment

**`_metaColumnTopInset`** increased **3 → 4**. Name/title/status gaps remain **4**. No bottom spacer after the status chip; card vertical padding **8 → 7** to avoid a taller footer.

## Behavior Preservation

Follow, guest sign-in snack, React toggle, More sheet (Learn/Save/Share), share URL logic unchanged.

## Theme / Accessibility

Blur + translucent fill use theme tokens. Icon buttons unchanged (**44** slot, **`NoSplash`**, **`'More actions'`** semantics).

## Tests Added

`m12b_mono_reader_actions_rail_more_sheet_test.dart` asserts **`Row`** footer (no **`Stack`/`Positioned`**), **`_FooterMetaBlurCard`** + **`BackdropFilter`**, action column with **two** icon buttons and **no** `DecoratedBox`, old **`_FooterMetaReactCard` / `_MonoFooterReactColumn`** absent, meta compact + top inset **4**, single **`Icons.more_horiz`**.

## Commands Run

- `dart format lib/features/mono/mono_screen.dart test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
- `flutter analyze` on those paths — no issues
- `flutter test test/features/mono` — 69 tests passed
- `flutter test` — 448 tests passed

## Manual Verification

- Story/cover shows through beside the meta card and behind the action column.
- Meta reads as frosted glass; heart and three-dots align vertically.

## Remaining Risks

**`BackdropFilter`** has a small GPU cost; scope is limited to the meta card.

## Recommended Next Step

Optional performance flag to fall back to translucent-only (no blur) on low-end devices; inline Learn CTA still out of scope.

## M12b13 follow-up

M12b13 **removed** **`_FooterMetaBlurCard`** entirely so meta is **fully transparent** like the action column. See [M12B13_READER_FOOTER_TRANSPARENT_META_REPORT.md](M12B13_READER_FOOTER_TRANSPARENT_META_REPORT.md).
