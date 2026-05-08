# Published Edit Update Button Runtime Fix Report

## Runtime Symptom

Editing a published story (sentences/basics flow) left the Creator progress drawer showing **Read Only Published** / **Full Learn Published**, a **disabled** publish button, and helper **“Published version is up to date.”** even when the user had unsaved edits or staged server dirty state—especially on the **Read Only** path.

## Debug Trace Findings

Instrumentation (`debugTraceCreatorDrawerPublish`, `[creator_draft] saved_ok`, `[remote_draft] PUT mapped`) confirmed:

- `StoryCreatorDraftState.dirty` could be **true** while `CreatorStoryV1.hasUnpublishedCoreChanges` from the **last** server snapshot was still **false** (not yet saved).
- `computeReadOnlyHasUnpublishedChanges` treated **`hasUnpublishedCoreChanges == false` as authoritative** and returned **false** before considering **`dirty`**, so “up to date” logic ran incorrectly.

## Root Cause

**Order of checks:** For Read Only, the helper returned false whenever the domain field `hasUnpublishedCoreChanges == false`, ignoring **local unsaved edits**. Full Learn already partially deferred to `dirty` in one branch; Read Only did not.

Secondary: helper copy always said workspace changes were saved even when edits were **only local** and not persisted.

## Fix Applied

1. **`computeReadOnlyHasUnpublishedChanges` / `computeFullLearnHasUnpublishedChanges`** (`creator_drawer_publish_labels.dart`): evaluate **`dirty` first** (then server flag, then signature drift when `null`).
2. **`creatorProgressDrawerPublishHelperText`**: new parameter **`hasLocalUnsavedEdits`** — when the publish row is enabled for an update, show **“Save changes, then update the published version.”** if still dirty; otherwise **“Changes are saved in Workspace. Update to publish them.”**
3. **`CreatorProgressDrawer`**: accepts **`creatorDraft`**, **`localDraftDirty`**, **`readOnlyPublishedCoreSig`**; expands **`didUpdateWidget`** so publish flags / dirty / draft linkage trigger refresh; runs **`debugTraceCreatorDrawerPublish`** each build (`kDebugMode` only).
4. **`persistLocalNow`** / remote **`saveDraft` PUT**: `kDebugMode` **`debugPrint`** of merged draft **`hasUnpublishedCoreChanges`** after save / PUT mapping.
5. **Sentences host**: passes **`ref.watch(storyCreatorDraftDataProvider)`** as **`creatorDraft`** so linkage fields match the notifier immediately after remote merge.

## Button State Rules

- **Unpublished changes** = `localDraftDirty` **or** `hasUnpublishedCoreChanges == true` **or** (when flag unknown) read-only **signature** differs from baseline.
- **Up to date** only when none of the above and server says clean (`hasUnpublishedCoreChanges == false`) after save.
- **Publish enabled** still requires **`isStoryReviewModeAllowed`** for the active mode (unchanged).

## Tests Added

- `computeReadOnlyHasUnpublishedChanges`: local dirty overrides server `false`; server `true` / clean cases.
- Helper: **`hasLocalUnsavedEdits: true`** → save-first line; **`false`** → workspace line.

## Flutter Analyze Result

Run on touched paths: **no compile errors** (project may still report existing infos/warnings unrelated to this fix).

## Flutter Test Result

- `flutter test test/features/create` — **pass**
- `flutter test` — **pass** (full suite)

## Manual Verification Steps

1. Open a **published** story in Creator; ensure drawer shows synced state.
2. Edit a sentence **without** waiting for autosave: drawer should show **Update Read Only** / **Update Full Learn** (when ready) and helper **save-first** if dirty.
3. Wait for autosave or tap Save: helper switches to **workspace + update**; **`[remote_draft] PUT mapped`** should show `hasUnpublishedCoreChanges=true` when backend stages.
4. Confirm **`[creator_drawer_publish]`** trace in debug console reflects `localDirty`, `hasUnpublishedCoreChanges`, `sigDirty`, `publishEnabled`, `reason`.

## Remaining Risks

- **Plaintext merge timing** on the sentences host: if UI text and provider draft diverge for a frame, signature vs draft could be briefly inconsistent; `dirty` still carries local intent.
- **Learn-only edits** with server never setting core dirty: still relies on **`dirty`** until save returns flags.
