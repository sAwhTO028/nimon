# M4 Learn Module Remote Wire Plan

**Report date:** 2026-05-03  
**Type:** Milestone plan / audit only — **no app, schema, or migration changes in this file.**

**References:** [M3_MONO_FEED_READER_CLOSEOUT_REPORT.md](M3_MONO_FEED_READER_CLOSEOUT_REPORT.md), [REMOTE_SENTENCE_TRANSLATION_FURIGANA_SYNC_FIX_REPORT.md](REMOTE_SENTENCE_TRANSLATION_FURIGANA_SYNC_FIX_REPORT.md), [P1_FURIGANA_TRANSLATION_FIX_REPORT.md](P1_FURIGANA_TRANSLATION_FIX_REPORT.md), [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md), [NIMON_LANGUAGE_SYSTEM.md](NIMON_LANGUAGE_SYSTEM.md), [NIMON_AI_FEATURE_PLAN.md](NIMON_AI_FEATURE_PLAN.md).

**Code anchors audited:** `lib/features/create/data/remote_story_draft_repository.dart`, `lib/features/create/data/story_draft_mapper.dart`, `lib/features/learn/**`, `lib/features/profile/data/published_mono_detail_parser.dart`, `nimon-backend/src/modules/story-drafts/story-drafts.service.ts`, `nimon-backend/prisma/schema.prisma`.

---

## 1. Executive Summary

**M3** closed the public Mono feed, reader hydration for **reading core** (sentences with `furiganaSpans` + `meanings`), and the **remote sentence wire** so creator edits round-trip through `RemoteStoryDraftRepository` with parity to local storage.

**M4** is needed because learn surfaces are not yet “catalog truth.” Non-sentence draft layers (vocabulary/kanji, grammar, quiz, story audio) still use **partial serializers** in `RemoteStoryDraftRepository`: PUT strips rich fields and GET drops server-returned JSON back to null/empty defaults — the same class of bug that existed for sentences before `remote_story_draft_sentence_wire.dart`. Separately, **full-learn publish** does not yet write a **learn snapshot** into `published_monos.content`, so readers cannot consume real learn data from PublishedMono even when Postgres draft rows are complete.

M4 aligns remote draft wire + (in a follow phase) published snapshot + reader contracts so Learn mode can eventually use **real** story-linked data end-to-end without silent data loss on sync.

---

## 2. Current Learn Module State

| Area | UI / navigation | Data source today | Notes |
|------|------------------|-------------------|--------|
| **Learn hub** | `LearnHubScreen` — cards for Vocabulary, Grammar, Quiz, Listening (`/learn/:contentId/...`) | Route args + **static** labels; default card taps show SnackBar with `contentId` unless wired elsewhere | Hub receives `contentId` (e.g. Mono id from `mono_screen.dart`). |
| **Vocabulary / Kanji** | `VocabKanjiListScreen`, `VocabKanjiDetailSheet`, `VocabKanjiItem` | **`mockItems`** — hard-coded demo entries (“later: derived from story”) | No repository; not tied to draft or PublishedMono. |
| **Grammar** | `GrammarPatternListScreen`, `GrammarPatternDetailScreen`, `GrammarPattern` models | **`mockPatterns`** — hard-coded | Same. |
| **Quiz** | `QuizSetupScreen` → `QuizPlayScreen` → `QuizResultScreen`; `quiz_mock_bank.dart` | **Mock bank** keyed by category/count | Same. |
| **Listening / Audio** | `ListeningPronunciationScreen` | **`ListeningSampleData`** default transcript lines + default audio URL unless route passes `audioUrl` / `lines` | Optional overrides exist for URL/lines; no draft audio pipeline. |
| **Generic “Learn” article** | `LearnScreen` | **`_mockLearnContent`** | Demonstration blocks only. |

**Explanation language:** `learnExplanationLanguageProvider` / `LearnExplanationLanguage` govern EN vs MY display for explanations across learn screens — orthogonal to data loading.

**Bottom line:** Learn UX is largely **product-complete at V1 mock depth** but **data integration is not started** beyond passing `contentId` through routes.

---

## 3. Vocabulary Remote Wire Audit

### Encode (Flutter → PUT)

`StoryDraftMapper` maps domain → `VocabularyKanjiEntryDto` with **full** `glosses`, `exampleMeanings`, `examplePairs`, `provenance` (`story_draft_mapper.dart`).

`RemoteStoryDraftRepository._vocabToJson` **overwrites** several fields with stubs:

- `glosses`: **null**
- `exampleMeanings`: **null**
- `examplePairs`: **empty list**
- `provenance`: **null**

