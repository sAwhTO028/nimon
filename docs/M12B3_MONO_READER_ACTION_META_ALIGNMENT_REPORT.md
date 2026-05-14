# M12b3 Mono Reader Action Meta Alignment Report

## Problem
- Reader action rail (React + 3-dots) felt visually “detached” from the author/title/description meta block.
- The sentence/text page used a right-side arrow-FAB expand/collapse system (drop-up/down icons) that did not match the cover page’s premium meta/action presentation.
- More must remain icon-only (no visible “More” label).

## Action Rail Alignment
- Restructured the bottom footer area into a single `Row`:
  - Left: `Expanded` meta/content block
  - Right: fixed-width rail container
- Rail now sits alongside the meta group (top-aligned), rather than being positioned separately at the bottom-right overlay.

## Padding / Margin Cleanup
- Removed the read-mode arrow-FAB expand/collapse behavior.
- Rail buttons are icon-only with a compact like count under the heart when \(likesCount > 0\).

## Story Sentence View Consistency
- The sentence/text page now uses the same bottom meta + action layout as the cover/image page (since both share the same footer row structure).

## Drop Icon Removal
- Deleted the arrow-FAB system that used `Icons.keyboard_arrow_down` / `Icons.keyboard_arrow_up` in read mode.

## More Sheet Preservation
- More remains icon-only and keeps semantics label “More actions”.
- Tapping More still opens the same bottom sheet and preserves:
  - Learn gating (Full Learn only)
  - Save/Unsave policy-aware behavior
  - Share behavior

## Theme / Accessibility
- No new colors introduced; existing tokens are used.
- Semantics label “More actions” preserved for the icon-only 3-dots button.

## Tests Added
- Updated mono rail tests to assert:
  - No `label: 'More'`
  - “More actions” semantics label still present
  - No read-mode arrow-FAB / drop icon system remains

## Commands Run
- `dart format` (touched files)
- `flutter analyze` (touched paths)
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification
- Cover page:
  - Meta block on left; heart + 3-dots rail on right; no visible labels.
  - Like count only shows when \(> 0\).
- Sentence/text page:
  - No arrow-FAB drop-up/down control on the right.
  - Same meta + action rail presentation as cover page.
- More:
  - Opens bottom sheet; contents unchanged.

## Remaining Risks
- Very large text scales may still require small spacing adjustments, but the structural alignment (Row + fixed rail width) is stable.

## Recommended Next Step
- Quick physical-device pass (small screen + larger text scale) to confirm the rail alignment feels correct and actions remain comfortably tappable.

