# M14K Create Shell Test Stabilization Report

## Problem

`test/create_shell_parent_child_flow_test.dart` failed in **Quiz module strict verification** → **A. Add per tab, filter, switch tabs, edit, delete, reorder, preview/help, save draft** at step 11 (**Save draft** via progress drawer).

Symptoms (expanded `flutter test`):

- `expect(find.byKey('creator_progress_drawer'), findsOneWidget)` failed (**0** widgets).
- `tap()` on `creator_progress_open_button` warned that the offset would not hit the target; the framework described the header `IconButton` as non-interactive in that configuration.
- Logs still showed normal creator readiness (`duration=missing`, story basics unmet) — **not** evidence that product code intentionally disabled the Progress control; the Progress menu callback in `story_creator_sentences_screen.dart` remains wired to `_openProgressDrawer`.

## Root Cause

Stacked **modal bottom sheets** (quiz **Test-play** previews) were **not reliably dismissed** by `tapAt(const Offset(500, 80))` on the test surface (**1000×1600**). That point often lies under the **floating sentences header**, so the barrier/scrim never received the tap, sheets stayed open, and a **full-screen modal barrier** continued to sit above the story UI. Subsequent taps (including **Progress**) missed the real control or behaved as if the control were inactive.

The **fit-to-content help sheet** (`showCreatorFitInfoBottomSheet` / `creatorFitInfoBottomSheetKey`) sometimes needed an explicit **`Navigator.pop`** on the **local** navigator after **Got it**, plus clock-driven pumps, so the Material route finished tearing down before opening the drawer.

**Test-play** sheets are shown with `showModalBottomSheet` without `useRootNavigator: true`; in this app shell they are still closed reliably from the test by calling **`Navigator.of(elementInsideSheet, rootNavigator: true).pop()`** and then pumping wall-clock deltas until the title `Text` disappears. The **help** sheet must **not** use `rootNavigator: true` for that pop, or the **GoRouter** host route can be popped instead of only the sheet.

## Scope

- **Changed:** `test/create_shell_parent_child_flow_test.dart` only (dismissal sequencing, drawer open settling, import of fit-info sheet keys).
- **Unchanged:** Public profile, profile providers, backend, validation rules, media upload, dark surfaces, creator product logic for Progress/publish/readiness.

## Fix Applied

- Dismiss **Test-play: Sentence** and **Test-play: Grammar** modals with **`Navigator.of(..., rootNavigator: true).pop()`** from a context under the sheet title, then **bounded** `pump(Duration)` loops until the title finder is empty.
- Dismiss **How to create quiz items** by tapping **`creatorFitInfoGotItButtonKey`**, pumping, then if **`creatorFitInfoBottomSheetKey`** remains, **`Navigator.of(...).pop()`** without `rootNavigator: true`, with the same style of timed pumps until the sheet key is gone.
- **`_openDrawer`:** replace open-ended `pumpAndSettle()` after the Progress tap with a **bounded** loop of `pump(Duration)` until `creator_progress_drawer` appears (avoids rare settle hangs and matches drawer animation).

## Test Changes

- File: `test/create_shell_parent_child_flow_test.dart`.
- Import: `creator_fit_info_bottom_sheet.dart` for **`creatorFitInfoBottomSheetKey`** / **`creatorFitInfoGotItButtonKey`**.
- No changes to `creator_progress_drawer.dart` or `story_creator_sentences_screen.dart` for M14K.

## Commands Run

- `flutter test test/create_shell_parent_child_flow_test.dart -r expanded` (during diagnosis; final green run used default reporter).
- `flutter test test/create_shell_parent_child_flow_test.dart`
- `flutter test test/features/create` — **122 passed**.
- `flutter test` — **626 passed, 0 failed**.

## Result

- **Create shell** parent/child + quiz strict verification: **pass**.
- **Create feature** tests: **pass**.
- **Full** `flutter test`: **pass**.

## Remaining Risks

- Dismissal still assumes **one** Test-play sheet per preview; if the product ever nests additional named routes on the root navigator, **`rootNavigator: true`** pops would need to be revisited.
- Fit-info **Got it** should remain wired to `Navigator.pop(ctx)`; if that API changes, the fallback local **`Navigator.pop`** path may need the same review.
