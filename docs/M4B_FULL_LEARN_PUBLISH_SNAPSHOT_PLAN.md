# M4b Full Learn Publish Snapshot Plan

**Report date:** 2026-05-03  
**Type:** Milestone plan / audit only — **no app, schema, or migration changes in this file.**

**References:** [M4A_LEARN_LAYER_WIRE_FIX_REPORT.md](M4A_LEARN_LAYER_WIRE_FIX_REPORT.md), [M4_LEARN_MODULE_REMOTE_WIRE_PLAN.md](M4_LEARN_MODULE_REMOTE_WIRE_PLAN.md), [M3_MONO_FEED_READER_CLOSEOUT_REPORT.md](M3_MONO_FEED_READER_CLOSEOUT_REPORT.md), [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md), [NIMON_LANGUAGE_SYSTEM.md](NIMON_LANGUAGE_SYSTEM.md).

**Code anchors:** `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` (`publishFullLearn`, `publishReadOnly`, `mapFullDraft`), `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` (`getPublicMonoById`), `nimon-backend/src/modules/published-monos/published-mono-common.ts` (`publishedMonoDetailFromRow`), `lib/features/profile/data/published_mono_detail_parser.dart`, `lib/features/learn/**`, `lib/features/create/data/remote_story_draft_learn_layers_wire.dart`, `nimon-backend/prisma/schema.prisma` (`DraftVocabEntry`, `DraftGrammarEntry`, `DraftQuizEntry`, `DraftAudio`, `PublishedMono.content`).

---

## 1. Executive Summary

**M4a** fixed Flutter **remote draft sync** so vocabulary, grammar, quiz, and story audio **round-trip** through `PUT/GET /v1/story-drafts/:id` with the same JSON richness as local storage.

**M4b** is needed because **readers never see that data** until it is copied into **`published_monos.content`**. Today, **`publishFullLearn`** only stamps metadata (`publishKind: full_learn_v1`, `sourceDraftId`, `updatedAt`) and explicitly **does not** write learn module snapshots. Public **`GET /v1/mono/:id`** and owner **`GET /v1/published-monos/:id`** return the full `content` blob via `publishedMonoDetailFromRow`, but **`content.learn` is absent**, so Learn hub and module screens **cannot hydrate** from catalog truth and remain **mock-driven**.

M4b defines the **published learn snapshot shape**, **backend copy logic**, **API behavior** (already returns `content` — snapshot is a **data** change), **Flutter parsing and screen hydration**, **gating**, tests, and a phased implementation split.

---

## 2. Current Full Learn Publish Behavior

In `StoryDraftsService.publishFullLearn` (after readiness checks and draft row updates), the service loads **`PublishedMono`** and merges into **`content`**:

- `sourceDraftId` — linked draft id  
- `publishKind` — `'full_learn_v1'`  
- `updatedAt` — ISO timestamp  

**Comment in source:** learn module snapshots are **not written yet**; `[content.learn]` reserved for later.

**Not updated:** `core` (sentences) — unchanged by full-learn today; **`publishReadOnly`** is what writes **`content.core`** with sentence snapshots.

**Child tables** (`draft_vocab_entries`, `draft_grammar_entries`, `draft_quiz_entries`, `draft_audio`) are **loaded** on the transaction reload but **not projected** into `published_monos.content`.

---

## 3. Required PublishedMono Learn Snapshot Shape

Proposed nested object: **`content.learn`**, versioned and aligned with **draft/API JSON** already produced by `mapFullDraft` / Flutter wire (see [M4A_LEARN_LAYER_WIRE_FIX_REPORT.md](M4A_LEARN_LAYER_WIRE_FIX_REPORT.md)).

```jsonc
{
  "learn": {
    "schemaVersion": 1,
    "vocabularyKanji": {
      "entries": [ /* same objects as draft_vocab_entries.content */ ]
    },
    "grammar": {
      "entries": [ /* draft_grammar_entries.content */ ]
    },
    "quiz": {
      "entries": [ /* draft_quiz_entries.content */ ]
    },
    "audio": {
      "storyAudio": { /* draft_audio row kind storyAudio .content, or null */ }
    }
  }
}
```

