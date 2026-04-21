# Nimon Add flow — post-repository migration check

**Date:** 2026-04-21  
**Scope:** Add flow stabilization after `StoryDraftRepository` migration (no UI redesign, no backend/DTO implementation).

---

## A. What was verified

### Automated / static (this pass)

- **Grep audit:** Call sites of `StoryCreatorDraftStorage.*` / `StoryCreatorDraftResumeStorage.*` are confined to:
  - `lib/features/create/story_creator_draft_storage.dart` (definitions + internal `recordLastActive` → `hasDraft` guard)
  - `lib/features/create/data/local_story_draft_repository.dart` (sole adapter implementation)
  - Doc references in `story_draft_repository.dart` (interface comments only)
- **Target Add-flow surfaces** (`story_creator_provider.dart`, Profile Processing paths, Add tab, Basics, Hub, `creator_resume_draft.dart`, `creator_route_sync.dart`) **do not** invoke storage statics directly.
- **Analyzer:** Focused runs during migration reported no issues on touched files (full-project analyze may still surface unrelated legacy warnings elsewhere).

### Manual / product regression (checklist for QA or developer)

These behaviors should be exercised on device or integration tests; **this document does not replace interactive testing.**

| Area | What to confirm |
|------|-----------------|
| Create new draft | `startNewLocalDraft` / new session persists and sets resume meta path via repository |
| First persist after basics | `applyBasics` → `persistLocalNow` → single `saveDraft` path |
| Autosave / debounce | Sentences and other editors still use `persistLocalDebounced` / `persistLocalNow` through notifier → repository |
| Save Draft (drawer / global) | `globalSaveDraftNow` → `persistLocalNow` → repository |
| Processing list | `listDraftIds` / `loadDraft` / `loadResumeMeta` + meaningful filter unchanged |
| Rename / delete (Profile) | Repository mutations + notifier `syncIf*` when same id |
| Continue current story (Hub) | `hasAnyIndexedDraft` + `savedAtActiveDraft` + navigation unchanged |
| Basics discard | `hasDraft` + conditional `deleteDraft` + `reset` unchanged |
| Resume (Add / Profile / Processing) | `ensureResumeMetaInitialized` + `loadDraftById` + `loadResumeMeta` + same URIs |
| Route sync | `recordResumeNavigation` preserves `recordLastActive` semantics |
| Read Only / Full Learn publish | Still `persistLocalNow` after state change in notifier (unchanged pattern) |

---

## B. Any remaining direct storage usage

### Allowed (adapter-only)

| Location | Role |
|----------|------|
| `local_story_draft_repository.dart` | **Only** production delegate to `StoryCreatorDraftStorage` / `StoryCreatorDraftResumeStorage`. |
| `story_creator_draft_storage.dart` | Canonical JSON keys, migration, static APIs. |

### Intentional non-adapter references

| Location | Notes |
|----------|--------|
| `story_draft_repository.dart` | **Documentation** references to storage class names in `///` comments (not runtime calls). |

### Cleanup still needed?

**No** for Add-flow call sites: migration goal (no direct storage from UI/notifier/resume routes except through repository) is met.

---

## C. Repository boundary consistency

- **Persistence:** Draft I/O and resume meta go through `StoryDraftRepository` / `LocalStoryDraftRepository` from migrated call sites.
- **Notifier:** Still owns `CreatorStoryV1` state, debounce timer, `dirty` / `saveStatus` / `lastSavedAt` / errors; single write path `persistLocalNow` → `_drafts.saveDraft`.
- **Resume:** `ensureResumeMetaInitialized`, `loadResumeMeta`, `recordResumeNavigation` delegate to the same storage helpers as before.
- **Duplicate save paths:** No second parallel persist implementation was added in screens; saves remain notifier- or repository-mediated as designed.

---

## D. Small cleanup performed (this pass)

- **Audit-only pass:** No behavioral code changes were required to fix a migration defect.
- **Optional hygiene:** Teams may later narrow `import .../story_creator_draft_storage.dart` to `show` types only in files that still import the barrel for enums (`CreatorLastActiveModule`, etc.) — cosmetic, not required for correctness.

---

## E. Recommended next step

1. **DTO / API phase (when ready):** Introduce request/response DTOs and mapping **at** the repository implementation or a thin sync layer; keep `StoryDraftRepository` as the app-facing seam.
2. **Tests:** Add `StoryDraftRepository` fakes + widget/integration tests for Processing rename/delete and resume routing (high value, low UI churn).
3. **Optional product follow-up:** Document or reduce **hub ambiguity** (see risks below) — not blocking DTO work if behavior is accepted.

---

## F. Remaining weak points / risks

| Risk | Severity | Mitigation today | Defer? |
|------|----------|------------------|--------|
| **Active draft vs notifier draft vs index** | Medium | Hub uses `hasAnyIndexedDraft` + `savedAtActiveDraft()` (prefs **active** id) while “Continue” path uses **in-memory** `draft` from `storyCreatorDraftProvider`. Rare mismatch if prefs/active id diverges from notifier state. | Could unify on one source in a later UX/tech pass. |
| **External rename/delete vs create session** | Low–medium | Notifier `syncIfSameDraftWasPersistedElsewhere` / `syncIfDraftWasRemovedExternally` on Profile actions. Other surfaces (future) should call the same hooks. | OK until multi-surface edit. |
| **Publish state** | Low | Still persisted via same `saveDraft` path after notifier updates `publishState`. | DTO phase: explicit mapping + versioning. |
| **Resume meta init** | Low | `ensureResumeMetaInitialized` before load; `recordLastActive` still skips when no draft payload (storage guard). | Unchanged. |

---

## G. Final verdict: stable enough for DTO hooks?

**Yes — with caveats.**

- The **boundary is in place**: new remote/sync code can sit behind `StoryDraftRepository` (or a decorator) without touching most UI.
- **Do first:** contract tests or manual QA on the checklist in section A, especially Hub continue + Profile sync + resume deep links.
- **DTO hooks** should live next to the repository implementation or a dedicated mapper, not inside the notifier.

---

## Document control

- **Authoring:** Post-migration static audit + checklist (not a substitute for full E2E test pass).
