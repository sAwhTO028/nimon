# Creator Drawer Test Fix Report

**Context:** After Cleanup Wave 2b, `flutter test test/creator_progress_drawer_module_switching_widget_test.dart` failed three cases (`find.text('Quiz')`). Investigation showed mismatched **pinned workspace header** strings vs. **progress drawer row** titles.

---

## Failure Summary

| Test | Symptom |
|------|---------|
| A, B, D | `Found 0 widgets with text "Quiz"` after navigating to the Quiz learn panel via the drawer. |
| A, B (after first fix) | `Found 0 widgets with text "Listening / Pronunciation"` after navigating to the Listening panel. |

Tests **C**, **E**, and **Local actions** already used **`Quizzes`** or **`Listening`** where appropriate and did not fail on the original run.

---

## Root Cause

1. **Quiz label:** `StoryCreatorSentencesScreen._pinnedWorkspaceTitle` maps `CreatorWorkspaceStep.quiz` to **`'Quizzes'`** (see `lib/features/create/story_creator_sentences_screen.dart`). The quiz module body (`StoryCreatorQuizModuleBody`) also suppresses the standalone **`'Quiz'`** heading when `hideWorkspaceModuleTitle: true`, which `CreatorWorkspaceModulePlaceholder` sets for the embedded quiz panel. So the **main canvas** does not show a literal **`Text('Quiz')`** after navigation; it shows **`Quizzes`** in the pinned header (and tab chrome such as Semantics / Grammar / Sentence inside the editor).

2. **Listening label:** The same `_pinnedWorkspaceTitle` maps **`listeningPronunciation`** to **`'Listening'`**, not **`'Listening / Pronunciation'`**. The longer string remains the **drawer row title** in `CreatorProgressDrawer` / `creator_progress_drawer.dart`, but the **pinned header** uses the short label.

The tests were **outdated** relative to intentional product copy, not evidence of a routing or Learn Mode regression.

---

## Files Changed

| File | Change |
|------|--------|
| `test/creator_progress_drawer_module_switching_widget_test.dart` | Align expectations with `_pinnedWorkspaceTitle` and drawer vs. canvas wording. |

---

## Test Updates

- After navigating to the Quiz panel via the drawer, assert **`find.text('Quizzes')`** instead of **`'Quiz'`** (tests **A**, **B**, **D**).
- After navigating to the Listening panel, assert **`find.text('Listening')`** instead of **`'Listening / Pronunciation'`** where the assertion targets the **pinned workspace header** (tests **A**, **B**).
- Short comments added clarifying that drawer rows still use **`Quiz`** / **`Listening / Pronunciation`** via `_expectDrawerRowState(..., moduleTitle: ...)` — those expectations were left unchanged.

---

## Production Updates

**None.** No changes under `lib/`.

---

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/creator_progress_drawer_module_switching_widget_test.dart` | **All tests passed** (`+6`). |

---

## Flutter Analyze Result

| Metric | Result |
|--------|--------|
| **Error-severity issues** | **0** (no `error •` lines in analyzer output for this run). |
| **Total issues** | **230** (warnings + infos; unchanged scope vs. pre-fix housekeeping policy). |

---

## Risk Notes

- Assertions now depend on **copy** in `_pinnedWorkspaceTitle`. If product renames pins again, update tests or extract shared test constants next to the sentences screen.
- Drawer rows still validate **`moduleTitle: 'Quiz'`** and **`'Listening / Pronunciation'`** via `_expectDrawerRowState`; behavior under Learn Mode was not weakened.

---

## Recommended Next Step

Run **`flutter test`** for the full suite to confirm no other tests assumed the old **`Quiz`** / **`Listening / Pronunciation`** pin strings.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Root cause** | Tests expected **`Quiz`** and **`Listening / Pronunciation`** on the main workspace, but **`StoryCreatorSentencesScreen`** intentionally pins **`Quizzes`** and **`Listening`**; embedded quiz also hides the inner **`Quiz`** module title. |
| **Files changed** | **`test/creator_progress_drawer_module_switching_widget_test.dart`** only (+ **`docs/CREATOR_DRAWER_TEST_FIX_REPORT.md`**). |
| **Targeted test passed?** | **Yes.** |
| **`flutter analyze` has 0 errors?** | **Yes** (0 error-severity issues). |
| **Full `flutter test` recommended?** | **Yes**, as a confidence check after copy-aligned test updates. |
