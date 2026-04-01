# NIMON V1 — Execution Plan

**Summary:** This plan turns **`NIMON_V1_TARGET_FOLDER_STRUCTURE.md`** (where the codebase should go) and **`CURRENT_FILES_KEEP_MOVE_ARCHIVE_MAPPING.md`** (what each file is today) into a **safe, ordered sequence** of work for a **Version 1** NIMON branch. V1 product direction: **Mono = main entry**, **Add = one-short creation only**, **Profile = basic profile**, **Learn = supporting screen from Mono**, **Auth = login/entry**. Out of scope for V1 main UX: Home, Library, long-story system, story series, AI stories, advanced social/community, settings-heavy flows.

**Rules for this document:** It is **documentation-only**. No code, routes, or files were changed to produce it.

---

## Recommended execution order (overview)

1. Establish **routing and navigation truth** (what users actually see).
2. Align **shell and bottom navigation** with V1 tabs (Mono | Add | Profile).
3. Make **Mono the real main entry** (replace placeholder, fix post-login default).
4. Narrow **Create** to **one-short only** (routes + UI entry points).
5. **Simplify Profile** for V1 (defer heavy settings).
6. **Connect Learn** from Mono (explicit entry points, optional route cleanup).
7. **Shared / core cleanup** (theme, duplicate sheets, barrels)—after features work.
8. **Archive or isolate** V2 features last—when the app no longer depends on them at runtime.

Each step is small enough to **commit and run** before the next.

---

## Phased implementation plan

### Phase 1: Routing truth

| | |
|--|--|
| **Goal** | A single, written map of **every route** (path, shell vs full-screen, which `Widget` builds) matches intentional V1 behavior; no “surprise” screens (e.g. placeholder Mono while `mono_screen.dart` exists). |
| **Likely files** | `lib/main.dart` (`GoRouter`, `ShellRoute`, route `builder`s). |
| **What to change** | Document current behavior; then **wire `/mono` to `MonoScreen(repo: repo)`** (or equivalent) **instead of `_MonoPlaceholderScreen`**. Update **guest / post-login** navigation so default shell location is **Mono**, not `/` Home, when you are ready for that product change. Remove **unused imports** in `main.dart` (e.g. `mono_screen` was imported but placeholder used—after wiring, import becomes real). |
| **What not to change yet** | Physical folder moves (`features/mono/presentation/…`), splitting `router` into `app/router.dart`, deleting Home/Library **files**. |
| **Risk** | **Low–medium** if you change **one route at a time** and run the app after each change. `MonoScreen` is large—watch for missing `repo` or performance on first paint. |
| **Why this order** | Routing is the **spine**. Wrong route table makes every later refactor harder to test. The mapping doc flags **placeholder vs real Mono** as the top confusion—fixing that is the fastest **product-aligned** win. |

---

### Phase 2: Shell and bottom navigation truth

| | |
|--|--|
| **Goal** | Bottom navigation matches V1: **Mono | Add (create) | Profile**; **Learn** is **not** a tab; **Home** and **Library** are not V1 main destinations. |
| **Likely files** | `lib/main.dart` — `AppShell`, `_CustomBottomNavBar`, `_indexFromLocation`, `onItemTapped` switch. |
| **What to change** | Replace five-tab layout (Home / Mono / Create / Library / Profile) with **three primary destinations** + center Add. Re-map **selected indices** and **`context.go` targets** (e.g. default `/mono`, Profile at `/more` or new `/profile`). Adjust **library/home routes** to **not** appear on the bar—or remove navigation to them until archived. |
| **What not to change yet** | Deleting `features/home` or `features/library` folders; extracting shell to `lib/app/shell/` (optional follow-up). |
| **Risk** | **Medium**—easy to break **highlight state** vs **actual route**. Test: tap each tab, back button, deep link if any. |
| **Why after Phase 1** | You need **correct screens** behind routes before reshaping the bar; otherwise you optimize navigation to the wrong home. |

---

### Phase 3: Mono as main entry

| | |
|--|--|
| **Goal** | After auth (or guest), the user lands on **Mono**; Mono screen is the **product home** for V1, not `HomeScreen`. |
| **Likely files** | `lib/features/mono/mono_screen.dart`, `start_mono_sheet.dart`; `lib/features/auth/login_screen.dart` (guest `go` target); `lib/main.dart` (`initialLocation` after login if you add redirect logic later). |
| **What to change** | Login **Guest >>** should `go` to **`/mono`** (or your chosen default) instead of `/`. Trim Mono UI only if something **hard-depends** on Home/Library (replace with stubs or remove links). |
| **What not to change yet** | Full **folder rehome** to `features/mono/presentation/`; extracting widgets. |
| **Risk** | **Low** once Phase 1–2 are correct; **medium** if `MonoScreen` pulls data paths that assume Home exists. |
| **Why this order** | V1 scope is **Mono-centric**; shell and default route must agree before polishing Mono internals. |

---

### Phase 4: Create = one-short only

