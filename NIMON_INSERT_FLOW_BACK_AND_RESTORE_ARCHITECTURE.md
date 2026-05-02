# Nimon Insert/Create — Back flush + Processing restore architecture (codebase-fit)

**Date:** 2026-04-23  
**Scope:** Architecture/spec adaptation for the **current** Nimon codebase.  
**Non-goals:** UI redesign, backend changes, broad unrelated refactors.

This document translates the locked product philosophy into a plan that fits the current V1 creator implementation:

- `StoryCreatorDraftNotifier` (`lib/features/create/story_creator_provider.dart`)
- creator “session” / drawer model (`creatorDrawerSessionProvider`)
- GoRouter canonical routes (`/create/story/...` + `?draftId=` + `?panel=...`)
- Processing reopen behavior (`CreatorDraftResumeFlow.resumeFromProcessing`)
- current persistence boundary (`StoryDraftRepository`, `CreatorDraftResumeMeta`)

---

## 1. Architecture explanation (philosophy → implementation)

### Product philosophy (locked)
- **Editor page is temporary working surface**
- **Processing tab item is the persistent workflow record**
- **Final V1 lock — Back is always available**
  - On **Back** from the editor, the system must always attempt:
    1) **flush** latest meaningful editable state to the related **Processing** content item  
    2) **reset** temporary editor UI state  
    3) **leave the page**
  - The only reason Back does not immediately leave is **blocking work** (defined in §7).
- Reopening from **Processing** restores **meaningful progress** and the **last meaningful working section**.

### Codebase-fitting translation

In the current codebase we already have the “two layers” we need:

- **Persistent content/workflow** already exists as:
  - **Draft content**: `CreatorStoryV1` (owned by `StoryCreatorDraftNotifier`, persisted by `StoryDraftRepository.saveDraft/saveDraftNow`)
  - **Resume metadata**: `CreatorDraftResumeMeta` (persisted by `StoryDraftRepository.saveResumeMeta/updateResumeMeta/recordResumeNavigation`)
  - **Processing list** is implicitly derived from “drafts that exist locally + resume meta timestamps”, and refreshed via `profile_processing_refresh.dart` hooks.

- **Ephemeral editor UI** already exists as:
  - `StoryCreatorSentencesScreen` local state: controllers, scroll position, selection/editing indices, drawer animation controller, etc.
  - progress drawer open/close (custom animated drawer) or Material `Scaffold` endDrawer on legacy screens
  - `creatorDrawerSessionProvider` (session-ish state used to highlight drawer rows and to track `learnModeEnabled` + embedded step)

This philosophy becomes stable when we enforce:

- **One persistent owner for workflow progress**: `CreatorDraftResumeMeta` (extended as needed, but not replaced)
- **One canonical “where am I” address**: GoRouter URI (`/create/story/sentences?...&panel=...`) + `draftId`
- **Back = “flush + reset + exit”** implemented through `creator_back_policy.dart` using **existing save APIs**, plus a strict “ephemeral reset” boundary
- **Processing reopen** chooses the destination from **persisted resume meta** (module/subPage) + learn mode rules, and must be **idempotent** when already in the same session

---

## 2. Codebase-fit ownership map (who owns what)

### A) Persistent workflow/content state (owner-of-record)

#### **Draft content (the actual story + module payloads)**
- **Owner**: `StoryCreatorDraftNotifier`
- **Storage boundary**: `StoryDraftRepository.saveDraft` / `saveDraftNow`
- **Domain**: `CreatorStoryV1` (basics, sentences, vocabulary, grammar, quiz, listening assets, publish state)

#### **Workflow record (Processing item)**
For V1 in this codebase, “Processing item” should be represented by persisted metadata, not by widget state:

- **Owner**: `StoryDraftRepository` resume meta functions
- **Record**: `CreatorDraftResumeMeta` (plus a small extension described below if needed)
- **Mutation points**:
  - route-sync: `syncCreatorDrawerSessionForRouter(...)` → `recordResumeNavigation(...)`
  - Back flush: update “last meaningful section” + timestamps at exit
  - Publish success: update publish-related fields on the draft (already done today)

