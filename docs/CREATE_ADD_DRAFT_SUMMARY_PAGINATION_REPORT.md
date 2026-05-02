# Create Add Draft Summary Pagination Report

## Files Changed

| Path | Role |
|------|------|
| `lib/features/create/presentation/providers/story_creator_add_tab_draft_summary_provider.dart` | **New.** AutoDispose notifier + `storyCreatorAddTabDraftSummaryProvider`; loads one summary page via `fetchWorkspaceDraftPage`. |
| `lib/features/create/story_creator_add_tab_screen.dart` | **Migrated.** Uses summary provider for Continue working + Drafts in progress; listens to `profileProcessingListRefreshProvider` for targeted refresh. |
| `test/features/create/story_creator_add_tab_draft_summary_provider_test.dart` | **New.** Provider tests with spy repo (no `loadDraft`). |

## Loading Before

The Add tab built a local snapshot by calling **`listDraftIds()`** and then **`loadDraft(draftId)` for each id** to populate featured and row cards with full `CreatorStoryV1` data.

## Loading After

A single **`StoryDraftRepository.fetchWorkspaceDraftPage(PageRequest)`** call per load/refresh:

- **`limit`**: `kStoryCreatorAddTabDraftSummaryLimit` (4) — first item → Continue working; next up to **3** → Drafts in progress.
- **`sort`**: `'latest'`.
- **`publishState`**: `StoryPublishState.draft.storageKey` (draft-only workspace list).

No enumeration of all draft ids for this UI.

## Full Draft Loads Still Allowed For

- **`CreatorDraftResumeFlow.resume(...)`** when the user taps Continue or a row — existing resume/editor path; **`loadDraft`** remains appropriate **inside** that flow, not for painting the list.

## Create Add Tab Changes

- **`_DraftListItemModel.fromSummary(DraftListSummaryDto)`** maps list UI from DTOs only.
- **Placeholders** (fields missing on summary vs full draft):
  - **`duration`**: `—` (not provided by summary).
  - **`stepLabel`**: empty string — featured card copy falls back where it previously used step-derived text.
  - **`readinessSummary`**: sentence count string or `'Draft'`.
- **Refresh**: `ref.listen(profileProcessingListRefreshProvider, ...)` calls `storyCreatorAddTabDraftSummaryProvider.notifier.refresh()` when the shared refresh counter bumps (e.g. after save — same signal Profile Workspace already uses). No `ref.invalidate` of unrelated providers.

## Tests Added

**`test/features/create/story_creator_add_tab_draft_summary_provider_test.dart`**

- Asserts **`publishState=draft`** and **`limit=4`** on the `PageRequest` passed to `fetchWorkspaceDraftPage`.
- Asserts ordering: first item Continue working, four ids preserved for featured + up to three in-progress rows.
- **`_SpyDraftRepo`** throws on **`loadDraft`**, **`listDraftIds`**, and other repository methods — notifier tests prove list rendering path does not call them.

Widget/tap tests were not added to keep scope small; resume still uses **`draftId`** + existing **`CreatorDraftResumeFlow`** unchanged.

## Flutter Analyze Result

`flutter analyze` reported **no analyzer `error` severity** issues. The project still has existing **info** and **warning** findings elsewhere (not cleaned per task scope).

## Flutter Test Result

`flutter test`: **All tests passed** (full suite).

## Risks

- **Summary vs full draft**: Duration and step labels are placeholders; UX may feel slightly less rich until summary API grows fields.
- **Stale list**: If draft save does not bump `profileProcessingListRefreshProvider`, Add tab may not refresh until next navigation or manual retry — same coupling as Profile refresh signal.
- **Remote failures**: Empty state + Retry on initial fetch error; refresh errors keep prior items (provider preserves `items`).

## Recommended Next Step

Optional: extend **`DraftListSummaryDto`** / backend summary when product needs **duration** or **last step** on the list without loading full drafts; add a small widget test that taps a row and verifies **`CreatorDraftResumeFlow.resume`** is invoked with the summary **`draftId`** if resume becomes mockable in tests.
