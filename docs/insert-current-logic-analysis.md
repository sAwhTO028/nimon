# Insert Current Logic Analysis

This document describes **only what exists in the codebase today** (Flutter / Dart app `nimon`). It focuses on the **Story Creator V1** pipeline: in-memory aggregate `CreatorStoryV1`, Riverpod `StoryCreatorDraftNotifier`, and **local** persistence via `SharedPreferences` JSON. There is **no** separate server/API “insert” for creator drafts in the paths inspected (`lib/data`, `lib/features/create`).

---

## 1. Executive Summary

- **Single source of truth for creator story data:** `CreatorStoryV1` in `lib/features/create/story_v1_model.dart`, held in **`storyCreatorDraftProvider`** (`StateNotifierProvider<StoryCreatorDraftNotifier, CreatorStoryV1>`) in `lib/features/create/story_creator_provider.dart`.
- **Persistence:** One on-device draft blob under keys `nimon_creator_current_draft_v1` and `nimon_creator_current_draft_v1_saved_at`, implemented in `lib/features/create/story_creator_draft_storage.dart` as JSON `jsonEncode` / `jsonDecode`. Not a SQL/NoSQL database.
- **“Insert” in practice:** Mutations are **in-memory state updates** on `CreatorStoryV1` via `StoryCreatorDraftNotifier` methods (`applyBasics`, `applySentences`, `addVocabKanjiEntry`, etc.), optionally followed by **`saveDraftToDisk()`** which writes the full aggregate to `SharedPreferences`.
- **Publish:** `StoryPublishState` transitions (`draft` → `readingOnlyPublished` / `fullLearnPublished`) are **local only**; UI copy explicitly states demo behavior (e.g. *“not sent to server”* for Full Learn on `StoryCreatorReviewScreen`). No `StoryRepo` / HTTP wiring for creator publish was found under `lib/features/create` or `lib/data` for this model.
- **Parallel “Create” path:** `CreateScreen` (`lib/features/create/create_screen.dart`) is the **One Short** prompt-driven UI; it does **not** import or write `CreatorStoryV1` / `storyCreatorDraftProvider`. It is a separate product surface unless manually integrated elsewhere (not observed in create folder).

---

## 2. Insert Flow Map

1. **Entry:** User opens **Story Creator hub** at route `/create/story` → `StoryCreatorHubScreen` (`story_creator_hub_screen.dart`). From **Create** tab, `CreateScreen` can `context.push('/create/story')` (`create_screen.dart`).
2. **Hydration:** `StoryCreatorDraftNotifier` constructor calls `_loadFromDiskIfAny()` → `StoryCreatorDraftStorage.load()`; if JSON exists, `state` becomes loaded `CreatorStoryV1`, else `CreatorStoryV1.empty()`.
3. **Step 1 — Basics:** `/create/story/basics` → `StoryCreatorBasicsScreen`. Local controllers seeded from `ref.read(storyCreatorDraftProvider)`. **Continue:** `_validateRequired()` (UI) → `_persistToDraft()` → `applyBasics(...)` → `context.push('/create/story/sentences')`. **Save draft:** `_persistToDraft()` + `saveDraftToDisk()`.
4. **Step 2 — Sentences:** `/create/story/sentences` → `StoryCreatorSentencesScreen`. Body text debounced (~400ms) to `applySentences(_body.text)` which runs `storySentencesFromPlaintextMerge` and `syncModuleWorkflowWithContent`. Per-sentence EN/MY/reading via dialog → `updateSentenceSupport`. Explicit **Save draft** calls `saveDraftToDisk()`. **Continue to review** validates at least one valid sentence line then navigates to `/create/story/review`.
5. **Step 3 — Review / publish ladder:** `/create/story/review` → `StoryCreatorReviewScreen`. Actions:
   - **Save as Draft:** `markDraft()` + `saveDraftToDisk()`.
   - **Publish Reading Only:** `publishReadingOnlyChecked()` (guards on `canPublishReadingOnly`) + `saveDraftToDisk()` + SnackBar.
   - **Publish Full Learn:** `publishFullLearnChecked()` (guards on `canPublishFullLearn`) + SnackBar; **note:** this path does **not** call `saveDraftToDisk()` in the current snippet (see §7).
6. **Learn hub (optional):** `/create/story/learn` → `StoryCreatorLearnHubScreen`. Manual **workflow status** cycling via `setModuleStatus`. Editors under `learn/vocabulary`, `grammar`, `quiz`, `audio` call notifier add/update/delete + `syncModuleWorkflowWithContent` and **Save draft** → `saveDraftToDisk()`.
7. **No backend flush:** After publish, state remains in memory + optionally disk; no second-phase “upload story” implementation was found for `CreatorStoryV1` in the analyzed paths.

