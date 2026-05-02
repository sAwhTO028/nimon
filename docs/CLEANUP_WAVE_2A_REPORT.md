# Cleanup Wave 2a Report

**Date:** 2026-05-01  
**Scope:** Delete **only** the seven orphan files listed in the Wave 2a brief—**no** folder archive, **no** mass delete, **no** routing/pubspec/backend changes, **no** edits to `StoryRepo` / mocks / singleton / episode mock / story or episode models, **no** changes to Mono, Profile, Create, or Learn screens.

---

## Deleted Files

| Path | Pre-delete check |
|------|------------------|
| `lib/shared/widgets/compact_story_card.dart` | No Dart importers outside the file. |
| `lib/shared/widgets/cards/episode_badged_card.dart` | No Dart importers outside the file. |
| `lib/ui/create/widgets/build_prompt_section.dart` | No Dart importers outside the file. |
| `lib/ui/create/widgets/build_step_indicator.dart` | No Dart importers outside the file. |
| `lib/ui/create/widgets/duration_accordion_field.dart` | No Dart importers outside the file. |
| `lib/ui/create/widgets/custom_prompt_sheet.dart` | No `import` of this library; `add_mono_bottom_sheet.dart` uses a **private** `_CustomPromptSheet` defined in-place (not this file). |

**Count deleted:** **6**

---

## Skipped Files

| Path | Reason |
|------|--------|
| `lib/ui/widgets/sheets/show_episode_modal.dart` | **Active reference:** `test/episode_bottom_sheet_test.dart` imports `package:nimon/ui/widgets/sheets/show_episode_modal.dart` and calls `showEpisodeModalFromMeta`. Deleting would **break tests** and violate the “zero active Dart importers” rule. |

**Count skipped:** **1** → treat as **NEEDS_MANUAL_REVIEW** if the modal is dead in **lib/** but tests should be updated or the test removed in a dedicated test-cleanup pass.

---

## Reference Checks

| Target | `lib/` importers | `test/` importers |
|--------|------------------|-------------------|
| `show_episode_modal.dart` | None found | `test/episode_bottom_sheet_test.dart` |
| `compact_story_card.dart` | None | None |
| `episode_badged_card.dart` | None | None |
| `build_prompt_section.dart` | None | None |
| `build_step_indicator.dart` | None | None |
| `duration_accordion_field.dart` | None | None |
| `custom_prompt_sheet.dart` | None | None |

---

## Imports Updated

**None.** No remaining Dart files imported the six deleted libraries; no import edits were required.

**`dart format`:** Not run (no Dart files modified).

---

## Flutter Analyze Result

- **Command:** `flutter analyze` (project root).
- **Exit code:** **1** (non-zero because warnings/infos exist—expected for this repo).
- **Error-severity issues:** **0** (confirmed: `dart analyze` output contains no `error -` lines).

---

## Remaining Error-Severity Issues

**0**

---

## Remaining Warning / Info Count

From `dart analyze` immediately after this wave (approximate):

| Severity | Count |
|----------|------:|
| **warning** | **69** |
| **info** | **332** |
| **Total** | **401** |

*(Counts can drift slightly as the codebase evolves.)*

---

## Risk Notes

- **`show_episode_modal.dart`** remains the only Wave 2a candidate still tied to **tests**. Removing it later requires **updating or deleting** `test/episode_bottom_sheet_test.dart` first.
- **`lib/ui/create/`** still contains **`one_short_paper_card.dart`** and **`prompt_carousel.dart`** (used by `add_mono_bottom_sheet.dart`); Wave 2a did **not** touch them.
- No runtime behavior change expected—deleted files were unreachable from `lib/main.dart` production paths.

---

## Recommended Next Step

1. **Manual review:** Decide whether to **keep** `show_episode_modal.dart` for tests, **refactor tests** to use `episode_bottom_sheet` APIs directly, or **delete both** in a test-aware pass.
2. Continue **Wave 2b** (archive / larger removals) **only** with explicit product approval per `docs/CLEANUP_WAVE_2_PLAN.md`.
