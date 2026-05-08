# Published Sentence Reorder Publish Fix Report

## Root Cause

**Full Learn publish** updated `PublishedMono.content.learn` from the draft but **did not refresh `PublishedMono.content.core`**. The reader and mono feed build Storytelling text from `content.core.sentences` (see `published_mono_detail_parser.dart`), so after **Update Full Learn** the learn layers changed while the published story body stayed on the previous core snapshot.

**Read-only publish** already rebuilt `content.core` from `draft_sentences` ordered by `DraftSentence.order`. The primary product bug was the Full Learn path omitting that core refresh. Separately, Flutter and `updateDraft` already persist `orderIndex` into the `order` column when present.

## Sentence Lifecycle Trace

| Step | Behavior |
|------|-----------|
| A. Flutter editor | `StorySentenceItem.orderIndex` updated on reorder; `StoryDraftMapper` / `storySentenceDtoToWireJson` send `orderIndex`, text, `furiganaSpans`, `meanings`, etc. |
| B. `PUT /v1/story-drafts/:id` | `RemoteStoryDraftRepository` sends `sentences` array with full wire objects. |
| C. `updateDraft` | `draftSentence.deleteMany` then `createMany` with `order` = each row’s `orderIndex` when numeric, else array index. |
| D. `publishReadOnly` | Loads draft with `sentences`, sorts by `order`, writes `content.core.sentences` as `{ order, content }`; merges prior JSON (e.g. `learn`). |
| E. `publishFullLearn` (fixed) | Same **core** payload as read-only plus **learn** snapshot; updates `PublishedMono` title/category/level/description scalars like read-only. |

## Flutter Wire Fix

No schema change required: `remote_story_draft_sentence_wire.dart` already emits `orderIndex`, `furiganaSpans`, and `meanings`. Tests assert stable PUT keys and that `StoryDraftMapper.fromDomainRemoteSafe` preserves per-row `orderIndex` in list iteration order (backend respects `orderIndex`, not JSON array order).

## Backend Draft Persistence Fix

Confirmed: `updateDraft` replaces all `draft_sentence` rows and sets `DraftSentence.order` from `sentence.orderIndex` when it is a number. Added unit coverage that a reorder-only payload persists orders `[2,0,1]`.

## Read Only Publish Fix

Refactored to `buildPublishedCorePayloadFromDraft` for a single definition of core shape (basics mirrors + sorted sentences). Added test that sentences with DB orders `(2,0,1)` appear in core as `(0,1,2)` with `furiganaSpans` / `meanings` preserved inside `content`.

## Full Learn Publish Fix

After reloading the draft post-version-bump, `publishFullLearn` now:

- Sets **`content.core`** from `buildPublishedCorePayloadFromDraft(reloaded)`.
- Sets **`content.learn`** via `buildLearnSnapshotFromDraft(reloaded)` (unchanged).
- Updates **PublishedMono** row **title**, **category**, **level**, **description** to match the draft (parity with read-only publish).

Choice **A**: full learn **always** refreshes core from the current draft (aligned with “full story” snapshot).

## Tests Added

- **Backend** (`story-drafts.service.spec.ts`): `publishFullLearn` core sentence order + furigana; scalar fields on `publishedMono.update`; `publishReadOnly` sorted core with meanings/furigana; `updateDraft` reorder `createMany` orders.
- **Flutter** (`remote_story_draft_sentence_wire_test.dart`): wire keys; mapper `orderIndex` preservation for PUT list order.

## Backend Test Result

```text
cd nimon-backend
node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts --no-cache
# Test Suites: 1 passed — Tests: 17 passed

node ./node_modules/jest/bin/jest.js src/modules/mono-feed --no-cache
# Test Suites: 1 passed — Tests: 11 passed
```

## Backend Build Result

```text
cd nimon-backend
node ./node_modules/@nestjs/cli/bin/nest.js build
# Exit code 0 (success)
```

## Flutter Analyze Result

```text
flutter analyze test/features/create/remote_story_draft_sentence_wire_test.dart
# No issues found!
```

## Flutter Test Result

```text
flutter test test/features/create
# All tests passed

flutter test
# All tests passed! (283 tests)
```

## Manual Verification Steps

1. Publish a story (Read Only or Full Learn), open as published edit, change sentence **text** and **Update Full Learn** — reader body should match.
2. **Reorder** sentences (unchanged text), save, **Update Full Learn** — reader order should match creator.
3. Edit **furigana** / **meaning**, publish — reader shows updated ruby / explanation.
4. Repeat with **Update Read Only** only — core should still refresh.

## Remaining Risks

- If the client ever omits `orderIndex` on sentences, the backend falls back to **array index** as `order`; keep the app sending explicit indices after reorder.
- Very old `PublishedMono` rows with missing `core` still depend on a successful publish to backfill core.
