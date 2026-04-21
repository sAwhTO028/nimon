# Nimon State Audit (sources of truth + mismatch risks)

This is **analysis-only**. No code was modified as part of this report.

## A. Executive summary

Overall risk level: **Medium** (with **high-risk pockets** in Creator flows and Mono UI state).

What’s good:
- The Creator system has a clear concept of a **canonical draft object** (`CreatorStoryV1`) plus a persisted storage layer (`StoryCreatorDraftStorage`) and a session/drawer tracker (`CreatorDrawerSessionState`).
- Settings are centralized via Riverpod `StateNotifierProvider`s (`settings_providers.dart`) backed by persistence (`AppSettingsPrefs`).

Main state-management risks:
- **Multiple layers of truth** exist for Creator navigation/UI (GoRouter URI, drawer session state, embedded “panel” state, and persisted “resume meta”).
- Some UI modes are stored as **local widget state** (Mono Hero/Read mode and Read-mode learn expand/collapse) while other related state lives in providers (settings toggles, creator learn mode).
- There are places where **state is persisted and also derived** (e.g., draft “processing/readiness” computed from fields vs. stored publish/module statuses), which can drift if invariants aren’t enforced.
- Several flows deliberately use `addPostFrameCallback` to avoid “modify during build” assertions—this is pragmatic, but it increases the chance of **transient mismatch frames** (UI briefly shows the wrong “active step” or panel).

## B. Duplicated state sources

### 1) Creator navigation state: URI vs session model vs embedded panel
- **Files**
  - `lib/features/create/creator_drawer_session.dart`
  - `lib/features/create/creator_route_sync.dart`
  - `lib/features/create/story_creator_sentences_screen.dart` (host for embedded learn panels; referenced by grep)
  - `lib/features/create/creator_progress_drawer.dart` (derives effective active step)
- **State sources**
  - **GoRouter state**: `GoRouterState.of(context).uri`, `matchedLocation`, query params like `panel=...`
  - **Session model**: `CreatorDrawerSessionState` fields:
    - `matchedPath`
    - `sentencesMainStep`
    - `activeModule`
    - `learnModulesVisited`
    - `learnModeEnabled`
  - **Embedded panel state**: `panel` query param and `sentencesMainStep`
- **Risk**
  - If URI and session state diverge temporarily (common due to post-frame sync), UI can show the wrong active step or wrong enabled/disabled module row.

### 2) Draft “resume” metadata vs current in-memory session
- **Files**
  - `lib/features/create/story_creator_draft_storage.dart`
  - `lib/features/create/creator_route_sync.dart`
  - `lib/features/create/creator_resume_draft.dart`
- **State sources**
  - Persisted resume meta: `StoryCreatorDraftResumeStorage.recordLastActive(...)`
  - Session state: `creatorDrawerSessionProvider` (`CreatorDrawerSessionNotifier`)
  - In-memory draft provider: `storyCreatorDraftProvider` / `storyCreatorDraftDataProvider`
- **Risk**
  - Resume meta is written on route sync (post-frame). If navigation is rapid or interrupted, the persisted “last active module” can lag.
  - Resume flow sets `sentencesMainStep` **imperatively** while also navigating to a route that encodes `panel=...`—two ways to represent the same intention.

### 3) Learn Mode toggle: session truth vs screen routing
- **Files**
  - `lib/features/create/creator_drawer_session.dart` (`learnModeEnabled`)
  - `lib/features/create/creator_learn_mode_sync.dart` (`applyCreatorLearnMode`)
- **State sources**
  - Session truth: `CreatorDrawerSessionNotifier.setLearnMode`
  - Navigation: when turning off Learn mode, the code redirects to `/create/story/sentences?...` and sets `sentencesMainStep` back to `storySentences`
- **Risk**
  - Learn-mode disabling is both a **state change** and a **navigation change**; if one happens without the other (edge cases/tests), UI can appear inconsistent.

### 4) Creator “processing/readiness” vs stored publish/module statuses
- **Files**
  - `lib/features/create/creator_readiness.dart`
  - `lib/features/create/story_creator_models.dart` (not opened here, but referenced by imports)
  - `lib/features/create/story_creator_provider.dart`
- **State sources**
  - Derived readiness: `computeReadOnlyReady`, `computeFullLearnReady`, `computeProcessingState`
  - Persisted draft fields: `CreatorStoryV1` includes `publishState` and `moduleWorkflowStatuses` (stored in `StoryCreatorDraftStorage._toJson`)