---

## 3. File and Module Inventory

| File | Role |
|------|------|
| `lib/features/create/story_v1_model.dart` | Domain model: `CreatorStoryV1`, `StoryBasics`, `StorySentenceItem`, learn layers, `LocalizedMeanings`, enums `StoryPublishState`, `LearnModuleId`, `LearnModuleTaskStatus`, `ContentProvenance`, plaintext merge + `syncModuleWorkflowWithContent`. |
| `lib/features/create/story_creator_models.dart` | Barrel export: `export 'story_v1_model.dart';` |
| `lib/features/create/story_creator_provider.dart` | `StoryCreatorDraftNotifier`: load/save/reset, all mutations, publish transitions, `setModuleStatus`. |
| `lib/features/create/story_creator_draft_storage.dart` | `SharedPreferences` JSON serialization / deserialization (tolerant `fromJson`). |
| `lib/features/create/creator_publish_validation.dart` | Extension `CreatorStoryV1PublishValidation`: `missingForReadingOnly`, `missingForFullLearn`, `blockedReason*`, `incompleteLearnModulesV1`. |
| `lib/features/create/creator_progress_logic.dart` | Extension `CreatorStoryV1Progress`: `basicsProgressStatus`, `sentencesProgressStatus`, `learnModuleProgressStatus`, hints, `learnModuleWorkflowAheadOfData`. |
| `lib/features/create/story_creator_hub_screen.dart` | Hub UI, “Start new story” (discard + reset + push basics), “Continue current story” (`_continuePath`). |
| `lib/features/create/story_creator_basics_screen.dart` | Basics form + UI validation + `applyBasics` / `saveDraftToDisk`. |
| `lib/features/create/story_creator_sentences_screen.dart` | Plaintext editor, debounced `applySentences`, support dialog, `saveDraftToDisk`. |
| `lib/features/create/story_creator_review_screen.dart` | Summaries, checklist, publish ladder, navigation to learn. |
| `lib/features/create/story_creator_learn_hub_screen.dart` | Module cards, `setModuleStatus` cycle, routes to editors. |
| `lib/features/create/story_creator_vocab_kanji_editor_screen.dart` | Vocab/Kanji CRUD → notifier. |
| `lib/features/create/story_creator_grammar_editor_screen.dart` | Grammar CRUD → notifier. |
| `lib/features/create/story_creator_quiz_editor_screen.dart` | Quiz MCQ CRUD → notifier. |
| `lib/features/create/story_creator_audio_editor_screen.dart` | Story-level audio URL asset → notifier. |
| `lib/features/create/story_creator_progress_checklist.dart` | UI checklist bound to `CreatorStoryV1` + progress extension. |
| `lib/main.dart` | GoRouter routes under `/create/story/...`. |
| `lib/features/create/create_screen.dart` | Separate **One Short** create UX; **not** wired to `CreatorStoryV1`. |

**Not found (for creator V1):** Dedicated REST client, repository insert for `CreatorStoryV1`, Firestore/SQLite adapters, or transactional multi-table writes for this draft model.

---

## 4. Current Data Model

### Aggregate: `CreatorStoryV1`

- **`StoryBasics basics`:** `storyId`, `title`, `category`, `level`, `description`, `promptSourceNote`, `coverImageUrl?`, `creatorOwnerId`, `createdAt`, `updatedAt`.
- **`List<StorySentenceItem> sentences`:** Per-sentence `id`, `storyId`, `orderIndex`, `japaneseText` (required for `isValidV1`), optional `reading`, `meanings` (`LocalizedMeanings?`), optional `audioStartMs` / `audioEndMs`, optional `provenance`.
- **`VocabularyKanjiLayer vocabularyKanji`:** `entries: List<VocabularyKanjiEntry>`.
- **`GrammarLayer grammar`:** `entries: List<GrammarEntry>`.
- **`QuizLayer quiz`:** `entries: List<QuizEntry>` (exactly 4 options when valid).
- **`AudioLayer audio`:** Optional single `StoryAudioAsset? storyAudio`.
- **`StoryPublishState publishState`:** `draft` \| `readingOnlyPublished` \| `fullLearnPublished` (storage keys in `StoryPublishStateStorage`).
- **`Map<LearnModuleId, LearnModuleTaskStatus> moduleWorkflowStatuses`:** Creator-toggled / auto-promoted statuses.

