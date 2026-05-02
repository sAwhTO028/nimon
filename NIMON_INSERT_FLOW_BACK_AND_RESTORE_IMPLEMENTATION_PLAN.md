# Nimon Insert/Create — Back/Restore implementation plan (current codebase)

**Date:** 2026-04-23  
**Scope:** Apply the locked Back/Restore architecture to the **current** Nimon Insert/Create flow.  
**Non-goals:** UI redesign, backend changes, greenfield rewrite.

**Foundation docs (must stay consistent):**
- `NIMON_INSERT_FLOW_FULL_AUDIT.md`
- `NIMON_INSERT_FLOW_V1_LOCKED_SPEC.md`
- `NIMON_INSERT_FLOW_REBUILD_PLAN.md`
- `NIMON_CREATE_V1_LOCKED_DECISIONS.md`
- `NIMON_INSERT_FLOW_BACK_AND_RESTORE_ARCHITECTURE.md`

---

## 1. The target contract (what we are implementing)

### Back (from editor surface)
On Back from a creator editor surface (**any** creator state: Basics, Sentences, any module, learn ON/OFF):

1. **Flush meaningful state** to the persistent workflow record (Processing item)  
2. **Reset ephemeral UI** (drawer, keyboard, edit sessions)  
3. **Exit** to the correct parent destination (entry context)

**Final V1 lock:** Back is always available. The only reason Back does not immediately leave is explicit **blocking work** (defined in §7).

### Restore (from Processing tab)
Processing reopen must:

- restore **draft content** from disk
- restore **last meaningful section** from persisted resume meta
- restore **learn mode** policy correctly (learn OFF normalizes to S0)
- **never** restore transient UI chrome
- be **idempotent** when reopening the same draft/section while already inside creator

---

## 2. Current state (what exists today)

### Canonical navigation model (already locked and implemented)
- Canonical editor route is GoRouter:
  - `/create/story/basics?draftId=…`
  - `/create/story/sentences?draftId=…&panel=…` where `panel ∈ {vocabulary, grammar, quiz, listening}`

### Persistent state already present
- Draft content: `CreatorStoryV1` owned by `StoryCreatorDraftNotifier`
  - file: `lib/features/create/story_creator_provider.dart`
- Persistence boundary: `StoryDraftRepository`
  - file: `lib/features/create/data/story_draft_repository.dart`
- Resume meta: `CreatorDraftResumeMeta` + `recordResumeNavigation(...)`
  - used by: `lib/features/create/creator_route_sync.dart`

### Back policy already centralized (but missing “flush on exit” in one place)
- file: `lib/features/create/creator_back_policy.dart`
  - `performCreatorBackFromSentencesHost(...)` is the main “exit from sentences” policy

### Processing reopen already exists
- file: `lib/features/create/creator_resume_draft.dart`
  - `CreatorDraftResumeFlow.resumeFromProcessing(...)` + target resolution `_v1ResumeTargetUriForDraft(...)`

---

## 3. Migration phases (exact, codebase-fit)

These phases align to `NIMON_INSERT_FLOW_REBUILD_PLAN.md` and are scoped to the Back/Restore philosophy.

### Phase 0 — Baseline harness (no behavior changes)
**Goal:** lock current behavior and add verification scaffolding before changing exit semantics.

- **Add/confirm tests** (prefer existing creator tests, expand only as needed):
  - confirm “Back closes drawer first” for sentences host
  - confirm Processing resume target resolution for a draft with stored resume meta
- **Manual script (documented)**:
  - Processing → resume → switch panel → Back normalize → Back exit

**Files:**
- `test/creator_*.dart` (existing suite)
- (optional) add a small regression test targeting “Back exit triggers flush” once implemented

**Exit criteria:**
- `flutter test` green for creator tests
- manual script written and repeatable

---

### Phase 1 — Normalize “EditorSection” mapping (pure utility, no UI changes)
**Goal:** make one shared mapping from router URI ↔ “meaningful editor section” so we can flush/restore consistently.

**Add:**
- A tiny mapping helper (new file, minimal):
  - `EditorSection sectionFromUri(Uri uri)`
  - `CreatorLastActiveModule resumeModuleForSection(EditorSection)`
  - `String? resumeSubPageForSection(EditorSection)`

**Recommended location (current codebase fit):**
- `lib/features/create/creator_editor_section.dart` (new)

**Consumers to update (later phases):**
- route sync writes
- back exit writes
- resume target resolution (ensure mapping is consistent)