| | |
|--|--|
| **Goal** | **Add** opens **one-short creation** only; story series, AI stories, and **`/create-mono`** mega-flow are **not** part of V1 user journey (hidden, removed from nav, or feature-flagged). |
| **Likely files** | `lib/features/create/create_screen.dart`, `lib/create_mono/create_mono_screen.dart`, `lib/create_mono/one_short_tab.dart`, `lib/create_mono/story_series/story_series_screen.dart`, `lib/ui/create/**`, `lib/main.dart` (routes `/create`, `/create-mono`). |
| **What to change** | Router: **one** primary create route (e.g. `/create` with one-short only). Remove or guard **tabs** that switch to series/AI inside `CreateScreen`. Stop linking **`CreateMonoScreen`** from V1 nav if it duplicates one-short. Long-term: extract **`create_one_short_screen`**-shaped widget (per target structure doc). |
| **What not to change yet** | Mass-delete `story_series_screen.dart`; moving every widget under `features/create/presentation/widgets/` in one pass. |
| **Risk** | **Medium–high**—`create_screen.dart` and `create_mono` are large and interconnected. Prefer **feature flags** or **conditional tabs** before deleting files. |
| **Why after Mono** | Create is second most visible; it should not be reorganized until **entry navigation** is stable. |

---

### Phase 5: Profile simplify

| | |
|--|--|
| **Goal** | **Profile** tab shows **basic** user/profile UI; **settings-heavy** flows deferred; no duplicate “More” vs Profile confusion. |
| **Likely files** | `lib/features/profile/profile_screen.dart`, `lib/features/more/more_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/main.dart` (`/more`, `/settings`). |
| **What to change** | Confirm **`/more` → `ProfileScreen`** only; remove **`more_screen.dart`** if truly unused (after `dart analyze`). Optionally **hide `/settings` route** from V1 or nest minimal rows under Profile. Strip Profile tabs that only exist for **non–V1** story lists if product allows. |
| **What not to change yet** | Full redesign of profile; new `auth_repository` until auth is real. |
| **Risk** | **Low** for routing cleanup; **medium** if Profile tabs import Home/story data—trim dependencies carefully. |
| **Why this order** | Profile is stable relative to Create; simplify after **Mono + Create** paths are clear. |

---

### Phase 6: Learn connection

| | |
|--|--|
| **Goal** | **Learn** is opened **from Mono** (buttons, cards, “deeper explanation”); **`/learn/:id`** behavior matches product (use or drop `:id`). |
| **Likely files** | `lib/features/learn/learn_hub_screen.dart`, `lib/features/mono/mono_screen.dart`, `lib/main.dart` (`/learn/:id`). |
| **What to change** | Add explicit **navigation** from Mono to `LearnHubScreen` (`context.push` / `go` with real args). If `id` is unused, simplify route to `/learn` to avoid confusion. |
| **What not to change yet** | Merging Learn into Mono folder; moving Learn widgets. |
| **Risk** | **Low** for wiring; **review** if Learn previously assumed **story/episode** context from long-form flows. |
| **Why this order** | Learn is **supporting**; Mono must be stable first so entry points are obvious. |

---

### Phase 7: Shared / core cleanup

| | |
|--|--|
| **Goal** | One **theme** source of truth; **one** canonical episode bottom sheet; **`core/theme.dart`** vs inline `NimonApp` theme reconciled; optional `app/router.dart` extract. |
| **Likely files** | `lib/main.dart`, `lib/core/theme.dart`, `lib/ui/bottom_sheets/episode_bottom_sheet.dart`, `lib/features/widgets/episode_bottom_sheet.dart`, `lib/ui/ui.dart`, `lib/app/app_shell.dart` (legacy). |
| **What to change** | Merge duplicate theme; **pick one** bottom-sheet implementation and update imports. Remove **`lib/app/app_shell.dart`** after grep confirms **no imports**. Optionally extract **`app/router.dart`** + **`app/shell/`** from `main.dart` for readability. |
| **What not to change yet** | Renaming every `shared/` widget; adding `domain/` layers. |
| **Risk** | **Medium**—wide import graph for bottom sheets; use **incremental** import rewrites and `flutter analyze`. |
| **Why late** | Avoid refactors that touch **many files** before **V1 routes and features** are settled. |

---

### Phase 8: Archive V2 / later features

| | |
|--|--|
| **Goal** | **Home, Library, long-story, story series, AI stories, see-more, quiz, unused screens** no longer ship in V1 **runtime paths**; code either **removed from router**, **moved to `archive/`**, or kept on a **long-lived branch**. |
| **Likely files** | `lib/features/home/**`, `lib/features/library/**`, `lib/features/story/**`, `lib/features/reader/**`, `lib/features/writer/**`, `lib/features/see_more/**`, `lib/data/ai_stories_repository.dart`, `lib/data/following_repository.dart`, parts of `models/`, etc. (see mapping doc). |
| **What to change** | **First:** remove or guard **routes** and **imports** from V1 screens so nothing calls archived code. **Then:** move folders or delete with git history. Run **tests** if any cover old flows. |
| **What not to change yet** | Big-bang delete **before** Phases 1–7—would break incremental testing. |
| **Risk** | **High** if done too early; **lower** once V1 paths **do not import** archived modules. |
| **Why last** | Archival is **destructive**; do it when V1 navigation and features **no longer depend** on legacy stacks. |

