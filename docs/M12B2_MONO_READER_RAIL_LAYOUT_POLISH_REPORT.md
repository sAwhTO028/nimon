# M12b2 Mono Reader Rail Layout Polish Report

## Problem
- Mono footer text (writer/title/description + “See more”) could visually flow under the right-side action rail.
- The More action showed a visible “More” label under the 3-dots icon (undesired clutter).
- Expand/collapse affordance should remain minimal and premium (text-first).

## Rail Label Cleanup
- Removed the visible label under the 3-dots icon (icon-only).
- Kept accessibility via semantics label: “More actions”.

## Description Overlap Fix
- Reserved a fixed right inset for the footer meta text column equal to `railWidth + spacing`, so text never renders under the rail hit-area.

## Expand Control Polish
- Description preview continues to use text-only controls (“See more” / “See less”) via `ExpandableFooterDescription`.
- No arrow / drop-up icon is used for the description expand control.

## More Sheet Preservation
- The More bottom sheet open behavior is unchanged.
- Action gating remains unchanged:
  - Learn only when Full Learn is available
  - Save/Unsave remains policy-aware
  - Share remains available and uses the standardized share URL flow

## Theme / Accessibility
- Continued to use existing theme tokens already in use by the reader (no hardcoded palette changes).
- “More actions” semantics label preserved after removing the visible label.

## Tests Added
- Updated existing rail test to assert:
  - semantics label “More actions” is present
  - no `label: 'More'` exists in the rail widget construction

## Commands Run
- `dart format` (touched files)
- `flutter analyze` (touched paths)
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification
- Open a mono with a long description:
  - ensure description/“See more” does not collide with the right rail
- Tap 3-dots:
  - confirm bottom sheet opens and contents match M12b
- Confirm the rail has no visible “More” text label.

## Remaining Risks
- Pixel-perfect overlap can vary by device font scaling; the fixed inset should cover the rail width, but very large text scales may still require follow-up tuning.

## Recommended Next Step
- Run a quick physical-device check (small phone + large text scale) to confirm the footer inset is sufficient in all expected reading modes.