**Exit criteria:**
- mapping is covered by unit tests (small and deterministic)
- no behavior changes yet

### Final constraint: zero UNKNOWN entry-context

At the end of Phase 1 and Phase 8 (final verification), the system must guarantee:

- No production path sets or falls back to UNKNOWN entry context
- Every creator entry path must explicitly set:
  - add
  - shellMore
  - processing
  - publishedReopen

Audit these launch sites explicitly:
- mono_screen.dart (dock + reader add)
- profile_screen.dart (Processing entry + empty CTA)
- profile_navigation_drawer.dart (Story Creator entry)
- mono_story_options_sheet.dart (if any creator entry exists)
- creator_resume_draft.dart (resume / continue flows)

Verification rules:
1. Grep for any remaining UNKNOWN usage → must be zero in production paths
2. All creator entry functions must assign a valid CreatorEntryChannel
3. No default/fallback logic should silently map to UNKNOWN
4. Tests/manual flow must confirm correct exit/back destination per entry context

Failure to meet this constraint should block Phase 8 sign-off.

---

### Phase 2 — Implement flush-on-exit (Back step 1) in the centralized back policy
**Goal:** on Back from any creator editor surface, flush meaningful state and ensure the Processing workflow record is correct before leaving.

#### 2.1 Where flush-on-exit should be triggered
**Trigger point:** `performCreatorBackFromSentencesHost(...)` in:
- `lib/features/create/creator_back_policy.dart`

**Final lock change:** do not build exit eligibility around incidental UI state (drawer open, panel active).
Back is one pipeline: **flush → reset ephemeral → leave**.

#### 2.2 What gets flushed (persistent)
**Draft content flush** (local-only):
- If `StoryCreatorDraftNotifier` says draft is dirty, flush immediately.
- Use the notifier’s existing disk flush API:
  - `StoryCreatorDraftNotifier.persistLocalNow(reason: 'back_exit')`
  - (or if a dedicated “flush now” method already exists and is stable, use that)

**Processing workflow record flush** (resume meta):
- Record last meaningful section *before leaving*:
  - compute `EditorSection` from router `uri`
  - write `StoryDraftRepository.updateResumeMeta(...lastActiveModule, lastActiveSubPage, touchEditedAtUtc: now)`
  - or call `recordResumeNavigation(...)` with the mapped module/subPage

**Important:** write from **router URI** (canonical), not from `creatorDrawerSessionProvider`.

#### 2.3 What should not be flushed
- drawer open/closed
- scroll/selection/edit session state
- any “UI chrome” flags

#### 2.4 How to handle save failures
**Policy:** do not crash; preserve UX.

- If flush fails:
  - show a minimal blocking dialog:
    - **Retry**
    - **Stay**
    - optional **Discard and leave** only if product allows it
  - do **not** block forever on repeated failure

**Implementation fit:**
- Use `ScaffoldMessenger.maybeOf(context)` (guarded) to avoid lifecycle asserts.
- Keep error copy consistent with existing basics exit behavior (no new UX strings if possible).

**Files to touch:**
- `lib/features/create/creator_back_policy.dart`
- `lib/features/create/story_creator_provider.dart` (only if you need a new “flush now” wrapper that returns success/failure)
- `lib/features/create/data/story_draft_repository.dart` only if a missing meta update API is needed (prefer existing `updateResumeMeta` / `recordResumeNavigation`)

**Exit criteria:**
- Back from S0 triggers a flush when dirty, and does not when clean
- Processing list reflects the draft as expected (timestamp bumped)
- no lifecycle assertions when backing during transitions

---

### Phase 3 — Implement “ephemeral reset” boundaries (Back step 2) in screens
**Goal:** ensure the only “reset” done during Back is ephemeral UI reset, and it stays local to the current screen.

#### 3.1 Where ephemeral UI reset should happen
**Rule:** the back policy closes transient UI layers first, but “reset” (clearing editing state) is owned by the screen widgets themselves.

**Sentences host**
- file: `lib/features/create/story_creator_sentences_screen.dart`
  - keep: progress drawer close (`_closeProgressDrawer`) and keyboard dismissal
  - keep: inline edit cancel (`_cancelEdit`) and any sheet dismissal logic
  - ensure: disposal clears controllers and notifiers (already true)

**Module editor screens with `Scaffold.endDrawer`**
- files:
  - `lib/features/create/story_creator_vocab_kanji_editor_screen.dart`
  - `lib/features/create/story_creator_grammar_editor_screen.dart`
