# Nimon Add flow — direct storage usage cleanup map

**Analysis only.** No refactors, UI changes, or repository wiring.

**Scope:** `StoryCreatorDraftStorage`, `StoryCreatorDraftResumeStorage`, and SharedPreferences usage **only as encapsulated by** `story_creator_draft_storage.dart` (callers do not import `SharedPreferences` directly for drafts).

**Implementation file (not a migration target itself):** `lib/features/create/story_creator_draft_storage.dart` — remains the **adapter** behind `StoryDraftRepository`.

---

## A. Executive summary

### How many direct storage entry points exist

- **8 consumer files** call `StoryCreatorDraftStorage` / `StoryCreatorDraftResumeStorage` APIs directly (excluding the storage implementation file).
- **Roughly 35+ discrete static API invocations** across those files (counting each `await StoryCreatorDraftStorage.*` / `StoryCreatorDraftResumeStorage.*` line once per occurrence). The highest concentration is **`profile_screen.dart`** (~11 calls across `_ProfileScreenState`, `_showProcessingDraftSheet`, `_ProcessingDraftCard`).

### Biggest coupling risks

1. **`profile_screen.dart`** — duplicates **load → mutate → save + touchEdited** and **clear + clearMeta** outside `StoryCreatorDraftNotifier`, so in-memory provider state can **diverge** from disk until something reloads the draft.
2. **`StoryCreatorHubScreen`** — `FutureBuilder` uses **`StoryCreatorDraftStorage.exists()`** while “Continue” uses **`ref.watch(storyCreatorDraftDataProvider)`** for routing — **two sources of truth** for “is there a draft?” (`exists()` = any indexed draft; provider may be another draft or empty).
3. **`creator_route_sync.dart`** — writes resume meta on every route tick; must stay consistent with repository’s resume contract later.

### Highest-priority files to migrate

1. `lib/features/create/story_creator_provider.dart` — centralize first (already owns most writes).
2. `lib/features/profile/profile_screen.dart` — most duplicated I/O and highest drift risk.
3. `lib/features/create/story_creator_add_tab_screen.dart` — list snapshot reads.
4. `lib/features/create/story_creator_basics_screen.dart` — discard path touches storage directly.
5. `lib/features/create/creator_resume_draft.dart` + `creator_route_sync.dart` — resume orchestration (coordinate after repository exists).

**Lower urgency (read-mostly or small surface):** `story_creator_hub_screen.dart`.

---

## B. Direct storage usage inventory

| # | File | Class / function | Storage API | What it does | Later move to |
|---|------|------------------|-------------|--------------|----------------|
| 1 | `story_creator_provider.dart` | `StoryCreatorDraftNotifier.loadDraftById` | `load`, `loadSavedAt` | Hydrate notifier from disk | **Notifier** (calls **repository**) |
| 2 | same | `startNewLocalDraft` | `saveMeta` | Seed resume meta for new draft | **Repository** |
| 3 | same | `persistLocalNow` | `save`, `touchEdited` | Canonical local persist | **Repository** |
| 4 | same | `discardDraftFromDiskAndReset` | `clear()` (no `draftId`) | Removes **active** draft only (see `StoryCreatorDraftStorage.clear` — uses `_activeIdKey`) | **Repository** |
| 5 | `profile_screen.dart` | `_ProfileScreenState._loadLocalCreatorDraftIntoProcessing` | `loadAllIds`, `load`, `loadMeta` | Build Processing list | **Repository** (or **notifier** method that returns list DTOs) |
| 6 | same | `_ProfileScreenState._showProcessingDraftSheet` | `load` | Load draft for readiness bottom sheet | **Repository** / **notifier** |
| 7 | same | `_showProcessingDraftSheet` delete button callback | `clear` | Delete draft from sheet | **Repository** |
| 8 | same | `_ProcessingDraftCard._rename` | `load`, `save`, `touchEdited` | Rename title on card | **Repository** + ideally **notifier** so provider updates |
| 9 | same | `_ProcessingDraftCard._delete` | `clear`, `clearMeta` | Delete draft from Processing | **Repository** |
| 10 | `story_creator_add_tab_screen.dart` | `_LocalDraftsSnapshot.load` | `loadAllIds`, `load`, `loadMeta` | Add tab “local drafts” list (`publishState == draft` filter in code) | **Repository** |
| 11 | `story_creator_basics_screen.dart` | `_StoryCreatorBasicsScreenState` pop handler (back) | `hasDraft` | Know if anything was ever persisted | **Repository** |
| 12 | same | discard branch | `clear`, `clearMeta` | Remove shell draft if never persisted | **Repository** |
| 13 | `story_creator_hub_screen.dart` | `StoryCreatorHubScreen.build` `FutureBuilder` | `exists`, `loadSavedAt` | Enable “Continue” + “Last saved” label | **Repository** |
| 14 | `creator_route_sync.dart` | `syncCreatorDrawerSessionFromContext` post-frame callback | `recordLastActive` | Persist last module/panel for resume | **Repository** |
| 15 | `creator_resume_draft.dart` | `CreatorDraftResumeFlow._restoreDraftState` | `ensureInit` | Ensure resume meta row exists | **Repository** |
| 16 | same | `_targetUri` | `loadMeta` | Resolve deep link from last module | **Repository** |
| 17 | `story_creator_draft_storage.dart` | `StoryCreatorDraftResumeStorage.recordLastActive` (internal) | `hasDraft` | Skip resume writes if no draft file | Stays inside **local adapter** |

