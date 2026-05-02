# Cleanup Wave 2 Plan

**Status:** PLAN ONLY — no files modified, moved, renamed, or deleted as part of this document.  
**Inputs read:** `docs/NIMON_PROJECT_AUDIT_REPORT.md`, `docs/CLEANUP_WAVE_1_REPORT.md`, `docs/ANALYZER_ERROR_FIX_REPORT.md`, `lib/main.dart` (GoRouter table + imports).  
**Tracer method:** `rg`-style import graph from `lib/**/*.dart` (January 2026 snapshot; re-verify before apply).

---

## 1. Current Live Route Graph

From `lib/main.dart`, **registered** routes / shells aligned with product draft:

| Area | Paths |
|------|--------|
| **Auth** | `/login` |
| **Mono (home)** | `/mono`, `/mono/search`, `/mono-reader` (shell branch + extras) |
| **Profile** | `/more` (shell), `/profile/public` (+ `folder/:folderId`), `/profile/share`, `/profile/notifications`, `/profile/followers`, `/profile/following` |
| **Settings** | `/settings`, `/settings/help` |
| **Create** | `/create`, `/create/story/basics`, `/create/story/sentences` (+ redirects / `?panel=` learn embed) |
| **Learn** | `/learn/:id`, `/learn/:id/grammar`, `/learn/:id/vocabulary`, `/learn/:id/quiz` (+ play/result), `/learn/:id/listening`, `/learn/:id/grammar/detail` |

**Not in router (legacy pushes may still exist in dead code):** `/`, `/story/:id`, `/library/...` (see audit).

**Global DI:** `import 'package:nimon/data/repo_singleton.dart';` → `StoryRepo repo` passed into **`MonoScreen`** and **`ProfileScreen`** (live).

---

## 2. Product Scope Decision

**V1:** **Mono** (`/mono`) is the primary home surface. **Discovery `HomeScreen`**, **library / see-more story discovery**, **writer lab**, **`create_mono` prototype**, and **old episode / one-short UI barrels** are **out of scope** for V1 unless explicitly revived.

**Non-goals for Wave 2 apply:** No behavior change to routed Mono / Create / Profile / Learn; no backend removal; no deletion of **`StoryRepo`** or core **`Story` / `Episode`** types while **`repo`** remains the mono/profile data port.

---

## 3. Candidate Group Classification

Legend: **Reachable from GoRouter** = imported (transitively) from `lib/main.dart`’s import closure into a widget used on a live route. **Legacy-only** = importers are all within other legacy groups or nowhere.

