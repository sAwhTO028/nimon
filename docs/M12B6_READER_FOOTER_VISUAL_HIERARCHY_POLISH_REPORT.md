# M12b6 Reader Footer Visual Hierarchy Polish Report

## Problem
- Follow / Following pill text could become unreadable or “disappear” in certain screenshot conditions.
- Status chip competed with the story title by sharing the same row.
- Username and title weights/sizes were too similar.
- Footer rail + meta group looked better visually bottom-aligned.

## Follow Button Text Fix
- Follow and Following now use an explicit, high-contrast pill:
  - background: `theme.colors.textPrimary` (muted alpha)
  - foreground/text: `theme.colors.appBackground`
  - disabled colors explicitly set
- Added `minWidth` constraints and `Text(maxLines: 1, softWrap: false)` so label remains visible.

## Meta Hierarchy Update
- Meta text column is now 3 rows:
  1. Username + Follow/Following
  2. Story title (1 line, ellipsis)
  3. Status chip (level + mode)

## Status Chip Placement
- Status chip moved **below the title**, aligned with the title’s start (same text column).

## Font Hierarchy
- Username slightly stronger than title:
  - username uses a slightly larger size + heavier weight
  - title slightly smaller and a touch muted

## Action Rail Alignment
- Bottom-aligned the rail with the meta group (`crossAxisAlignment: CrossAxisAlignment.end`) while keeping rail behavior unchanged.

## Behavior Preservation
- Follow toggling unchanged (same repositories/endpoints, same guest messaging).
- React and More unchanged; More sheet content unchanged.
- Description remains removed; handle remains removed.

## Theme / Accessibility
- Uses existing theme tokens (`textPrimary`, `appBackground`, `textSecondary`, `surface`, `border`).
- Semantics labels preserved (More actions, Follow/Following).

## Tests Added
- Updated mono footer tests to assert:
  - no handle / no description
  - chip-row separation signal (spacing marker)
  - More semantics + rail remains React + More only

## Commands Run
- `dart format` (touched files)
- `flutter analyze` (touched paths)
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification
- Footer shows:
  - readable Follow/Following text in light/dark mode
  - title on its own row
  - status chip under title
  - username visually stronger than title
- Rail bottom-align feels cohesive with footer baseline.

## Remaining Risks
- Extremely large text scales may still compress the username; username ellipsizes before Follow label.

## Recommended Next Step
- Quick physical device pass in dark mode + large text scale to confirm follow label contrast is ideal.

