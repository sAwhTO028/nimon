# StoryRepo Live Dependency Map

**Purpose:** Snapshot of how `StoryRepo`, `StoryRepoMock`, legacy story/episode surfaces, and related models relate to **live** GoRouter surfaces (`MonoScreen`, `ProfileScreen`) versus **legacy** code, before **Cleanup Wave 2b** archive work.  
**Method:** Static analysis (`rg`-style search of `lib/**/*.dart`) plus reads of `lib/main.dart`, `lib/data/story_repo*.dart`, `lib/features/mono/mono_screen.dart`, `lib/features/profile/profile_screen.dart`. **No code was modified** for this document.

**Related docs:** `docs/CLEANUP_WAVE_2_PLAN.md`, `docs/CLEANUP_WAVE_2A_REPORT.md`, `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`, `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`.

---

## 1. Live Entry Points

`lib/main.dart` imports `repo_singleton.dart` and passes the global `StoryRepo repo` instance only into:

| Route / surface | Widget | `StoryRepo` wiring |
|-----------------|--------|---------------------|
| `/mono` | `MonoScreen` | `repo: repo` (`NoTransitionPage` in `StatefulShellRoute` branch). |
| `/mono-reader` | `MonoScreen` | `repo: repo` (full-screen reader variant with `initialItemsOverride` / `initialIndexOverride`). |
| `/more` | `ProfileScreen` | `repo: repo` (Profile tab shell; optional `initialTabIndex`, `highlightDraftId`). |

No other **registered** GoRoute builders pass `StoryRepo` from `main.dart`. Legacy `HomeScreen`, `StoryDetailScreen`, `SeeMorePage`, etc. are **not** in the current router table (`docs/CLEANUP_WAVE_2_PLAN.md` §1) but still contain `StoryRepo` parameters or call sites if reached via old `Navigator` routes or dead imports.

**Singleton:** `lib/data/repo_singleton.dart` sets `final StoryRepo repo = StoryRepoMock();` — this runs for every app launch that imports `main.dart`’s repo, so **`StoryRepoMock` construction is a live cold-start dependency** even when live screens never call `StoryRepo` methods.

---

## 2. StoryRepo Methods Used By Live Mono

**File:** `lib/features/mono/mono_screen.dart`

| Finding |
|--------|
| `MonoScreen` declares `final StoryRepo repo` and `required this.repo` in its constructor. |
| **No** occurrences of `repo.` / `widget.repo` / `this.repo` **method calls** on `StoryRepo` were found in this file (only the field and constructor wiring). |

**Exact `StoryRepo` methods called by live Mono:** **none** (injection only).

Live Mono feed and reader data use **`MonoFeedItem`**, **`MonoContent`**, and related types in the same file and `mono_content_model.dart`, not `StoryRepo` list/detail APIs.

---

## 3. StoryRepo Methods Used By Live Profile

**File:** `lib/features/profile/profile_screen.dart`

| Finding |
|--------|
| `ProfileScreen` declares `final StoryRepo repo`. |
| Published tab and workspace flows use **`RemotePublishedMonoRepository`**, **`storyDraftRepositoryProvider`** / `StoryDraftRepository`, and creator models — local variables named `repo` in those blocks refer to **other** repository types, not `StoryRepo`. |
| **No** `widget.repo.<method>` or unambiguous `StoryRepo` method invocations on the profile `StoryRepo` field were found. |

**Exact `StoryRepo` methods called by live Profile:** **none** (injection only).

---

## 4. StoryRepo Methods Used Only By Legacy Code

Call sites in `lib/` (excluding `story_repo.dart` / `story_repo_mock.dart` definitions):

| Method | Legacy consumers (representative) |
|--------|-----------------------------------|
| `listStories` | `lib/features/home/home_screen.dart` |
| `getStories` | `home_screen.dart`, `lib/features/home/widgets/community_section.dart` |
| `getStoryById` | `lib/features/story/story_detail_screen.dart` |
| `getEpisodesByStory` | `home_screen.dart`, `story_detail_screen.dart`, `community_section.dart` |
| `getStoriesBySection` | `lib/features/see_more/see_more_page.dart` |
| `getFilteredStories` | `see_more_page.dart` |
| `fetchQuickOneShots` | `lib/features/home/sections/quick_one_shot_section.dart` |

**No Dart call sites in `lib/`** (only abstract + mock):

| Method | Notes |
|--------|--------|
| `addEpisode` | Comment on interface says writer append; **`WriterScreen` holds `StoryRepo` but does not call `widget.repo`** — same “injection / dead port” pattern as Mono/Profile. |
| `getQuizByStory` | Placeholder; mock returns empty list; **no callers** in `lib/`. |

