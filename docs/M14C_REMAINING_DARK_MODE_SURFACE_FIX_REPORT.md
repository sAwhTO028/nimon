# M14C Remaining Dark Mode Surface Fix Report

## Problem

After M14B, dark-mode QA still flagged: (1) Profile -> Workspace section headers barely visible, (2) creator Vocabulary / Grammar cards and the Grammar add-pattern sheet using hardcoded or theme-incomplete colors, (3) Quiz / Listening help sheets needing the same shell as other creator info sheets.

## Scope

Flutter UI and tests only. No validation, publish, upload, routing, or backend changes. Light mode hierarchy preserved by using `ColorScheme` roles instead of fixed blacks.

## Workspace Section Label Fix

`ProfileWorkspaceSectionHeader` (`lib/features/profile/presentation/profile_workspace_section_header.dart`) centralizes uppercase Drafts/Editing labels with `colorScheme.onSurfaceVariant` and stable `ValueKey`s for tests.

## Learn Card Token Fix

`lib/features/learn/learn_creator_module_tokens.dart` adds card surface/border and action foreground helpers; `_VocabKanjiEntryCard` and `_GrammarCard` consume them for consistent dark surfaces and readable text/icons.

## Vocabulary Sheet Fix

Entry details / edit flows continue to use `ColorScheme` for section titles, helpers, accordions, and field fills (M14B/M14C pass). Modal shells use theme surface colors.

## Grammar Add Pattern Sheet Fix

`_GrammarPatternSheet` text fields now pass explicit `fillColor: colorScheme.surface` wherever `InputDecoration` was `const` without a fill, fixing dark-mode contrast on the sheet surface.

## Shared Info Sheet Alignment

`showNimonScrollableHelpBottomSheet` delegates to `showCreatorInfoBottomSheet` (`lib/features/create/widgets/creator_info_bottom_sheet.dart`) so Quiz and Listening long-copy help matches Vocabulary / Grammar / Storytelling info (handle, radius, surface, title, body typography, **Got it**, scroll, safe area).

## Tests Added

- `test/features/profile/profile_workspace_section_header_dark_test.dart`
- `test/features/create/m14c_creator_learn_dark_surfaces_test.dart`
- `test/features/learn/learn_creator_module_tokens_widget_test.dart`

## Commands Run

```bash
dart format lib/features/profile/presentation/profile_workspace_section_header.dart lib/features/profile/profile_screen.dart lib/features/learn/learn_creator_module_tokens.dart lib/features/create/story_creator_vocab_kanji_editor_screen.dart lib/features/create/story_creator_grammar_editor_screen.dart test/features/profile/profile_workspace_section_header_dark_test.dart test/features/create/m14c_creator_learn_dark_surfaces_test.dart test/features/learn/learn_creator_module_tokens_widget_test.dart

flutter analyze lib/features/profile/presentation/profile_workspace_section_header.dart lib/features/profile/profile_screen.dart lib/features/learn/learn_creator_module_tokens.dart lib/features/create/story_creator_vocab_kanji_editor_screen.dart lib/features/create/story_creator_grammar_editor_screen.dart test/features/profile/profile_workspace_section_header_dark_test.dart test/features/create/m14c_creator_learn_dark_surfaces_test.dart test/features/learn/learn_creator_module_tokens_widget_test.dart

flutter test test/features/profile
flutter test test/features/create
flutter test test/features/learn
flutter test
```

## Manual Verification

1. Profile -> Workspace: **DRAFTS** / **EDITING** readable.  
2. Vocabulary: cards, Details, Entry details sheet.  
3. Grammar: cards, Add pattern sheet.  
4. Story sentences host: Quiz / Listening "how it works" sheets match other info sheets, no overflow on small phone.  
5. Light mode: quick pass on the same surfaces.

## Remaining Risks

- Full `ProfileScreen` workspace tab is not widget-tested (private tab stack); the extracted header is.  
- `flutter analyze` on the whole repo may still report pre-existing warnings outside these paths.

## M14E follow-up (info sheet height)

M14C dark-mode and token fixes for creator info copy remain valid. **M14E** (`docs/M14E_INFO_SHEET_FIT_CONTENT_RESTORE_REPORT.md`) restores **fit-to-content** height for module info sheets by replacing the fixed `FractionallySizedBox(heightFactor: 0.88)` pattern with `showCreatorFitInfoBottomSheet` (Story Basics–style max-height + `Column` `mainAxisSize.min`).