---

## Phased checklist (quick reference)

- [ ] **Phase 1:** Document routes; wire **`MonoScreen`** for `/mono`; fix unused imports; set post-login default toward Mono when ready.
- [ ] **Phase 2:** Bottom nav = Mono | Add | Profile; remove Home/Library from bar.
- [ ] **Phase 3:** Guest/login → **Mono** as home; validate `MonoScreen` dependencies.
- [ ] **Phase 4:** Create route(s) = **one-short only**; gate series/AI/`create-mono`.
- [ ] **Phase 5:** Profile simplified; resolve **More**/`settings` vs V1.
- [ ] **Phase 6:** **Learn** reachable from **Mono**; cleanup `/learn/:id` if needed.
- [ ] **Phase 7:** Theme + single bottom sheet + remove legacy `app_shell.dart` + optional router extract.
- [ ] **Phase 8:** Archive or delete **non–V1** features after imports are clean.

---

## First real cleanup target (after documentation)

**Safest first code change:** **Replace `_MonoPlaceholderScreen` with `MonoScreen(repo: repo)` for the `/mono` route in `lib/main.dart`,** and **point Guest (and any post-login `go`) to `/mono`** instead of `/` when you want V1 behavior.

**Why this first**

- **Small diff**, **immediate** product alignment (Mono = real screen).
- **Validates** that `MonoScreen` works under `GoRouter` + `AppShell` before you restructure tabs.
- **Resolves** the biggest documented inconsistency: **imported `mono_screen` vs placeholder route**.

**Follow immediately with:** run **`flutter analyze`** and fix **unused imports** in `main.dart` (mapping doc: `more_screen`, `reader_screen`, `story_repo_mock` if unused)—still low risk, improves clarity.

---

## Archive strategy: when to move vs ignore

| Situation | Strategy |
|-----------|----------|
| **Feature still imported** by V1 screens (e.g. Home widget inside Mono) | **Do not archive yet**—break dependency first (Phase 3–4). |
| **Feature only reachable via old routes/tabs** you removed | **Ignore in UI** first (dead routes harmless in repo); then **remove routes**; then **delete or move** folder. |
| **Large folders (home, library, story)** | **Ignore temporarily** only if **router + imports** guarantee they never load—acceptable for a short branch; **not** acceptable long-term (binary size / confusion). Prefer **feature flag** or **`kV1Mode`** guard during transition. |
| **Physical `lib/archive/`** | Use when **analyzer** is clean and you want **clear separation** on `main`—typically **after** Phase 8 prep (imports cut). Alternative: **git branch** `legacy/pre-v1-home` and delete on `main`. |
| **Docs / templates** (e.g. `backend/*.md`) | **Move to `docs/`** when convenient; **no** runtime impact. |

**Rule:** **Cut runtime references first**, **move or delete files second**. That minimizes breakage for a solo developer.

---

## Risks and cautions

- **`MonoScreen` and `CreateScreen` are large**—expect follow-up fixes (imports, `StoryRepo` usage) after routing changes.
- **`EpisodeReaderScreen` / `/reader`** may still link from legacy code; decide if V1 Learn needs them before archiving readers.
- **Riverpod** in `create_mono` vs **StatefulWidget** elsewhere—don’t rewrite everything to one pattern for V1; **keep** create-mono working, **narrow** surface in router.
- **Tests** (`test/`) may reference old flows—update or skip when archiving.

---

## Solo developer guidance

- **One phase per PR or per day** when possible; **run the app** on device/emulator after each phase.
- Prefer **`flutter analyze`** + manual smoke test over large refactors without running builds.
- **Defer** `presentation/` subfolders and **`data/repositories/`** split until **navigation** works—folder moves are **cosmetic** compared to route truth.
- **Do not** introduce **domain/usecases** layers for V1 unless a single file exceeds maintainability—per target structure doc.

---

## Recommended first action (final)

1. **Code:** In `lib/main.dart`, route **`/mono`** to **`MonoScreen(repo: repo)`** (constructor matches existing `MonoScreen` API—verify `const` vs `repo` required). Delete **`_MonoPlaceholderScreen`** if unused.
2. **Product:** Change **Guest >>** in `login_screen.dart` from **`/`** to **`/mono`** when you want V1 default entry.
3. **Hygiene:** Run **analyzer** and remove **unused imports** in `main.dart`.

Then proceed to **Phase 2** (bottom nav) when Phase 1 is stable.

---

*Documentation only. No repository files were modified to create `NIMON_V1_EXECUTION_PLAN.md`.*