**Pass-through / optional wiring (legacy, no method calls found):**

- `lib/features/writer/writer_screen.dart` — `StoryRepo repo` parameter, **no** `widget.repo` usage.
- `lib/features/home/widgets/trending_for_you.dart`, `section_header.dart` — optional `StoryRepo?` for navigation to see-more / story flows; **`TrendingForYou` opens `/story-details` with `Navigator.pushNamed` and map arguments, not `StoryRepo`**.

---

## 5. Models Used By Live Code

### `lib/models/story.dart` — `Story`, `Episode`, `EpisodeBlock`, `BlockType`

| Area | Usage |
|------|--------|
| **Live Mono / Profile** | **Do not** import `story.dart` in `mono_screen.dart` or `profile_screen.dart`. |
| **Live compile graph** | `StoryRepo` (`story_repo.dart`) **imports** `story.dart`; any code that references `StoryRepo` transitively depends on those types for **analysis and future real implementations**. |
| **Legacy** | `HomeScreen`, `StoryDetailScreen`, `WriterScreen`, `SeeMorePage`, `TrendingForYou`, `CommunitySection`, mocks, etc. |

### `lib/models/story_category.dart` — `StoryCategory`

| Area | Usage |
|------|--------|
| **Live Mono / Profile** | **No** direct imports in `mono_screen.dart` / `profile_screen.dart`. |
| **Transitive** | Pulled by `story.dart` (`Story.category`); required while `Story` remains the `StoryRepo` row type. |

### `lib/models/episode_model.dart` / `lib/models/episode_meta.dart`

| Area | Usage |
|------|--------|
| **Live Mono / Profile** | **No** references in `mono_screen.dart` or `profile_screen.dart`. |
| **Legacy / shared** | `episode_bottom_sheet.dart`, `episode_details_sheet.dart`, `show_episode_modal.dart`, `home_screen.dart`, `mono_collection_row.dart`, `quick_one_shot_section.dart`, `share_utils.dart`, `episode_action_bar.dart`, tests. |

**Conservative read:** **`Story` + `Episode` (+ blocks) + `StoryCategory` (via `Story`)** must remain for `StoryRepo` and `StoryRepoMock`. **`EpisodeModel` / `EpisodeMeta`** are **not** required for current live Mono/Profile behavior but are **DO_NOT_TOUCH** for Wave 2b if any legacy archive moves could break tests or transitive imports you have not re-verified.

---

## 6. Mock Data Dependency

### `lib/data/story_repo_mock.dart`

- Eagerly builds `_stories`, `_episodes`, `_oneShots` at library load via `late final` initializers.
- Implements **all** `StoryRepo` methods; **legacy** home/see_more/story_detail paths exercise subset; **live** Mono/Profile do **not** call methods but **still load this library** through `repo_singleton` → **`StoryRepoMock()` runs `_genStories` / `_genEpisodes` / `_genOneShots` on startup.**

### `lib/data/episode_mock_data.dart`

- Imported by `story_repo_mock.dart` for **`getMockEpisodeText`** inside `_genEpisodes` (long canonical narration text per episode index).
- **Functional requirement for live Mono/Profile UI:** **none** for feed/reader (they do not use `getEpisodesByStory`).
- **Cold-start requirement today:** **yes** — as long as `repo` is a `StoryRepoMock`, episode mock text is part of **singleton initialization**, not lazy behind first `StoryRepo` call.

---

## 7. Keep / Archive / Do Not Touch Recommendation

| Item | Classification | Rationale |
|------|----------------|-----------|
| `story_repo.dart`, `repo_singleton.dart`, `StoryRepoMock` | **KEEP_NOW** | Wired from `main.dart`; singleton is live cold-start path. |
| `story.dart`, `story_category.dart` | **KEEP_NOW** | `StoryRepo` API surface; transitive for any `StoryRepo`-typed widget. |
| `episode_mock_data.dart` | **KEEP_NOW** (until mock split) | Used by `StoryRepoMock` episode generation at init. |
| `MonoScreen.repo` / `ProfileScreen.repo` | **LEGACY_ONLY_BUT_WAIT** or **DO_NOT_TOUCH** | Unused for method calls today; removing parameters is a **behavior/API refactor** — **do not** do in Wave 2b without an explicit task and router/widget signature updates. |
| `addEpisode` / `getQuizByStory` on `StoryRepo` | **DO_NOT_TOUCH** (interface) | No callers; still part of public contract and mock; changing risks unknown tests/tools. |
| `lib/features/home/**`, `library/**`, `see_more/**`, `story/**`, `writer/**`, `create_mono/**`, legacy `ui/**` episode stack | **SAFE_AFTER_ARCHIVE** (per plan, re-verify) | Not in live router; `docs/CLEANUP_WAVE_2_PLAN.md` §3. **Re-run import graph before moving.** |
| `episode_model.dart` / `episode_meta.dart` | **DO_NOT_TOUCH** (for this wave) | Tests + legacy UI + share helpers; uncertain if CI tests import archived paths. |