**Identity:** `CreatorStoryV1.id` is an alias for `basics.storyId` (UUID from `CreatorStoryV1.empty()`).

### `LocalizedMeanings`

- Fields: `en?`, `my?`, `byLanguage` map for extra locales.
- `asMap` merges into a string map for JSON.
- `layerFromEnMy(enRaw, myRaw, preserveExtrasFrom:)` used by editors to merge dialog input with existing `byLanguage` keys.

### JSON top-level keys (`StoryCreatorDraftStorage._toJson`)

`basics`, `sentences`, `vocabularyKanji`, `grammar`, `quiz`, `audio`, `publishState`, `moduleWorkflowStatuses` — **no** separate top-level `id` (story id lives in `basics.storyId`).

---

## 5. Module-by-Module Insert Logic

### 5.1 Story basic info

- **Notifier:** `applyBasics(...)` updates `StoryBasics` via `copyWith`, trims cover URL to null if empty, sets `updatedAt`.
- **UI gate for navigation:** `_validateRequired()` on `StoryCreatorBasicsScreen` requires non-empty title, category, level, description before **Continue** (not enforced for **Save draft** alone before persist — user can save partial if `_persistToDraft` still sends empty strings for unset dropdowns as `''`).
- **Completion (data model):** `isBasicsComplete` = all of `title`, `category`, `level`, `description` trimmed non-empty.

### 5.2 Sentences

- **Input:** Plain multiline text → `applySentences(plain)` → `storySentencesFromPlaintextMerge(storyId, plain, previous: state.sentences)`.
- **Merge rule:** Non-empty lines become sentences; if a line’s `japaneseText` matches a previous row, that row’s `id` and optional `reading` / `meanings` are preserved with updated `orderIndex`.
- **Support fields:** `updateSentenceSupport(sentenceId, readingRaw, meanings)` with explicit clear flags when empty/null.
- **Validity:** `StorySentenceItem.isValidV1` ⇔ `japaneseText.trim().isNotEmpty`.

### 5.3 Sentence translations (support meanings)

- Stored in `StorySentenceItem.meanings` as `LocalizedMeanings` (EN/MY + map).
- **UI:** Dialog on sentences screen collects EN/MY; builds meanings via `LocalizedMeanings.layerFromEnMy`.
- **Required for publish:** **No** — not part of `missingForReadingOnly` / `missingForFullLearn`.

### 5.4 Vocabulary / Kanji

- **Notifier:** `addVocabKanjiEntry`, `updateVocabKanjiEntry`, `deleteVocabKanjiEntry`. Early return if `termJapanese` empty on add/update.
- **Fields:** `VocabularyKanjiEntry`: `termJapanese` (required for `isValidV1`), `type`, optional `reading`, `glosses`, `exampleSentence`, `exampleMeanings`, `provenance`.
- **Module completion (data):** `moduleMeetsV1Completion(LearnModuleId.vocabularyKanji)` ⇔ **at least one** entry with `isValidV1`.

### 5.5 Grammar

- **Notifier:** `addGrammarEntry`, `updateGrammarEntry`, `deleteGrammarEntry`. Headline required (trim non-empty); examples filtered with `GrammarExample.isEmptyV1`.
- **Module completion:** At least one `GrammarEntry` with `isValidV1` (headline non-empty).

### 5.6 Quiz

- **Notifier:** `addQuizEntry` / `updateQuizEntry` / `deleteQuizEntry`.
- **Hard constraints in notifier:** prompt non-empty, `options4.length == 4`, each option non-empty after trim, `correctIndex` in `0..3`.
- **Module completion:** At least one `QuizEntry` with `isValidV1` (includes 4-option rule).

### 5.7 Audio

- **Notifier:** `setStoryAudio` (requires non-empty `sourceUrl` after trim), `clearStoryAudio`.
- **Module completion:** `audio.storyAudio?.isValidV1 == true` (URL non-empty).

### 5.8 Review / publish data

- **State only:** `publishState` + timestamps in `basics.updatedAt` (via notifier methods).
- **Review UI:** `StoryCreatorReviewScreen` uses summary cards and `StoryCreatorProgressChecklist`.

### 5.9 Module status cards / completion flags