| Field | Policy |
|-------|--------|
| **schemaVersion** | **1** for V1; increment when breaking shape changes. Readers ignore unknown keys; writers preserve extras when merging. |
| **vocabularyKanji.entries** | Array of **pass-through JSON** from each **`draft_vocab_entries.content`** row (order preserved), matching Flutter wire: `glosses` / `exampleMeanings` as **`{ en, my, byLanguage }`**, `examplePairs`, `provenance`, etc. |
| **grammar.entries** | Same for **`draft_grammar_entries.content`**. |
| **quiz.entries** | Same for **`draft_quiz_entries.content`**. |
| **audio.storyAudio** | **`draft_audio`** row with **`kind === 'storyAudio'`** — spread **`content`** JSON (or **`null`** if none). |
| **Source / English meaning** | Per [NIMON_LANGUAGE_SYSTEM.md](NIMON_LANGUAGE_SYSTEM.md): persist **`en`** (English Meaning / bridge) and **`my`** (Learn / Source language) inside **`LocalizedMeanings`** maps as today; **do not strip** English from snapshot — **display** remains governed by Flutter settings (e.g. show English meaning toggles). |
| **Provenance** | Include **`sourceMode`** / **`lastReviewedByCreator`** as authored; snapshot is **immutable public copy** at publish time (creator edits draft until next publish). |

**Compatibility:** Existing **`content.core`**, **`publishKind`**, **`sourceDraftId`**, top-level **`updatedAt`** remain; **`publishFullLearn`** should **merge** `learn` without deleting **`core`**.

---

## 4. Backend Implementation Plan

**Location:** `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` — inside the **`publishFullLearn`** transaction, after **`reloaded`** is fetched (it already **`include`s** `vocabEntries`, `grammarEntries`, `quizEntries`, `audios`).

**Steps:**

1. **Build a `learnPayload` object** mirroring **`mapFullDraft`** list shaping for non-sentence layers (same order sort as `mapFullDraft`: by `order` ascending):
   - `vocabularyKanji: { entries: vocabEntries.map(e => ({ ...(e.content ?? {}) })) }`
   - `grammar: { entries: grammarEntries.map(...) }`
   - `quiz: { entries: quizEntries.map(...) }`
   - `audio: { storyAudio: audios.find(kind === 'storyAudio') ? { ...row.content } : null }`

2. **Merge into `publishedMono.update`**:
   - `content: { ...prev, learn: { schemaVersion: 1, ...learnPayloadParts } }`  
   - Preserve **`prev.core`**, **`publishKind`**, etc.

3. **Idempotency:** Full-learn publish replaces **`content.learn`** with the **current** draft snapshot for that transaction (same as sentence snapshot philosophy for read-only).

4. **No new Prisma columns required** for V1 — **`PublishedMono.content`** is already **`Json`** (`schema.prisma`).

**Note:** Table names in Prisma: **`draft_vocab_entries`**, **`draft_grammar_entries`**, **`draft_quiz_entries`**, **`draft_audio`** (not “quiz_items”).

---

## 5. API Detail Behavior

| Endpoint | Behavior today | After M4b |
|----------|----------------|-----------|
| **`GET /v1/mono/:id`** (`MonoFeedService.getPublicMonoById`) | Returns **`publishedMonoDetailFromRow`** — includes raw **`content`**. | Same handler; **`content.learn`** appears automatically when written. |
| **`GET /v1/published-monos/:id`** (owner) | Same **`publishedMonoDetailFromRow`**. | Identical **`content`** shape for the same row. |

**Conclusion:** No route contract change required if clients already parse **`content`** as opaque JSON; Flutter must **parse `content.learn`** when present.

**Feed list:** `GET /v1/mono/feed` still omits full **`content`** from list items (summary only); detail hydration loads learn via **detail** call — acceptable unless product wants **`hasLearn`** teaser fields later.

---

## 6. Flutter Parser / DTO Plan

**Today:** `published_mono_detail_parser.dart` focuses on **`content.core.sentences`** for **`MonoContent`** (reading). It does not read **`content.learn`**.

**Proposed:**

1. Add **`learnPublishedSnapshotFromContent(Object? contentRoot)`** (or similar) that:
   - Reads **`content`** map → **`learn`** map.
   - Validates **`schemaVersion`** (support **1**; unknown → treat as empty or best-effort parse per policy).
   - Returns a **typed model** (e.g. **`LearnPublishedSnapshotV1`**) with:
     - Parsed lists using the **same tolerance** patterns as **`remote_story_draft_learn_layers_wire.dart`** (optional: reuse wire **`FromWireJson`** helpers by converting maps to **`Map<String, Object?>`** per entry).

