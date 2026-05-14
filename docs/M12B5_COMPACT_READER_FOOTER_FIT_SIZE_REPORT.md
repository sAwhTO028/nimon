# M12b5 Compact Reader Footer Fit Size Report

## Problem
- Footer was still too tall after M12b4.
- Follow button text could get clipped / disappear.
- Row 2 (title + status) alignment didn’t sit under the username column cleanly.

## Corrected Layout
- Meta group now matches the intended structure:
  - Left column: avatar (single instance)
  - Right column: a compact 2-row text block
    - Row 1: `Flexible(username)` + Follow button (Follow keeps visible text)
    - Row 2: title (ellipsis) + status chip

## Follow Button Text Fix
- Removed `Expanded`-style squeezing pressure by making **username flexible** (ellipsizes first) and keeping the Follow button as a fixed widget.
- Added a small **minimum width** constraint to the Follow button so the label can’t collapse to nothing.

## Row 2 Alignment
- Because the avatar sits outside the text column, Row 2 naturally aligns under username (no “far left” start).

## Height Reduction
- Reduced internal spacing:
  - avatar + text gap tightened
  - row gap reduced
- No description rendered in footer.

## Action Rail Preservation
- React + More rail unchanged (icon-only More, semantics “More actions”, bottom sheet unchanged).

## Tests Added
- Updated footer meta test to assert:
  - no handle / no description
  - `_WriterFooterAvatar` appears exactly once in `_PostFooterMeta`

## Commands Run
- `dart format` (touched files)
- `flutter analyze` (touched paths)
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification
- Footer:
  - avatar appears once
  - Row 1: username + Follow (label visible)
  - Row 2: title + status chip aligned under username
  - no description
- Rail:
  - React + More unchanged

## Remaining Risks
- Extreme text scaling may still cause tighter layouts; username will ellipsize first while preserving Follow label.

## Recommended Next Step
- Quick device pass (small phone + larger text scale) to confirm the follow label remains visible and the footer feels “fit-size”.

