# M14C Remaining Dark Mode Surface Audit

Follow-up to M14B: phone QA still showed low-contrast creator learn surfaces and mismatched help sheets.

| Surface | File | Bad token / issue | Good reference | Fix applied | Test / manual |
| --- | --- | --- | --- | --- | --- |
| Workspace **DRAFTS** / **EDITING** labels | `lib/features/profile/profile_screen.dart` (was `_ProcessingSectionHeader`) | Near-black `Colors.black.withOpacity` (M14B predecessor) | `ColorScheme.onSurfaceVariant` section labels | Extracted `ProfileWorkspaceSectionHeader` using `onSurfaceVariant` + `ValueKey` for tests | `test/features/profile/profile_workspace_section_header_dark_test.dart` |
| Vocabulary card (term, type, status, actions, handle, overflow) | `lib/features/create/story_creator_vocab_kanji_editor_screen.dart` (`_VocabKanjiEntryCard`) | Fixed ink `#1A1917` / muted `#5C5A55` | Learn list cards + scheme | `learn_creator_module_tokens.dart` for surface, border, primary/secondary/action colors | `test/features/create/m14c_creator_learn_dark_surfaces_test.dart` |
| Vocabulary **Entry details** sheet | Same file (`_VocabDetailsBottomSheetState`) | Hardcoded ink on titles/helpers (pre-M14C) | Other sheets using `ColorScheme` | `onSurface` / `onSurfaceVariant`, `surface` fills for fields (prior pass) | Widget test opens **Details** |
| Vocabulary **Edit term** sheet | Same file (`_VocabTermEditBottomSheet`) | Same class of issues | Details sheet | Verified tokens in prior pass; no logic change | Manual / spot-check |
| Grammar card | `lib/features/create/story_creator_grammar_editor_screen.dart` (`_GrammarCard`) | Mixed `cs.onSurface` only | Vocabulary card token set | Same `learn_creator_module_tokens` usage | `m14c` widget test |
| **Add pattern** bottom sheet | Same (`_GrammarPatternSheet` + `showModalBottomSheet`) | `const InputDecoration(filled: true)` without `fillColor` -> wrong fill in dark; light sheet mismatch risk | Vocabulary upsert fields | Explicit `fillColor: cs.surface` on all former const fields; sheet `backgroundColor: colorScheme.surface` (already) | `m14c` opens **Add pattern** |
| Quiz info / help sheet | `lib/ui/widgets/nimon_scrollable_help_bottom_sheet.dart` -> `showCreatorInfoBottomSheet` | Older layout differed from vocab/grammar/storytelling | `creator_info_bottom_sheet.dart` | Delegates to shared shell (drag handle, radius 20, `surface`, scroll, **Got it**) | `test/features/create/nimon_scrollable_help_bottom_sheet_test.dart` + `m14c` |
| Listening info / help sheet | Same as quiz (`story_creator_sentences_screen.dart` callers) | Same | Same shared shell | Same delegation | Same tests |

## Manual status

- Workspace, vocab, grammar, quiz/listening sheets: re-check on device dark mode after M14C (see fix report checklist).
