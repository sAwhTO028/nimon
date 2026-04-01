# Current Files → V1 Target Mapping (NIMON)

**Summary:** This document classifies **existing** `lib/` files (and related assets) against your **V1 product scope** (Mono main entry, Add = one-short create, Profile, Learn from Mono, Auth) and the **target layout** described in `NIMON_V1_TARGET_FOLDER_STRUCTURE.md`. It is **documentation-only**—no code, routes, or files were modified to produce it.

**Legend — `V1 action` values**

| Action | Meaning |
|--------|---------|
| **KEEP** | Needed for V1; path may stay as-is initially or match target after small moves. |
| **MOVE / REHOME** | Needed for V1; should live under the recommended destination when you reorganize. |
| **ARCHIVE** | Out of V1 scope; keep in repo for V2+ or move to `archive/` / branch later. |
| **REVIEW** | Ambiguous dependency, duplicate, or product decision needed before deleting or archiving. |
| **POSSIBLY UNUSED** | No references found in typical import graph; verify before removal (may be unused import or dead file). |

---

## 1. Classification overview (high level)

| Category | What it covers in this repo |
|----------|-----------------------------|
| **KEEP / MOVE (V1 core)** | `main.dart`, router/shell (today embedded in `main.dart`), `login_screen`, real **`mono_screen`** (wire it), `learn_hub_screen`, **`create_screen` + `ui/create/`** one-short pieces, **`create_mono`** parts used for one-short, `profile_screen`, `core/*`, `data/*` (trim interfaces), `models/*` (subset), `shared/*`, `ui/ui` exports used by V1 flows. |
| **ARCHIVE (V1 out of scope)** | `features/home/**`, `features/library/**`, long-story **`story/**`, `reader/**`, `writer/**`, `see_more/**`, `settings/**` (if “settings-heavy” deferred), **`create_mono/story_series`**, AI-stories data paths, challenges/community data on Home. |
| **REVIEW** | `lib/app/app_shell.dart` (duplicate shell), two **`episode_bottom_sheet`** implementations, `more_screen`, `story_screen`, `quiz_screen`, `backend/*.md`, imports in `main.dart` that reference unused modules. |
| **POSSIBLY UNUSED** | `StoryScreen` (if never routed), `MoreScreen` (if `/more` uses Profile only), **`mono_screen` import in `main.dart`** while route uses **`_MonoPlaceholderScreen`**, duplicate imports. |

---

## 2. Master mapping table (important paths)

Paths are relative to `lib/` unless noted.

