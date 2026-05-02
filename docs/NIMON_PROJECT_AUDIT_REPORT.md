# Nimon Project Audit Report

**Audit type:** Read-only structure and dependency survey (no code moves, renames, or deletions).  
**Method:** Static inspection of `lib/`, `test/`, `pubspec.yaml`, `assets/`, and `nimon-backend/`; `grep`-style reference tracing from `lib/main.dart` and registered `GoRouter` routes; conservative classification where uncertainty remains.

**Scan scope (approximate):** **551** files under the repository root excluding `.git/`, `build/`, `.dart_tool/`, and `node_modules/` (PowerShell recursive count). **`202`** Dart files under `lib/` and **`8`** under `test/` counted separately.

---

## 1. Project Summary

Nimon is a **Flutter 3.x** app using **Material 3**, **Riverpod** (`flutter_riverpod`), and **go_router** for navigation. A **NestJS-style** backend lives in `nimon-backend/` (TypeScript, Prisma modules for story drafts and published monos). The Flutter `pubspec` declares a single asset directory: `assets/images/`.

**Product entry today:** `GoRouter` in `lib/main.dart` uses `initialLocation: '/login'`, then a **stateful shell** with **`/mono`** (vertical mono feed / reader) and **`/more`** (profile hub), plus full-screen **`/create`** and **`/learn/:id...`** branches. **There is no registered route for `/`**, and several `context.push` targets from legacy UI **do not exist** in the router table (see §5).

**Important structural note:** A second, older shell (`lib/app/app_shell.dart`) defines another `AppShell` using `Navigator` + `IndexedStack` (Home, Mono, Settings). It is **not imported** by `main.dart`. The live shell is **`AppShell` inside `main.dart`**, which wraps `StatefulNavigationShell` and `FloatingDockNavBar`.

---

## 2. Current Architecture Detected

| Layer | Technology / location |
|--------|-------------------------|
| **Entry** | `lib/main.dart` — `ProviderScope`, `MaterialApp.router`, `GoRouter` |
| **Shell** | `AppShell` in `main.dart` — dock tabs Mono / Create / Profile (`/more`) |
| **State** | Riverpod — `StateNotifierProvider`, `StateProvider`, `Provider` |
| **Navigation** | `go_router` — mix of `go`, `push`, `extra` payloads, query tabs |
| **Persistence** | `shared_preferences` (settings, draft index, etag hints) |
| **Networking** | `http` — `RemoteStoryDraftRepository`, `RemotePublishedMonoRepository` |
| **Audio** | `just_audio` — listening module + creator sentences preview |
| **Theming** | `lib/core/theme.dart` + `google_fonts` (Noto Sans JP) |
| **Backend** | `nimon-backend/src` — modules: `story-drafts`, `published-monos`, `users`, `auth`, `health`, `processing`, `prisma` |

**Observed pattern:** Large “god” screens (`mono_screen.dart`, `story_creator_sentences_screen.dart`, `profile_screen.dart`) centralize orchestration; learn flows are split into multiple routed screens; creator flow uses **URL query parameters** (`draftId`, `panel=`) synchronized with drawer session state.

---

## 3. Valid Product Scope Mapping

| Scope area | Primary implementation (live router path) | Notes |
|------------|-------------------------------------------|--------|
| **Home Mono** | `lib/features/mono/mono_screen.dart` — `/mono`, `/mono/search`, `/mono-reader` | This is the **actual** home surface in `GoRouter`, not `HomeScreen`. |
| **Add / Create** | `lib/features/create/*` — `/create`, `/create/story/basics`, `/create/story/sentences` (+ `?panel=` learn editors) | Standalone `/create/story` redirects to `/create`. |
| **Profile** | `lib/features/profile/*` — `/more` (+ query `tab=`), `/profile/public`, `/profile/share`, notifications, followers/following | |
| **Learn (from mono)** | `lib/features/learn/*` — `/learn/:id`, grammar, vocab, quiz, listening | Reached via navigation `extra` from mono/learn entry; creator embeds panels on sentences route. |

**Disconnected from current router graph (treat as legacy / V2 / optional):**

