# Nimon Navigation Audit (routes + back-stack + flow consistency)

This is **analysis-only**. No code was modified as part of this report.

## A. Executive summary

Overall risk level: **Medium** (with a few **High** risk areas).

The app uses **GoRouter** with a **StatefulShellRoute.indexedStack** for the main “Mono + Profile” dock tabs, plus several **full-screen routes outside the shell** (Create, Learn, etc.). This is a good foundation, but there are some navigation pitfalls:
- **Duplicate/competing shell implementations** exist (`lib/main.dart` defines a GoRouter-driven `AppShell`, while `lib/app/app_shell.dart` defines a different `Navigator + IndexedStack` shell). Even if one is unused, it’s a drift risk.
- The Creator flow has **multiple route aliases** (e.g. `/create/story/learn/vocabulary` redirects to `/create/story/sentences?panel=vocabulary`) which is intentional but increases the chance of **back-stack surprises** and “wrong screen highlighted” if sync lags.
- Several flows mix `context.go` vs `context.push` for correctness (avoid stacking shell routes), but it also means some user “Back” expectations can change depending on where they came from.
- **Hero/Read mode** in Mono is **not a route**; it’s a UI mode inside a page. That avoids route noise but can create “no obvious exit” issues if the UI doesn’t provide a close affordance.

Top concerns:
- Create → Processing navigation uses **`go`** (not push) to avoid duplicating shell routes: correct technically, but can **erase the prior stack** and feel abrupt.
- Route duplication for Creator Learn surfaces can cause **mismatch** between “selected drawer item” and visible content during transitions.

## B. Entry points map

### Primary app entry
- **`/login`**
  - File: `lib/main.dart`

### Main shell (dock)
- **Stateful shell**: `StatefulShellRoute.indexedStack`
  - File: `lib/main.dart`
  - Branch 0: **`/mono`** → `MonoScreen`
  - Branch 1: **`/more`** → `ProfileScreen` (tabs controlled by query params)
  - Dock is rendered by: `FloatingDockNavBar` (custom) inside `AppShell` in `lib/main.dart`

### Create / Add flow (outside shell)
- **`/create`**
  - File: `lib/main.dart`
  - Behavior:
    - Default: `StoryCreatorAddTabScreen` (the “Add tab” hub)
    - `?editBasics=1`: opens `CreateScreen(... editFromReview: true)`

### Creator subroutes
- **`/create/story/*`**
  - File: `lib/main.dart`
  - Special redirect:
    - `/create/story` → redirects to `/create` (hub removed from product flow)
  - Subroutes:
    - `/create/story/basics` → `StoryCreatorBasicsScreen`
    - `/create/story/sentences` → `StoryCreatorSentencesScreen`
    - `/create/story/learn` → `StoryCreatorLearnHubScreen`
      - `/create/story/learn/vocabulary` → redirect to `/create/story/sentences?panel=vocabulary`
      - `/create/story/learn/grammar` → redirect to `/create/story/sentences?panel=grammar`
      - `/create/story/learn/quiz` → redirect to `/create/story/sentences?panel=quiz`
      - `/create/story/learn/audio` → redirect to `/create/story/sentences?panel=listening`

### Learn (outside shell)
- `/learn/:id` → `LearnHubScreen`
- `/learn/:id/grammar`, `/learn/:id/grammar/detail`
- `/learn/:id/vocabulary`
- `/learn/:id/quiz`, `/learn/:id/quiz/play`, `/learn/:id/quiz/result`
- `/learn/:id/listening`
  - File: `lib/main.dart`

### Mono “reader” variant
- **`/mono-reader`**
  - File: `lib/main.dart`
  - Builds `MonoScreen` with:
    - `initialItemsOverride`, `initialIndexOverride`
    - `showTopControls: false`
    - `readerMenuOrigin`, optional callbacks
  - Intended as folder-aware immersive reader (Uploaded/Bookmark).

### Profile public pages (outside shell branch path detection)
- `/profile/public` (+ nested `folder/:folderId`)
- `/profile/notifications`
- `/profile/followers`, `/profile/following`
- `/profile/share`
  - File: `lib/main.dart`

### Settings
- `/settings` (+ `/settings/help`)
  - File: `lib/main.dart`

## C. Broken/messy route flows (where confusion is likely)

