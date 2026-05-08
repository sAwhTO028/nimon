# Published Edit Update Button Fix Report

## Files Changed

- `lib/features/create/story_v1_model.dart` — optional `publishedMonoId`, `hasUnpublishedCoreChanges` on `CreatorStoryV1` (remote draft parity).
- `lib/features/create/data/dto/story_draft_dto.dart` — `hasUnpublishedCoreChanges` on `StoryDraftDto`.
- `lib/features/create/data/story_draft_mapper.dart` — map new fields DTO ↔ domain.
- `lib/features/create/data/remote_story_draft_repository.dart` — parse `hasUnpublishedCoreChanges` from JSON.
- `lib/features/create/story_creator_draft_storage.dart` — optional round-trip of linkage/dirty fields in local JSON.
- `lib/features/create/data/dto/draft_list_summary_dto.dart` — `fromCreatorStoryV1` prefers domain `hasUnpublishedCoreChanges` when set.
- `lib/features/create/creator_drawer_publish_labels.dart` — **new** helpers for “dirty” detection and publish label/helper copy.
- `lib/features/create/creator_progress_drawer.dart` — uses extracted label/helper functions; Full Learn branch shows **Update Full Learn** vs **Full Learn Published**.
- `lib/features/create/story_creator_sentences_screen.dart`, `story_creator_vocab_kanji_editor_screen.dart`, `story_creator_grammar_editor_screen.dart` — pass unified flags into the drawer.
- `test/features/create/creator_drawer_publish_labels_test.dart` — unit tests for copy and staging detection.

## Root Cause

1. **Full Learn “unpublished” used only `StoryCreatorDraftState.dirty`.** After a successful save, `dirty` became `false` even when the server still had staged core changes (`hasUnpublishedCoreChanges`), so the drawer thought the story was **up to date** and showed **Full Learn Published** with the button disabled.

2. **Publish primary label for Learn mode never distinguished “first Full Learn publish” vs “already Full Learn published”.** When not “up to date”, the label was generic **Full Learn** instead of **Full Learn Publish** or **Update Full Learn**.

3. **Server `hasUnpublishedCoreChanges` was not retained on the in-memory draft**, so the UI could not reflect staging after PUT until local signature tricks aligned.

## Button Copy Rules

| Mode | Situation | Button label |
|------|-----------|----------------|
| Read Only | Not yet RO-published | **Read Only Publish** |
| Read Only | RO-published, staged changes | **Update Read Only** |
| Read Only | RO-published, no staged changes | **Read Only Published** (disabled) |
| Full Learn | RO exists, FL not yet published | **Full Learn Publish** |
| Full Learn | FL-published, staged changes | **Update Full Learn** |
| Full Learn | FL-published, no staged changes | **Full Learn Published** (disabled) |

Helper when disabled and synced: **Published version is up to date.**  
Helper when enabled on an update path: **Changes are saved in Workspace. Update to publish them.**

## Enabled / Disabled Rules

Unchanged from product rules: `_publishEnabled` still requires `isStoryReviewModeAllowed` for the active mode, and disables when the chosen mode is already **up to date** (`readOnlyPublishedExists && !readOnlyHasUnpublishedChanges` for RO, or full-learn analogue). **Full-learn “has changes”** now uses `computeFullLearnHasUnpublishedChanges`, which combines server `hasUnpublishedCoreChanges`, local read-only signature drift, and `dirty` for learn-layer edits.

## Publish Intent Behavior

**No change** to publish wiring: `performCreatorDrawerPublish` → `publishReadingOnlyToDisk` / `publishFullLearnToDisk` with the same reasons/intents as before. Normal save remains save-only.

## Tests Added

- `test/features/create/creator_drawer_publish_labels_test.dart` — labels (Publish vs Update vs Published), helper text, and `computeFullLearnHasUnpublishedChanges` with server `true` while `dirty` is false.

## Flutter Analyze Result

`flutter analyze` on touched paths: **no errors** (pre-existing infos/warnings in some create files, e.g. unused private widgets in grammar editor).

## Flutter Test Result

- `flutter test test/features/create` — **passed**
- `flutter test` (full suite) — **262 tests passed** (exit code 0)

## Manual Verification Steps

1. Remote drafts on; open a **Full Learn published** story for edit from Workspace.
2. Change a sentence; let autosave or tap **Save changes (workspace)**.
3. Open Creator progress: publish button should read **Update Full Learn**, be enabled if readiness is satisfied, helper mentions Workspace → Update.
4. With no edits, button shows **Full Learn Published**, disabled, helper **Published version is up to date.**
5. Repeat with Learn mode off for **Update Read Only** / **Read Only Published**.

## Remaining Risks

- **Learn-only edits** after save: if the API leaves `hasUnpublishedCoreChanges` false and `dirty` is cleared, the UI depends on the server eventually exposing a learn-layer dirty signal or the user making a further edit that sets `dirty` again (unchanged from prior limitation if the API only tracks core).
