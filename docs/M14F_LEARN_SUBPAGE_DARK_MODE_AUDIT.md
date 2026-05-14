# M14F Learn Subpage Dark Mode Audit

Audit of Learn landing vs. Grammar / Vocabulary / Quiz / Listening reader surfaces after M14F.

| Page | Route / screen file | Scaffold / background | Theme source | Hardcoded light colors (before M14F) | Local `Theme` override? | Dark status (before) | Fix status (M14F) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Learn landing | `lib/features/learn/learn_hub_screen.dart` | `learnModuleListPageBackground`, hub tiles | App `ThemeData` / `ColorScheme` | None critical | No | OK | N/A |
| Vocabulary / Semantics list | `lib/features/learn/vocab_kanji_list_screen.dart` | `learnModuleListPageBackground`, list cards via `learn_module_surface_tokens` | App theme | None in scaffold | No | OK | N/A |
| Grammar list | `lib/features/learn/grammar_pattern_list_screen.dart` | Same as vocab list | App theme | None in scaffold | No | OK | N/A |
| Grammar pattern detail | `lib/features/learn/grammar_pattern_detail_screen.dart` | Static warm `_bg`, white cards | App theme | `_bg`, `_ink`, white `_SurfaceCard` | No | Broken | Fixed: page `learnModuleListPageBackground`, text `ColorScheme`, cards `learn_creator_module_tokens` |
| Quiz setup | `lib/features/learn/quiz_setup_screen.dart` | `QuizFlowTheme.pageBg` | App theme but page used quiz palette | White option chips, `QuizFlowTheme` ink | No | Broken | Fixed: module background + `ColorScheme` + M14C card tokens on options |
| Quiz play | `lib/features/learn/quiz_play_screen.dart` | `QuizFlowTheme.pageBg`, white panels | App theme | Heavy quiz palette / white cards | No | Broken | Fixed: `learnModuleListPageBackground`, creator card tokens, dark branches for feedback/options |
| Quiz results | `lib/features/learn/quiz_result_screen.dart` | `QuizFlowTheme.pageBg` | App theme | Quiz palette, secondary button fill | No | Broken | Fixed: module background + `ColorScheme` + outline secondary |
| Listening | `lib/features/learn/listening_pronunciation_screen.dart` | Static `_bg` on catalog scaffold; warm paper + ink in transcript/player | App theme | `_bg`, `_ink`, light player card | No | Broken | Fixed: `learnModuleListPageBackground` + `ColorScheme` + M14C card tokens on player |

## Theme tokens referenced

- `learnModuleListPageBackground` — list/learn subpage scaffold (warm paper light, `surface` dark).
- `learnCreatorModuleCardSurfaceColor`, `learnCreatorModuleCardBorderColor`, `learnCreatorModulePrimaryTextColor`, `learnCreatorModuleSecondaryTextColor`, `learnCreatorModuleActionForegroundColor` — M14C learn/creator module alignment for cards and actions.

## Notes

- `creator_compact_info_bottom_sheet.dart` is not present in the repo; info flows use `creator_fit_info_bottom_sheet.dart` and delegating helpers only.
- No backend or copy changes in M14F.