| # | Group | Current importers | GoRouter reachable? | Legacy-only chain? | Live Mono/Create/Profile/Learn depends? | Risk | Recommended action | Exact file list |
|---|--------|-------------------|---------------------|---------------------|----------------------------------------|------|-------------------|----------------|
| **1** | `lib/features/home/**` | **No** external importers after Wave 1 removed `lib/app/app_shell.dart`. Only **internal** imports within `home/**` and `section_header` → `see_more`. | **No** | **Yes** (self + §3 + §9) | **No** direct dependency from `mono_screen` / `profile_screen` / `create` / `learn` imports. **Indirect:** `StoryRepoMock` implements APIs *used by* this tree (`fetchQuickOneShots`, section APIs) — **mock still used by live app** for other methods. | **MEDIUM** (mock API surface overlap) | **ARCHIVE_TO_LEGACY** (move folder as a unit; then trim `StoryRepo` *separately* with tests). | `home_screen.dart`, `widgets/*.dart`, `sections/*.dart`, `data/challenges.dart` — **16** `.dart` files (see glob snapshot). |
| **2** | `lib/features/library/**` | **Internal only:** `library_screen.dart` → `following_writers_section.dart`; `following_writers_screen.dart` → repository. **No** `main.dart` import. | **No** | **Yes** | **No** | **LOW** | **ARCHIVE_TO_LEGACY** | `library_screen.dart`, `following_writers_screen.dart`, `widgets/following_writers_section.dart` — **3** files. |
| **3** | `lib/features/see_more/**` | `section_header.dart` (home) → `see_more_page.dart`; `filter_bottom_sheet` used from `see_more_page`. | **No** | **Yes** (via home §1) | **No** | **LOW** | **ARCHIVE_TO_LEGACY** (with home §1) | `see_more_page.dart`, `widgets/filter_bottom_sheet.dart` — **2** files. |
| **4** | `lib/features/story/**` | **No** external importers. `story_detail_screen` imports `ui/ui.dart`, `reader_screen`, `story_repo`. | **No** | **Yes** (+ reader §, ui §8) | **No** (`learn_hub_screen` has a **comment** referencing `StoryDetailScreen` only). | **LOW** | **ARCHIVE_TO_LEGACY** | `story_detail_screen.dart`, `story_screen.dart` — **2** files. |
| **5** | `lib/features/writer/**` | **No** importers (Wave 1 removed `red_square.dart`). | **No** | **Yes** | **No** | **LOW** | **DELETE_IN_WAVE_2** *or* **ARCHIVE_TO_LEGACY** (single file — product may want copy). | `writer_screen.dart` — **1** file. |
| **6** | `lib/features/more/**` | **No** importers. | **No** | **Yes** | **No** (live profile is `ProfileScreen` on `/more`, not `MoreScreen`). | **LOW** | **DELETE_IN_WAVE_2** *or* **ARCHIVE_TO_LEGACY** | `more_screen.dart` — **1** file. |
| **7** | `lib/create_mono/**` | **No** importers from `lib/main.dart` or live features (self-contained prototype). | **No** | **Yes** | **No** | **LOW** | **ARCHIVE_TO_LEGACY** (README explicitly describes standalone entry). | **13** `.dart` files under `lib/create_mono/` (screens, tabs, `mono_draft_v1.dart`, widgets, `story_series/`). |
| **8** | `lib/ui/ui.dart` | **Only** `home_screen.dart`, `quick_one_shot_section.dart`, `mono_collection_row.dart`, `story_detail_screen.dart`. | **No** | **Yes** | **No** — live Mono/Create import **`package:nimon/ui/reading/...`** and **`nimon_circle_nav_button`** **directly**, not this barrel. | **MEDIUM** (barrel re-exports reading widgets; **live code must not import `ui.dart` for reading** — today it does not). | **ARCHIVE_TO_LEGACY** *after* migrating any stray `import 'package:nimon/ui/ui.dart';` (currently only legacy). | `lib/ui/ui.dart` — **1** file. |
| **9** | `lib/ui/create/**` | `add_mono_bottom_sheet.dart` → `one_short_paper_card.dart`, `prompt_carousel.dart`. `prompt_carousel` → `one_short_prompt_card.dart`. Several widgets **have zero importers** (dead). | **No** | **Yes** (via add_mono §10) | **No** (`features/create` does **not** import these). | **MEDIUM** | **Split:** **ARCHIVE_TO_LEGACY** the **used** subtree with `add_mono` (§10); **DELETE_IN_WAVE_2** for **zero-importer** files (§4). | `widgets/one_short_paper_card.dart`, `widgets/prompt_carousel.dart`, plus orphans: `widgets/build_prompt_section.dart`, `widgets/build_step_indicator.dart`, `widgets/duration_accordion_field.dart`, `widgets/custom_prompt_sheet.dart` — **7** files total under `lib/ui/create/`. |
| **10** | `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart` | Exported from `ui/ui.dart`; **no** direct call sites to `showAddMonoSheet` found outside this file + barrel. | **No** | **Yes** | **No** | **LOW** | **ARCHIVE_TO_LEGACY** (with §8–9; keeps prompt UX reference). | `add_mono_bottom_sheet.dart` — **1** file (large). |
| **11** | `lib/ui/bottom_sheets/episode_bottom_sheet.dart` | `home_screen`, `mono_collection_row`, `quick_one_shot_section`, `story_detail_screen`, `show_episode_modal.dart`. | **No** | **Yes** | **No** | **LOW** | **ARCHIVE_TO_LEGACY** | `episode_bottom_sheet.dart` — **1** file. |
| **12** | `lib/ui/bottom_sheets/episode_details_sheet*.dart` | **Only** `episode_details_sheet_launcher.dart` re-exports `showEpisodeDetailsSheet`; **no** other Dart importers of the launcher or sheet. | **No** | **Yes** | **No** | **LOW** | **ARCHIVE_TO_LEGACY** | `episode_details_sheet.dart`, `episode_details_sheet_launcher.dart` — **2** files. |
| **13** | `lib/ui/widgets/sheets/show_episode_modal.dart` | **None** (wrapper only). | **No** | **Yes** | **No** | **LOW** | **DELETE_IN_WAVE_2** | `show_episode_modal.dart` — **1** file. |
| **14** | `lib/shared/widgets/compact_story_card.dart` | **None**. | **No** | **Yes** | **No** | **LOW** | **DELETE_IN_WAVE_2** | `compact_story_card.dart` — **1** file. |
| **15** | `lib/shared/widgets/cards/episode_badged_card.dart` | **None**. | **No** | **Yes** | **No** | **LOW** | **DELETE_IN_WAVE_2** | `episode_badged_card.dart` — **1** file. |
| **16** | `lib/widgets/story_card.dart` | **Only** `see_more_page.dart`. | **No** | **Yes** (via see_more §3) | **No** | **LOW** | **ARCHIVE_TO_LEGACY** (with see_more) *or* **DELETE_IN_WAVE_2** after see_more archived. | `lib/widgets/story_card.dart` — **1** file. |
| **17** | `lib/data/story_repo*.dart` | **`main.dart`** → `repo_singleton.dart` → `story_repo.dart` + **`story_repo_mock.dart`**. **`MonoScreen`**, **`ProfileScreen`**, and legacy home/see_more/writer/story_detail reference **`StoryRepo`**. | **Yes** | N/A | **Yes** — **critical** for `/mono` and `/more`. | **HIGH** if mishandled | **KEEP** | `story_repo.dart`, `story_repo_mock.dart`, `repo_singleton.dart` (singleton not in `story_repo*` glob but inseparable). |
| **18** | `lib/data/episode_mock_data.dart` | **`story_repo_mock.dart`** (live), plus legacy **episode** UI files. | **Yes** (via mock → repo singleton → mono/profile) | Partial | **Yes** — mock feed data path. | **HIGH** if deleted before mock rewrite | **KEEP** (until `StoryRepo` has a mono-native implementation). | `episode_mock_data.dart` — **1** file. |
| **19** | `lib/models/story*.dart` | **`story_repo.dart`** imports **`story.dart`**; **`story.dart`** imports **`story_category.dart`**. Legacy UI also imports `story.dart`. | **Yes** (via repo interface) | N/A | **Yes** — type surface for **`StoryRepo`**. | **HIGH** if mishandled | **KEEP** | `story.dart`, `story_category.dart` — **2** files. |
| **20** | `lib/models/episode*.dart` | **`episode_model.dart`** ↔ **`episode_meta.dart`**. Used by **episode** sheets, **home** widgets, **`share_utils`**, and **`episode_action_bar`** (legacy cluster). **Not** referenced from `story_repo_mock` textually. | **No** direct route import; **optional** for live mono depending on future sharing UX. | Mostly **legacy** today | **No** current **mono_screen** import of `episode_meta` / `episode_model` (live mono does not import these files). | **MEDIUM** — safe to **keep** until legacy UI removed; then **NEEDS_MANUAL_REVIEW** whether to fold sharing into mono-specific types. | `episode_meta.dart`, `episode_model.dart` — **2** files. |