| Current path | Purpose | V1 action | Recommended V1 destination | Notes |
|--------------|---------|-----------|----------------------------|-------|
| **Entry & routing** |
| `main.dart` | `runApp`, `ProviderScope`, `GoRouter`, `NimonApp`, **`AppShell`**, `_CustomBottomNavBar`, **`_MonoPlaceholderScreen`** | MOVE / REHOME | `main.dart` + extract `app/router.dart`, `app/shell/v1_app_shell.dart` (optional split) | V1 must change routes/shell to Mono \| Add \| Profile; today Home is `/`, Mono tab shows **placeholder**, not `MonoScreen`. |
| `app/app_shell.dart` | Legacy `Navigator` + `IndexedStack` (Home, Mono, Settings) | REVIEW → ARCHIVE? | None (delete after confirm unused) or `archive/app_shell_legacy.dart` | **Not used** by `main.dart` GoRouter; duplicate “AppShell” name causes confusion. |
| **Auth** |
| `features/auth/login_screen.dart` | Login / guest / placeholder Google | KEEP / MOVE | `features/auth/presentation/login_screen.dart` | V1 core; guest path should align with post-login **Mono** default. |
| **Mono** |
| `features/mono/mono_screen.dart` | Full Mono UI (tabs, repo, collections) | KEEP / MOVE | `features/mono/presentation/mono_screen.dart` | **V1 core** but router currently uses **`_MonoPlaceholderScreen`** instead—must **wire** or merge. |
| `features/mono/start_mono_sheet.dart` | Sheet to start mono flow | REVIEW | `features/mono/presentation/` | Keep if Mono entry still uses it in V1. |
| **Learn** |
| `features/learn/learn_hub_screen.dart` | Learn hub / deeper explanation | KEEP / MOVE | `features/learn/presentation/learn_hub_screen.dart` | V1 supporting; opened from Mono (`/learn/:id` exists). |
| **Create / one-short** |
| `features/create/create_screen.dart` | Large create hub (tabs: one-short, series, AI, etc.) | MOVE / REHOME | Split: `features/create/presentation/create_one_short_screen.dart` + trim | V1 = **one-short only**; rest **ARCHIVE** inside file or separate routes. |
| `ui/create/**` (widgets, `one_short_paper_view.dart`) | One-short UI building blocks | KEEP / MOVE | `features/create/presentation/widgets/` or `shared/ui/create/` | Core for Add; shared with old flows—**REVIEW** imports from Home. |
| `create_mono/create_mono_screen.dart` | Riverpod create-mono shell | REVIEW | `features/create/` or keep folder | V1 may fold into single create entry; **story series** not V1. |
| `create_mono/one_short_tab.dart` | One-short tab content | KEEP / MOVE | `features/create/presentation/` | V1-relevant. |
| `create_mono/story_series/story_series_screen.dart` | Story series flow (very large) | ARCHIVE | `archive/create_mono/story_series/` or feature-flag | Not V1 scope. |
| `create_mono/widgets/*` | Prompt cards, chips, preview, etc. | REVIEW | `features/create/presentation/widgets/` | Map **per widget**—one-short widgets **KEEP**; series-only **ARCHIVE**. |
| `create_mono/README.md` | Module documentation | REVIEW | `features/create/README.md` | Update when structure stabilizes. |
| **Profile** |
| `features/profile/profile_screen.dart` | Profile tabs, stories | KEEP / MOVE | `features/profile/presentation/profile_screen.dart` | V1 core; simplify if tabs pull non–V1 data. |
| `features/more/more_screen.dart` | Wraps `SettingsScreen` | POSSIBLY UNUSED | — | **`/more` route uses `ProfileScreen`**, not `MoreScreen`; file may be dead. **REVIEW** before delete. |
| **Home (out of V1 main scope)** |
| `features/home/home_screen.dart` | Main discovery feed | ARCHIVE | `archive/features/home/` or remove from router | Not V1 main entry; V1 uses **Mono** as home. |
| `features/home/widgets/*` | Banners, community, trending, mono rows, etc. | ARCHIVE | same | Entire folder non-core for V1. |
| `features/home/sections/*` | Challenges, quick one-shot, horizontal sections | ARCHIVE | same | |
| `features/home/data/challenges.dart` | Challenge copy/data | ARCHIVE | same | |
| **Library** |
| `features/library/library_screen.dart` | Library shell | ARCHIVE | `archive/features/library/` | Not V1 scope. |
| `features/library/following_writers_screen.dart` | Full following list | ARCHIVE | same | Social-adjacent; not V1 main. |
| `features/library/widgets/following_writers_section.dart` | Horizontal following row | ARCHIVE | same | |
| **Long-story / reader / writer** |
| `features/story/story_detail_screen.dart` | Story detail + episodes | ARCHIVE | `archive/features/story/` | Long-story system not V1. |
| `features/story/story_screen.dart` | Alternate story view | POSSIBLY UNUSED → ARCHIVE | — | **No imports found** elsewhere; likely dead. |
| `features/reader/reader_screen.dart` | Block list reader | ARCHIVE | `archive/features/reader/` | Unless Learn reuses—**REVIEW** vs `EpisodeReaderScreen`. |
| `features/reader/episode_reader_screen.dart` | Episode reader route | REVIEW | `features/learn/` or archive | Tied to `/reader` + Episode model; V1 Learn may differ. |
| `features/writer/writer_screen.dart` | Write episode | ARCHIVE | archive | Writer flow not V1. |
| **Other features** |
| `features/see_more/see_more_page.dart` | Filter + list for sections | ARCHIVE | archive | Pulled from Home section headers. |
| `features/see_more/widgets/filter_bottom_sheet.dart` | Filters | ARCHIVE | archive | |
| `features/settings/settings_screen.dart` | Settings | ARCHIVE / REVIEW | archive or minimal entry under Profile | “Settings-heavy” deferred; small About may stay. |
| `features/quiz/quiz_screen.dart` | Quiz UI | POSSIBLY UNUSED → ARCHIVE | archive | **Not in GoRouter** in `main.dart`. |
| `features/widgets/*` | `episode_bottom_sheet`, `real_book_3d_cover`, `red_square` | REVIEW | `shared/` or archive | **Duplicate** `episode_bottom_sheet` vs `ui/bottom_sheets`—consolidate one. |
| **UI / shared** |
| `ui/ui.dart` | Barrel exports | KEEP / MOVE | `shared/ui/ui.dart` | Update exports when paths change. |
| `ui/bottom_sheets/episode_bottom_sheet.dart` | Global episode sheet + `showEpisodeBottomSheetFromMeta` | REVIEW | `shared/ui/bottom_sheets/` | Canonical for many call sites; **duplicate** with `features/widgets/episode_bottom_sheet.dart`. |
| `ui/bottom_sheets/episode_details_sheet*.dart` | Episode details variants | ARCHIVE / REVIEW | archive if story-only | |
| `ui/bottom_sheets/add_mono_bottom_sheet.dart` | Add mono | REVIEW | `features/create/` or `features/mono/` | Depends if V1 still uses. |
| `ui/widgets/episode_action_bar.dart` | Episode actions | ARCHIVE / REVIEW | archive with story flow | |
| `ui/widgets/paper_sheet_widget*.dart`, `one_short_prompt_card.dart` | Create UI | KEEP / MOVE | `features/create/presentation/widgets/` | |
| `shared/widgets/*` | Compact cards, badged cards | REVIEW | `shared/widgets/` | Used by Home/Mono—trim for V1. |
| `widgets/story_card.dart` | Story card | ARCHIVE / REVIEW | archive if no story list in V1 | Used by See More / Home. |
| **Data & models** |
| `data/repo_singleton.dart` | `final StoryRepo repo = StoryRepoMock()` | KEEP / REHOME | `data/repositories/` + DI | V1: split into smaller repos or narrow `StoryRepo`. |
| `data/story_repo.dart` | Abstract repo | KEEP / REHOME | `data/repositories/story_repository.dart` (or split) | Trim methods not needed for V1. |
| `data/story_repo_mock.dart` | Mock stories/episodes | KEEP / REHOME | `data/mock/` | |
| `data/prompt_repository.dart` | Prompts for create | KEEP | `data/repositories/` | One-short create. |
| `data/ai_stories_repository.dart` | AI stories | ARCHIVE | `archive/data/` | AI stories not V1. |
| `data/episode_mock_data.dart` | Episode fixtures | ARCHIVE / REVIEW | archive | Reader/story demos. |
| `data/following_repository.dart` | Following writers mock | ARCHIVE | archive | Library/social. |
| **Models** |
| `models/story.dart` | Story, Episode, blocks | REVIEW | `models/` subset | Mono may still use `Story`; trim if V1 mono model differs. |
| `models/mono.dart`, `oneshot.dart`, `story_category.dart` | Create / mono shapes | KEEP / REVIEW | `models/` | |
| `models/episode_*.dart`, `episode_model.dart` | Episode metadata | ARCHIVE / REVIEW | archive | For reader/detail flows. |
| `models/ai_stories.dart` | AI story payloads | ARCHIVE | archive | |
| `models/filter_state.dart`, `section_key.dart` | See More / Home filters | ARCHIVE | archive | |
| `models/following_writer.dart` | Following | ARCHIVE | archive | |
| **Core** |
| `core/theme.dart` | `buildTheme()` | REVIEW | `core/theme/app_theme.dart` | **Not used** by `NimonApp` (theme inline in `main.dart`)—merge or remove duplicate. |
| `core/responsive.dart`, `share_utils.dart`, `story_categories.dart` | Helpers | REVIEW | `core/utils/` | Keep only what V1 screens import. |
| **Other** |
| `backend/ai_category_prompt_template.md` | Prompt template doc | REVIEW | `docs/` or `assets/` | Not runtime code. |

