# M14E Info Sheet Fit-to-Content Restore Report

## Problem

Creator module "how it works" / info bottom sheets (Storytelling, Vocabulary, Grammar, Quiz, Listening) used a **fixed tall shell** (`FractionallySizedBox` with `heightFactor: 0.88` in `showCreatorInfoBottomSheet`), leaving a large empty dark area below short bullet copy and the **Got it** button.

## Reference

`create_story_basics_form.dart` -> `_showStep1StatusBottomSheet`: `showModalBottomSheet` with `ConstrainedBox` **maxHeight only** (`0.88 * height`), `SingleChildScrollView`, inner `Column` with `mainAxisSize: MainAxisSize.min`, horizontal padding `20`, top radius `16`, `titleMedium` / `w700` title, and **no** forced fractional height on the sheet itself.

## Root Cause

`lib/features/create/widgets/creator_info_bottom_sheet.dart` wrapped content in `FractionallySizedBox(heightFactor: 0.88)`, forcing the modal body to occupy ~88% of viewport height regardless of content length.

## Helper Changed

New: `lib/features/create/widgets/creator_fit_info_bottom_sheet.dart`

- API: `showCreatorFitInfoBottomSheet(context, title, children, [actionLabel], [showActionButton])`
- `showModalBottomSheet`: `backgroundColor: Colors.transparent`, `isScrollControlled: true`, `useSafeArea: true`, `showDragHandle: false` (M14F: built-in handle disabled; custom pill inside sheet — see `docs/M14F_INFO_HANDLE_AND_LEARN_DARK_MODE_FIX_REPORT.md`).
- `Align` bottom + `ConstrainedBox(maxHeight: 0.80 * height)` **only** (no min height)
- `Material` + top radius **16**, `colorScheme.surface`
- `SingleChildScrollView` -> `Padding` -> `Column(mainAxisSize: min)` -> title (`titleMedium`, `w700`) + children + **Got it** `FilledButton`
- Test keys: `creatorFitInfoBottomSheetKey`, `creatorFitInfoTitleKey`, `creatorFitInfoGotItButtonKey`

`showCreatorInfoBottomSheet` now **delegates** to `showCreatorFitInfoBottomSheet` with `children: [body]` (same bullets/widgets, fit height).

`showNimonScrollableHelpBottomSheet` delegates to `showCreatorFitInfoBottomSheet` with a single `Text` child (quiz/listening copy unchanged).

## Sheets Migrated

| Sheet | Entry |
| --- | --- |
| Storytelling | `story_creator_sentences_screen.dart` `_showHowThisWorks` |
| Vocabulary / Semantics | `story_creator_sentences_screen.dart` `_showVocabHowTo`, `story_creator_vocab_kanji_editor_screen.dart` `_showVocabHowTo` |
| Grammar | `story_creator_grammar_overlays.dart` `showHowTo` |
| Quiz | `story_creator_sentences_screen.dart` `_showQuizHowTo` via `showNimonScrollableHelpBottomSheet` |
| Listening | `story_creator_sentences_screen.dart` `_showListeningHowTo` via `showNimonScrollableHelpBottomSheet` |

## Height Behavior

- Short bullet / section content: sheet height tracks intrinsic content (well below old 88% blank slab).
- Long plain-text (quiz/listening): height grows until **max ~80%** of screen, then scrolls inside `SingleChildScrollView`.

## Tests Added

`test/features/create/m14e_fit_info_bottom_sheet_test.dart` (height + keys + overflow checks).

## Commands Run

```bash
dart format lib/features/create/widgets/creator_fit_info_bottom_sheet.dart lib/features/create/widgets/creator_info_bottom_sheet.dart lib/ui/widgets/nimon_scrollable_help_bottom_sheet.dart lib/features/create/story_creator_sentences_screen.dart lib/features/create/story_creator_vocab_kanji_editor_screen.dart lib/features/create/story_creator_grammar_overlays.dart test/features/create/m14e_fit_info_bottom_sheet_test.dart

flutter analyze lib/features/create/widgets/creator_fit_info_bottom_sheet.dart lib/features/create/widgets/creator_info_bottom_sheet.dart lib/ui/widgets/nimon_scrollable_help_bottom_sheet.dart lib/features/create/story_creator_sentences_screen.dart lib/features/create/story_creator_vocab_kanji_editor_screen.dart lib/features/create/story_creator_grammar_overlays.dart test/features/create/m14e_fit_info_bottom_sheet_test.dart

flutter test test/features/create/m14e_fit_info_bottom_sheet_test.dart
flutter test test/features/create
flutter test test/features/learn
flutter test
```

## Manual Verification

On device: open Story Basics progress sheet, then Storytelling / Vocabulary / Grammar / Quiz / Listening info sheets; confirm sheet height hugs content, **Got it** sits just below copy, no huge empty region, no overflow. Repeat quick light-mode check.

## Remaining Risks

Very long future info content could approach the **~0.80** max height; scroll should prevent overflow. Other non-info bottom sheets (add/edit, review lists) were intentionally not changed.

## M14F follow-up

Fit-to-content and max-height behavior are unchanged. M14F moves the drag pill **inside** the rounded sheet (`creatorFitInfoBottomSheetHandle` key) so it does not render detached at the top of the screen when `showDragHandle` was true. Widget tests for handle alignment live in `test/features/create/m14f_info_sheet_handle_alignment_test.dart`. Learn subpage dark mode propagation is documented in `docs/M14F_LEARN_SUBPAGE_DARK_MODE_AUDIT.md` and `docs/M14F_INFO_HANDLE_AND_LEARN_DARK_MODE_FIX_REPORT.md`.
