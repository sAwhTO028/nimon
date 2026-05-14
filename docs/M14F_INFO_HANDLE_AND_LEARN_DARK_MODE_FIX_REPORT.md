# M14F Info Handle and Learn Dark Mode Fix Report

## Problem

1. **Creator info sheets (post M14E):** Fit-to-content height was correct, but the modal **drag handle appeared detached** near the top of the screen instead of inside the rounded sheet. Root cause: Flutter’s modal **`showDragHandle: true`** draws the handle in the modal chrome above the transparent sheet body, while the visible card is a bottom-aligned `Material` inside the builder—so the handle and the card were visually **decoupled**.
2. **Learn subpages:** The Learn hub respected dark mode, but **Grammar detail**, **Quiz** (setup / play / results), and **Listening** still used **light-only** backgrounds, ink colors, and/or white cards from `QuizFlowTheme` or static `Color` constants.

## Scope

- Creator fit info bottom sheet API and layout only (no copy, validation, or localization changes).
- Learn reader surfaces: grammar pattern **detail**, quiz **setup / play / results**, **listening** (catalog scaffold + playback view + transcript). Vocabulary/grammar **list** screens were already theme-aware.
- Tests: handle alignment + learn dark propagation; M14E height tests adjusted where the logical window equals the **0.80** max-height cap.
- No backend changes.

## Info Sheet Handle Root Cause

`showModalBottomSheet(..., showDragHandle: true)` with `backgroundColor: Colors.transparent` and a **separate** inner `Material` sheet: the framework paints the drag handle **outside** the inner rounded container, so it floats high on the viewport.

## Info Sheet Fix

- `showCreatorFitInfoBottomSheet`: **`showDragHandle: false`**.
- **Custom 44×4** pill as the **first** child in the scrollable column, keyed `creatorFitInfoBottomSheetHandle`, using `colorScheme.onSurfaceVariant` with alpha **0.55**.
- **`creatorFitInfoBottomSheetKey`** remains on the sheet `Material` so tests measure the real card.
- **Fit-to-content preserved:** `Column` `mainAxisSize.min`, `ConstrainedBox` **maxHeight ~0.80** only, no fractional min height, no `Expanded` in the main column.

## Learn Subpage Dark Mode Root Cause

- **Grammar detail:** Hardcoded paper background and **white** `_SurfaceCard` fills with light-only mistake chips.
- **Quiz flow:** `QuizFlowTheme.pageBg` / `ink` / white option surfaces tied to a fixed light quiz aesthetic.
- **Listening:** Hardcoded warm `_bg` and light player card independent of `ColorScheme`.

## Learn Subpage Fix

- Page scaffolds use **`learnModuleListPageBackground(context)`** so dark mode matches the hub (`surface` in dark).
- Text uses **`ColorScheme.onSurface` / `onSurfaceVariant`** (or `learnCreatorModulePrimaryTextColor` / `Secondary` where appropriate).
- Cards / floating player use **`learnCreatorModuleCardSurfaceColor` / `learnCreatorModuleCardBorderColor`** (and action emphasis via **`learnCreatorModuleActionForegroundColor`** where it improved contrast).
- Quiz play **feedback** and option **revealed** states: keep `QuizFlowTheme` tints in **light**; in **dark**, map to **`ColorScheme` tertiary / error** roles so states stay readable.
- No local `Theme` wrapper forcing light mode; no `ThemeMode.light` on these routes.

## Tests Added

- `test/features/create/m14f_info_sheet_handle_alignment_test.dart` — vocabulary + quiz sheets: handle `dy` within a few pixels of sheet top; height ≤ max cap; no overflow.
- `test/features/learn/m14f_learn_subpage_dark_mode_test.dart` — dark theme: vocab list, grammar list, quiz setup, listening demo scaffold vs `learnModuleListPageBackground`; title contrast; light vocab smoke for warm paper.
- `test/features/create/m14e_fit_info_bottom_sheet_test.dart` — grammar/quiz/listening height assertions relaxed to **`<= 0.80 * logical height + 1`** when content hits the max-height cap on the default test viewport.

## Commands Run

```bash
dart format lib/features/learn/grammar_pattern_detail_screen.dart lib/features/learn/quiz_setup_screen.dart lib/features/learn/quiz_result_screen.dart lib/features/learn/quiz_play_screen.dart lib/features/learn/listening_pronunciation_screen.dart test/features/create/m14f_info_sheet_handle_alignment_test.dart test/features/learn/m14f_learn_subpage_dark_mode_test.dart

flutter analyze lib/features/learn/grammar_pattern_detail_screen.dart lib/features/learn/quiz_setup_screen.dart lib/features/learn/quiz_result_screen.dart lib/features/learn/quiz_play_screen.dart lib/features/learn/listening_pronunciation_screen.dart

flutter test test/features/create/m14e_fit_info_bottom_sheet_test.dart test/features/create/m14f_info_sheet_handle_alignment_test.dart test/features/learn/m14f_learn_subpage_dark_mode_test.dart
flutter test test/features/create
flutter test test/features/learn
flutter test
```

Repo-wide `flutter test` was also run once: **554 passed, 1 failed** in `test/create_shell_parent_child_flow_test.dart` (“Quiz module strict verification …”) because `creator_progress_open_button` was **disabled** (tap did not open `creator_progress_drawer`). This failure is **outside M14F** touch paths; scoped `flutter test test/features/create` and `flutter test test/features/learn` both **passed**.

## Manual Verification

Phone **dark**: Learn hub → Vocabulary, Grammar (list + open a pattern), Quiz (setup → play one question → results if time), Listening — backgrounds dark, cards readable, info sheets (creator) show handle **inside** the sheet.

Phone **light**: Quick pass same routes; warm paper lists and light quiz tints unchanged in spirit.

## Remaining Risks

- **Listening** `just_audio` streams can keep frames pending; widget tests avoid `pumpAndSettle` on that screen.
- Long quiz/listening info copy can still grow to the **0.80** max height; scrolling remains the safety valve.
