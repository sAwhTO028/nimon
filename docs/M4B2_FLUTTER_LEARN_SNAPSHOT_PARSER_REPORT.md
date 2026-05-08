# M4b2 Flutter Learn Snapshot Parser Report

**Report date:** 2026-05-03  
**Scope:** Parser + typed model for `published_monos.content.learn` only — **no** Learn screens, MonoScreen, or publish flow changes.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/profile/data/published_mono_learn_snapshot_parser.dart` | **New** — `LearnPublishedSnapshot`, `learnPublishedSnapshotFromContent`, `learnPublishedSnapshotFromPublishedMonoDetail`. |
| `test/features/profile/published_mono_learn_snapshot_parser_test.dart` | **New** — coverage for null paths, v1 payload, tolerance, schema handling, detail delegate. |

---

## Model Shape

**`LearnPublishedSnapshot`**

| Field | Type |
|-------|------|
| `schemaVersion` | `int` — effective **1** when parsing succeeds |
| `vocabularyKanjiEntries` | `List<VocabularyKanjiEntryDto>` |
| `grammarEntries` | `List<GrammarEntryDto>` |
| `quizEntries` | `List<QuizEntryDto>` |
| `storyAudio` | `StoryAudioDto?` |
| `hasAnyLearnData` | `bool` — true if any list non-empty or `storyAudio != null` |

---

## Parser Behavior

- **`learnPublishedSnapshotFromContent(Object? content)`**
  - **`content`** not a `Map` → **`null`**
  - **`content['learn']`** missing or not a `Map` → **`null`**
  - **`schemaVersion`** explicitly **≠ 1** → **`null`** (unsupported future schema until parser is extended)
  - **`schemaVersion` omitted** → treated as **1** (tolerant; matches M4b1 backend always sending `1`)
  - Layer maps (`vocabularyKanji`, etc.) missing or wrong shape → **empty lists**
  - **`entries`** not a `List` → **empty list**
  - Non-map rows in **`entries`** → **skipped**
  - **`audio.storyAudio` null** → **`storyAudio` null**; non-map raw → **`null`**

- **`learnPublishedSnapshotFromPublishedMonoDetail(PublishedMonoDetailDto)`** — delegates to **`learnPublishedSnapshotFromContent(dto.content)`**.

---

## Reused Wire Decoders

From **`remote_story_draft_learn_layers_wire.dart`** (M4a):

- `vocabularyKanjiEntryDtoFromWireJson`
- `grammarEntryDtoFromWireJson`
- `quizEntryDtoFromWireJson`
- `storyAudioDtoFromWireJson`

DTO types from **`story_draft_dto.dart`**.

---

## Tests Added

| Case |
|------|
| Invalid / missing `content` / `learn` → null |
| Full v1 payload → lists + audio + `hasAnyLearnData` |
| Missing sections → empty lists, `hasAnyLearnData` false |
| Non-list `entries` → empty |
| Malformed row skipped, valid row kept |
| `schemaVersion: 2` → null |
| Omitted `schemaVersion` → parse as v1 |
| `storyAudio: null` |
| `learnPublishedSnapshotFromPublishedMonoDetail` |

---

## Flutter Analyze Result

```bash
flutter analyze lib/features/profile/data/published_mono_learn_snapshot_parser.dart \
  test/features/profile/published_mono_learn_snapshot_parser_test.dart
```

**Result:** No issues found.

---

## Flutter Test Result

```bash
flutter test test/features/profile
flutter test
```

**Result:** All tests passed (**156** total suite run).

---

## Remaining Risks

- **`schemaVersion` > 1** returns **`null`** — apps must not assume learn is absent forever; future parsers may widen support.
- **Quiz rows** with fewer than four options still decode (wire pads/clamps in mapper upstream); Learn UI will normalize in M4b3.
- **Large `content` blobs** — parsing happens on detail fetch; consider caching at provider layer later.

---

## Recommended Next Step

**M4b3:** Wire **`LearnPublishedSnapshot`** into Learn routes/providers (replace mocks when `hasAnyLearnData` / `publishKind` allow), with honest empty states when snapshot is null.