---

## 3. V1 relevance priority (short list)

**Must align first (routing + product truth)**

- `main.dart` — shell indices, `/` vs `/mono`, placeholder vs `mono_screen.dart`, `/create` scope.
- `features/mono/mono_screen.dart` vs `_MonoPlaceholderScreen` in `main.dart`.

**Auth → Mono → Learn → Create → Profile chain**

- `features/auth/login_screen.dart`
- `features/mono/mono_screen.dart`, `start_mono_sheet.dart`
- `features/learn/learn_hub_screen.dart`
- `features/create/create_screen.dart`, `ui/create/**`, `create_mono/one_short_tab.dart` + selected widgets
- `features/profile/profile_screen.dart`

**Shared / data**

- `data/repo_singleton.dart`, `story_repo*.dart`, `prompt_repository.dart`
- `models/*` (subset)
- `ui/ui.dart`, `ui/bottom_sheets/episode_bottom_sheet.dart` (after duplicate resolution)
- `core/theme.dart` + theme in `main.dart`

---

## 4. Legacy / confusing areas (specific)

| Issue | What exists | Classification |
|-------|-------------|----------------|
| **Two AppShells** | `main.dart` defines **`AppShell`** + bottom nav; `lib/app/app_shell.dart` defines different shell | **REVIEW:** legacy file appears **unused** by GoRouter; safe to archive after grep confirms no imports. |
| **Placeholder vs real Mono** | **`/mono`** → `_MonoPlaceholderScreen`**; **`MonoScreen`** in `features/mono/mono_screen.dart` **imported in `main.dart` but not used** in route builder | **MOVE/KEEP** MonoScreen for V1; **remove placeholder** when wiring; clean **unused import**. |
| **Duplicate episode bottom sheets** | `ui/bottom_sheets/episode_bottom_sheet.dart` vs `features/widgets/episode_bottom_sheet.dart` (same conceptual API) | **REVIEW:** pick canonical file; archive or delete duplicate. |
| **MoreScreen unused** | `more_screen.dart` exists; **`/more`** → **`ProfileScreen`** | **POSSIBLY UNUSED** file; **REVIEW** imports. |
| **StoryScreen unused** | `story_screen.dart` only references itself | **POSSIBLY UNUSED / ARCHIVE**. |
| **Quiz unrouted** | `quiz_screen.dart` not registered in `main.dart` `_router` | **POSSIBLY UNUSED / ARCHIVE**. |
| **Home / Library / Story in shell** | Bottom nav: Home, Mono, Create, Library, Profile | V1 wants **Mono** as main entry—not Home; Library not in scope—**ARCHIVE** routes/tabs when migrating. |
| **Create sprawl** | `create_screen.dart` + `create_mono/` + `ui/create/` + **`create-mono` route** | **REVIEW:** consolidate **one-short** under one feature folder; **ARCHIVE** story series + AI stories. |
| **main.dart unused imports** (verify with analyzer) | e.g. `mono_screen`, `more_screen`, `reader_screen`, `story_repo_mock` may be unused | **REVIEW** — analyzer `unused_import` will list. |

