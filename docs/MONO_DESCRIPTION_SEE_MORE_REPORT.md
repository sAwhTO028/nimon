# Mono Description See More Report

## Files Changed

- `lib/features/mono/expandable_footer_description.dart` — New stateful widget: 2-line collapsed preview, `TextPainter` overflow check, compact **See more** / **See less** control; expanded body is scroll-capped to avoid layout overflow.
- `lib/features/mono/mono_screen.dart` — `_PostFooterMeta` uses `ExpandableFooterDescription` for `subtitleLine` (Story Basics) instead of a plain two-line `Text`.
- `test/features/mono/expandable_footer_description_test.dart` — Unit + widget tests for visibility, overflow detection, and expand/collapse taps.

## Root Cause

Story Basics in the Mono footer was rendered as a fixed **max two lines + ellipsis** `Text` with no way to read the rest. Long descriptions were effectively truncated with no affordance.

## New Expand / Collapse Behavior

- **Collapsed (default):** `maxLines: 2`, `TextOverflow.ellipsis`, same footer typography as before.
- **Overflow detection:** `ExpandableFooterDescription.textExceedsPreviewLines` uses `TextPainter` with the same `TextStyle` and `LayoutBuilder` max width so **See more** appears only when content would exceed two lines.
- **Expanded:** Full text is shown **untruncated** inside a **`SingleChildScrollView`** with **`maxHeight: 172`** so the footer stays compact and the reading surface does not throw `RenderFlex` overflows on very long copy. **See less** returns to the two-line preview.
- **State:** Local `_expanded` flag on the widget only (per card instance).

## Visibility Rules

- Trimmed empty string → `SizedBox.shrink()` (parent `_PostFooterMeta` still omits the spacer + widget when `subtitleLine` is blank).
- Text fits in two lines → no **See more** / **See less** row.
- Text exceeds two lines → **See more** when collapsed; **See less** when expanded.

## Tests Added

- `textExceedsPreviewLines`: empty / non-positive width / long string on narrow width.
- Widget: empty → no controls; short → no **See more**; long → **See more**; tap expand/collapse; consistency check between painter and UI.

## Flutter Analyze Result

- `flutter analyze lib/features/mono/expandable_footer_description.dart test/features/mono/expandable_footer_description_test.dart` → **No issues found.**
- Analyzing `mono_screen.dart` together with the above still reports **pre-existing** infos/warnings in that large file (unchanged by this task).

## Flutter Test Result

- `flutter test test/features/mono` — **passed**
- `flutter test` — **All tests passed** (244 tests at time of run).

## Remaining Risks

- **Expanded height cap:** Extremely long descriptions require **scrolling inside the footer** rather than growing without bound; this is intentional for compactness and overflow safety.
- **Font / locale:** Overflow detection follows `TextPainter` with `TextDirection.ltr`; mixed-direction text is uncommon in this footer but could theoretically diverge slightly from on-screen line breaks.