**Principle:** Processing should not depend on ephemeral widget state like “drawer is open” or “scroll offset”.

### B) Ephemeral UI / transient state (allowed to reset freely)

- `StoryCreatorSentencesScreen` local UI state:
  - `_body` controller text selection, `_editingSentenceIndex`, temporary sheets, scroll position, focus, `_drawerPanSession`, `_progressDrawerController` value
- Drawer chrome:
  - custom progress drawer open/closed animation state
  - Material `Scaffold` endDrawer open/closed state
- UI-only session helpers:
  - `creatorDrawerSessionProvider` fields that are purely presentation and reconcilable from router (see “derived vs persistent” split below)

---

## 3. Persistent vs ephemeral split (explicit)

### Persistent workflow state (must survive exit/reopen)

**Persist (write to disk / repo)**
- **Draft content** (`CreatorStoryV1`) – the work itself
- **Workflow progress / resume target** (`CreatorDraftResumeMeta`)
  - last meaningful section (module/subPage)
  - last edited at
  - any workflow status fields (see section 5)

### Ephemeral editor UI state (must NOT be treated as business state)

**Do NOT persist (reset on exit)**
- Drawer open/closed
- Scroll offsets / focus / selection
- Temporary “editing a sentence row” indices
- Any in-flight animation controller values
- Any “currently open sheet/dialog” state

### Derived state only (computed, not owned)

**Derived from draft content + resume meta**
- readiness gates (core complete, learn complete, publish enabled)
- progress checklist model shown in the drawer (`buildCreatorDrawerProgressModel`) should be purely derived

### Remove from business ownership (current mismatches)

The current codebase sometimes uses `creatorDrawerSessionProvider` as if it is workflow ownership (e.g. “what module is active”) while also treating the router `?panel=` as canonical.

**Direction:** `creatorDrawerSessionProvider` is presentation/session cache only; the persisted workflow record is `CreatorDraftResumeMeta`.

---

## 4. Standardize a clean `EditorSection` model (fits current routing)

### Required enum (new, V1)

```dart
enum EditorSection {
  storyBasics,
  storySentences,
  vocabulary,
  grammar,
  quiz,
  listening,
}
```

### Mapping rules (must match current router shape)

**Canonical location**
- `storyBasics` → `/create/story/basics?draftId=…`
- `storySentences` → `/create/story/sentences?draftId=…` (no `panel=`)
- learn sections → `/create/story/sentences?draftId=…&panel=...`
  - `vocabulary` → `panel=vocabulary`
  - `grammar` → `panel=grammar`
  - `quiz` → `panel=quiz`
  - `listening` → `panel=listening`

### Mapping to existing storage enum

Current storage uses `CreatorLastActiveModule` (and optional `subPage`).

**Proposed mapping**
- `EditorSection.storyBasics` → `CreatorLastActiveModule.storyBasics`
- `EditorSection.storySentences` → `CreatorLastActiveModule.storytelling`
- `EditorSection.vocabulary` → `CreatorLastActiveModule.semantics` + `subPage='vocabulary'`
- `EditorSection.grammar` → `CreatorLastActiveModule.grammar` + `subPage='grammar'`
- `EditorSection.quiz` → `CreatorLastActiveModule.quizzes` + `subPage='quiz'`
- `EditorSection.listening` → `CreatorLastActiveModule.listening` + `subPage='listening'`

**Note:** this fits the current `CreatorDraftResumeFlow._v1ResumeTargetUriForDraft` logic and avoids inventing a new persistence type immediately.

---

## 5. Workflow status model (Processing as persistent record)

### Goal
Processing needs a stable status model that is:

- derived from **persisted** content/meta (not widget flags)
- compatible with the current V1 publish semantics (`StoryPublishState`, RO signature, etc.)
- easy to compute for list rows without building editor UI

### Proposed model (minimal, codebase-fit)

Keep the current domain publish state on the draft, and treat resume meta as the persistent workflow record.

#### A) Persisted workflow anchor (required)