- **Workflow map:** `moduleWorkflowStatuses[LearnModuleId]` — `notStarted` \| `inProgress` \| `completed`.
- **Manual override:** `StoryCreatorLearnHubScreen` cycles via `setModuleStatus`.
- **Auto-promotion:** `syncModuleWorkflowWithContent` sets workflow to **`completed`** when `moduleMeetsV1Completion(id)` is true; it does **not** automatically demote when data is removed (see §8 / debt).

---

## 6. Validation and Publish Rules

### Reading Only publish (`canPublishReadingOnly`)

From `CreatorStoryV1`:

- `isStoryCoreReadyForReading` = `isBasicsComplete` **and** `sentences.any((s) => s.isValidV1)`.

`missingForReadingOnly()` (`creator_publish_validation.dart`): title, category, level, description, at least one valid sentence — mirrors the above.

### Full Learn publish (`canPublishFullLearn`)

- `isStoryCoreReadyForReading` **and** `allLearnModulesDataComplete`.
- `allLearnModulesDataComplete`: **every** `LearnModuleId` passes `moduleMeetsV1Completion` (each module’s **data** threshold, not workflow checkbox).

### UI vs model

- **Basics continue:** Local `_validateRequired()` on basics screen (hard block for navigation).
- **Sentences continue:** Uses `storyPlaintextHasValidSentence` / line checks in screen code (hard block for route to review).
- **Publish buttons:** Disabled when `canReading` / `canFull` false; SnackBar uses `blockedReasonReadingOnly()` / `blockedReasonFullLearn()` from validation extension.

### Blocks vs warnings

- **Hard blocks:** Publish methods `publishReadingOnly()` / `publishFullLearn()` early-return if `canPublish*` is false; `publish*Checked` returns false.
- **Warnings:** After successful Reading Only publish, SnackBar can list **incomplete** learn modules by label (`incompleteLearnModulesLabel`) — informational, not blocking Reading Only.

---

## 7. Draft / Resume / Recovery Behavior

- **Single global draft:** One JSON string in `SharedPreferences`; starting “new story” from hub calls `discardDraftFromDiskAndReset()` then navigates to basics — **destructive** to previous draft.
- **Resume:** `StoryCreatorHubScreen` “Continue current story” uses `_continuePath`: incomplete basics → `/create/story/basics`; else incomplete core → `/create/story/sentences`; else `/create/story/review`.
- **Autosave:** **Partial** — sentences screen debounces **state** updates to provider (`applySentences`) but **disk** save is explicit on **Save draft** buttons and some publish actions. Sentences do **not** auto-call `saveDraftToDisk` on every keystroke (only `applySentences`).
- **Incomplete data on disk:** `saveDraftToDisk` comment in notifier: *“Save incomplete drafts too”* — full JSON written regardless of completion (subject to whatever state is currently in `CreatorStoryV1`).
- **Hydration flag:** `hydratedFromDisk` on notifier; screens generally seed controllers in `addPostFrameCallback` from provider (pattern on basics/sentences).
- **Inconsistency:** **Publish Full Learn** success path in `StoryCreatorReviewScreen` shows SnackBar but **does not** call `saveDraftToDisk()` (whereas Reading Only does after publish). Updated `publishState` may therefore **not** be persisted** until a later manual save — **verified by reading review screen source**.

---

## 8. Multilingual Handling Today

- **Model:** `LocalizedMeanings` with first-class **`en`** and **`my`** fields plus **`byLanguage`** `Map<String,String>` for extensibility (`story_v1_model.dart`).
- **Persistence:** JSON keys `en`, `my`, `byLanguage` under each meanings blob (`story_creator_draft_storage.dart`).
- **UI:** Creator editors label fields as “English” / “Myanmar” in multiple screens (hardcoded copy, e.g. `story_creator_sentences_screen.dart`, grammar/vocab/quiz editors). No dynamic locale picker for arbitrary BCP-47 codes in creator UI beyond `byLanguage` preservation in `layerFromEnMy`.
- **Sentence summary:** `StorySentenceItem.supportMeaningsSummaryV1` returns human strings like `No translation`, `Source only`, `EN only`, `Source · EN` — **display helper**, not learner app language switching.
- **Reader Learn explanation language** (`learn_explanation_language` under `lib/features/learn/`) is **separate** from creator insert; no import linkage found in `lib/features/create/*`.

---

## 9. Offline Readiness Assessment

**Strengths**

- Entire `CreatorStoryV1` is JSON-serializable to a single string — easy to **copy/export/blob** for offline packaging if a wrapper is added later.
- Learn payloads are **structured** (entries, options, URLs) rather than opaque HTML.

**Gaps / risks**