2. **DTO alignment:** Prefer parsing into structures compatible with **`VocabularyKanjiEntryDto`**, **`GrammarEntryDto`**, **`QuizEntryDto`**, **`StoryAudioDto`** or thin view-models for Learn UI (`VocabKanjiItem`, `GrammarPattern`, quiz MCQ) — **mapping layer** separate from parser.

3. **Unit tests:** Parser tests with JSON fixtures (`content` with/without `learn`, malformed entries skipped).

---

## 7. Learn Screen Hydration Plan

| Screen / area | Current source | Proposed |
|---------------|----------------|----------|
| **`LearnHubScreen`** | `contentId` only; cards often SnackBar | Optional: show “Learn available” when snapshot non-empty; gate deep links. |
| **`VocabKanjiListScreen`** | `mockItems` | If **`learn.vocabularyKanji.entries`** non-empty → map to **`VocabKanjiItem`**; else **empty state** or **optional** mock fallback behind flag (product decision — prefer **honest empty** per §8). |
| **`GrammarPatternListScreen`** | `mockPatterns` | Map grammar entries → **`GrammarPattern`**; else empty. |
| **`QuizSetupScreen` / `QuizPlayScreen`** | **`QuizMockBank`** | Build session from **`quiz.entries`** when present; else empty / disable start or mock fallback policy. |
| **`ListeningPronunciationScreen`** | **`ListeningSampleData`** | Use **`learn.audio.storyAudio`** for **`audioUrl`** (prefer **`https`** **`sourceUrl`**); transcript lines may require **product definition** (V1 may only ship **audio URL + displayName** unless transcript JSON is added later). |
| **`LearnScreen`** | **`_mockLearnContent`** | Lowest priority; optional article blocks from snapshot later or remain demo-only. |

**Mocks when no snapshot:** Keep compile-time mocks **unused** in production paths when **`content.learn`** is missing and **`publishKind`** is **`read_only_v1`** — show **empty / locked** messaging rather than fake story data.

---

## 8. Full Learn Gating

| **`publishKind`** | **`content.learn`** | UX expectation |
|-------------------|---------------------|----------------|
| **`read_only_v1`** | Absent or ignored | Learn modules **must not** imply published learn — **no** fictional vocab/quiz from mocks tied to catalog id (use empty state or “complete modules in creator / publish full learn”). |
| **`full_learn_v1`** | Present, non-empty | Enable Learn module **real data** paths when parser returns entries. |
| **`full_learn_v1`** | Missing / empty (legacy row or failure) | **Honest empty state** — do not substitute mocks; optional banner “Republish full learn” for owner. |
| **Unknown / older rows** | — | Treat as **no learn** until republish. |

**Flutter:** Combine **`displayPublishKind`** / **`publishKind`** from DTO with **`learnPublishedSnapshotFromContent` != null && hasEntries** before switching off mocks.

---

## 9. Tests Needed

### Backend (Nest)

- **`publishFullLearn`** integration/unit test: after success, **`published_monos.content.learn`** exists, **`schemaVersion === 1`**, entries lengths match draft rows, **`content.core`** preserved for prior read-only publish.
- Regression: **`publishReadOnly`** does not wipe **`learn`** if already present — define merge policy (typically RO updates **`core` only**).

### Flutter

- Parser: **`learn`** present/absent**,** malformed entry skipped**, audio null.
- Widget / provider (phase M4b3): detail provider exposes snapshot; list screens receive mapped items.

### Learn / E2E (manual in §10)

- End-to-end: remote save → full learn publish → detail JSON contains **`learn`**.

---

## 10. Manual Smoke Checklist

