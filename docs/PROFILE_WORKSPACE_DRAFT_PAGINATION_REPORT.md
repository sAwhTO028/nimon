# Profile Workspace Draft Pagination Report

**Date:** 2026-05-02  
**Scope:** Profile **Workspace / Processing** list uses paged `DraftListSummaryDto` via `ProfileWorkspaceDraftPager` — no N+1 `loadDraft` for row display.

---

## Files Changed

- `lib/features/profile/presentation/providers/profile_workspace_draft_pager.dart` — **new** Riverpod pager (`StateNotifierProvider`).
- `lib/features/profile/profile_screen.dart` — Workspace data source, `_ProcessingDraftItem` now built from `DraftListSummaryDto`, delete/rename/refresh wiring.
- `lib/features/create/creator_processing_copy.dart` — `secondaryLineSummaryOnly` for summary-only list rows.
- `test/features/profile/profile_workspace_draft_pager_test.dart` — **new** pager unit tests.

---

## Public API Added

- `profileWorkspaceDraftPagerProvider` — `StateNotifierProvider<ProfileWorkspaceDraftPager, PaginatedState<DraftListSummaryDto>>`.
- `ProfileWorkspaceDraftPager` — `loadFirstPage`, `refresh`, `loadMore`, `removeDraftById`, `removeDraftsByIds`.
- `CreatorProcessingCopy.secondaryLineSummaryOnly(StoryPublishState)` — list-row secondary line when full `CreatorStoryV1` is not loaded.

Top-level helpers in `profile_screen.dart` (`publishStateFromDraftSummaryKey`, `workspaceStateFromDraftSummary`) are file-local building blocks, not a separate public module.

---

## Workspace Loading Before

- `listDraftIds()` then **`loadDraft(id)` for every id** in `_loadLocalCreatorDraftIntoProcessing`.
- Local diff vs read-only published signature to classify **Editing** vs hiding published-clean rows.

---

## Workspace Loading After

- `StoryDraftRepository.fetchWorkspaceDraftPage(PageRequest)` with `PaginationDefaults.workspacePageLimit`.
- `PaginatedState<DraftListSummaryDto>`: first page, `loadMore` with cursor, `refresh` with stale-response guards (`requestEpoch`).
- **No `loadDraft`** for populating the Workspace list UI.

---

## Full Draft Loads Still Allowed For

- **Rename** (menu): `loadDraft` → mutate title → `saveDraft`.
- **`CreatorDraftResumeFlow.resumeFromProcessing`** (tap primary action / row).
- **Processing detail sheet** flows that already loaded draft content where needed.
- **`storyCreatorDraftProvider.syncIf…`** after mutations.

---

## ProfileScreen Changes

- Removed `_processingItems` state list and `_loadLocalCreatorDraftIntoProcessing`.
- `initState` / `profileProcessingListRefreshProvider` / Workspace tab focus → `ProfileWorkspaceDraftPager` `loadFirstPage` / `refresh`.
- Published-tab “hide mock row when Editing” still uses Workspace pager summaries (`workspaceStateFromDraftSummary`).
- **`duration`** chip: **`—`** (summary has no `targetDurationBandKey`; documented limitation).
- **`sentenceCount`** shown as a chip when `> 0`.
- Row subtitle prefers **`previewText`** (via `_ProcessingDraftItem.preview`).
- Scroll **~72%** of extent triggers `loadMore`; footer spinner when `isLoadingMore`.
- Initial empty → **progress** indicator while `isInitialLoading`.
- **Delete** from row menu: `deleteDraft` + **`removeDraftById`** (no full-list reload).

---

## Classification Caveat (Editing vs hidden published-clean)

Previously, published drafts **without** core diff were **hidden** from Workspace. Summary rows **cannot** reproduce local signature diff without backend metadata or `loadDraft`.

**Current rule:** `publishState == draft` → **Drafts** section; any **published** summary row → **Editing** section. Published-but-synced stories **may** appear under Editing until the API exposes a flag (see risks).

---

## Tests Added

- `profile_workspace_draft_pager_test.dart`: `loadFirstPage`, `loadMore` append, `loadMore` no-op when `hasMore == false`, `refresh`, stale `loadMore` after `refresh`, `removeDraftById` / `removeDraftsByIds`.

**Widget test:** Not added — Workspace UI is tightly coupled to `ProfileScreen` and navigation; provider/unit coverage chosen instead.

---

## Flutter Analyze Result

- **No analyzer diagnostics with severity `error`** on the touched surfaces (`dart analyze` / project-wide spot-check).

---

## Flutter Test Result

- **`flutter test`:** all tests passed (**72** at last run, including **6** new pager tests).

---

## Risks

- **Editing vs published-clean:** summary-only classification can **over-include** rows in **Editing** (see above).
- **Duration chip** always **`—`** until summary carries duration metadata.
- **`secondaryLineSummaryOnly`** omits `computeFullLearnReady` nuance for Read Only rows until full draft loads on resume.
- **Scroll `NotificationListener`** may fire `loadMore` repeatedly near the end; mitigated by **`PaginatedState.canLoadMore`** and busy flags.

---

## Recommended Next Step

- Extend backend summary with **`targetDurationBandKey`** / **`workspaceState`** (or `hasUnpublishedCoreChanges`) to restore precise Editing visibility and duration chips without full-document reads.
