# Draft Summary Metadata Implementation Report

**Date:** 2026-05-02  
**Scope:** Cheap draft list metadata only — no `hasUnpublishedCoreChanges`, no draft-vs-published diff in the list endpoint, no per-row `loadDraft`.

## Files Changed

### Backend (NestJS)

| File | Change |
|------|--------|
| `nimon-backend/src/modules/story-drafts/dto/story-draft.dto.ts` | Extended `DraftListSummaryResponseDto`; added `DraftListWorkspaceState`. |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` | `listDrafts` `select` includes `targetDurationBandKey`, `moduleWorkflowStatuses`; `mapDraftListSummary` emits new fields; private helpers for completion %, learn mode, `lastEditingStep`, `workspaceState`. |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.spec.ts` | Extended fixtures and tests for new fields, bounds, learn mode, cursor. |

### Flutter

| File | Change |
|------|--------|
| `lib/features/create/data/dto/draft_summary_completion.dart` | **New.** Shared cheap completion % + module heuristics (mirrors backend formula). |
| `lib/features/create/data/dto/draft_list_summary_dto.dart` | New fields, `fromJson` fallbacks, `fromCreatorStoryV1` / `interimIdOnly` updated; `workspaceStateKeyFromPublishStateKey`. |
| `lib/features/create/creator_processing_copy.dart` | `draftSummaryDurationChip`, `draftSummaryLastEditingLabel`, `draftSummaryReadinessLine`. |
| `lib/features/profile/profile_screen.dart` | Duration chip from summary; `workspaceStateFromDraftSummary` prefers API `workspaceState` when present. |
| `lib/features/create/story_creator_add_tab_screen.dart` | Duration, step label, readiness from DTO + helpers. |
| `test/features/create/draft_list_summary_dto_test.dart` | **New.** JSON parse, legacy JSON, clamp, helpers. |
| `test/features/create/draft_summary_completion_test.dart` | **New.** Completion bounds. |

## Backend Fields Added

- `targetDurationBandKey: string | null` — from `StoryDraft.targetDurationBandKey`
- `moduleWorkflowStatuses: Record<string, string>` — merged with V1 defaults (`vocabulary_kanji`, `grammar`, `quiz`, `audio`)
- `learnModeEnabled: boolean`
- `completionPercent: number | null` — always set (0–100) from list mapping
- `workspaceState: "draft" | "editing"`
- `lastEditingStep: string | null` — first module in fixed order with status `in_progress`
- `processingStatus` — still **`null`**

## Derived Field Rules

| Field | Rule |
|-------|------|
| **learnModeEnabled** | `true` if any module value ≠ `not_started` |
| **completionPercent** | **35%** basics (5 slots: title, category, level, description, `targetDurationBandKey`) + **25%** sentences (full bucket at ≥5 `sentenceCount`) + **40%** modules (10 pts completed, 5 pts `in_progress` per module). Clamped **0–100**. |
| **workspaceState** | `"draft"` iff `publishState === draft`; else `"editing"` |
| **lastEditingStep** | First of `vocabulary_kanji`, `grammar`, `quiz`, `audio` with `in_progress`; else `null` |

## Flutter DTO Changes

- Mirrors backend keys; **defaults:** missing `moduleWorkflowStatuses` → merged defaults; missing `learnModeEnabled` → derived from map; missing `workspaceState` → `workspaceStateKeyFromPublishStateKey(publishState)`; missing `completionPercent` → `null` (UI falls back to sentence/Draft line).

## UI Changes

- **Profile Workspace:** duration chip uses `CreatorProcessingCopy.draftSummaryDurationChip(targetDurationBandKey)`; editing vs draft section uses optional `workspaceState` then legacy publish-state rule (defaults safe for old payloads).
- **Create Add tab:** same duration helper; step label from `draftSummaryLastEditingLabel(lastEditingStep)`; readiness from `draftSummaryReadinessLine(completionPercent, sentenceCount)`.

## Backward Compatibility

- Old JSON rows without new keys still parse; interim id-only path unchanged.
- Defaults do **not** treat published rows as “synced” or hide Editing — `workspaceState` falls back to publish-state-derived **`draft` vs `editing`**.

## Tests Added

- **Flutter:** `draft_list_summary_dto_test.dart`, `draft_summary_completion_test.dart`
- **Backend:** extended `story-drafts.service.spec.ts` (**8** tests total)

## Flutter Analyze Result

- `dart analyze` on touched DTO/helper files: **no issues found**.
- Full `flutter analyze`: no **`error`** severity; repo retains existing info/warnings elsewhere (not cleaned per scope).

## Flutter Test Result

- **`flutter test`:** all tests passed (suite total included **+84** at last run).

## Backend Test Result

- **`node node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts`:** **8 passed**

## Risks

- **completionPercent** is a rough UX estimate — not a substitute for full readiness checks.
- **lastEditingStep** ignores basics/sentences when no module is `in_progress` — often `null`.
- **Published-tab hide / true “synced”** still blocked until a future `hasUnpublishedCoreChanges` (out of scope).

## Recommended Next Step

- Persist and expose **`hasUnpublishedCoreChanges`** (or equivalent) on write paths, then allow **`workspaceState: synced`** and precise Published duplicate hiding — per `DRAFT_SUMMARY_METADATA_ENHANCEMENT_PLAN.md`.