---

## 8. Future Pagination Migration Plan

Aligned with `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md` and `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`:

1. **Today:** Live Mono/Profile **do not** call `StoryRepo` list APIs — pagination of **`StoryRepo`** does **not** block Mono/Profile UX **unless** you later wire feed/discovery through `StoryRepo`.
2. **Add paged APIs alongside** (e.g. `Future<PageResult<Story>> fetchStoriesPage(PageRequest)`) on a **new** interface or extended class; keep existing `Future<List<Story>>` methods until legacy archive removes call sites.
3. **Mono/Profile-safe path:** When/if `MonoScreen` / `ProfileScreen` start calling `StoryRepo`, implement **only** the new methods they need (e.g. mono-native feed) in a **remote** repo; **`StoryRepoMock`** can return single-page `PageResult` with `hasMore: false` for tests.
4. **Split mock (optional later):** Lazy-init or split **`StoryRepoMock`** so cold start does not build 50 stories × episodes if live product never calls `StoryRepo` — **out of scope** for this doc; would be a performance task, not Wave 2b archive.

---

## 9. Risks Before Wave 2b Archive

1. **Singleton side effects:** Archiving legacy folders does **not** remove `StoryRepoMock` eager init; **memory/CPU at startup** stay until mock is refactored.
2. **Hidden dynamic imports / tests:** Tests may import legacy widgets (`show_episode_modal`, episode sheets) — **Wave 2a** already kept `show_episode_modal.dart` because **`test/episode_bottom_sheet_test.dart`** imports it. Similar coupling may exist for other legacy files.
3. **Stray routes:** `Navigator.pushNamed('/story-details', …)` in legacy widgets could still exist at runtime if any **live** code path reaches them — **re-grep** for `pushNamed`, `HomeScreen`, and `story-details` before archive.
4. **Over-trimming `StoryRepo`:** Removing methods that only legacy uses **before** deleting all call sites and tests causes **analyzer errors**; order should be: archive/delete legacy → then narrow interface in a dedicated PR.
5. **False sense of “unused” `repo` on Mono/Profile:** Removing the field without auditing **future** product specs could block a quick wiring of discovery — treat as **product/API decision**, not dead-code cleanup, unless explicitly approved.

---

## Output Summary

| Metric | Value |
|--------|--------|
| **Live `StoryRepo` method count** (methods **invoked** from `mono_screen.dart` + `profile_screen.dart`) | **0** |
| **Legacy-only `StoryRepo` method count** (methods with **only** non-router legacy call sites under `lib/features/home`, `see_more`, `story`, and related widgets) | **7** (`listStories`, `getStories`, `getStoryById`, `getEpisodesByStory`, `getStoriesBySection`, `getFilteredStories`, `fetchQuickOneShots`) |
| **StoryRepo methods with no `lib/` callers** | **2** (`addEpisode`, `getQuizByStory`) — still implemented on `StoryRepoMock` |
| **Models that must stay** (for current `StoryRepo` + mock stack) | **`Story`**, **`Episode`** (+ **`EpisodeBlock`**), **`StoryCategory`** via `story.dart`; **`OneShot`** used by `fetchQuickOneShots` (import from `story_repo.dart`). |
| **Models live Mono/Profile do not use directly** | **`EpisodeModel`**, **`EpisodeMeta`** (legacy / sheets / share). |
| **Files / folders safe to archive later** (re-verify before move) | Per **`docs/CLEANUP_WAVE_2_PLAN.md` §3:** `lib/features/home/**`, `lib/features/library/**`, `lib/features/see_more/**`, `lib/features/story/**`, `lib/features/writer/**`, `lib/create_mono/**`, and associated legacy `lib/ui/**` episode/story barrels — **not** `story_repo*.dart`, `repo_singleton.dart`, `episode_mock_data.dart`, or `models/story*.dart` until `StoryRepo` is re-homed or replaced. |
| **Recommended next step** | Execute **Wave 2b archive** per plan with a **post-move** `flutter analyze` and **test** run; keep **`StoryRepo` + mock + episode mock + story models** on **KEEP_NOW**; treat **`MonoScreen`/`ProfileScreen` `repo` fields** as **DO_NOT_TOUCH** unless a separate approved task removes injection from `main.dart` and widgets. |