### Adjacent legacy (not in numbered list but moves **with** episode/home archive)

| Path | Importers | Action with Wave 2 |
|------|-----------|-------------------|
| `lib/features/reader/reader_screen.dart`, `episode_reader_screen.dart` | Legacy home, `episode_bottom_sheet`, `story_detail_screen` | **ARCHIVE_TO_LEGACY** with §4 + §11 |
| `lib/ui/widgets/episode_action_bar.dart` | `episode_details_sheet.dart`, `ui.dart` export | **ARCHIVE_TO_LEGACY** with §12 |
| `lib/ui/story/nimon_story_list_item.dart`, `lib/ui/widgets/nimon_metadata_row.dart`, `lib/ui/drawer/nimon_drawer_section.dart` | Only via **`ui.dart`** exports (no live direct imports found) | **ARCHIVE_TO_LEGACY** with §8 or **DELETE_LATER** after barrel removal |

---

## 4. Safe Delete Candidates

**Definition:** Dart files with **zero** importers elsewhere (standalone dead code). Prefer deleting **before** or **during** archive PR to reduce noise; re-run `flutter analyze` after.

| File | Rationale |
|------|-----------|
| `lib/ui/widgets/sheets/show_episode_modal.dart` | Unused wrapper; nothing calls `showEpisodeModalFromMeta`. |
| `lib/shared/widgets/compact_story_card.dart` | No references. |
| `lib/shared/widgets/cards/episode_badged_card.dart` | No references. |
| `lib/ui/create/widgets/build_prompt_section.dart` | No references (orphan). |
| `lib/ui/create/widgets/build_step_indicator.dart` | No references. |
| `lib/ui/create/widgets/duration_accordion_field.dart` | No references. |
| `lib/ui/create/widgets/custom_prompt_sheet.dart` | **Superseded** by private `_CustomPromptSheet` inside `add_mono_bottom_sheet.dart`; no external import of `CustomPromptSheet`. |