- ensure: Back closes drawer first (already aligned via `tryCloseEmbeddedScaffoldSideDrawers`)
- do not add persistence logic here; flush is centralized

**Important:** ephemeral reset must **not** mutate:
- `CreatorDraftResumeMeta`
- `CreatorStoryV1` content (except via normal editing flows)
- entry context (`creatorEntryChannelProvider`)

#### 3.2 What must not change in UX
- No new confirmation dialogs except where an equivalent already exists (e.g. basics exit save failure)
- No new animations or drawer behavior changes
- No new route shapes

**Exit criteria:**
- Back closes drawer first, then falls through to normal policy
- Back after drawer close works normally
- no “stuck” edit states after leaving and reopening

---

### Phase 4 — Make Processing restore the single workflow restore mechanism (Back/Restore step)
**Goal:** ensure Processing reopen restores meaningful section and never overlaps sessions.

#### 4.1 Where restore-from-processing should read from
- draft content:
  - `StoryDraftRepository.loadDraft(draftId)` via `StoryCreatorDraftNotifier.loadDraftById(...forceReloadFromDisk: true)`
- workflow/section pointer:
  - `StoryDraftRepository.loadResumeMeta(draftId)` which contains `CreatorLastActiveModule` (+ optional subPage)

**File:** `lib/features/create/creator_resume_draft.dart`
- `_v1ResumeTargetUriForDraft(...)` already implements the rule:
  - learn mode OFF → S0
  - learn mode ON → last active module mapping → basics or sentences + `panel=...`

#### 4.2 Idempotent re-entry rules (must be enforced)
- If already at the same destination (same `draftId` + same `panel` + same path):
  - do nothing
- If already under `/create/story` but switching target:
  - replace with `go` (avoid stacking)
- If outside creator flow:
  - `push` into the flow

This must remain the only behavior for Processing reopen; no extra “close and reopen” stacks.

**Exit criteria:**
- tapping reopen/edit while already on the same sentences draft does not push a duplicate route
- back after reopen/edit never crashes

---

## 4. Notifier/repository methods needed (and what may change)

### 4.1 `StoryCreatorDraftNotifier` (persistent content owner)

**Use (already present):**
- `loadDraftById(draftId, forceReloadFromDisk: true)` for Processing resume
- `persistLocalNow(reason: ...)` (or existing equivalent) for final flush

**May need to add (minimal):**
- `Future<bool> flushForExit({required String reason})`
  - returns success/failure (lets back policy decide whether to exit anyway)
  - internally calls `persistLocalNow(...)` and catches errors

### 4.2 `StoryDraftRepository` (workflow record boundary)

**Use (already present):**
- `updateResumeMeta(draftId, lastActiveModule: ..., lastActiveSubPage: ..., touchEditedAtUtc: ...)`
- `recordResumeNavigation(...)` (route sync)

**May need to add (only if missing in current resume meta shape):**
- ability to persist “last meaningful section” even when not changing routes (exit flush write)

---

## 5. Autosave + final flush-on-back (how they interact)

### Rules
- Autosave remains opportunistic (debounced) as today.
- Back exit triggers a **final flush** to guarantee Processing has the latest meaningful edits.

### Implementation contract
- Autosave:
  - continues to call `markDirty()` + `persistDebounce` logic (owned by notifier)
- Back flush:
  - calls notifier flush API (`persistLocalNow`) only when `dirty == true`
  - writes resume meta “last meaningful section” regardless of dirty (cheap and deterministic)

### Why this is codebase-fit
- It respects the existing `StoryDraftRepository.saveDraft` contract (“touch resume edited at”).
- It doesn’t introduce new background queues or backend work.

---

## 6. PopScope / back policy integration (current surfaces)

### Sentences host
- file: `lib/features/create/story_creator_sentences_screen.dart`
  - `PopScope(canPop: false)` calls `_handleSentencesBackNavigation()`
  - `_handleSentencesBackNavigation()` calls `performCreatorBackFromSentencesHost(...)`

**Action:** keep this shape; only extend the policy with flush-on-exit.

### Basics screen
- file: `lib/features/create/story_creator_basics_screen.dart`
  - already has a “dirty? flush before leaving” model

**Action:** align it to the same “flush meaningful state + exit by entry context” contract, but do not redesign it.

### Create root (`/create`)
- file: `lib/features/create/create_screen.dart` + `story_creator_add_tab_screen.dart`
  - exits are routed through `performExitFromCreateRoot(...)`

**Action:** no change unless you need a small flush when leaving create root while dirty (only if product requires it; otherwise keep as-is).

---

