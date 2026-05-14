# M12b4 Compact Reader Meta Group Report

## Problem
- The reader footer meta group was too tall and information-dense (handle + multi-line title + description).
- The redesigned rail (React + More) should stay unchanged, while the **meta group** becomes compact and premium.

## New Meta Group Layout
- **Row 1**: avatar + **username only** + Follow button
- **Row 2**: story title (1 line, ellipsis) + compact status chip (`<level> · Read only` / `<level> · Full Learn`)

## Removed Fields
- Removed **handle** display from the reader footer.
- Removed **description** (and its See more/See less control) from the reader footer.

## Follow Button Behavior
- Visible only when:
  - `writerId` is present, and
  - viewer is not the owner (`currentUserId != writerId`)
- Uses existing follow wiring:
  - Reads initial follow state via public profile fetch (optional-auth).
  - Follow/Unfollow via existing follow endpoints.
  - Guest taps show the existing “sign in to follow” message.

## Story Title / Status Chip
- Title:
  - `maxLines: 1`
  - `TextOverflow.ellipsis`
- Status chip:
  - `Full Learn` when `publishedAccess?.isFullLearnPublished == true`
  - Otherwise `Read only`
  - Level prefix included when present (e.g. `N2 · Full Learn`)

## Height Reduction
- Avatar reduced to a compact size (38px).
- Removed the entire description block.
- Tightened vertical rhythm between rows (4px gap).

## Action Rail Preservation
- Rail remains:
  - React + More only
  - More is icon-only with semantics label “More actions”
  - Like count remains compact (only shown when > 0)
- More bottom sheet behavior/content unchanged.

## Theme / Accessibility
- Used existing tokens only (no hardcoded new palette).
- Kept semantics labels for key actions (More + Follow).

## Tests Added
- Updated mono reader tests to verify footer meta:
  - does not contain handle
  - does not contain description widget
  - contains Follow button widget
  - contains both status labels (`Read only`, `Full Learn`) in code paths

## Commands Run
- `dart format` (touched files)
- `flutter analyze` (touched paths)
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification
- Open a mono:
  - footer shows avatar + username + Follow (if not owner)
  - footer shows title (1 line) + status chip
  - no handle, no description
- More:
  - still opens actions sheet (Learn/Save/Share) unchanged

## Remaining Risks
- Initial follow state requires a single profile fetch per creator; if this proves too heavy, we can swap to a cached/provider-backed approach later.

## Recommended Next Step
- Quick device pass to confirm:
  - footer height is meaningfully reduced
  - Follow button doesn’t feel cramped at common text scales

