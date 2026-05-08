# Published Mono Edit Button Fix Report

## Files Changed

- `lib/features/mono/mono_feed_models.dart` — optional `sourceDraftId` on `MonoFeedItem`.
- `lib/features/profile/data/published_mono_reader_mapper.dart` — maps `sourceDraftId` from published detail into feed items.
- `lib/features/mono/data/mono_feed_item_mapper.dart` — `monoFeedItemMergePublishedDetail` carries `sourceDraftId` from hydrated detail.
- `lib/features/profile/profile_screen.dart` — profile-published surfaces pass `sourceDraftId` into resume; removed unused import.
- `lib/features/create/creator_resume_draft.dart` — `tryResumeFromPublishedSurface` accepts `sourceDraftId`, tries ordered draft-id candidates (`publishedEditResumeDraftLookupIds`), shows failure snackbar, calls `resume` with resolved draft id; removed redundant `foundation` import.
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart` — threads `hostContextForActions` from `showMonoStoryOptionsPanel`; Edit closes panel then resumes using host context + `item.id` + `sourceDraftId`.
- `test/features/create/creator_resume_published_edit_lookup_test.dart` — unit tests for lookup ordering / dedupe.
- `test/features/mono/mono_feed_item_mapper_test.dart` — asserts merge copies `sourceDraftId`; existing merge test asserts null when detail has no source draft.

## Root Cause

1. **Wrong id for `loadDraft`:** Resume used only the feed/item id. On Profile, that id is often the **published mono** id (sometimes `profile-` prefixed), not the **story draft** id, so `loadDraft` returned null and Edit appeared to do nothing (or was gated behind placeholder copy).
2. **Overlay context:** Running navigation from the overlay’s inner `BuildContext` after `onClose` could leave an **unmounted** context, so the resume path exited early.

## Edit Button Behavior

- **Published Mono dock panel** (`showMonoStoryOptionsPanel` / `_MonoStoryOptionsContent`, non–`profileSaved` branch): **Delete** remains “Delete - Coming soon”. **Edit** closes the panel, then calls `CreatorDraftResumeFlow.tryResumeFromPublishedSurface(hostContextForActions, item.id, sourceDraftId: item.sourceDraftId)` so actions use a stable, mounted host context.
- **Failure:** If no candidate id loads a draft, a **SnackBar** shows: “Could not open this story for editing.”

## Navigation / Resume Flow

- `tryResumeFromPublishedSurface` builds candidates with `publishedEditResumeDraftLookupIds`: strip `profile-` prefix from the surface id, try that first, then `sourceDraftId` if distinct.
- First successful `storyDraftRepositoryProvider.loadDraft` wins; then `resume(..., resolvedDraftId, entryChannel: CreatorEntryChannel.publishedReopen)` restores draft state, resolves learn/sentences target, sets entry channel, and navigates via the existing GoRouter path.

## Refresh Behavior

- `CreatorDraftResumeFlow.resume` (used after a successful load) calls `bumpProfileCatalogSurfacesRefresh(container)` after navigation, matching other resume entry points (M5e-style catalog bumps). Further hide/refresh after save continues to follow existing publish/save signals elsewhere in the app.

## Tests Added

- `test/features/create/creator_resume_published_edit_lookup_test.dart` — lookup list: profile prefix strip + `sourceDraftId`, dedupe when equal, raw id only when no `sourceDraftId`.
- `test/features/mono/mono_feed_item_mapper_test.dart` — `monoFeedItemMergePublishedDetail copies sourceDraftId from detail`; first merge test extended to expect `sourceDraftId` null when DTO has none.

**Deferred:** Widget test for Edit tap → `tryResumeFromPublishedSurface` (would require pumping overlay + host + Riverpod scope); helper-level tests cover the critical id resolution contract.

## Flutter Analyze Result

Command: `flutter analyze` on the touched library paths.

- **Result:** Exit code 1 with **52 issues** reported for those paths. The remaining items are **pre-existing** in `profile_screen.dart` (unused private helpers/params, `withOpacity` deprecation) and deprecation infos in `mono_story_options_sheet.dart`. **No issues** on `creator_resume_draft.dart` alone after removing the duplicate import. **No new errors** introduced by this fix for the mono mapper / `mono_feed_models` / `published_mono_reader_mapper` files.

## Flutter Test Result

- `flutter test test/features/profile test/features/create test/features/mono/mono_feed_item_mapper_test.dart` — **All tests passed** (includes new lookup + mapper tests).
- `flutter test` (full suite) — **248 tests, all passed.**

## Manual Verification Steps

1. Sign in; enable remote drafts if applicable.
2. **Profile → Published** → open a published mono in the reader → open the **⋯** / options **dock panel** (“Published Mono” with Delete / Edit).
3. Tap **Edit** → panel closes → Creator opens on the **linked draft** (sentences/basics per learn resume rules).
4. With a story that has `sourceDraftId` from detail: confirm edit opens. With summary-only / missing linkage: confirm **SnackBar** “Could not open this story for editing.”
5. After saving from edit mode, confirm **Published** / Mono catalog refresh behavior matches existing M5e expectations (row hides when draft returns to non-published visibility).

## Remaining Risks

- **Mono Home feed rows** that never merge published detail may lack `sourceDraftId`; Edit will show the failure snackbar until detail hydration supplies it.
- **Offline / missing draft:** If the draft was deleted remotely or never synced, lookup still fails with the same user-visible message.
- **Analyze noise:** `profile_screen.dart` still carries historical lints unrelated to this change.
