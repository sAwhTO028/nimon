# Published Edit Staging Lifecycle Fix Report

## Root Cause

1. **Flutter — accidental publish on every save:** `RemoteStoryDraftRepository.saveDraft` inspected **`persisted.publishState`** after PUT and, when it was `reading_only_published` or `full_learn_published`, automatically chained **`POST …/publish/read-only`** and **`POST …/publish/full-learn`**. Editing a published story keeps that publish state in memory, so **routine autosave/save ran publish endpoints** and updated **`PublishedMono`** as if the user had pressed **Update / Republish**.

2. **Flutter — PUT payload forced `publishState: draft`:** Every save tried to demote the draft in JSON while local state stayed published, conflicting with staging semantics.

3. **Backend — linked staging PUT:** `updateDraft` accepted **`publishState: draft`** from the client and could **demote** a linked published draft on PUT. **`hasUnpublishedCoreChanges`** used `becomesPublishedRelated`, which did not reliably mean “dirty while linked”.

## Expected Lifecycle

| Action | StoryDraft tables | `publishState` (linked) | `hasUnpublishedCoreChanges` | PublishedMono |
|--------|-------------------|---------------------------|-----------------------------|---------------|
| Edit / autosave / Save draft | Updated via PUT | **Preserved** (`reading_only_*` / `full_learn_*`) | **true** | **No write** |
| Drawer **Update Read Only** / first RO publish | Via publish endpoint | Set by service | **false** after publish | **Core** updated |
| Drawer **Full Learn** publish | Via publish endpoint | Set by service | **false** after publish | **Learn** (+ merge) updated |

## Backend Changes

**File:** `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` — `updateDraft`

- Load **`publishedMonoId`** with `version` / `publishState`.
- **`hasLinkedMono`:** If `publishedMonoId` is set:
  - **`publishState`** on the row stays **`current.publishState`** (ignore client attempt to set `draft` on PUT).
  - **`hasUnpublishedCoreChanges`** is set **`true`** (staging edit).
- If not linked: previous **`body.publishState`** and **`becomesPublishedRelated`** logic for dirty flag.

**PublishedMono** was already untouched by `updateDraft`; only **`publishReadOnly`** / **`publishFullLearn`** mutate it.

## Flutter Changes

- **`StoryDraftRemotePublishIntent`** (`none` | `readOnly` | `fullLearn`) on **`StoryDraftRepository.saveDraft`** (optional, default **`none`**).
- **`RemoteStoryDraftRepository.saveDraft`:**  
  - PUT-only unless intent is **`readOnly`** or **`fullLearn`**.  
  - Removed forced **`publishState: draft`** in PUT JSON — payload uses **`StoryDraftMapper.fromDomainRemoteSafe`** as-is.
- **`StoryCreatorDraftNotifier.persistLocalNow`:** passes **`readOnly`** / **`fullLearn`** only when **`reason`** is **`publish_reading_only`** / **`publish_full_learn`** (same paths as **`publishReadingOnlyToDisk`** / **`publishFullLearnToDisk`**).
- **`CreatorProgressDrawer`:** outline button label **`Save changes (workspace)`** when a published row exists **and** there are unpublished changes; otherwise **`Save draft`**.
- **Tests:** `remote_story_draft_full_learn_publish_sequence_test.dart` passes explicit **`remotePublishAfterPut: fullLearn`** where the chain is intended; new **`remote_story_draft_save_staging_test.dart`** asserts **GET + PUT only** for **`reading_only_published`** + **`none`**.

## Dirty Flag / Visibility Behavior

After a linked PUT, **`hasUnpublishedCoreChanges`** is **true** on the server. Existing **M5d / M5e** rules (mono feed + profile published hiding while dirty, workspace **Editing**) apply once list/detail responses carry that flag.

## Publish / Update Behavior

Unchanged endpoints: **`POST /v1/story-drafts/:id/publish/read-only`**, **`POST …/publish/full-learn`**.  
They remain the **only** paths that write **`PublishedMono.content`** and clear **`hasUnpublishedCoreChanges`**.

## Tests Added

| Suite | What |
|-------|------|
| **Backend** `story-drafts.service.spec.ts` | `updateDraft` linked mono preserves **`reading_only_published`**, **`hasUnpublishedCoreChanges: true`**; unlinked draft follows body **`draft`**. |
| **Flutter** `remote_story_draft_save_staging_test.dart` | Published draft + **`intent none`** → no publish POSTs. |
| **Flutter** `remote_story_draft_full_learn_publish_sequence_test.dart` | Explicit **`fullLearn`** intent for publish-chain tests. |

## Backend Test Result

- `jest src/modules/story-drafts/story-drafts.service.spec.ts` — **15 passed** (includes new `updateDraft` cases).
- `jest src/modules/mono-feed` — **11 passed**.
- `jest src/modules/published-monos` — **3 passed**.

## Backend Build Result

- `nest build` — **success** (exit code 0).

## Flutter Analyze Result

- `flutter analyze` on touched create paths — **no issues**.

## Flutter Test Result

- `flutter test test/features/create` — **passed**.
- `flutter test test/features/profile` — **passed**.
- `flutter test` (full suite) — **252 passed**.

## Manual Verification Steps

1. Enable remote drafts; open a **published** story in Creator (linked mono).
2. Change a sentence; wait for autosave or tap **Save changes (workspace)**.
3. Confirm **no** new public content: hit **public** mono reader / another client — text unchanged.
4. Confirm **Profile Published** / **Mono Home** hide the card while dirty (per M5 rules).
5. Tap **Update Read Only** (or Full Learn) from review/drawer — public content updates and row reappears.

## Remaining Risks

- **Local-only mode** (`NIMON_USE_REMOTE_DRAFTS=false`): staging semantics are local; no server dirty flag.
- **First-time publish** still relies on **`publish_reading_only`** / **`publish_full_learn`** reasons to chain POSTs after PUT — ensure no code path sets those reasons during ordinary edit.