---

## C. Usage groups

| Group | Locations | Role |
|-------|-----------|------|
| **Load current draft** | `StoryCreatorDraftNotifier.loadDraftById` | Hydrate in-memory draft |
| **Load all drafts** | `_loadLocalCreatorDraftIntoProcessing`, `_LocalDraftsSnapshot.load` | Indexed list + per-id load |
| **Save draft** | `persistLocalNow` (notifier); `_ProcessingDraftCard._rename` (Profile) | Canonical save vs ad-hoc save |
| **Delete / clear draft** | `discardDraftFromDiskAndReset`; Profile sheet/card; basics discard | Full clear vs per-id clear |
| **Save / load resume meta** | `saveMeta`, `touchEdited`, `loadMeta`, `clearMeta`, `ensureInit`, `recordLastActive` | Resume + edited timestamps |
| **Check existence** | `hasDraft`, `exists` | Gate UI / discard / `recordLastActive` guard |
| **Processing list building** | `_loadLocalCreatorDraftIntoProcessing` | Filter `isMeaningfulDraftForProcessing` + meta |
| **Add tab local list** | `_LocalDraftsSnapshot.load` | Draft-only subset |
| **Route sync / resume** | `syncCreatorDrawerSessionFromContext`, `CreatorDraftResumeFlow` | Navigation truth |
| **Publish persistence** | Only via **`persistLocalNow`** in notifier (`publish*ToDisk`) — **no direct Profile storage for publish** | OK path today |
| **Basics / hub discard** | `story_creator_basics_screen`, `story_creator_hub_screen` | Edge cases + hub UX |

---

## D. Migration target map

| Group | Future target | Notes |
|-------|---------------|--------|
| **All read/write of draft JSON + resume bundled ops** | **`StoryDraftRepository`** | Single place for `save` + `touchEdited`, `delete` + `clearMeta`, etc. |
| **Debounced typing, dirty flags, in-memory aggregate** | **`StoryCreatorDraftNotifier`** | Unchanged responsibility |
| **“Load list for Processing / Add tab”** | **Repository** `listDrafts` / `listProcessingItems` **or** notifier **`refreshFromRepository()`** returning cached list — avoid widgets calling storage | Profile/Add tab call **one** API |
| **Rename title on Processing card** | Prefer **notifier** method **`updateTitleAndPersist`** calling **repository** — keeps provider and disk aligned | Eliminates Profile’s direct `save` |
| **`syncCreatorDrawerSessionFromContext`** | **`repository.updateResumeFromRoute(...)`** or thin wrapper calling repository | Keeps resume writes out of UI file |
| **`CreatorDraftResumeFlow`** | Call **notifier.loadDraftById** (already does) + **repository.ensureResumeMeta** instead of static `ensureInit` | |
| **Hub `exists` / `loadSavedAt`** | **Repository** `hasAnyDraft`, `savedAtForActiveOrLatest` — or derive from notifier + repository | Remove `FutureBuilder` on static storage |

---

## E. High-risk mismatches

| Risk | Where | Why |
|------|-------|-----|
| **Stale in-memory state** | `_ProcessingDraftCard._rename` | Updates disk **without** `storyCreatorDraftProvider` if that draft is not the active loaded draft — provider can be wrong until next `loadDraftById`. |
| **Duplicated source of truth** | Hub: `exists()` vs provider’s `draft` | “Continue” enabled when **any** draft exists on disk, but path uses **current** `CreatorStoryV1` — wrong draft id possible in multi-draft scenarios. |
| **Provider vs storage drift** | Profile delete/rename | Disk updated; active notifier may still reference old draft if user had it open elsewhere. |
| **Route state mismatch** | `recordLastActive` guarded by `hasDraft` | If meta exists but draft missing (corruption), behavior undefined; rare. |
| **“Start new story” vs multi-draft** | Hub `discardDraftFromDiskAndReset` → `clear()` | Clears **only the active** draft id, not the full index — other drafts remain; `exists()` can still be true after tap. |
| **`ensureInit` vs disk** | `CreatorDraftResumeFlow._restoreDraftState` | `ensureInit` can create meta without verifying draft payload exists first (then `loadDraftById` may load null — notifier handles null poorly depending on path). |
| **Resume meta inconsistency** | Multiple writers: notifier `touchEdited`, Profile rename `touchEdited`, route `recordLastActive` | All valid but **order** matters; repository should serialize writes. |