**Count:** **7** files (conservative **DELETE_IN_WAVE_2** list).

**Optional single-file deletes** (product copy preference): `writer_screen.dart`, `more_screen.dart` — **+2** if team prefers delete over archive for one-liners.

---

## 5. Archive Candidates

Move to e.g. `archive/legacy_v1_discovery/` (or a `packages/` / `legacy/` tree) **preserving relative history in git**, then delete from `lib/` in a follow-up commit after CI green:

- **§1** `features/home/**` (**16**)
- **§2** `features/library/**` (**3**)
- **§3** `features/see_more/**` (**2**)
- **§4** `features/story/**` (**2**)
- **§7** `create_mono/**` (**13**)
- **§8** `ui/ui.dart` (**1**)
- **§9** (subset) `ui/create/` **used** by add_mono: `one_short_paper_card.dart`, `prompt_carousel.dart` (**2**) — *or* archive entire `ui/create/` after orphan deletes (**7** → **2** remain)
- **§10** `add_mono_bottom_sheet.dart` (**1**)
- **§11** `episode_bottom_sheet.dart` (**1**)
- **§12** `episode_details_sheet.dart`, `episode_details_sheet_launcher.dart` (**2**)
- **§16** `widgets/story_card.dart` (**1**) — with see_more/home
- **Reader + episode chrome:** `features/reader/*.dart` (**2**), `ui/widgets/episode_action_bar.dart` (**1**), `ui/story/nimon_story_list_item.dart` (**1**), `ui/widgets/nimon_metadata_row.dart` (**1**), `ui/drawer/nimon_drawer_section.dart` (**1**)

**Approximate archive file count:** **16+3+2+2+13+1+2+1+1+1+2+1+2+1+1+1+1 ≈ 50** `.dart` files (exact count may drift; re-glob before apply).

---

## 6. Must Keep

| Artifact | Reason |
|----------|--------|
| **`lib/data/story_repo.dart`, `story_repo_mock.dart`, `repo_singleton.dart`** | **`MonoScreen`** / **`ProfileScreen`** / **`main.dart`** depend on **`StoryRepo`**. |
| **`lib/data/episode_mock_data.dart`** | **`StoryRepoMock`** builds episode/story mock graph. |
| **`lib/models/story.dart`, `story_category.dart`** | **`StoryRepo`** contract types. |
| **`lib/models/episode_meta.dart`, `episode_model.dart`** | Keep until legacy episode UI is gone **and** sharing (`share_utils`) / mono design is decided (see §7). |
| **`lib/core/share_utils.dart`** | Episode sharing helper; only used from legacy **`episode_action_bar`** today — **do not delete** until call graph confirmed post-archive. |
| **Backend client files** (`remote_*`, DTOs) | Per instructions — not in Wave 2 delete set. |

---

## 7. Needs Manual Review

1. **`StoryRepo` / `StoryRepoMock` API** — Still implements **home-only** methods (`fetchQuickOneShots`, `getStoriesBySection`, …). **Live** mono/profile may call a **subset**. **Refactor or split** is a product/backend decision, not Wave 2 mechanical delete.
2. **`lib/data/prompt_repository.dart`** — Only referenced from **`add_mono`** / dead **`ui/create`** paths. After archive, confirm **no** future Add Story flow needs prompt catalog; then **archive or merge** into creator.
3. **`lib/data/following_repository.dart`** — Only **library** feature. Archive **with** library or delete after route decision.
4. **`lib/models/episode_*` + `share_utils`** — After episode UI archive, decide if **mono** should own sharing entry points; may inline or delete **`ShareUtils`** later.
5. **`lib/features/learn/learn_screen.dart`** / **`lib/features/quiz/quiz_screen.dart`** — Not in numbered groups; still **unwired** — **REVIEW_OPTIONAL_V2**.
6. **`lib/features/widgets/real_book_3d_cover.dart`** — Orphan widget; not in list — **DELETE_LATER** or archive with home assets.
7. **Tests / `tool/`** — Re-run grep after moves; update imports if tests referenced archived paths (currently **no** `test/` matches for `HomeScreen`).

