# P2 Trash UX Polish Report

## Files Changed

- `lib/features/profile/profile_trash_screen.dart`
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart`
- `test/features/mono/mono_story_options_trash_test.dart`
- `test/features/profile/profile_trash_screen_gate_test.dart`

## Back Icon Fix

- `ProfileTrashScreen` now uses the standard `NimonBackButton` (same circular affordance + `arrow_back_ios_new_rounded`) instead of a plain `Icons.arrow_back` icon button.

## Move To Trash Dialog Layering Fix

**Problem:** confirmation dialog could appear behind the story details dock overlay.

**Fix:** `Move to Trash` now:

1. Closes the dock overlay first (`onClose?.call()`).
2. Waits a microtask (`await Future<void>.delayed(Duration.zero)`) so the overlay is removed.
3. Shows the dialog using the **stable host context** (`hostContextForActions`) with `useRootNavigator: true`.

## Cancel / Confirm Behavior

- **Cancel**: dialog closes and the original story options panel is reopened for the same `MonoFeedItem`.
- **Confirm**:
  - Calls `POST /v1/published-monos/:id/trash` via repository.
  - Shows snackbar **Moved to Trash.**
  - Does **not** reopen the options panel.

## Post-trash Navigation / Refresh

- Refresh: `bumpPublishedMonoTrashSurfacesRefresh(container)` + `profilePublishedMonoPagerProvider.refresh()` (existing Mono feed + Profile published/processing refresh listeners still apply).
- Navigation: after a successful trash, if the host route can pop, it calls `Navigator.of(host).maybePop()` to return to the previous surface (typically Profile Published list when in the Profile reader route).

## Story Description Fix

**Problem:** the quote/summary card displayed `bodyText` (reading text) instead of Story Basics metadata.

**Fix:** the description card now renders `MonoFeedItem.storyDescription` and is **hidden** when empty.

## Tests Added

- `test/features/mono/mono_story_options_trash_test.dart`
  - Dialog closes the sheet and Cancel reopens.
  - Confirm calls repo and does not reopen.
  - Asserts description card shows `storyDescription`.
- `test/features/profile/profile_trash_screen_gate_test.dart`
  - Asserts there is no `BackButton` (ensures we’re using the standard `NimonBackButton` approach).

## Flutter Analyze Result

`flutter analyze lib/features/profile/profile_trash_screen.dart lib/ui/bottom_sheets/mono_story_options_sheet.dart test/features/mono/mono_story_options_trash_test.dart test/features/profile/profile_trash_screen_gate_test.dart`

- **No issues found.**

## Flutter Test Result

- `flutter test test/features/profile` — **passed**
- `flutter test test/features/mono/mono_story_options_trash_test.dart` — **passed**
- `flutter test` — **All tests passed**

## Manual Verification Steps

1. Open Profile → Published story → options → **Move to Trash**.
2. Confirm the dialog appears above the page (not behind the dock panel).
3. Tap **Cancel** → options panel returns.
4. Tap **Move to Trash** again → confirm → snackbar appears → user returns to previous surface; story disappears from Published and appears in Trash list.
5. Verify the quote/description card shows Story Basics description (and is hidden when empty).

## Remaining Risks

- Navigation “return to Published surface” is implemented as `maybePop()` on the host route; if this panel is used from a non-reader surface that can pop unexpectedly, we may need to further scope this to known reader routes in a future pass.