- **Risk**
  - If “publishState/moduleWorkflowStatuses” are stored and also inferable, you can get drift unless writes are centralized and invariants are validated.

### 5) Mono UI mode state: local widget state vs global settings
- **Files**
  - `lib/features/mono/mono_screen.dart`
  - `lib/features/settings/settings_providers.dart` (mono explanation toggle)
- **State sources**
  - Local UI state:
    - `_ReadingFeedPostState._pageIndex` (Hero vs Read)
    - `_ReadingFeedPostState._readModeLearnExpanded` (collapsed vs expanded learn group in Read mode)
  - Global setting state:
    - `monoExplanationEnabledSettingProvider` (persisted)
- **Risk**
  - Mode ownership is local (good for UI), but related toggles/settings are global; ensure the handoff doesn’t create “stale UI” when settings change mid-session.

## C. State mismatch hotspots

### 1) Route sync is post-frame (transient mismatch)
- **File**: `lib/features/create/creator_route_sync.dart`
- **Owner**: `CreatorDrawerSessionNotifier.reportRoute(...)`
- **Pattern**: `WidgetsBinding.instance.addPostFrameCallback` is used to avoid modifying providers during build.
- **Mismatch risk**
  - One-frame lag where drawer highlights/active module doesn’t match the visible screen, especially when:
    - switching embedded learn panels on sentences host
    - redirecting between legacy `/create/story/learn/*` and embedded panel routes

### 2) “Preserve sentences workspace step” logic can hide divergence
- **File**: `lib/features/create/creator_drawer_session.dart`
- **Owner**: `_preserveSentencesWorkspaceStep`, `reportRoute`, `setSentencesMainStep`
- **Mismatch risk**
  - The deliberate “preserve” logic prevents flicker, but can also mask genuine state mismatch if the route no longer corresponds to the preserved embedded step.

### 3) Resume flow mixes navigation and session state writes
- **File**: `lib/features/create/creator_resume_draft.dart`
- **Owner**: `CreatorDraftResumeFlow`
- **Mismatch risk**
  - `_targetUri` both:
    - returns a route that encodes intent (`panel=vocabulary` etc.)
    - and sets `drawer.setSentencesMainStep(...)` before navigation
  - If navigation fails/cancels, session state may be updated without the route change.

### 4) Overlay/bottom-sheet state vs page state
- **Files**
  - `lib/ui/bottom_sheets/mono_story_options_sheet.dart` (OverlayEntry)
  - `lib/features/mono/mono_screen.dart` (PopScope listens to `monoReaderStoryOptionsOpen`)
- **Mismatch risk**
  - Overlay open/close is tracked by:
    - `_monoStoryOptionsOverlay != null` (internal)
    - `monoReaderStoryOptionsOpen` ValueNotifier (external)
  - If these ever desync (e.g., exception during insert/remove), back handling could misbehave.

### 5) Profile push drawer dock visibility state
- **File**: `lib/features/profile/profile_push_drawer_scope.dart`
- **Owner**: `ProfilePushDrawerDockScope.obscuresDock` (ValueNotifier)
- **Mismatch risk**
  - Dock visibility depends on a notifier passed via inherited scope; if a screen forgets to update it on animation states, the dock may appear/disappear incorrectly.

## D. Derived-vs-stored state problems

### 1) Draft “dirty/saveStatus/lastSavedAt” vs disk writes
- **File**: `lib/features/create/story_creator_provider.dart`
- **Owner**: `StoryCreatorDraftNotifier`
- **Stored**
  - `dirty`, `saveStatus`, `lastSavedAt`, `lastSaveError`
- **Derived possibility**
  - Some of these could be derived from a persisted queue or a monotonic “revision” counter, but that’s likely overkill.
- **Risk**
  - Multiple entry points calling `persistLocalDebounced` + `persistLocalNow` can cause edge cases:
    - lastSavedAt set but disk write failed later
    - saveStatus transitions during rapid edits

### 2) Processing readiness derived from thresholds but also implied by stored workflow statuses
- **File**: `lib/features/create/creator_readiness.dart`
- **Risk**
  - If module completion statuses are stored separately, keep them in sync with computed completion logic.