**Manual review “file count” (order-of-magnitude):** **~8–12** decision touchpoints (repos + models + sharing + optional screens).

---

## 8. Risk Matrix

| Group / topic | Risk | Mitigation |
|----------------|------|------------|
| **§17–20 (`story_repo*`, `episode_mock_data`, `story` models)** | **HIGH** if deleted | **KEEP** until mock/repo redesign signed off. |
| **§1 `home/**` + `StoryRepoMock` overlap** | **MEDIUM** | Archive **UI first**; change mock in a **separate PR** with mono/profile smoke tests. |
| **`ui/ui.dart` barrel** | **MEDIUM** | Ensure **no** live file imports barrel for reading widgets; keep **direct** `package:nimon/ui/reading/...` imports only. |
| **§5–6 single-file screens** | **LOW** | Prefer archive if legal/product wants retention of old UI source. |

**Highest risk group (if mishandled):** **§17–20** — **`story_repo*`**, **`episode_mock_data`**, and **`models/story*.dart`** — **must not** be treated as legacy discovery debris; they underpin **`/mono`** and **`/more`**.

---

## 9. Recommended Wave 2 Action

**Smallest safe sequence:**

1. **Wave 2a — Delete orphans (§4):** **7** files, single PR, trivial analyze verification.
2. **Wave 2b — Archive monolith:** Move **§1–4, §7–12, §16** + **reader + episode chrome** into `archive/legacy_.../` in **one** mechanical PR (no logic edits), fix **only** broken imports / exports.
3. **Wave 2c — Data layer review (manual):** Map **`StoryRepo`** methods actually invoked from **`mono_screen` / `profile_screen`**; schedule **Wave 3** to slim mock + models.

---

## 10. Exact Cursor Prompt For Wave 2 Apply

```text
You are a senior Flutter maintainer. Implement ONLY docs/CLEANUP_WAVE_2_PLAN.md Wave 2a+2b.

Constraints:
- Follow docs/CLEANUP_WAVE_2_PLAN.md exactly: first DELETE the 7 orphan files listed in §4 Safe Delete Candidates; then ARCHIVE (git mv) the legacy folders/files listed in §5 into archive/legacy_v1_discovery/ preserving paths.
- Do NOT modify lib/main.dart routes.
- Do NOT delete or refactor lib/data/story_repo.dart, story_repo_mock.dart, repo_singleton.dart, episode_mock_data.dart, lib/models/story.dart, lib/models/story_category.dart.
- Do NOT change behavior of MonoScreen, ProfileScreen, StoryCreatorSentencesScreen, or Learn screens beyond fixing imports broken by the archive move.
- After moves: run dart format on touched files only, flutter pub get, flutter analyze; ensure zero error-severity issues.

Deliver: short summary + list of moved paths.
```

---

## 11. Questions For Product Owner

1. Should **`HomeScreen` / discovery** code be **archived** indefinitely, or kept in-repo under `legacy/` for **A/B** revival?
2. Is **`create_mono/`** a **dead prototype** or a **V2** candidate to merge into **`features/create`**?
3. After archive, should **`StoryRepo`** be **split** (e.g. `MonoRepository` + `LegacyStoryRepository`) or kept monolithic with unused methods until backend replaces mocks?
4. Should **`writer_screen` / `more_screen`** be **deleted** outright or kept in **`archive/`** for reference?
5. Does any **marketing / legal** requirement mandate keeping **UI source** for abandoned flows (screenshots, patents)?

---

## Executive Summary (planning metrics)

| Metric | Value |
|--------|------:|
| **Safe delete file count (§4)** | **7** (+ **2** optional: `writer_screen.dart`, `more_screen.dart`) |
| **Archive candidate file count (§5, approximate)** | **~50** `.dart` files (re-glob before apply) |
| **Manual review touchpoints (§7, approximate)** | **~8–12** |
| **Highest risk group if mishandled** | **§17–20** — **`story_repo*`**, **`episode_mock_data`**, **`models/story*.dart`** (live **`/mono`** + **`/more`**) |
| **Recommended next action** | Execute **§9 Wave 2a** (7 orphan deletes), then **§9 Wave 2b** (single archive PR), then schedule **StoryRepo** slimming with tests (**§9 Wave 2c**). |

---

*End of plan.*