### 1) Dual shell implementations (drift/duplication risk)
- **Files**
  - `lib/main.dart` defines `AppShell` for GoRouter shell (StatefulNavigationShell + custom dock)
  - `lib/app/app_shell.dart` defines another `AppShell` using a nested `Navigator` and `IndexedStack` with a Material `NavigationBar`
- **Risk**
  - If both are partially referenced (or tests/imports pull the wrong one), navigation behavior can diverge.
  - Even if unused, it’s a maintenance hazard: fixes get applied to the wrong shell.
- **Severity**: **High** (structural drift risk)

### 2) Creator Learn routes redirect into Sentences “panel” query param
- **File**: `lib/main.dart` (redirects), `lib/features/create/creator_route_sync.dart` (sync)
- **Risk**
  - Two user-visible routes map to the same destination UI:
    - `/create/story/learn/vocabulary`
    - `/create/story/sentences?panel=vocabulary`
  - Redirects are good for canonicalization, but:
    - It can create confusing back behavior (Back may jump “past” intermediate screens).
    - Drawer highlighting can briefly mismatch while sync settles (post-frame sync).
- **Severity**: **High**

### 3) Processing → Continue flow depends on both persisted draft meta and route sync
- **Files**
  - `lib/features/create/creator_resume_draft.dart`
  - `lib/features/create/creator_route_sync.dart`
  - `lib/features/profile/profile_screen.dart` (Processing list + resume entry; referenced by grep)
- **Risk**
  - Resume selects a target route using persisted “last active module” meta, but meta updates are triggered by route sync and can lag.
  - If the draft is resumed and immediately navigated again, the user may land on an unexpected module.
- **Severity**: **Medium–High**

### 4) Create hub vs Create form vs review edit
- **Files**
  - `lib/features/create/story_creator_add_tab_screen.dart`
  - `lib/features/create/create_screen.dart`
  - `lib/main.dart` (`/create` query switches)
- **Risk**
  - `/create` sometimes means “hub”, sometimes means “edit basics from review” depending on query.
  - Back behavior differs:
    - Hub is a full-screen push outside shell (opened from dock Add button).
    - Edit-from-review returns via `context.pop()` (expects to go back to review).
- **Severity**: **Medium**

### 5) Mono Hero/Read transitions are not routes
- **File**: `lib/features/mono/mono_screen.dart`
- **Risk**
  - There is no route-level back affordance for Read mode; the user must swipe back horizontally.
  - This can feel “stuck” if the user expects system back to return to Hero (especially after removing the close icon).
- **Severity**: **Medium**

## D. Back-stack risks

### 1) Use of `go` for cross-surface transitions
- **File**: `lib/features/profile/profile_navigation_helpers.dart`
- **Example**
  - `ProfileNavigation.openProcessingTab(...)` uses `context.go('/more?tab=processing&highlight=...')`
- **Risk**
  - Correctly prevents stacking duplicate shell routes, but `go` **replaces** current location. If invoked from Create/other flows, Back may not return where the user expects.
- **Severity**: **Medium**

### 2) Redirect-based routes can skip stack entries
- **File**: `lib/main.dart`
- **Example**
  - `/create/story/learn/vocabulary` redirects to `/create/story/sentences?panel=vocabulary`
- **Risk**
  - Back may skip returning to the “learn hub” or the original link source depending on how the redirect is processed.
- **Severity**: **Medium**

### 3) Overlay panels and back handling
- **Files**
  - `lib/ui/bottom_sheets/mono_story_options_sheet.dart`
  - `lib/features/mono/mono_screen.dart` (`PopScope` around reader dock panel open)
- **Risk**
  - Back is intercepted to close overlay first. If overlay state and notifier diverge, back behavior can break (pop blocked unexpectedly).
- **Severity**: **Medium**

## E. Drawer/route mismatch risks

### 1) Creator progress drawer: active step derived from session + embedded panel
- **Files**
  - `lib/features/create/creator_drawer_session.dart`
  - `lib/features/create/creator_route_sync.dart` (post-frame)
  - `lib/features/create/creator_progress_drawer.dart`
- **Risk**
  - When the visible UI is driven by `panel=...` (embedded learn), but the session state hasn’t synced yet, the drawer can highlight the wrong item.
- **Severity**: **High**