## 7. Save failure / upload / publish edge cases (behavior)

### Save failure on Back flush
- If flush fails:
  - show a minimal blocking dialog:
    - **Retry**
    - **Stay**
    - optional **Discard and leave** only if allowed by product rules for that surface
- Never crash; never leave the app stuck.

### Upload/publish (future backend work not in this plan)
- This plan does **not** change backend or upload queues.
- The Back/Restore implementation must not assume network.

### Audio upload in progress on Back (V1 rule)
**Chosen V1 behavior:**
- Back shows a minimal blocking dialog:
  - **Stay**
  - **Cancel upload and leave**

Implementation fit (current codebase):
- Track audio upload as a creator “blocking operation” (provider or notifier flag) that the centralized back handler checks.

### Publish edge cases
- Publishing already has an orchestrated path (`performCreatorDrawerPublish`).
**Chosen V1 behavior:**
- Safest preferred approach: **block exit until the critical publish step resolves**.
- While publish is in-flight, Back remains available but shows blocking UI/state; user cannot leave until completion/failure.

---

## 8. What must explicitly NOT be changed

- **UI** layout/copy/interaction patterns (drawer, pill header, module placeholders)
- **Route shapes** (`/create/story/sentences?...&panel=...` remains canonical)
- **Backend** APIs, DTOs, remote repository contracts
- **Shell** routing model (`StatefulShellRoute.indexedStack` + `NoTransitionPage`)
- Any broad refactor of `story_creator_sentences_screen.dart` or `story_creator_provider.dart` unrelated to flush/restore boundaries

---

## 9. Implementation checklist (exact files, hooks, responsibilities, verification)

### Checklist A — Add shared section mapping (Phase 1)
- **Add file**: `lib/features/create/creator_editor_section.dart`
  - **functions**:
    - `EditorSection sectionFromUri(Uri uri)`
    - mapping to `CreatorLastActiveModule` + `subPage`
- **Verification**
  - unit tests for mapping:
    - sentences no panel → `storySentences`
    - `panel=vocabulary|grammar|quiz|listening`
    - basics path → `storyBasics`

### Checklist B — Add flush-on-exit in `creator_back_policy` (Phase 2)
- **File**: `lib/features/create/creator_back_policy.dart`
  - **Hook**: inside `performCreatorBackFromSentencesHost` on the S0 exit branch
  - **Responsibilities**
    - compute current section from router `uri`
    - if dirty → flush draft to disk
    - persist resume meta last meaningful section (module/subPage)
    - then exit via `_goToParentForEntryChannel`
- **Files possibly touched**
  - `lib/features/create/story_creator_provider.dart` (only if you add `flushForExit`)
  - `lib/features/create/data/story_draft_repository.dart` (only if you need a missing meta update call)
- **Verification**
  - device/manual:
    - edit sentences → Back exit → reopen from Processing → edits are present
  - automated:
    - test that flush is invoked when dirty (mock repository or verify state transitions)

### Checklist C — Ephemeral reset stays local (Phase 3)
- **File**: `lib/features/create/story_creator_sentences_screen.dart`
  - ensure Back path closes progress drawer first (already policy-driven)
  - ensure edit sessions cancel on exit as they do today
- **Verification**
  - open drawer → Back closes drawer only
  - immediately Back again → normal back policy triggers

### Checklist D — Processing restore reads from persisted meta (Phase 4)
- **File**: `lib/features/create/creator_resume_draft.dart`
  - confirm it reads:
    - draft: `loadDraftById(...forceReloadFromDisk: true)`
    - meta: `loadResumeMeta`
  - ensure idempotent navigation rules remain enforced
- **Verification**
  - while already on sentences for draft X, tap reopen/edit for X:
    - no new push, no crash, back works
  - reopen/edit for different draft Y:
    - route replaces, no overlap

### Checklist E — Regression suite (continuous)
- Run:
  - `flutter test` for creator tests
  - manual script from Phase 0
- Watch for:
  - lifecycle asserts (inactive context)
  - duplicate subtree/key overlaps
  - Processing row not updating timestamps after exit

---

## 10. Deliverables and sign-off criteria

**Minimum deliverables**
- flush-on-exit for S0 implemented in back policy
- resume meta always contains a valid “last meaningful section” pointer
- Processing resume opens the right section deterministically and idempotently

**Sign-off**
- no crash on Back after transitions
- no duplicate creator subtree on reopen/edit
- Processing reopen restores meaningful progress and last meaningful section
- UI is unchanged (only stability/behavioral correctness improved)

