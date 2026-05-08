# M4a Learn Layer Wire Fix Report

**Report date:** 2026-05-03  
**Scope:** Flutter remote wire encode/decode for vocabulary, grammar, quiz, and story audio (M4a). **No** backend, migrations, `publishFullLearn`, or Learn UI changes.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/data/remote_story_draft_learn_layers_wire.dart` | **New** — `vocabularyKanjiEntryDtoToWireJson` / `FromWireJson`, `grammarEntryDto*`, `quizEntryDto*`, `storyAudioDto*`; reuses `localizedMeaningsDtoToWireJson` / `FromWireJson` and `contentProvenanceDtoToWireJson` / `FromWireJson` from `remote_story_draft_sentence_wire.dart`. |
| `lib/features/create/data/remote_story_draft_repository.dart` | `_vocabToJson` / `_vocabDtoFromJson` (and grammar, quiz, audio) delegate to the new wire helpers instead of hard-coded nulls / empty lists. |
| `test/features/create/remote_story_draft_learn_layers_wire_test.dart` | **New** — round-trip and tolerance tests per layer. |

---

## Root Cause

`RemoteStoryDraftRepository` mirrored the pre-M3 sentence bug for learn layers: **PUT** emitted nulls / empty structures for rich fields, and **GET** discarded fields returned by the API. That caused **silent data loss** on remote sync even though `StoryDraftMapper` and local storage (`StoryCreatorDraftStorage`) carried full vocab / grammar / quiz / audio payloads.

---

## Vocab Wire Fix

Serialize and deserialize **`glosses`**, **`exampleMeanings`**, **`examplePairs`** (`source` / `english`), **`provenance`**, plus existing scalars (`id`, `termJapanese`, `type`, `reading`, `exampleSentence`). **`examplePairs`** parsing skips non-map rows; pair fields coerce non-strings via `toString()` so malformed rows degrade safely.

Default **`type`** when missing is **`vocabulary`** (aligned with `VocabularyKanjiEntryTypeLabels.fromStorageKey`).

---

## Grammar Wire Fix

Full round-trip for **`meanings`**, **`usage`**, **`examples[]`** (each with `japanese` + optional **`meanings`**), **`relatedNote`**, **`mistakeWrong`**, **`mistakeCorrect`**, **`provenance`**. Example list entries that are not maps are skipped.

---

## Quiz Wire Fix

Round-trip **`explanations`**, **`provenance`**, **`prompt`**, **`options`**, **`correctIndex`**, **`category`**, **`sourceNote`**. **`correctIndex`** accepts **`double`** from JSON (same tolerance pattern as sentence `orderIndex`).

---

## Audio Wire Fix

Round-trip **`provenance`** and all **`StoryAudioDto`** scalar/metadata fields: **`sourceUrl`**, **`localFileName`**, **`localPath`**, **`localSizeBytes`**, **`localExtension`**, **`displayName`**, **`durationSeconds`**. Decode accepts optional aliases **`localFilePath`** and **`localUri`** when **`localPath`** is absent (tolerant ingest only; encode still emits **`localPath`**). **`localSizeBytes`** / **`durationSeconds`** parse int or double.

---

## JSON Shape

Aligned with **`StoryCreatorDraftStorage`** layer JSON (`_toJsonVocabLayer`, `_toJsonGrammarLayer`, `_toJsonQuizLayer`, `_toJsonAudioLayer`):

- Localized text: **`en`**, **`my`**, **`byLanguage`** via shared sentence wire helpers.
- Provenance: **`sourceMode`**, **`lastReviewedByCreator`**.

---

## Tests Added

`test/features/create/remote_story_draft_learn_layers_wire_test.dart`:

- Vocab: full round-trip; malformed `examplePairs`; `jsonEncode` / `jsonDecode` preserve keys.
- Grammar: full round-trip; malformed `examples` list.
- Quiz: explanations + provenance; `correctIndex` from double.
- Audio: provenance + scalars; `localFilePath` alias; null provenance / missing numerics.

---

## Flutter Analyze Result

```text
flutter analyze lib/features/create/data/remote_story_draft_learn_layers_wire.dart lib/features/create/data/remote_story_draft_repository.dart test/features/create/remote_story_draft_learn_layers_wire_test.dart
```

**Result:** No issues found.

---

## Flutter Test Result

```text
flutter test test/features/create
```

**Result:** All tests passed (includes new learn-layer tests + existing create tests).

```text
flutter test
```

**Result:** All tests passed (146 tests).

---

## Remaining Risks

- **Reader / publish:** `published_monos.content` still has no learn snapshot (M4b). Wire parity does not by itself expose learn data in Mono detail.
- **Audio URLs:** Device-local paths sync to Postgres but are not playable on other devices until HTTPS or an upload pipeline exists (out of M4a scope).
- **Legacy rows:** Drafts saved earlier under stub PUTs may still have incomplete JSON in DB until re-saved from the app.

---

## Recommended Next Step

**M4b:** Extend full-learn (and/or PublishedMono) snapshot + Flutter parser so Learn mode can hydrate from catalog data; optional manual smoke with `NIMON_USE_REMOTE_DRAFTS=true` after verifying Studio rows for `draft_vocab_entries` / `draft_grammar_entries` / `draft_quiz_entries` / `draft_audio`.