### 2) Profile push drawer navigation is “close then navigate”
- **File**: `lib/features/profile/profile_navigation_drawer.dart`
- **Risk**
  - If close animation is interrupted or host context unmounts, navigation callbacks may be dropped.
  - The drawer itself has local expansion state (`_switchProfilesExpanded`) that can survive longer than expected if the drawer is reused.
- **Severity**: **Medium**

## F. Route duplication (same destination reachable multiple ways)

### 1) Creator learn editors
- `/create/story/learn/vocabulary` → redirect → `/create/story/sentences?panel=vocabulary`
- same for grammar/quiz/audio
- **Consequence**: multiple “URLs” for the same surface; requires careful canonicalization and route sync.

### 2) Mono screen variants
- `/mono` (shell branch)
- `/mono-reader` (specialized MonoScreen instance)
- `MonoScreen` also appears in `lib/app/app_shell.dart` (older shell)
- **Consequence**: multiple instantiation paths; back behavior and dock presence differ by entry.

### 3) Episode bottom sheets vs route reader screens
- Episode details can open via:
  - bottom sheets (`showEpisodeBottomSheet`, `showEpisodeDetailsSheet`)
  - and also full reader screens (`EpisodeReaderScreen` referenced by imports in sheet code)
- **Consequence**: user can “enter reading” from either modal or full-page; ensure back returns to the correct surface consistently.

## G. Recommended cleanup order (analysis-only)

1. **Resolve shell duplication**
   - Confirm `lib/app/app_shell.dart` is unused; if so, deprecate or remove later (not in this task).
2. **Canonicalize Creator routes**
   - Pick one canonical path for embedded learn panels and ensure all navigation uses it.
3. **Back behavior for Mono Read mode**
   - Decide whether system back should return to Hero mode (UI-only) or pop route. (Currently it cannot by design.)
4. **Unify episode entry**
   - Standardize one episode sheet/entry pattern to reduce drift.
5. **Strengthen drawer sync**
   - Reduce reliance on post-frame syncing for drawer highlighting where possible.

## H. Top 10 navigation fixes first (ordered)

1. **Eliminate/retire the legacy `lib/app/app_shell.dart` shell** (or clearly isolate it) to prevent route/shell drift.
2. **Make `/create` semantics unambiguous** (hub vs edit basics) by using clearer subroutes (e.g. `/create/hub`, `/create/edit-basics`) — recommendation only.
3. **Canonicalize embedded learn routing**: ensure Creator always navigates to `/create/story/sentences?panel=...` (or always to `/create/story/learn/...` with a single redirect direction).
4. **Audit back behavior from Create → Processing** when `ProfileNavigation.openProcessingTab` uses `go` (ensure expected “Back” is communicated or handled).
5. **Ensure draftId is always present in creator routes** when coming from resume/processing to avoid wrong-draft continuation.
6. **Reduce “post-frame route sync” mismatch** by centralizing route-report calls (fewer entry points calling sync from build).
7. **Document Mono `/mono` vs `/mono-reader` expectations** (dock visible vs hidden, menu origin differences).
8. **Standardize episode “Start reading” navigation** from bottom sheets (push vs go, which navigator, and where it returns).
9. **Harden overlay back handling** (ensure overlay open notifier and actual overlay existence cannot diverge).
10. **Add route ownership notes** near `main.dart` router for which surfaces are “outside shell” (Create/Learn) vs “inside shell” (Mono/Profile).

## I. File impact list

Navigation definitions / routing:
- `lib/main.dart`

Shell / dock behavior:
- `lib/main.dart` (GoRouter `AppShell`)
- `lib/app/app_shell.dart` (legacy/alternate shell)
- `lib/widgets/floating_dock_nav_bar.dart`
- `lib/features/profile/profile_push_drawer_scope.dart`

Creator navigation flows:
- `lib/features/create/story_creator_add_tab_screen.dart`
- `lib/features/create/create_screen.dart`
- `lib/features/create/story_creator_sentences_screen.dart`
- `lib/features/create/creator_route_sync.dart`
- `lib/features/create/creator_resume_draft.dart`
- `lib/features/profile/profile_navigation_helpers.dart`
- `lib/features/create/creator_learn_mode_sync.dart`

Mono mode transitions / overlays:
- `lib/features/mono/mono_screen.dart`
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart`