1. **Create** vocab, grammar, quiz, and optional audio on a draft; **remote save** (`NIMON_USE_REMOTE_DRAFTS=true`).
2. **Publish read-only** (ensures **`publishedMonoId`** + **`core`**).
3. **Publish full learn** (authenticated, readiness satisfied).
4. **Inspect** Postgres **`published_monos.content`**: verify **`learn`** subtree and **`publishKind: full_learn_v1`**.
5. **Call** **`GET /v1/mono/:monoId`** — confirm **`content.learn`** in JSON.
6. **Open** Mono feed → story detail → Learn hub (after M4b3 wiring).
7. **Verify** Vocabulary / Grammar / Quiz / Listening show **published** data or expected empty states.

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| **Payload bloat** | `content` grows with large quiz/grammar; monitor size; future: lazy endpoint or compression if needed. |
| **Audio URLs** | Local paths in snapshot are useless to other users — document that **HTTPS `sourceUrl`** is required for public listening; upload pipeline remains separate. |
| **Schema versioning** | Bump **`learn.schemaVersion`** on breaking changes; keep parsers tolerant. |
| **Stale snapshot** | Editing draft after full learn sets **`hasUnpublishedCoreChanges`** — Learn tab may show old snapshot until republish; surface “update publish” when dirty. |
| **Backward compatibility** | Old **`full_learn_v1`** rows without **`learn`** — empty states; no crash. |
| **`publishReadOnly` overwrite** | Ensure **`update`** merges **`learn`** correctly when updating **`core`** only. |

---

## 12. Recommended Implementation Split

| Phase | Scope |
|-------|--------|
| **M4b1** | **Backend:** `publishFullLearn` writes **`content.learn`**; merge tests; verify **`publishReadOnly`** merge behavior. |
| **M4b2** | **Flutter:** `LearnPublishedSnapshot` parser + DTO/view-model mapping + unit tests; optional extension of **`PublishedMonoDetailDto`** consumption layer. |
| **M4b3** | **Learn screens:** Hydrate from provider; empty states; mock fallback policy (prefer off). |
| **M4b4** | **Smoke:** Manual checklist + optional integration test against dev API. |

---

## 13. Exact Cursor Prompt For M4b1

Use this when implementing **backend snapshot only** (no Flutter in same PR unless coordinated):

---

**M4b1 — Full-learn published learn snapshot (NestJS only)**

**Constraints:** Do **not** change Prisma schema or run migrations in this task. Do **not** modify Flutter. Focus on **`StoryDraftsService.publishFullLearn`** (and any small helper in `story-drafts.service.ts`).

**Goal:** When **`publishFullLearn`** succeeds, **`published_monos.content`** must include a **`learn`** object built from the draft’s **`draft_vocab_entries`**, **`draft_grammar_entries`**, **`draft_quiz_entries`**, and **`draft_audio`** rows (same ordering as **`mapFullDraft`**: sort children by **`order`** ascending).

**Shape:**

```ts
content.learn = {
  schemaVersion: 1,
  vocabularyKanji: { entries: [...] }, // each entry = spread row.content JSON
  grammar: { entries: [...] },
  quiz: { entries: [...] },
  audio: { storyAudio: <spread draft_audio content for kind storyAudio> | null },
};
```

**Merge:** When updating **`PublishedMono`**, shallow-merge with existing **`content`** so **`core`** from **`publishReadOnly`** is **preserved**. Set/update **`publishKind: 'full_learn_v1'`**, **`sourceDraftId`**, **`updatedAt`** as today.

**Tests:** Add or extend **`story-drafts.service`** specs: mock Prisma transaction; assert **`publishedMono.update`** receives **`content.learn`** with expected entry counts; assert **`core`** unchanged when present.

**Files:** `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` (primary), tests alongside existing story-drafts tests.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Full learn publish currently ready?** | **No** — only metadata is written; **`content.learn`** is **not** populated. |
| **Proposed `content.learn` shape** | **`{ schemaVersion: 1, vocabularyKanji, grammar, quiz, audio }`** — mirrors draft/API layer JSON (pass-through **`content`** blobs). |
| **Backend files likely to change** | **`story-drafts.service.ts`** (`publishFullLearn`; possibly **`publishReadOnly`** merge review); **`story-drafts.service.spec.ts`** (or equivalent). |
| **Flutter files likely to change later** | **`published_mono_detail_parser.dart`** or new **`learn_published_snapshot*.dart`**; Mono/detail providers; **`lib/features/learn/**`** screens to consume snapshot + empty states. |
| **Biggest risk** | **`publishReadOnly`** **`content`** updates **overwriting** **`learn`** if merge is wrong — must **preserve** **`learn`** when updating **`core`**. |
| **First implementation step** | **M4b1:** Implement **`content.learn`** write + **`publishReadOnly`** merge audit/tests so RO publish does not erase learn snapshot. |
