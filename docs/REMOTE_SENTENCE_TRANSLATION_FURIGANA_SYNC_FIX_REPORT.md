# Remote Sentence Translation Furigana Sync Fix Report

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/data/remote_story_draft_sentence_wire.dart` | **New** — canonical encode/decode for `StorySentenceDto` ↔ wire JSON (furigana, meanings, provenance, audio indices). |
| `lib/features/create/data/remote_story_draft_repository.dart` | `_sentenceToJson` / `_sentenceDtoFromJson` delegate to the wire helpers (replacing hard-coded empty spans / null meanings). |
| `test/features/create/remote_story_draft_sentence_wire_test.dart` | Round-trip and tolerance tests. |

## Root Cause

`RemoteStoryDraftRepository` used stub sentence serialization for PUT (`furiganaSpans: []`, `meanings: null`) and stub deserialization on GET, so **remote sync never persisted** learner meanings or furigana despite correct local draft storage and UI updates.

## Serialization Fix

`storySentenceDtoToWireJson` now emits:

- `furiganaSpans`: array of `{ start, end, reading }` from `FuriganaSpanDto`
- `meanings`: `localizedMeaningsDtoToWireJson` → `{ en, my, byLanguage }` (aligned with `StoryCreatorDraftStorage._toJsonMeanings`)
- Existing fields: `id`, `storyId`, `orderIndex`, `japaneseText`, `reading`, `audioStartMs`, `audioEndMs`, `provenance` (when present)

## Deserialization Fix

`storySentenceDtoFromWireJson`:

- Parses `furiganaSpans` via `furiganaSpansFromWireJson` — skips invalid list entries
- Parses `meanings` via `localizedMeaningsDtoFromWireJson` — tolerates missing/null/malformed maps; returns `null` when no meaningful content
- `orderIndex`: accepts `int` or `double` from JSON
- `provenance`: optional; ignored when absent or empty

## JSON Shape

Matches local sentence JSON and P1 reader expectations on published snapshots:

- `japaneseText`
- `furiganaSpans[]` with `start` / `end` / `reading`
- `meanings.en`, `meanings.my`, `meanings.byLanguage`

## Tests Added

`test/features/create/remote_story_draft_sentence_wire_test.dart`:

- Japanese text only
- Furigana only
- Meanings only
- Combined furigana + meanings
- Malformed span rows skipped
- Missing meanings
- `orderIndex` as double
- Full `jsonEncode` / `jsonDecode` round-trip

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/data/remote_story_draft_sentence_wire.dart \
  lib/features/create/data/remote_story_draft_repository.dart \
  test/features/create/remote_story_draft_sentence_wire_test.dart
```

**Result:** No issues found.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/create` | Passed |
| `flutter test` (full suite) | Passed |

## Manual Verification Steps

1. Enable remote drafts, edit a story sentence: add **Source / English** meanings and **furigana**.
2. Trigger save (wait for sync / leave screen so `saveDraft` runs).
3. **Optional DB:** Inspect `draft_sentences.content` for the draft — JSON should include non-empty `furiganaSpans` and `meanings`.
4. Reload the draft from the server (new session or pull-to-refresh if applicable) — fields should reappear.
5. Publish read-only and confirm `published_monos.content.core.sentences[].content` carries the same keys (backend copies draft sentence content).

## Remaining Risks

- Vocab/grammar/quiz layers in `RemoteStoryDraftRepository` still use partial `_vocabToJson` / `_grammarToJson` / `_quizToJson` stubs — **out of scope** for this fix.
- Very old server rows with unexpected `meanings` shapes may still lose fields if structure differs; parsing is defensive but not exhaustive.

## Recommended Next Step

Align **non-sentence** draft layers’ remote wire encode/decode with `StoryDraftMapper` the same way, or route PUT JSON generation through a single shared serializer to avoid future drift.