Persist **only** the “last meaningful section” (module/subPage) as part of `CreatorDraftResumeMeta`. This is the stable “resume here” pointer.

Optionally (later), persist a status enum if you want Processing list to be fast without recomputing readiness from draft JSON.

#### B) Optional persisted workflow status (only if needed)

```dart
enum CreatorWorkflowStatus {
  editing,
  readyReadOnly,
  readyFullLearn,
  publishedReadOnly,
  publishedFullLearn,
}
```

**Default V1 stance:** do **not** persist this yet; compute it as **derived state** (section 6).

---

## 6. Derived readiness rules (single place, derived-only)

### Required derived gates

These gates must be computed from draft content (and learn-mode), not stored in UI/session.

- **`isCoreComplete`**: basics + storytelling readiness
- **`isLearnModulesComplete`**: learn module readiness when learn-mode is ON
- **`canPublishReadOnly`**
- **`canPublishFullLearn`**

**Implementation fit:** Use/centralize existing rules in:
- `lib/features/create/creator_readiness.dart`
- `lib/features/create/creator_publish_validation.dart`
- `lib/features/create/creator_completion_rules.dart` (if still the canonical checklist rules)

---

## 7. Back philosophy mapped to CURRENT code

### Intent
On back from the editor surface, we must:

1. **Flush meaningful state** to the persistent workflow record (Processing item)
2. **Reset ephemeral UI** (drawer, edits, keyboard, animations)
3. **Exit** the editor page to the correct parent (entry context)

### Final lock: “no random UI branches”
Back behavior must not be defined by incidental UI micro-state (expanded widgets, drawer open as a *decision*, etc.).

- **Ephemeral UI reset** may close drawers/sheets/keyboards as implementation details, but Back is still a single pipeline.
- **Routing/section** should be recorded as “last meaningful section” in resume meta, not used to create a growing tree of back rules.

### Blocking work (the only allowed interruption)
Back must still be available when blocking work exists, but it may present a minimal blocking decision before leaving.

**Blocking work categories (V1):**
1. **Save/flush failure** (cannot persist meaningful state locally)
2. **Audio upload in progress** (see rule below)
3. **Publish in progress** (must block until critical step resolves)

#### Save failure on Back (V1)
- Do **not** silently lose user data.
- Show a minimal blocking dialog:
  - **Retry**
  - **Stay**
  - **Optional**: **Discard and leave** only if allowed by current product rules for that surface

#### Audio upload in progress on Back (V1 rule — chosen)
**Rule:** If an audio upload is in progress, Back shows a minimal blocking dialog:
- **Stay** (default/safest)
- **Cancel upload and leave**

Rationale: consistent and safe without backend changes; avoids leaving while an in-flight operation may later mutate draft state.

#### Publish in progress on Back (V1 rule)
**Rule:** Prefer safety: block exit until the critical publish step resolves.
- While publishing, Back must show a blocking UI (“Publishing…”) and prevent leaving until completion or failure.
- On failure, user can **Stay** or **Retry**; Back remains available.

### Processing vs Published separation (explicit)
**Lock:** all current local editable work belongs to the **Processing** workflow record.
- Published tab represents the already-published snapshot.
- Editing a previously published item creates/continues a Processing draft; Back flush always targets Processing state.

### Current code hooks to use (no new architecture required)

- **Back decision point**: `lib/features/create/creator_back_policy.dart`
  - `performCreatorBackFromSentencesHost(...)`
  - `performExitFromCreateRoot(...)`
- **Flush draft to disk**: `StoryCreatorDraftNotifier.persistLocalNow(...)` (or its existing “save now” equivalent)
- **Record last meaningful section**: `StoryDraftRepository.recordResumeNavigation(...)` / `updateResumeMeta(...)`
  - This should be fed from the **router URI** (section 4 mapping)
- **Ephemeral reset**: stays inside screens (close drawers, dismiss keyboard); policy already does drawer-first closure.

### What is flushed (precise)

From sentences host (S0 / S1–S4), before a creator exit:

- **Draft content**: if the draft notifier is dirty, flush immediately (local-only):
  - `persistLocalNow(reason: 'back_exit')`
