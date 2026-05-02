# Cleanup Wave 2b Archive Report

**Scope:** Move legacy V1 discovery / story / episode / `create_mono` UI out of `lib/` into `archive/legacy_v1_discovery/lib/...`, preserving relative paths. **No** `main.dart` route edits. **No** changes to `MonoScreen`, `ProfileScreen`, Create, or Learn product logic. **No** removal of `StoryRepo`, mocks, `episode_mock_data`, or tests.

**Inputs read:** `docs/NIMON_WIREFRAME_SCOPE_LOCK.md`, `docs/CLEANUP_WAVE_2_PLAN.md`, `docs/CLEANUP_WAVE_2A_REPORT.md`, `docs/STORY_REPO_LIVE_DEPENDENCY_MAP.md`, `docs/NIMON_ARCHITECTURE_CONSTITUTION.md` (per task brief).

---

## Archived Files

All paths are under **`archive/legacy_v1_discovery/lib/`** (original `lib/...` layout preserved below that prefix).

| Group | Path(s) |
|-------|---------|
| Home (16) | `features/home/**` — `home_screen.dart`, `data/challenges.dart`, `sections/*`, `widgets/*` |
| Library (3) | `features/library/**` |
| See more (2) | `features/see_more/**` |
| Story (2) | `features/story/**` |
| Writer (1) | `features/writer/writer_screen.dart` |
| More (1) | `features/more/more_screen.dart` |
| Create mono (14) | `create_mono/**` including `README.md` |
| UI barrel (1) | `ui/ui.dart` |
| Create UI widgets (2) | `ui/create/widgets/one_short_paper_card.dart`, `prompt_carousel.dart` |
| Bottom sheets (3) | `ui/bottom_sheets/add_mono_bottom_sheet.dart`, `episode_details_sheet.dart`, `episode_details_sheet_launcher.dart` |
| Widgets (2) | `widgets/story_card.dart`, `ui/widgets/nimon_metadata_row.dart` |
| UI story / drawer (2) | `ui/story/nimon_story_list_item.dart`, `ui/drawer/nimon_drawer_section.dart` |

**Counts:** **48** Dart files + **1** non-Dart file (`create_mono/README.md`) = **49** files moved.

---

## Skipped Files

These items were **in the Wave 2b target list** but **not moved** (`SKIPPED_NEEDS_MANUAL_REVIEW`):

| # | Path | Reason |
|---|------|--------|
| 12 | `lib/ui/bottom_sheets/episode_bottom_sheet.dart` | **`lib/ui/widgets/sheets/show_episode_modal.dart`** (kept for `test/episode_bottom_sheet_test.dart`) imports **`package:nimon/ui/bottom_sheets/episode_bottom_sheet.dart`**. Archiving the bottom sheet would break analysis for that live path. |
| 16 | `lib/features/reader/reader_screen.dart` | Still required by **`episode_bottom_sheet.dart`** (see above). |
| 17 | `lib/features/reader/episode_reader_screen.dart` | **`EpisodeReaderScreen`** is still referenced from **`episode_bottom_sheet.dart`** (~line 669). |
| 18 | `lib/ui/widgets/episode_action_bar.dart` | **`test/episode_action_bar_test.dart`** imports **`package:nimon/ui/widgets/episode_action_bar.dart`**. This wave does not change tests. |

**Skipped count:** **4** files.

---

## Reference Checks

**Live importers (must be clean before move):** Searched `lib/features/mono/**`, `lib/features/profile/**`, `lib/features/create/**`, `lib/features/learn/**`, `lib/features/settings/**`, and `lib/main.dart` for imports of the planned archive paths — **no matches**.

**Tests:** `test/episode_bottom_sheet_test.dart` → `show_episode_modal` → `episode_bottom_sheet` (chain above). `test/episode_action_bar_test.dart` → `episode_action_bar`.

**Other `lib/`:** After moves, **no** remaining `lib/**/*.dart` imports pointed at the archived locations (legacy was self-contained + old barrel).

---

## Imports Updated

- **`analysis_options.yaml`:** Added `analyzer: exclude: [archive/**]` so archived Dart under `archive/` is not analyzed as part of the app package (avoids stale `package:nimon/...` paths inside the archive tree).
- **No** `lib/**` Dart import edits were required: nothing in the live tree imported the moved modules.

---

## Flutter Analyze Result

- **Command:** `flutter analyze`
- **Outcome:** **No `error`‑severity issues** reported (output contained **warnings** and **info** only; e.g. duplicate imports in `story_repo_mock.dart`, deprecation infos, and an **unused_import** on `reader_screen` inside `episode_bottom_sheet.dart`).
- **Total issues reported:** **230** (infos + warnings; same order of magnitude as pre-wave noise in this repo snapshot).

---

## Flutter Test Result

- **Command:** `flutter test`
- **Outcome:** **Failed** — **3** failing cases, all in **`test/creator_progress_drawer_module_switching_widget_test.dart`** (`Expected: … text "Quiz"` — widget not found). **`test/episode_bottom_sheet_test.dart`** and **`test/episode_action_bar_test.dart`** completed in the same run.
- **Note:** Failures appear **unrelated** to the archived discovery/story tree (creator drawer expectations). Treat as **pre-existing / environment** unless a bisect proves otherwise.

---

## Remaining Error-Severity Issues

**0** (no analyzer `error` diagnostics observed in `flutter analyze` output for `lib/` + `test/`).

---

## Remaining Warning / Info Count

**230** total analyzer issues in the last `flutter analyze` run (mix of **warning** and **info**; not broken down by severity in the CLI one-liner).

---

## Risk Notes

1. **`episode_bottom_sheet` + reader cluster** must stay in **`lib/`** until tests are refactored off `show_episode_modal` or the sheet is duplicated/copied into a non-archived module.
2. **`episode_action_bar`** stays in **`lib/`** until **`episode_action_bar_test`** is updated or archived with a test strategy.
3. **Archived code is excluded from analysis** — restoring it later requires moving back under `lib/` or tightening imports; it is **not** part of the published `package:nimon` API.
4. **Working tree:** This repo snapshot may contain **other unrelated modified/deleted files** (pre-existing). Wave 2b intentionally only **moved** the listed legacy tree + **`analysis_options.yaml`** + this report.

---

## Recommended Next Step

1. **Optional:** Remove the now-unused **`import '../../features/reader/reader_screen.dart';`** from **`lib/ui/bottom_sheets/episode_bottom_sheet.dart`** (warning-only; small import hygiene).
2. **Tests:** Investigate **`creator_progress_drawer_module_switching_widget_test.dart`** “Quiz” finder failures on `main` (independent of Wave 2b archive).
3. **Next archive tranche:** After tests stop importing **`episode_action_bar`** / **`show_episode_modal`** from legacy paths, re-attempt **`episode_bottom_sheet.dart`**, **`reader_screen.dart`**, **`episode_reader_screen.dart`**, and **`episode_action_bar.dart`**.

---

## Output Summary

| Metric | Value |
|--------|--------|
| **Archived file count** | **49** (48 `.dart` + 1 `README.md`) |
| **Skipped file count** | **4** |
| **`flutter analyze` has 0 errors?** | **Yes** (no error-severity diagnostics in the analyzed scope) |
| **`flutter test` passed?** | **No** (3 failures in creator progress drawer test) |
| **Total remaining analyzer issue count** | **230** (warnings + infos in last run) |
| **Unexpected risk** | **`show_episode_modal` → `episode_bottom_sheet` → reader** chain blocks archiving **four** planned files until tests/deps are reconciled. |