---

## 5. Safe migration order (phased, minimal breakage)

Suggested **later cleanup** order when you actually move code (not part of this doc):

1. **Routing truth** — Document current `GoRouter` table (paths, shell vs full-screen). Decide V1 default route after login (`/mono` vs `/`). **Wire `MonoScreen`** in place of placeholder **before** deleting Home tab, or swap tabs incrementally.
2. **Single shell** — Extract shell from `main.dart` into `app/shell/`; delete or archive `lib/app/app_shell.dart` after confirming unused.
3. **Bottom nav V1** — Replace Home/Library with Mono/Add/Profile layout; keep old routes **behind feature flag** or commented until stable.
4. **Mono** — Point `/mono` to real `mono_screen.dart`; move widgets under `features/mono/presentation/widgets/`.
5. **Create (one-short)** — Extract one-short from `create_screen.dart` / `create_mono/one_short_tab.dart` / `ui/create/` into `features/create/`; **archive** `story_series_screen.dart` and AI tabs from navigation.
6. **Profile** — Keep `profile_screen.dart`; fold minimal settings if needed; remove `more_screen` if unused.
7. **Learn** — Ensure `LearnHubScreen` reachable from Mono only; trim params if `/learn/:id` unused.
8. **Shared / UI** — Resolve **one** episode bottom sheet; move barrels to `shared/ui/`.
9. **Data** — Split or narrow `StoryRepo`; move mocks to `data/mock/`; **archive** `following_repository`, `ai_stories_repository` if features gone.
10. **Models** — Delete or move unused models with archived features.
11. **Archive** — Move `features/home`, `features/library`, `features/story`, `features/reader`, `see_more`, optional `settings`, `widgets/story_card` to `archive/` **or** separate git branch **last**, after tests pass.

**Rule of thumb:** **Router + shell first**, then **Mono + Create**, then **Profile + Learn**, then **delete/archive** Home/Library/story stacks.

---

## 6. Final recommendation

- Use this table as a **checklist**—not a mandate to delete files immediately.
- **Highest-risk confusion today:** Mono **placeholder** vs **`mono_screen.dart`**, and **two AppShell** files. Fix those in **routing** before large folder moves.
- **Highest bulk for V1:** `home_screen.dart`, `create_screen.dart`, `story_series_screen.dart`—plan **archival** of non-one-short paths rather than rewriting everything at once.

---

*Documentation only. No repository files were modified to create `CURRENT_FILES_KEEP_MOVE_ARCHIVE_MAPPING.md`.*
