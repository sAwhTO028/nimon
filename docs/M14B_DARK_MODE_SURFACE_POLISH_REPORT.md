# M14B Dark Mode Surface Polish Report

## Problem

Phone QA in dark mode showed **low-contrast text**, **light-only card surfaces**, and **bottom sheet overflow** (quiz/listening how-to) on small viewports.

## Scope

Flutter UI only: profile icon tabs, Create add tab, reader learn lists (vocab, grammar, hub), creator quiz/listening modules and related bottom sheets. **No** behavior, validation, routing, or backend changes.

## Profile Tab Fix

`_ProfileIconTabs` now uses `ColorScheme.onSurface` / `onSurfaceVariant` and `primary` for the selected indicator; dividers use `outlineVariant` with a controlled alpha.

## Add Page Fix

`StoryCreatorAddTabScreen` section headers and featured draft title use theme roles instead of fixed warm ink colors; mini chips use `onSurface`.

## Vocabulary / Semantics Fix

`VocabKanjiListScreen` scaffold, app bar, empty/error bodies, and list cards use `learn_module_surface_tokens.dart` plus `onSurface` / `onSurfaceVariant`.

## Grammar Fix

`GrammarPatternListScreen` mirrors the vocabulary list token pattern. Grammar overlay titles use explicit `onSurface` where needed.

## Quiz Fix

`StoryCreatorQuizEditorScreen`: module header and count line use scheme colors; `_EmptyState` and `_QuizCard` use `surfaceContainerHigh` and `outlineVariant` borders; add/edit sheet uses `surface` instead of cream paper.

## Listening Fix

`StoryCreatorListeningModuleBody` headers use scheme colors; `_EmptyState` / `_AudioSummaryCard` use elevated dark surfaces. Audio upsert sheet background uses `surface`.

## Bottom Sheet Overflow Fix

Shared `showNimonScrollableHelpBottomSheet` implements scroll, fractional max height, `SafeArea`, and keyboard bottom padding. Quiz and listening how-to flows in `story_creator_sentences_screen.dart` call this helper.

## Shared Helpers

- `lib/features/learn/learn_module_surface_tokens.dart` — warm paper in light, `surface` / `surfaceContainerHigh` in dark for learn list pages and cards.
- `lib/ui/widgets/nimon_scrollable_help_bottom_sheet.dart` — scroll-controlled help sheet for long creator copy.

## Tests Added

- `test/features/profile/profile_icon_tabs_dark_mode_test.dart`
- `test/features/create/story_creator_add_tab_dark_smoke_test.dart`
- `test/features/create/nimon_scrollable_help_bottom_sheet_test.dart`
- `test/features/learn/learn_dark_surface_smoke_test.dart`

## Commands Run

```bash
dart format lib/features/learn/learn_module_surface_tokens.dart lib/features/learn/learn_hub_screen.dart lib/features/learn/vocab_kanji_list_screen.dart lib/features/learn/grammar_pattern_list_screen.dart lib/features/profile/profile_screen.dart lib/features/create/story_creator_add_tab_screen.dart lib/features/create/story_creator_quiz_editor_screen.dart lib/features/create/story_creator_audio_editor_screen.dart lib/features/create/creator_audio_upload_sheet.dart lib/features/create/story_creator_sentences_screen.dart lib/features/create/story_creator_grammar_overlays.dart lib/ui/widgets/nimon_scrollable_help_bottom_sheet.dart test/features/profile/profile_icon_tabs_dark_mode_test.dart test/features/create/nimon_scrollable_help_bottom_sheet_test.dart test/features/create/story_creator_add_tab_dark_smoke_test.dart test/features/learn/learn_dark_surface_smoke_test.dart

flutter analyze lib/features/learn/learn_module_surface_tokens.dart lib/features/learn/learn_hub_screen.dart lib/features/learn/vocab_kanji_list_screen.dart lib/features/learn/grammar_pattern_list_screen.dart lib/features/profile/profile_screen.dart lib/features/create/story_creator_add_tab_screen.dart lib/features/create/story_creator_quiz_editor_screen.dart lib/features/create/story_creator_audio_editor_screen.dart lib/features/create/creator_audio_upload_sheet.dart lib/features/create/story_creator_sentences_screen.dart lib/features/create/story_creator_grammar_overlays.dart lib/ui/widgets/nimon_scrollable_help_bottom_sheet.dart test/features/profile/profile_icon_tabs_dark_mode_test.dart test/features/create/nimon_scrollable_help_bottom_sheet_test.dart test/features/create/story_creator_add_tab_dark_smoke_test.dart test/features/learn/learn_dark_surface_smoke_test.dart

flutter test test/features/profile test/features/create test/features/learn
flutter test
```

## Manual Verification

Use the checklist in the M14B request (Part K): profile tabs, add tab, vocab, grammar sheet, quiz tabs/cards/sheets, listening, plus **light mode** spot-check on profile tabs, add tab, and scrollable help sheet.

## Remaining Risks

- `flutter analyze` on the repo still reports **warnings** unrelated to this change (unused private helpers, etc.).
- Other creator surfaces (e.g. large `story_creator_vocab_kanji_editor_screen.dart` ink constants) were **not** part of this pass; follow up if QA flags them.

## M14C follow-up

Addressed in **M14C** (`docs/M14C_REMAINING_DARK_MODE_SURFACE_FIX_REPORT.md`): workspace Drafts/Editing header extraction, vocabulary/grammar creator cards + Grammar add-pattern field fills, shared `showCreatorInfoBottomSheet` path for quiz/listening help, and targeted widget tests.