- **No canonical “published artifact”** separate from draft; reader `MonoContent` / feed models are **not** populated from `CreatorStoryV1` in the analyzed code — offline “read + learn” would need an explicit mapping layer (missing today).
- **Audio** is a **URL string** (`StoryAudioAsset.sourceUrl`) — offline read/learn would require download sidecar or binary embedding (not implemented).
- **Quiz / grammar / vocab** are creator-specific shapes (`CreatorQuizCategory`, `GrammarEntry`, …) — learner app screens under `/learn/...` use **different** content drivers (e.g. quiz mock bank) unless bridged (not found in create folder).
- **Single-device draft:** No multi-draft, no sync — conflict if multi-device later.
- **Publish state vs disk** after Full Learn publish without save (§7).

---

## 10. Risks and Technical Debt

1. **No server insert:** Publish is mostly **state + messaging**; risk of user believing content is “live” when it is only local.
2. **`syncModuleWorkflowWithContent` asymmetry:** Promotes to `completed` when data sufficient; **does not** downgrade workflow when entries deleted → `learnModuleWorkflowAheadOfData` UI branch.
3. **Full Learn publish without `saveDraftToDisk`:** Possible **publishState drift** if process dies before another save.
4. **Global single draft:** `discardDraftFromDiskAndReset` is data-loss prone without export/confirm in all entry paths (hub shows start new flow — user-dependent).
5. **Two create systems:** `CreateScreen` (One Short) vs `StoryCreator*` — documentation / product confusion unless explicitly scoped.
6. **Quiz JSON import padding:** `_fromJsonQuizLayer` pads options to length 4 with empty strings — can produce **invalid** `QuizEntry` until edited (assert in model constructor expects 4 options).
7. **Tight coupling:** All screens depend on **one** `storyCreatorDraftProvider` global instance — hard to edit two stories concurrently.

---

## 11. Recommended Change Surface (Future Work — Not Implemented)

Likely touch points for multilingual explanation architecture + offline learn packaging:

- `story_v1_model.dart` — extend or version `LocalizedMeanings`, per-module explanation fields, schema versioning.
- `story_creator_draft_storage.dart` — migration of JSON, optional compression, checksum, export bundle.
- `story_creator_provider.dart` — new persistence hooks, transaction boundaries, `save` after publish consistency.
- Each `story_creator_*_editor_screen.dart` + `story_creator_sentences_screen.dart` — UI for additional locales, validation copy.
- `creator_publish_validation.dart` / `CreatorStoryV1` getters — new required fields for publish tiers.
- **New** adapter: `CreatorStoryV1` → reader `MonoContent` / API DTO (does not exist in repo today).
- `learn_explanation_language` integration — only if creator should respect learner prefs at **authoring** time (currently separate).

---

## 12. Open Questions / Unclear Areas

1. **Is One Short (`CreateScreen`) supposed to feed `CreatorStoryV1`?** No code link found; intent unclear.
2. **Where should published stories land** (feed, backend, author profile)? Not implemented for `CreatorStoryV1` in analyzed paths.
3. **`creatorOwnerId`:** Preserved on `reset()` from current state; is it ever set from auth? Not verified in create module alone.
4. **Sentence `audioStartMs` / `audioEndMs`:** Modeled and serialized; **no** UI found in sentences screen grep scope — who sets them?
5. **AI fields:** `ContentProvenance` / `ContentSourceMode` exist; are they set outside manual defaults? Creator editors mostly use `const ContentProvenance()`.
6. **Full Learn publish persistence gap:** Confirm product intent — bug vs feature (current code as read).

---

## Appendix: Key function and type index

| Symbol | Location |
|--------|-----------|
| `StoryCreatorDraftNotifier.saveDraftToDisk` | `story_creator_provider.dart` |
| `StoryCreatorDraftStorage.save` / `load` / `clear` | `story_creator_draft_storage.dart` |
| `applyBasics`, `applySentences`, `updateSentenceSupport` | `story_creator_provider.dart` |
| `publishReadingOnly`, `publishFullLearn`, `markDraft` | `story_creator_provider.dart` |
| `CreatorStoryV1.canPublishReadingOnly`, `canPublishFullLearn`, `moduleMeetsV1Completion` | `story_v1_model.dart` |
| `syncModuleWorkflowWithContent` | `story_v1_model.dart` |
| `missingForReadingOnly`, `missingForFullLearn` | `creator_publish_validation.dart` |
| GoRouter `/create/story/*` | `main.dart` |

---

*Document generated from repository inspection. No code was modified for this task.*