(`remote_story_draft_repository.dart` approximately lines 354–364.)

### Decode (GET → DTO)

`_vocabDtoFromJson` **always** sets:

- `glosses`, `exampleMeanings`: **null**
- `examplePairs`: **const []**
- `provenance`: **null**

even if the API returned richer JSON (`remote_story_draft_repository.dart` approximately lines 252–263).

### Backend

`updateDraft` stores each vocab entry’s JSON **as sent** in `draft_vocab_entries.content`. `mapFullDraft` returns `vocabularyKanji.entries` as **spread `e.content`** — no server-side stripping (`story-drafts.service.ts`).

### Local vs remote parity

| Concern | Status |
|---------|--------|
| Domain ↔ DTO (mapper) | **Full** |
| DTO ↔ wire JSON (remote repo) | **Lossy** on PUT and GET |
| DB vs API | **Reflects last PUT**; client currently sends incomplete payloads |

### Publish snapshot

`publishReadOnly` copies **`core.sentences`** into `published_monos.content` only — **not** vocabulary (`story-drafts.service.ts`). `publishFullLearn` does not add vocab to PublishedMono (see §7).

---

## 4. Grammar Remote Wire Audit

Same pattern as vocabulary.

**Encode:** `_grammarToJson` forces `meanings`, `usage`, `examples`, `relatedNote`, `provenance` to null/empty (`remote_story_draft_repository.dart` ~366–377).

**Decode:** `_grammarDtoFromJson` forces `meanings`, `usage`, `examples`, `relatedNote`, `provenance` to null/empty (~266–278).

**Mapper:** `StoryDraftMapper` supports full grammar DTOs (~282–324).

**Backend:** Same pass-through storage and response mapping as vocab.

**Publish:** Not included in read-only snapshot; full-learn metadata only (§7).

---

## 5. Quiz Remote Wire Audit

**Encode:** `_quizToJson` sets `explanations` and `provenance` to **null** (~379–388).

**Decode:** `_quizDtoFromJson` sets `explanations` and `provenance` to **null** (~281–294).

Core MCQ fields (`prompt`, `options`, `correctIndex`, `category`, `sourceNote`) **do** round-trip.

**Publish:** Not in read-only snapshot; full-learn does not write quiz payload to PublishedMono.

---

## 6. Listening / Audio Remote Wire Audit

**Encode:** `_audioToJson` forwards `sourceUrl`, local file metadata, `displayName`, `durationSeconds`; forces `provenance` **null** (~390–400).

**Decode:** `_audioDtoFromJson` parses the same scalar/object fields; `provenance` **null** (~297–308).

**Gaps beyond JSON:**

1. **Upload / canonical URL:** Creator may hold **local** paths; `StoryDraftMapper._remoteSourceUrl` only treats `http(s)` as remote when stripping locals for certain paths — remote draft PUT still sends local paths if present. Backend stores whatever JSON is sent; readers need **HTTPS** URLs for `just_audio`.
2. **No object storage contract in M4 scope:** Plan phase should assume **either** server-side upload pipeline **or** creator-supplied HTTPS URLs before Learn listening is “real.”
3. **Published snapshot:** Story audio is **not** copied into `published_monos.content` on read-only publish; full-learn publish does not add it (§7).

---

## 7. Full Learn Publish Snapshot

**What `publishFullLearn` does today** (`story-drafts.service.ts` ~803–908):

- Validates readiness (`getFullLearnReadinessUnmet`), requires existing `publishedMonoId`.
- Updates draft: `publishState: full_learn_published`, `fullLearnPublishedAt`, clears `hasUnpublishedCoreChanges`, increments version.
- Updates **PublishedMono** `content` by merging:

  - `sourceDraftId`
  - `publishKind: 'full_learn_v1'`
  - `updatedAt`

**Comment in source:** *“Learn module snapshots are not written here yet (V1: Flutter must not render fake learn data; [content.learn] is optional for later).”*

So **no** vocabulary, grammar, quiz, or audio payload is copied into `published_monos.content` on full-learn publish. The learn payload **does not survive** into the public snapshot today.

**Contrast:** `publishReadOnly` writes a rich `core` object with **sentences** only — still no learn modules.

---

## 8. Reader Learn Mode Requirements

**PublishedMono reader path today:** `published_mono_detail_parser.dart` builds **`MonoContent`** from `content.core.sentences` only (`buildMonoContentFromPublishedCore`, `plainBodyFromPublishedCore`). It interprets **sentence** `content` maps (`japaneseText`, `furiganaSpans`, `meanings`) for the **reading** experience — **not** learn modules.

