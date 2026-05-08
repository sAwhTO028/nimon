# Published Edit Baseline Diff Button Fix Report

## Root Cause

Published-edit readiness relied too heavily on `StoryCreatorDraftState.dirty`, `draft.hasUnpublishedCoreChanges`, and the legacy thin read-only signature (`computeReadOnlyPublishedCoreSignature`). Those signals often lag behind in-memory edits (before autosave completes) or miss learn-layer-only changes relative to Full Learn publish. Users could change basics, sentences, or learn modules while the drawer still showed “up to date” with the primary action disabled.

## Product Rule

When editing a story that is already linked to a published mono:

- Compare **current in-memory draft** to a **persisted published baseline** (v2 read-only baseline + optional v1 full-learn baseline).
- If the relevant signature differs → treat as having unpublished changes and enable the matching **Update Read Only** / **Update Full Learn** action immediately (still subject to readiness rules).
- Do **not** require the server staging flag alone for immediate enable.
- Refresh baselines only after a **successful** Read Only or Full Learn update (not on ordinary save).

## Baseline / Current Draft Comparison

- **Helpers:** `lib/features/create/creator_published_edit_baseline.dart`
  - `computeReadOnlyEditBaselineSignature` — stable JSON over basics (title, category, level, description, promptSourceNote, target duration band, cover URL) + ordered sentence payloads (text, reading, sorted furigana spans, meanings map).
  - `computeFullLearnEditBaselineSignature` — read-only payload plus vocabulary, grammar, quiz (sorted by id), and story audio fields that matter for sync (excludes noisy local paths).
- **Storage:** `SharedPreferences` keys `nimon_pub_edit_ro_baseline_v2_<draftId>` and `nimon_pub_edit_fl_baseline_v1_<draftId>` via `load/save/clearPublishedEdit*Baseline`.
- **Notifier state:** `StoryCreatorDraftState.publishedEditReadOnlyBaselineSig` and `publishedEditFullLearnBaselineSig` in `story_creator_provider.dart`.
- **Hydration:** `_hydratePublishedEditBaselines` runs after draft load; when the draft is linked to a published story and `hasUnpublishedCoreChanges != true`, missing baselines are **seeded** from the current draft and persisted (first open / clean sync).
- **After successful publish:** `_persistPublishedEditBaselinesAfterSuccessfulPublish` recomputes and saves read-only baseline; saves or clears full-learn baseline according to `publishState`.

## Read Only Dirty Detection

`computeReadOnlyHasUnpublishedChangesWithBaseline` (via `computeReadOnlyHasUnpublishedChanges` in `creator_drawer_publish_labels.dart`) uses this order:

1. **v2 baseline diff** — `computeReadOnlyEditBaselineSignature(draft)` vs `publishedEditReadOnlyBaselineSig`
2. **Local dirty** — `draftState.dirty`
3. **Server** — `draft.hasUnpublishedCoreChanges == true`
4. **Legacy thin signature** — `computeReadOnlyPublishedCoreSignature(draft)` vs stored `readOnlyPublishedCoreSig` (fallback when baseline absent / migration)

## Full Learn Dirty Detection

`computeFullLearnHasUnpublishedChangesWithBaseline`:

1. **Full-learn baseline diff** — `computeFullLearnEditBaselineSignature(draft)` vs `publishedEditFullLearnBaselineSig`
2. Otherwise delegates to **read-only unpublished** detection above (core changes imply Full Learn must update).

Learn mode toggle only changes which publish mode the drawer submits; baseline diff still drives dirty flags regardless.

## Button State Rules

Primary label helpers (`creatorProgressDrawerPublish_labels.dart`): **Update Read Only** / **Update Full Learn** / **\* Published** / **\* Publish** as before, driven by existence + dirty booleans computed with baselines.

`CreatorProgressDrawer` enables the primary button when not “up to date” for the active mode **and** `isStoryReviewModeAllowed` for readiness.

Helper copy (`creatorProgressDrawerPublishHelperText`): unchanged semantics — unsaved local edits → save-first hint; staged/saved dirty → workspace update hint; fully synced → published up to date.

**Debug trace (debug builds only):** `debugTraceCreatorDrawerPublish` logs baseline/current signature previews, `roDiff`, `flDiff`, `thinLegacyDiff`, dirty flags, and final enabled state.

**Surfaces:** Baselines feed the drawer on story sentences (embedded host), vocabulary, grammar, quiz, and listening/audio editors (`CreatorProgressDrawer` + menu affordance on quiz/audio).

## Tests Added / Updated

- `test/features/create/creator_published_edit_baseline_test.dart` — signature stability and dirty detection for basics, sentences, furigana, meanings, vocab, grammar, quiz, listening; server-false vs baseline-diff; synced full-learn case.
- `test/features/create/creator_drawer_publish_labels_test.dart` — public API baseline integration plus existing primary-label and helper-text tests (adjusted legacy-sig fixtures where the thin signature would spuriously mark drafts dirty).

## Flutter Analyze Result

```text
flutter analyze lib/features/create/creator_published_edit_baseline.dart \
  lib/features/create/creator_progress_drawer.dart \
  lib/features/create/story_creator_quiz_editor_screen.dart \
  lib/features/create/story_creator_audio_editor_screen.dart \
  test/features/create/creator_drawer_publish_labels_test.dart \
  test/features/create/creator_published_edit_baseline_test.dart
# No issues found!
```

## Flutter Test Result

```text
flutter test test/features/create
flutter test
# All tests passed! (281 tests)
```

## Manual Verification Steps

1. Open a **Full Learn published** story from workspace; confirm progress drawer menu opens on sentences and each learn route (vocab, grammar, quiz, listening).
2. Without saving, change **title** on basics (or any sentence text on sentences); open drawer — expect **Update Read Only** or **Update Full Learn** enabled as soon as readiness allows, with debug log showing `roDiff=true` when appropriate.
3. Revert text to match published content (or complete an update) — expect **\* Published** disabled and helper “up to date” when clean.
4. With learn mode on, change **quiz** or **audio** only — expect **Update Full Learn** with `flDiff=true` in logs without needing `hasUnpublishedCoreChanges` from the server first.
5. After a successful update, confirm baselines realign (button returns to disabled until a new edit).

## Remaining Risks

- **Staged workspace reopen:** If `hasUnpublishedCoreChanges == true` and no baselines exist yet in prefs, the client cannot reconstruct the true last-published snapshot without an extra fetch; behavior falls back to dirty/server/legacy thin sig until baselines are seeded or the user publishes again.
- **Story basics-only screen** still uses a progress bottom sheet without the full publish drawer; publish UX is reached from routes that host `CreatorProgressDrawer`. In-memory draft updates still flow through the provider, so opening the drawer from sentences/learn surfaces remains consistent.
- **Legacy thin signature** intentionally omits some basics fields (e.g. cover); v2 baseline is authoritative when present.