### 3) Active creator step derivation
- **File**: `lib/features/create/creator_progress_drawer.dart`
- **Owner**: `creatorEffectiveActiveStep(...)`
- **Risk**
  - Active step is derived from `matchedPath` and `activeModule`. If either source is stale (post-frame sync), the derived step becomes wrong.

## E. Draft/session state problems

### 1) Multi-draft persistence + “active id” semantics
- **File**: `lib/features/create/story_creator_draft_storage.dart`
- **State**
  - Index of draft ids + `_activeIdKey`
- **Risk**
  - The app has both “explicit draftId routes” and “active draft id” fallback. If callers omit draftId inconsistently, you can open/overwrite the wrong draft.

### 2) Resume metadata written from route sync
- **File**: `lib/features/create/creator_route_sync.dart`
- **Risk**
  - Resume meta is written opportunistically from navigation state; if user edits without route changes, resume meta may not reflect the true “last active module”.

### 3) Publish flow touches multiple state owners
- **File**: `lib/features/create/creator_drawer_publish.dart`
- Owners:
  - `storyCreatorDraftProvider.notifier` publish calls
  - `ProfileNavigation.openProcessingTab(...)` navigation
- Risk:
  - Snackbars + post-frame navigation can create transitions where UI state is between screens while draft state has already changed.

## F. Drawer/module state problems

### 1) Drawer session “visited learn modules” is in-memory only
- **File**: `lib/features/create/creator_drawer_session.dart`
- **Risk**
  - Visited state resets between app launches; that may be intended, but it can surprise users if the drawer UI implies a persistent milestone.

### 2) Learn mode constraints enforced by navigation side effects
- **File**: `lib/features/create/creator_learn_mode_sync.dart`
- **Risk**
  - When Learn mode is turned off, the code navigates away from Learn surfaces. If a screen forgets to call `applyCreatorLearnMode` and only toggles provider state, the user may remain on a Learn-only surface.

## G. Recommended cleanup order (analysis-only plan)

1. **Creator navigation state consolidation**
   - Ensure a single canonical “current module” source (preferably URI-derived) and keep session state purely as a cache.
2. **Draft resume workflow hardening**
   - Reduce duplicated intent encoding (panel in URI vs sentencesMainStep writes).
3. **Explicit draft id everywhere**
   - Avoid relying on “active id” fallback in any user-visible entry point.
4. **Overlay open-state robustness**
   - Ensure OverlayEntry existence and ValueNotifier cannot diverge (guard rails / assertions).
5. **Mono mode ownership documentation**
   - Keep UI-local state local, but clearly define what comes from settings and how it updates.

## H. Top 10 state fixes first (ordered)

1. **Creator: unify “active module” derivation** (URI → module) and make session state a derived mirror, not a peer source of truth.
2. **Creator: remove dual-encoding of embedded panel** (avoid setting `sentencesMainStep` when navigation already encodes `panel=...`, or vice versa).
3. **Creator: make route-sync callers consistent** (avoid “modify during build” by moving sync to a single lifecycle hook per screen).
4. **Creator: require `draftId` in routes for all resume/continue paths** to avoid wrong-draft bugs.
5. **Creator: clarify persisted vs derived completion** (publish/module workflow statuses vs computed readiness rules).
6. **Creator: ensure resume meta updates on meaningful editor focus changes**, not only route changes.
7. **Overlay panels: harden open/close invariants** (`mono_story_options_sheet.dart` overlay vs `monoReaderStoryOptionsOpen`).
8. **Profile push drawer: ensure dock obscuring notifier is driven by one owner** to avoid mismatches during animation.
9. **Mono: clearly scope Read-mode UI state** (page index, learn-group expansion) so it cannot leak across items.
10. **Settings: confirm async loads don’t create “flash of default”** (providers load persisted values after construction; consider a loading gate if flicker is visible).

## I. File impact list

Highest impact for state cleanup:
- `lib/features/create/creator_drawer_session.dart`
- `lib/features/create/creator_route_sync.dart`
- `lib/features/create/story_creator_provider.dart`
- `lib/features/create/story_creator_draft_storage.dart`
- `lib/features/create/creator_resume_draft.dart`
- `lib/features/create/creator_learn_mode_sync.dart`
- `lib/features/create/creator_progress_drawer.dart`
- `lib/features/create/creator_drawer_publish.dart`
- `lib/features/mono/mono_screen.dart`
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart`
- `lib/features/profile/profile_push_drawer_scope.dart`