**For Learn reader pages to use catalog truth**, consumers need a **stable contract**, for example (product-defined):

- Under `published_monos.content` (or a versioned sub-tree):  
  - **`learn.vocabularyKanji.entries[]`** — aligned with draft/wire JSON  
  - **`learn.grammar.entries[]`**  
  - **`learn.quiz.entries[]`**  
  - **`learn.audio.storyAudio`** (HTTPS URL + display metadata + duration)  
- Optional: **`learn.version`** / **`learn.schemaVersion`** for forward compatibility.

Until that exists, Learn screens **cannot** hydrate from `GET /v1/mono/:id` or profile Published detail in a principled way — they remain mock-driven.

**Navigation:** Hub already receives `contentId` (Mono id). Readers need **either** embedded learn JSON in detail DTO **or** a dedicated endpoint — out of scope for M4a wire-only work but required for M4b.

---

## 9. JSON Shape Mismatches

| Layer | Local / mapper (DTO) concept | Remote PUT payload (current) | GET → client DTO (current) | Reader / parser expectation |
|-------|------------------------------|------------------------------|----------------------------|-----------------------------|
| **Sentence** | Full wire via `remote_story_draft_sentence_wire.dart` | Fixed in M3 | Fixed in M3 | `published_mono_detail_parser` / P1 |
| **Vocab** | `glosses`, `exampleMeanings`, `examplePairs`, `provenance` | **Stubs / omitted** | **Dropped on parse** | No parser yet; must match future `content.learn` |
| **Grammar** | `meanings`, `usage`, `examples[]`, `relatedNote`, `provenance` | **Stubs** | **Dropped** | No parser yet |
| **Quiz** | `explanations`, `provenance` | **explanations null** | **Dropped** | No parser yet |
| **Audio** | `provenance` + locals | provenance null | provenance dropped | Needs HTTPS `sourceUrl` + metadata |
| **PublishedMono** | N/A | N/A | Detail API returns `content` | **Only `core` sentences** parsed today |

**Meanings shape:** Vocab/grammar/quiz DTOs use the same **localized meanings** patterns as sentences (`LocalizedMeanings` / `MeaningLineDto` families in mapper). Wire JSON should stay **consistent** with established keys (`en`, `my`, `byLanguage` where used) per [NIMON_LANGUAGE_SYSTEM.md](NIMON_LANGUAGE_SYSTEM.md).

---

## 10. Priority / Fix Order

### M4a — Audit-backed wire serializer fixes (Flutter)

- Replace vocab/grammar/quiz/audio stubs in `RemoteStoryDraftRepository` with **full** encode/decode aligned to `StoryDraftMapper` and backend pass-through (mirror **sentence** split: dedicated wire modules + tests).
- **No migration**; backend already stores JSON blobs.

### M4b — Full-learn publish + parser + reader contract

- **Backend:** Extend `publishFullLearn` (and/or read-only update policy if product wants incremental learn snapshot) to write **`content.learn`** (or agreed shape) from draft rows.
- **Flutter:** Extend PublishedMono detail parsing / mappers to expose learn data to providers.
- **Learn:** Replace mocks with repository/providers driven by **mono id** + published payload.

### M4c — Manual smoke

- Remote drafts ON + strict mode optional: edit learn layers → PUT → GET → verify DB / UI.
- Publish full learn → public mono detail → Learn hub → spot-check each module.
- Regression: sentence wire still round-trips.

---

## 11. Tests Needed

### Unit / integration (automated)

| Test | Purpose |
|------|---------|
| **Vocab wire** round-trip (`jsonEncode`/`decode` or DTO loop) | Glosses, example meanings, pairs, provenance survive |
| **Grammar wire** round-trip | Nested examples + meanings |
| **Quiz wire** round-trip | Explanations + provenance |
| **Audio wire** round-trip | Provenance + edge cases (null locals) |
| **RemoteStoryDraftRepository** integration-style test (optional) | PUT payload includes non-null learn fields when mapper has data |

### Manual smoke checklist

1. Enable `NIMON_USE_REMOTE_DRAFTS=true`; optional `NIMON_STRICT_REMOTE_DRAFTS=true`.
2. Create/edit vocab entry with EN/MY glosses and example pair → save → reload draft → fields present.
3. Same for grammar (usage, examples), quiz (explanations), audio (metadata).
4. Prisma Studio: `draft_vocab_entries.content` etc. match app expectations.
5. After M4b: publish full learn → fetch mono detail → Learn screens show real data (not mocks).