- **Workflow record**: persist the “last meaningful section” to resume meta:
  - derived from GoRouter `uri.path` + `uri.queryParameters['panel']`
  - stored via `recordResumeNavigation(...)` or `updateResumeMeta(lastActiveModule: ..., lastActiveSubPage: ...)`

### What is reset (precise)

Reset is local, not persisted:

- close progress drawer/endDrawer if open (policy already closes drawer first)
- dismiss keyboard
- cancel inline edits/sheets
- clear per-screen editing indices / temporary state on dispose (existing behavior)

### What must not be reset

- persisted draft content
- resume meta (except intentionally updating it)
- entry context provider (only overwritten when a **new** session entry begins)

---

## 8. Processing reopen / restore mapped to CURRENT code

### Restore responsibilities

Processing reopen (`CreatorDraftResumeFlow.resumeFromProcessing`) must:

- load draft content from disk (already: `loadDraftById(...forceReloadFromDisk: true)`)
- compute a resume target from persisted meta + learn mode (already: `_v1ResumeTargetUriForDraft`)
- navigate in a way that **does not create overlapping creator subtrees**

### Same-draft vs different-draft behavior

To match the philosophy and to avoid lifecycle/back crashes:

- **Same draft already open at same destination**:
  - do not re-enter; do nothing (idempotent)
- **Same flow but different draft/section**:
  - replace (`go`) to the new destination, do not stack (`push`)
- **Not currently in creator flow**:
  - `push` into creator as usual

This keeps the editor a temporary surface and ensures the Processing record is the stable pointer.

### What is *not* restored

- drawer open state
- scroll offsets
- transient sheet/dialog state
- inline edit session state

---

## 9. Biggest current mismatches in the codebase (from audit/spec)

1. **Workflow record is implicit**
   - Processing is currently “derived from drafts + timestamps” without an explicit “last meaningful section” contract.
2. **Session can look like a state owner**
   - `creatorDrawerSessionProvider` stores module/step while the router `?panel=` is canonical; drift risk remains.
3. **Flush-on-exit is inconsistent across surfaces**
   - Basics does a flush-on-exit pattern; sentences exit needs the same explicit contract (even if it is a no-op when not dirty).
4. **Multiple sync pathways and post-frame work**
   - Route/session sync and after-nav updates must remain lifecycle-safe and bounded; the rebuild should reduce fan-out, not add more.

---

## 10. Recommended migration path (fits `NIMON_INSERT_FLOW_REBUILD_PLAN.md`)

This is intentionally aligned to the existing phases; it’s not a greenfield rewrite.

### Step A (Phase 2): add a “flush on exit” hook to back policy

- In `performCreatorBackFromSentencesHost`, immediately before exiting from S0:
  - flush draft if dirty
  - record last meaningful section to resume meta

### Step B (Phase 3): make `EditorSection` a shared mapping utility

- Introduce a tiny mapper:
  - `EditorSection sectionFromUri(Uri uri)`
  - `CreatorLastActiveModule moduleFromSection(EditorSection)`
- Use it in:
  - route sync → `recordResumeNavigation`
  - back exit flush → `updateResumeMeta`
  - resume target resolution → ensure the mapping is consistent

### Step C (Phase 5): Processing reopen uses persisted “last meaningful section”

- Ensure resume meta always has a valid “last active module” for any persisted draft.
- When learn mode is OFF, normalize to S0 (already consistent with locked spec).

### Step D (Phase 6–7): shrink duplicate authorities

- Keep router `?panel=` canonical.
- Treat `creatorDrawerSessionProvider` as derived/presentation cache only.

---

## Appendix A. Ownership summary (quick)

| Category | Persistent owner | Ephemeral owner |
|---|---|---|
| Draft content | `StoryCreatorDraftNotifier` + `StoryDraftRepository` | — |
| Workflow record (Processing) | `CreatorDraftResumeMeta` | — |
| Current section | GoRouter URI (`?panel=`) | `creatorDrawerSessionProvider` (derived cache) |
| Drawer open state | — | screen state/controllers |

