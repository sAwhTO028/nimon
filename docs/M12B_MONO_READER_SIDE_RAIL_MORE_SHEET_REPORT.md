# M12b Mono Reader Side Rail More Sheet Report

## Scope

This milestone implements **M12b** from `docs/MONO_READER_ACTIONS_REDESIGN_DECISION_SPEC.md`:

- Reader action rail shows only **React** + **More**.
- Secondary actions move into a **More** bottom sheet:
  - **Learn this story** (Full Learn only)
  - **Save / Unsave** (policy-aware)
  - **Share** (uses canonical `shareUrl` behavior)

Out of scope (deferred):

- Inline **Start Learn** CTA inside the reader body (**M12c**).
- Backend changes, share URL standardization, feed pagination changes.

## Side Rail Changes

**Before:** rail contained React, Learn, Save, Share.

**After:** rail contains:

1. **React** (one tap; count label preserved; active/inactive token colors preserved)
2. **More** (3-dots) with semantics label **“More actions”**

Removed from visible rail:

- Learn
- Save / Bookmark
- Share

## More Bottom Sheet

Added a token-based bottom sheet titled **“Mono actions”**.

Rows:

1. **Learn this story**
   - Shown only when `PublishedMonoAccess.isFullLearnPublished == true`.
   - Uses the existing Learn handler (same routing target as prior Learn rail action).
2. **Save / Saved**
   - Shown only when bookmark policy allows (own-content rule preserved).
   - Uses the existing bookmark toggle handler (guest/auth behavior unchanged).
3. **Share**
   - Uses the existing share helper (`shareMonoLink`).
   - If the resolved share URL is unavailable, the row is disabled and shows **“Share link unavailable”**.

Sheet style:

- Background: `theme.colors.surface`
- Labels: `textPrimary`
- Subtitles/disabled: `textSecondary`
- Divider: `border` (via `Divider`)
- `ListTile` ensures minimum tap targets and native semantics.

## Learn Availability Rule

Learn row is shown only when:

- `item.publishedAccess?.isFullLearnPublished == true`

Tap behavior continues to be owned by the existing Learn handler (which already enforces any deeper constraints like `learnModulesInPayload` messaging).

## Bookmark Policy Preservation

Bookmark row visibility remains governed by:

- `canBookmarkMono(currentUserId, monoOwnerId)`

If the mono is not bookmark-eligible (e.g. own content), Save is omitted from the sheet (no invalid actions presented).

## Share Policy Preservation

- Share continues to use `MonoFeedItem.shareUrl` when present.
- Client fallback behavior remains in `share_mono_link.dart` and refuses loopback origins.
- No localhost share URLs are reintroduced.

## Theme / Accessibility

- Rail and sheet continue to use token colors (`surface`, `textPrimary`, `textSecondary`, `react`, etc.).
- More button includes a semantics label (**“More actions”**).
- Bottom sheet actions are built from `ListTile` for consistent tap target sizing and accessibility.

## Tests Added

- `test/features/mono/m12b_mono_reader_actions_rail_more_sheet_test.dart`
  - Asserts the rail contains **React + More** only (Learn/Save/Share removed from `_BottomActionRail`).
  - Asserts More sheet gates Learn on **Full Learn** (`isFullLearnPublished == true`).

## Commands Run

Run locally from the project root:

- `dart format` on touched Dart sources under `lib/` and the new test.
- `flutter analyze` on touched paths.
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification

- React is still one tap
- More opens bottom sheet
- Full Learn mono shows Learn in sheet
- Non-Full Learn mono does not show Learn in sheet
- Bookmark respects own-content policy
- Share uses standardized `shareUrl`
- Dark/light mode sheet is readable

## Remaining Risks

- Learn discoverability now depends more on the More sheet until **M12c** adds the inline CTA.
- If product later requires `learnModulesInPayload == true` to show Learn, the visibility rule will need tightening.
- Any reader-rail layout changes risk spacing regressions; verify on small screens + dynamic text.

## Recommended Next Step

Implement **M12c**: inline Full Learn CTA inside the reader body so Learn is not hidden behind More.