- `lib/features/home/**` — **entire “discovery home” tree** is only referenced by the **unused** `lib/app/app_shell.dart`, not by `main.dart`.
- `lib/create_mono/**` — alternate “create mono” prototype; **no imports** from `main.dart` or routed features found.
- Standalone screens under `features/story`, `features/library`, `features/see_more`, `features/writer`, `features/quiz`, `features/more` — **not registered** in `GoRouter` and largely **not imported** by live paths (see §13).

**Learn modules:** Routed `/learn/...` is **connected** to the app. **Standalone** `LearnScreen` (`learn_screen.dart`) and **`QuizScreen`** (`features/quiz/quiz_screen.dart`) are **not** on the router and show **no importers** → classify **`REVIEW_OPTIONAL_V2`** (or archive) unless you plan a separate hub.

---

## 4. Feature Classification

Legend: each path is assigned **one primary** bucket; duplicates are called out in §12.

### KEEP_CORE

- `lib/main.dart` (router + live `AppShell`)
- `lib/core/*` — theme, tokens, typography, layout, breakpoints, responsive helpers, `share_utils.dart`, `story_categories.dart`
- `lib/widgets/floating_dock_nav_bar.dart`
- `lib/features/auth/login_screen.dart`, `dev_current_user_provider.dart`

### KEEP_SHARED