---

## F. Safe migration order

1. **Easiest / safest:** Introduce **repository interface** + **local impl** delegating to current static classes; **switch `StoryCreatorDraftNotifier` only** — behavior unchanged, one choke point.
2. **Medium:** **`story_creator_add_tab_screen`** and **`story_creator_hub_screen`** — read-only patterns; low risk.
3. **Medium-high:** **`story_creator_basics_screen`** discard path — must preserve `hasDraft` + clear semantics.
4. **High:** **`profile_screen.dart`** — many paths; do rename/delete through **notifier** or repository + **reload** list.
5. **Last / coordination:** **`creator_route_sync`** + **`creator_resume_draft`** — ensure **repository** is the only resume writer; test all “Continue” entry points.

---

## G. Exact suggested sequence (codebase-specific)

1. **`story_creator_provider.dart`** — Replace static `StoryCreatorDraftStorage` / `ResumeStorage` calls with **`StoryDraftRepository`** (local implementation wraps existing statics). **No UI file changes yet.**
2. **`profile_screen.dart`** — `_loadLocalCreatorDraftIntoProcessing`: use **`repository.list…`** or notifier **`watchProcessingDrafts`**. Then migrate **`_ProcessingDraftCard._rename` / `_delete`** to **notifier + repository** (remove duplicate save/delete).
3. **`story_creator_add_tab_screen.dart`** — `_LocalDraftsSnapshot.load` → repository list API.
4. **`story_creator_basics_screen.dart`** — replace `hasDraft` / `clear` / `clearMeta` with **repository** methods (discard flow).
5. **`story_creator_hub_screen.dart`** — replace `exists` / `loadSavedAt` **FutureBuilders** with repository or a small **hub-specific provider** fed by repository.
6. **`creator_resume_draft.dart`** — `ensureInit` → **`repository.ensureResumeMeta(draftId)`**; `loadMeta` → repository.
7. **`creator_route_sync.dart`** — `recordLastActive` → **`repository.recordResumeLastActive(...)`** (same behavior, one implementation).

---

## H. Top 15 direct storage cleanup decisions (prioritized)

1. **All persistence goes through `StoryDraftRepository`** eventually — static storage classes become **private to local repository impl**.
2. **Migrate `StoryCreatorDraftNotifier` first** — maximum reuse, minimal UI churn.
3. **Profile `_ProcessingDraftCard._rename` must update notifier or reload** after save — avoid orphan disk writes.
4. **Profile Processing load** should use **one** repository list method — delete hand-rolled `loadAllIds` loops in UI.
5. **Add tab list** uses same list API with **client-side filter** `publishState == draft` until server filters.
6. **Basics discard** uses **`repository.deleteDraftIfEmptyShell`** or keep explicit `hasDraft` + delete — preserve current UX text.
7. **Hub** must resolve **`exists()` vs multi-draft`** — prefer **“any draft”** vs **“active draft id”** explicitly in API.
8. **`recordLastActive`** stays a **repository** concern; route sync file only **calls** repository.
9. **`ensureInit`** semantics: fold into **`loadDraft` side effect** or **`repository.touchResumeDefaults`** — document whether meta can exist without draft.
10. **Delete flows** must always **`clear` + `clearMeta`** in repository **one method** `deleteDraft(id)`.
11. **Publish persistence** already centralized in notifier — **do not** add Profile-side publish saves.
12. **`touchEdited`** always paired with **draft save** in repository `saveDraft` implementation.
13. **Tests:** mock **repository**, not `SharedPreferences`.
14. **No new direct static storage calls** in new features — lint/rule optional later.
15. **`story_creator_draft_storage.dart`** file **stays** as adapter; **no** feature imports it except local repository.

---

## Closing lists

### 1. These files should stop touching storage directly first

- **`lib/features/create/story_creator_provider.dart`** — convert to repository (foundation for everything else).
- **`lib/features/profile/profile_screen.dart`** — highest duplication and drift risk (`_loadLocalCreatorDraftIntoProcessing`, `_ProcessingDraftCard`, `_showProcessingDraftSheet`).

### 2. These files are safe to leave for later

- **`lib/features/create/story_creator_hub_screen.dart`** — read-only `exists` / `loadSavedAt`; small surface; depends on clarifying multi-draft vs “active” draft UX first.

### 3. These files may need special care because of route/resume behavior

- **`lib/features/create/creator_route_sync.dart`** — fires on navigation; must not cause double-writes or races when repository adds sync/queue later.
- **`lib/features/create/creator_resume_draft.dart`** — orchestrates `loadDraftById` + meta routing; any change to `ensureInit` / `loadMeta` affects every “Continue” entry point.

---

*End of report.*