---

## 12. Risks

| Risk | Detail |
|------|--------|
| **AI-generated fields** | [NIMON_AI_FEATURE_PLAN.md](NIMON_AI_FEATURE_PLAN.md) — AI outputs are provisional until user acceptance; provenance and review UX matter when syncing to server. |
| **Source / English meaning** | Vocab glosses and grammar meanings use **localized** maps; inconsistent wire keys would break EN/MY toggles in Learn. |
| **Partial stubs** | Same failure mode as pre-fix sentences: **silent data loss** on sync — high severity for creators. |
| **Audio storage** | Local paths in DB do not help readers; need HTTPS URLs or upload pipeline. |
| **Payload size** | Large quiz/grammar arrays increase PUT/GET size; monitor mobile performance and backend limits. |
| **PublishedMono bloat** | Embedding full learn in `content` JSON affects detail payload size; may need lazy endpoints later. |

---

## 13. Exact Cursor Prompt For M4a

Use this **implementation** prompt when executing M4a (serializer fixes only — **no** migrations, **no** `publishFullLearn` content changes):

---

**M4a implementation — Remote learn-layer wire parity (Flutter only)**

You are working in the Nimon Flutter repo. **Do not run migrations or edit Prisma.**

**Goal:** Eliminate data loss for non-sentence draft layers when `RemoteStoryDraftRepository` syncs to `GET/PUT /v1/story-drafts/:id`. Sentence wire is already fixed via `remote_story_draft_sentence_wire.dart`; learn layers still stub fields.

**Requirements:**

1. Read `lib/features/create/data/remote_story_draft_repository.dart` — `_vocabToJson`, `_grammarToJson`, `_quizToJson`, `_audioToJson` and matching `_vocabDtoFromJson`, `_grammarDtoFromJson`, `_quizDtoFromJson`, `_audioDtoFromJson`.

2. Read `lib/features/create/data/story_draft_mapper.dart` for canonical **DTO shapes** (`VocabularyKanjiEntryDto`, `GrammarEntryDto`, `QuizEntryDto`, `StoryAudioDto`) including nested meanings / examples / provenance.

3. Introduce focused wire helpers (new files, mirroring the sentence pattern), e.g.  
   `lib/features/create/data/remote_story_draft_vocab_wire.dart`,  
   `remote_story_draft_grammar_wire.dart`,  
   `remote_story_draft_quiz_wire.dart`,  
   `remote_story_draft_audio_wire.dart`  
   — **or** a single `remote_story_draft_learn_layers_wire.dart` if it stays readable. Each module must:
   - Emit JSON keys compatible with what Nest stores in `draft_*_entries.content` / `draft_audio.content` (pass-through from existing mapper expectations).
   - Parse GET JSON **tolerantly** (missing/null sections → safe defaults consistent with mapper).

4. Replace stub `null` / `[]` assignments with **full** round-trip for:
   - Vocab: `glosses`, `exampleMeanings`, `examplePairs`, `provenance`
   - Grammar: `meanings`, `usage`, `examples`, `relatedNote`, `provenance`
   - Quiz: `explanations`, `provenance`
   - Audio: `provenance` (and any fields already on DTO but dropped today)

5. Add tests under `test/features/create/` mirroring `remote_story_draft_sentence_wire_test.dart`: round-trip tests per layer + malformed input tolerance.

6. Run `flutter analyze` on touched files and tests.

**Out of scope for M4a:** `publishFullLearn` snapshot changes, `published_mono_detail_parser`, Learn UI mocks, backend TypeScript.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Vocab remote sync ready?** | **No** — PUT/GET stubs drop glosses, example meanings/pairs, provenance. |
| **Grammar remote sync ready?** | **No** — same class of stub for meanings, usage, examples, related note, provenance. |
| **Quiz remote sync ready?** | **Partial** — MCQ core fields sync; **explanations** and **provenance** do not. |
| **Listening / audio remote sync ready?** | **Partial** — scalar/metadata fields sync; **provenance** dropped; **HTTPS/audio hosting** not solved for readers. |
| **Full learn publish ready?** | **No** — `publishFullLearn` only tags PublishedMono (`publishKind`, metadata); **no learn payload** in `published_monos.content`. |
| **Biggest risk** | **Silent creator data loss** on remote sync for learn layers (same severity as pre-M3 sentence bug) until M4a wire is fixed. |
| **Recommended first implementation step** | **M4a:** Implement full learn-layer wire encode/decode + tests in Flutter; validate with Studio that `draft_*` JSON matches local mapper output after a reload. |