- `lib/ui/app_messenger.dart`
- `lib/ui/widgets/nimon_circle_nav_button.dart`
- `lib/ui/reading/*` — furigana / sentence / translation / ruby (used by mono + creator)
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart`
- `lib/features/settings/*`, `help_feedback_screen.dart`

### KEEP_BACKEND (Flutter client integration)

- `lib/features/create/data/remote_backend_config.dart`
- `lib/features/create/data/remote_story_draft_repository.dart`
- `lib/features/profile/data/remote_published_mono_repository.dart`
- `nimon-backend/**` (API surface paired with above)

### KEEP_FEATURE_HOME_MONO

- `lib/features/mono/**` (primary: `mono_screen.dart`, `mono_search_screen.dart`, `mono_reading_layout.dart`, `mono_content_model.dart`, reader dock, sheets tied to mono)
- `lib/features/mono/mono_reader_menu_origin.dart` (if present in tree)

### KEEP_FEATURE_ADD_STORY

- `lib/features/create/**` including `create_screen.dart`, `story_creator_*`, `creator_*`, `data/story_draft_*`, DTOs, mappers, validation, publish flow

### KEEP_FEATURE_PROFILE

- `lib/features/profile/**` (screens, drawers, public profile, published/saved/workspace UI, DTO parsers)

### KEEP_FEATURE_LEARN

- `lib/features/learn/**` **except** `learn_screen.dart` (unwired; see §13)

### REVIEW_OPTIONAL_V2

- `lib/create_mono/**` — self-contained prototype + README; not wired to router
- `lib/features/learn/learn_screen.dart` — no Dart importers found
- `lib/features/quiz/quiz_screen.dart` — no Dart importers found (separate from routed quiz flow)
- Large corpus of **root-level `*.md` planning/audit documents** — product/process artifacts, not runtime code

### UNUSED_CANDIDATE

*(No imports from `main.dart` or from any file reachable from it via `package:nimon/...` or relative imports into live features — verified by reference search.)*

- **Entire** `lib/features/home/**` (16 `.dart` files) — only `lib/app/app_shell.dart` imports `HomeScreen`
- `lib/features/story/story_detail_screen.dart`, `story_screen.dart` — no external importers; `/story/:id` **not** in router
- `lib/features/library/**` — internal only; `/library/...` **not** in router
- `lib/features/see_more/**` — only used from dead `home` / `section_header`
- `lib/features/writer/writer_screen.dart` — only referenced from `red_square.dart`
- `lib/features/more/more_screen.dart`
- `lib/features/widgets/red_square.dart`
- `lib/features/widgets/real_book_3d_cover.dart`
- `lib/features/mono/start_mono_sheet.dart`
- `lib/models/mono.dart` — **no** `import` of this file found
- `lib/data/ai_stories_repository.dart`, `lib/models/ai_stories.dart` — mutually contained, no app imports
- **Large `lib/ui/` subtree** reachable only through dead barrels or dead sheets, including notably:
  - `lib/ui/ui.dart` barrel — importers are **only** dead `home` / `story_detail` / `mono_collection_row` / `quick_one_shot_section`
  - `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart`, `episode_bottom_sheet.dart`, `episode_details_sheet*.dart`
  - `lib/ui/create/**`, `lib/ui/drawer/nimon_drawer_section.dart`, `lib/ui/story/nimon_story_list_item.dart`, `lib/ui/widgets/paper_sheet_widget*.dart`, `lib/ui/widgets/sheets/show_episode_modal.dart`, `lib/ui/widgets/one_short_prompt_card.dart`
  - `lib/ui/create/one_short_paper_view.dart` — not imported
- `lib/shared/widgets/compact_story_card.dart`, `lib/shared/widgets/cards/episode_badged_card.dart` — no importers found (`oneshot_badged_card` only from dead `quick_one_shot_section`)
- `lib/widgets/story_card.dart` — only `see_more_page.dart`

### DUPLICATE_CANDIDATE

- **`AppShell` name collision:** `lib/main.dart` (live) vs `lib/app/app_shell.dart` (legacy) — different constructors and behavior
- **Episode bottom sheet:** `lib/ui/bottom_sheets/episode_bottom_sheet.dart` vs `lib/features/widgets/episode_bottom_sheet.dart` — parallel APIs (`showEpisodeBottomSheet`); **only the `ui/` copy** is referenced (from dead paths + self); **`features/widgets`** copy has **no** Dart importers found

### DELETE_CANDIDATE

*Conservative list: only items that are **duplicate**, **provably unreferenced**, or **standalone demo files**. Do **not** delete until a human confirms no upcoming re-merge of legacy home.*

- `lib/app/app_shell.dart` — unused duplicate shell (after confirming no external package references)
- `lib/features/widgets/episode_bottom_sheet.dart` — duplicate of `ui/` implementation; zero importers
- `lib/ui/create/one_short_paper_view.dart` — zero importers
- `lib/features/widgets/red_square.dart` — demo widget, zero importers
- `lib/models/mono.dart` — zero importers (verify no barrel exports or codegen)
- `lib/data/ai_stories_repository.dart` + `lib/models/ai_stories.dart` — closed pair, zero external use

### NEEDS_MANUAL_REVIEW

- **Whether to delete or archive the whole `features/home` product surface** — large removal; may still hold UX you want to reattach later
- **`lib/ui/ui.dart` and everything only exported through it** — deleting the barrel without mapping each export risks missing a future import path
- **`EpisodeReaderScreen` / `episode_bottom_sheet` chain** — currently only invoked from **orphaned** home/story paths; confirm you will never open legacy episode sheets before deleting reader + mock episode prefs usage
- **`StoryRepo` / `StoryRepoMock` / `episode_mock_data`** — still tied to singleton `repo`; mono may still call `StoryRepo` methods even if episode UI is dead — **profile** vs **mono** data contracts need human confirmation
- **`modal_bottom_sheet` pubspec dependency** — no `package:modal_bottom_sheet` import found in `lib/` (may be unused or planned)
- **`intl` direct usage** — no `package:intl` import in `lib/` (may be transitive only)
- **Root `*.md` files** — dozens of planning documents; retention is a **process** decision, not a code dependency decision

---

## 5. Route / Navigation Audit

### Registered `GoRouter` routes (from `lib/main.dart`)

| Path pattern | Screen / behavior |
|--------------|-------------------|
| `/login` | `LoginScreen` |
| `/profile/public` (+ optional `folder/:folderId`) | `PublicProfileScreen`, `PublicFolderDetailScreen` |
| `/profile/share` | `ShareProfileScreen` (hard-coded demo args) |
| `/profile/notifications` | `NotificationsScreen` |
| `/profile/followers`, `/profile/following` | `ProfileConnectionsScreen` |
| `/settings`, `/settings/help` | `SettingsScreen`, `HelpFeedbackScreen` |
| `/create` | `CreateScreen` or `StoryCreatorAddTabScreen` (query `editBasics`, `tab`) |
| `/create/story` | Redirect to `/create` when path is exactly `/create/story` |
| `/create/story/basics` | `StoryCreatorBasicsScreen` |
| `/create/story/sentences` | `StoryCreatorSentencesScreen` |
| `/create/story/learn` (+ children) | Redirects into sentences with `?panel=` |
| `/learn/:id/...` | Learn hub, grammar, vocab, quiz, listening, results |
| `/mono/search` | `MonoSearchScreen` |
| `/mono-reader` | `MonoScreen` with `extra` payload |
| Shell `/mono` | `MonoScreen` |
| Shell `/more` | `ProfileScreen` (query `tab`, `highlight`, `saved`) |

### Pushed / referenced paths **missing** from `GoRouter`

| Path | Source | Risk |
|------|--------|------|
| `/story/:id` | `home_screen.dart` | **Broken navigation** if `HomeScreen` were ever shown |
| `/library/following-writers` | `following_writers_section.dart` | **No route** — runtime error on tap |
| `/` | `story_detail_screen.dart` (`context.go('/')`) | **No `/` route** — likely broken |
| `/premium`, `/discover?...` | commented in `home_screen.dart` | N/A (commented) |

### Screens **not** in router but potentially embedded

- Creator grammar / quiz / vocab / audio editor **widgets** — embedded from `StoryCreatorSentencesScreen` and related creator files (not separate top-level routes).

---

## 6. State Management Audit

| Provider / notifier | File | Role |
|---------------------|------|------|
| `themeModeSettingProvider` | `settings_providers.dart` | Theme mode |
| `appLocaleSettingProvider` | idem | Locale |
| `readingTextScaleSettingProvider` | idem | Text scale |
| `notificationsEnabledSettingProvider` | idem | Notification toggle |
| `monoExplanationEnabledSettingProvider` | idem | Mono explanation toggle |
| `storyCreatorDraftProvider`, `storyCreatorDraftDataProvider` | `story_creator_provider.dart` | Creator draft state |
| `creatorDrawerSessionProvider` | `creator_drawer_session.dart` | Drawer ↔ route sync |
| `storyDraftRepositoryProvider` | `story_draft_repository_provider.dart` | Abstract draft repo |
| `creatorEntryChannelProvider`, `creatorPublishInProgressProvider`, … | `creator_back_policy.dart` | Creator navigation / flags |
| `quizTabIndexProvider` | `creator_quiz_ui_state.dart` | Quiz sub-tab |
| `learnExplanationLanguageProvider` | `learn_explanation_language_provider.dart` | Learn language preference |
| `devCurrentUserProvider` | `dev_current_user_provider.dart` | Dev user id (used by creator provider) |
| `profileProcessingListRefreshProvider` | `profile_processing_refresh.dart` | Profile list bump |
| `createMonoProvider` | `create_mono/create_mono_screen.dart` | **Orphan** — no router import |

---

## 7. Backend / Repository / Service Audit

### Flutter (`lib/data`, feature `data/`)

| Artifact | Role |
|----------|------|
| `repo_singleton.dart` | Global `StoryRepo repo = StoryRepoMock()` |
| `story_repo.dart` / `story_repo_mock.dart` | Abstract + mock stories/episodes |
| `episode_mock_data.dart` | Mock episodes (episode UI paths mostly orphaned) |
| `following_repository.dart` | Following writers (only referenced from **orphaned** library UI) |
| `prompt_repository.dart` | Prompt catalog — used from **`lib/ui/create/**`** which is currently **orphaned** from live graph |
| `story_draft_repository.dart`, `local_story_draft_repository.dart`, mappers, DTOs | Draft persistence + mapping |
| `remote_story_draft_repository.dart` | HTTP draft CRUD + processing |
| `remote_published_mono_repository.dart` | HTTP published mono fetch |
| `remote_backend_config.dart` | Base URL / config |

### `nimon-backend` (TypeScript)

- `story-drafts` — controller, service, DTOs, requests
- `published-monos` — controller, service, DTOs, common helpers
- `users`, `auth`, `prisma`, `health`, `processing` modules

---

## 8. Model / Entity Audit

| Model / file | Status |
|----------------|--------|
| `models/story.dart`, `episode_model.dart`, `episode_meta.dart`, `filter_state.dart`, `section_key.dart`, `story_category.dart`, `following_writer.dart`, `oneshot.dart` | Used from **legacy home / story / repo mock** paths and/or shared UI — **confirm** before removal |
| `models/mono.dart` | **No imports found** — UNUSED_CANDIDATE |
| `models/ai_stories.dart` | Only with `ai_stories_repository.dart` — UNUSED_CANDIDATE |
| `features/mono/mono_content_model.dart`, mono reader types | **Live** mono feed |
| `features/create/story_v1_model.dart`, `story_creator_models.dart`, DTOs under `data/dto/` | **Live** creator |

**Duplicate / parallel story representations:** `CreatorStoryV1` / sentence card models vs `Story` / `Episode` mock world — intentional separation but increases cognitive load; cleanup should not merge blindly.

---

## 9. UI / Widget Audit

- **Live shared UI:** `nimon_circle_nav_button`, `app_messenger`, reading stack (`nimon_ruby_text`, `nimon_sentence_block`, …), `mono_story_options_sheet`.
- **Mono:** `mono_screen.dart` is extremely large; houses feed, reader, reactions, navigation side-effects.
- **Creator:** multiple `story_creator_*` screens + drawers; grammar overlays and editors.
- **Orphan / legacy clusters:** `features/home/widgets`, `features/home/sections`, `features/widgets` (partial), `shared/widgets` cards not referenced, `ui/create` pipeline, `ui` barrel consumers.

---

## 10. Asset Audit

Declared: `assets/images/` (directory).

| Asset | Notes |
|-------|--------|
| `assets/images/one_short/*.png` | Referenced from **live** `mono_screen.dart` category mapping |
| `assets/images/mono_hero_blur_backdrop.png` | **No code reference found** in `lib/` — UNUSED_CANDIDATE |
| `assets/images/README.md` | Documentation only |
| **Missing vs code expectations** | Prior audits (`NIMON_ASSET_AUDIT.md`) note `assets/images/writer.png` and flat `assets/images/<category>.png` paths referenced from `story_categories.dart` / `mono_collection_row.dart` — **those call sites are in orphaned trees**, but **risk remains** if you re-enable home without fixing assets |

---

## 11. Pubspec Dependency Audit

| Package | Observation |
|---------|----------------|
| `go_router`, `flutter_riverpod`, `google_fonts`, `uuid`, `collection`, `http`, `shared_preferences`, `just_audio`, `image_picker`, `file_picker` | **Used** from live creator / mono / learn / settings paths (or tests) |
| `modal_bottom_sheet` | **No `package:modal_bottom_sheet` import** in `lib/` — flag as **UNUSED_CANDIDATE** or remove after test grep |
| `intl` | **No direct** `import 'package:intl/...'` in `lib/` — may be **transitive** via SDK; treat as **NEEDS_MANUAL_REVIEW** before removal |
| `animated_accordion` | Only referenced from **`add_mono_bottom_sheet.dart`**, which is **orphaned** — if that sheet is deleted, dependency may be removable |

---

## 12. Duplicate Code Candidates

- Two **`AppShell`** classes (`main.dart` vs `app/app_shell.dart`)
- Two **`episode_bottom_sheet.dart`** implementations (`ui/` vs `features/widgets/`)
- Overlapping **episode / story detail** presentation vs **mono reader** (different mental models; shared `EpisodeMeta` in legacy only)

---

## 13. Unused / Abandoned Code Candidates

**High confidence orphaned trees (not referenced from live `main.dart` import graph):**

- `lib/features/home/**`
- `lib/features/library/**`, `see_more/**`, `story/**` (both files), `writer/**`, `more/**`
- `lib/create_mono/**`
- `lib/app/app_shell.dart`
- Most of `lib/ui/**` except the **KEEP_SHARED** list in §4
- `lib/shared/widgets/compact_story_card.dart`, `episode_badged_card.dart`
- `lib/widgets/story_card.dart`

**Unregistered navigation targets:** `/story/:id`, `/library/following-writers`, `/` (see §5).

---

## 14. Delete Candidates

See **DELETE_CANDIDATE** in §4. Prefer **merge-then-delete** for duplicate bottom sheets rather than deleting both.

**Do not mass-delete** `features/home` until product confirms mono-only direction.

---

## 15. Needs Manual Review

- **Product decision:** Is **`HomeScreen` / discovery** officially retired in favor of **Mono-only home**? If not, work is **re-wiring**, not deletion.
- **Episode reader stack** vs **mono reader** — overlapping user value; removal affects `episode_reader_screen.dart`, prefs usage, and mock data.
- **`StoryRepoMock` contract** — still global; trimming `Story`/`Episode` models may break mock API used in ways not fully traced in one pass.
- **Backend alignment** — `nimon-backend` modules beyond drafts/published monos (`users`, `auth`, `processing`) — confirm which endpoints the Flutter client actually calls before labeling dead.
- **Tests** — `test/*.dart` may import subsets not scanned in exhaustive depth; run `dart analyze` / tests after any deletion wave.

---

## 16. Performance Risk Areas

- **`mono_screen.dart`** — very large widget file; high rebuild / scroll cost risk; difficult to tree-shake and reason about.
- **`story_creator_sentences_screen.dart`** — large; embeds audio player and many panels.
- **`profile_screen.dart`** — large; multiple tabs and lists.
- **Blur / backdrop filters** — present in legacy bottom sheets (`episode_bottom_sheet`, `add_mono`); if reintroduced on mono, watch **GPU cost on low-end devices**.
- **Synchronous JSON / HTTP on UI isolate** — verify `http` calls are not doing heavy parsing on main isolate without `compute` / isolates (file-level review recommended, not proven here).

---

## 17. Recommended Cleanup Order

1. **Resolve navigation contradictions** — remove or implement `/story/:id`, `/library/...`, `/` (or register routes). Prevents silent dead features.
2. **Rename or archive duplicate `AppShell`** — eliminate class name collision between `main.dart` and `app/app_shell.dart`.
3. **Pick canonical episode sheet** (if episode UX returns) — delete the other `episode_bottom_sheet.dart`.
4. **Decide fate of `features/home` + `ui/ui.dart` barrel** — archive folder vs reattach to router; drives largest bulk deletion.
5. **`create_mono` prototype** — archive or promote to `features/create`; avoid leaving Riverpod `createMonoProvider` “dangling.”
6. **Pubspec hygiene** — after tree deletion, re-run `dart pub deps` and remove `modal_bottom_sheet` / `animated_accordion` if truly unused.
7. **Asset pass** — add missing writer image or remove references; confirm `mono_hero_blur_backdrop.png` intent.

---

## 18. Questions Before Cleanup

1. Is **Mono (`/mono`)** the **only** intended long-term home surface, with **no** revival of **`HomeScreen`** discovery?
2. Should **legacy episode + story detail** flows be **deleted**, **merged into mono**, or kept behind a feature flag?
3. Is **`create_mono/`** an abandoned experiment or a **planned V2** entry point?
4. Should **`ShareProfileScreen`** keep **hard-coded** demo identity, or is that placeholder blocking release?
5. Which **`nimon-backend` endpoints** are considered **production-required** for the next milestone (drafts only vs full auth/users)?
6. Are **tests** expected to cover **legacy home**, or can test files targeting abandoned flows be archived with the code?

---

## Executive tally (approximate)

| Metric | Value |
|--------|------:|
| **Files scanned (repo-wide, excl. ignores)** | **551** |
| **`lib/` Dart files** | **202** |
| **`test/` Dart files** | **8** |
| **KEEP_* (all keep buckets combined, approximate)** | **~130–145** Dart units clearly on live / backend-integrated paths |
| **DELETE_CANDIDATE (explicit small set §4)** | **~6** primary file entries (+ duplicate sheet file) |
| **NEEDS_MANUAL_REVIEW / large orphan buckets** | **~60+** Dart files in orphaned trees **plus** backend / asset / pubspec judgment calls |

### Top 5 cleanup risks

1. **Deleting `features/home` or `StoryRepo` paths** without confirming **Mono** does not still rely on indirect mock behaviors.
2. **Duplicate `AppShell` naming** — accidental import could compile wrong shell in a refactor.
3. **Broken pushes** (`/story/...`, `/library/...`) — user-facing crashes if legacy UI is partially re-enabled.
4. **`mono_screen` / `story_creator_sentences` size** — merge conflicts and regression risk during any extraction.
5. **Over-aggressive pubspec pruning** — `intl` / `modal_bottom_sheet` may be unused in *app* code but required transitively or by future work; verify with `dart pub deps --style=compact` after code deletion.

---

*End of report.*
