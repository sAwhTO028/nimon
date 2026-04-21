# Nimon Add flow — final stabilization check (pre-backend)

**Date:** 2026-04-21  
**Scope:** Add flow + Profile Processing touchpoints only. No backend, no UI redesign, no new features.

**Method:** Static architecture audit + code-path review. **Interactive device QA** is still recommended before shipping; this document records confidence from the codebase and known patterns.

---

## A. What was tested

### Automated / static (this pass)

| # | Check | Method |
|---|--------|--------|
| 13 | Storage only behind repository adapter | `rg` for `StoryCreatorDraftStorage.` / `StoryCreatorDraftResumeStorage.` — only `local_story_draft_repository.dart`, `story_creator_draft_storage.dart`, and **doc comments** in `story_draft_repository.dart` |
| — | `devCurrentUserProvider` wired into notifier | `story_creator_provider.dart` reads `ref.watch(devCurrentUserProvider).userId` |
| — | Initial draft owner | `StoryCreatorDraftState.initial(creatorOwnerId: _devOwnerId)` |
| — | Owner backfill on load | `loadDraftById` sets `creatorOwnerId` when empty + `persistLocalNow(reason: 'owner_backfill')` |
| — | Processing ↔ notifier sync hooks | `profile_screen.dart` calls `syncIfDraftWasRemovedExternally` / `syncIfSameDraftWasPersistedElsewhere` on delete/rename |
| — | DTO/mapper present (unused at runtime) | `story_draft_dto.dart`, `story_draft_processing_item_dto.dart`, `story_draft_mapper.dart` exist for future HTTP |

### Manual / device (recommended, not executed in this pass)

| # | Scenario |
|---|----------|
| 1 | Cold start → Create → confirm `basics.creatorOwnerId == dev_user_1` (debug inspect or log) |
| 2 | Reset / new story from Add tab |
| 3 | Basics confirm → persist |
| 4 | Sentences edit → debounced save |
| 5 | Vocab / grammar / quiz / audio edits → save |
| 6 | Profile → Processing list |
| 7 | Rename / delete draft from Processing |
| 8 | Hub → Continue current story |
| 9 | Resume from Add / Profile / Processing |
| 10–11 | Publish Read Only / Full Learn → relaunch app → state restored |
| 12 | Old draft with empty `creatorOwnerId` → open in creator → disk after backfill |

---

## B. What passed (from static review)

- **Repository boundary:** All direct `StoryCreatorDraftStorage` / `StoryCreatorDraftResumeStorage` **calls** are confined to **`LocalStoryDraftRepository`** (+ definitions in `story_creator_draft_storage.dart`). Add-flow UI and notifier do not call storage statics.
- **Owner dev stub:** `devCurrentUserProvider` is the single injected `userId`; initial state, `reset` / `startNewLocalDraft` (`_effectiveCreatorOwnerId`), and `loadDraftById` backfill are implemented consistently.
- **Processing integration:** Delete/rename go through `StoryDraftRepository` and refresh the list; notifier sync methods reduce stale session state when the same draft id is affected.
- **DTO layer:** Mapper + DTOs are available for a future remote repository without changing domain types today.
- **No broad refactors** were required for this checklist.

---

## C. What still feels risky

| Risk | Notes |
|------|--------|
| **Hub “indexed vs active vs notifier”** | Hub uses `hasAnyIndexedDraft` + `savedAtActiveDraft()` (prefs **active** id) while Continue path uses **notifier** `draft`. Edge case if prefs/active and in-memory draft diverge — known pre-existing ambiguity. |
| **Drafts never opened in notifier** | Owner backfill runs only on `loadDraftById`. Legacy drafts with empty owner stay on disk unchanged until opened. |
| **E2E not run here** | Publish, resume, and multi-step saves were **not** executed on a device in this pass. |
| **Tests** | Some widget tests may be flaky or environment-specific; unrelated failures should not block backend prep but should be tracked. |

---

## D. Remaining technical debt (Add flow only)

- **`StoryDraftRepository.createNewDraft`** — not used by runtime yet; future remote create can align with `devCurrentUserProvider` when wired.
- **Resume meta** — still device-local only (by design); cross-device resume is out of scope until API defines `client-meta` or similar.
- **Integration tests** — high value: fake `StoryDraftRepository` + notifier + one navigation test per resume path.

---

## E. Final verdict: ready for backend start?

**Yes** — for **app-side** backend preparation: repository seam, DTO/mapper, dev `ownerId`, and storage encapsulation are in place.  
**Condition:** Run a **short manual smoke** on device (checklist A manual rows) before relying on production behavior; no code blocker identified in this audit.

---

## F. Recommended very next step

1. **Backend contract:** OpenAPI (or equivalent) for draft CRUD + publish endpoints aligned with `StoryDraftDto` / `PublishResponseDto`.
2. **Implement `RemoteStoryDraftRepository`** (or decorator) that uses HTTP + mapper — behind the same `StoryDraftRepository` interface.
3. **Auth:** Replace `devCurrentUserProvider` with real session provider when tokens exist; keep a single owner injection point on the notifier.

---

## Document control

Prepared as a **stabilization snapshot** before backend work; update after first API integration milestone.
