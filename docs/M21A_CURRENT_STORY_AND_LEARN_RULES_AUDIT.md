# M21A — Current Storytelling & Full Learn Mode Rules (Audit)

**Scope:** Read-only audit of Flutter creator/editor + backend validation as of M20G. **No code changes.**

**Stack label:** Rules live in the **M13A/M13B** validation foundation (`lib/core/validation/`, `nimon-backend/src/common/validation/`). There is no `M21A` marker in source.

---

## 1. Executive summary

Publishing is gated in **three layers**:

1. **UI readiness** (`creator_completion_rules.dart`, `creator_readiness.dart`) — disables publish when duration-band **minimum counts** are not met; stricter on basics (category, level, duration) than the publish gate.
2. **Client publish preflight** (`validateStoryPublishData` in `publish_validation.dart`, invoked from `creator_drawer_publish.dart`) — blocking vs warning issues; warnings allow “Publish anyway”.
3. **Backend publish** (`validateStoryPublishInput` in `publish-validation.ts`, `StoryDraftsService.publishReadOnly` / `publishFullLearn`) — only **blocking** issues return `400 validation_failed`; warnings do **not** block HTTP publish.

**Read-only publish** requires story title/description rules + at least one Japanese sentence + JLPT×duration sentence/body limits when level and band resolve. Learn modules are **not** validated.

**Full-learn publish** adds: all four module workflow keys `completed`, JLPT×band vocab/grammar/quiz **counts**, and per-item vocab meaning/furigana, grammar headline, quiz shape. **Listening** is only `audio: completed` in workflow — no transcript, URL, or audio file validation at publish.

**Important mismatches:** UI minimum sentence/vocab/quiz counts are **lower** than publish minimums (e.g. N5 `3_5`: UI 8 sentences vs publish 10). Vocab “complete” in UI = non-empty `termJapanese` only; publish requires **meaning** + **furigana** when kanji. Quiz UI forces **4** options; publish allows **2–4**. `creator_publish_validation.dart` duplicates looser checks but is **not wired** into the live publish path.

Flutter and backend **limit tables and validators are intentionally mirrored** (Flutter `story_validators.dart` comments “Mirrors backend `STORY_SENTENCE_LIMITS` exactly”).

---

## 2. Storytelling current rules

### 2.1 Validity & per-sentence fields

| Rule | Where | Detail |
|------|--------|--------|
| Valid sentence (UI counts) | `StorySentenceItem.isValidV1` — `lib/features/create/story_v1_model.dart` | Non-empty `japaneseText` only |
| Japanese required | Same | Yes for `isValidV1` |
| Translation / meanings | `StorySentenceItem.meanings`, `supportMeaningsSummaryV1` | **Optional**; not in publish gate |
| Furigana | `reading`, `furiganaSpans` | **Optional**; not in publish gate |
| `orderIndex` | Model field | Used for display/sort; **not** validated at publish |
| Empty sentences | Excluded from valid count | Rows with empty Japanese do not count toward min/max |
| Duplicate `orderIndex` | Backend `story-drafts.service.ts` (`persistSentences` / PUT) | Logged and **ignored for DB order**; payload renumbered by array index; duplicates do not fail save |

### 2.2 UI readiness (duration band)

**Class:** `CreatorV1DurationThresholds` — `lib/features/create/creator_completion_rules.dart`  
**Function:** `computeStorySentencesStatus`, `computeReadOnlyReady` — `lib/features/create/creator_readiness.dart`

| Band key | Min valid sentences (UI) |
|----------|--------------------------|
| `3_5` | 8 |
| `5_7` | 14 |
| `7_9` | 20 |

Requires resolved duration band (`targetDurationBandKey` or legacy `promptSourceNote` parse). **UI only** — not enforced in `validateStoryPublishData` for category/level/duration.

### 2.3 Publish gate (read-only & full-learn)

**Functions:** `extractStorySentenceMetrics`, `validateStoryPublishData` — `lib/core/validation/publish_validation.dart`  
**Limits:** `storySentenceLimits` — `lib/core/validation/story_validators.dart` (mirrors `STORY_SENTENCE_LIMITS` — `nimon-backend/src/common/validation/story-validation.ts`)

| Rule | Severity | When applied |
|------|----------|--------------|
| ≥1 sentence with Japanese (`japanese`, `japaneseText`, `jp`, `textJa`, `text`, `value`) | **Blocking** | Always |
| `validCount < minSentences` | **Blocking** | JLPT + band resolved |
| `validCount > maxSentences` | **Blocking** | JLPT + band resolved |
| `totalJapaneseChars > maxChars` | **Blocking** | JLPT + band resolved |
| Missing JLPT | **Warning** (`story.limits.skippedNoJlpt`) | Limits skipped |
| Missing band | **Warning** (`story.limits.skippedNoBand`) | Limits skipped |

**Example (N5, band `3_5`):** min 10, max 35 sentences, max 900 Japanese chars.

**JLPT normalization:** `normalizeJlptLevel` — `lib/core/validation/story_duration_band.dart` / `story-duration-band.ts`  
**Band resolution:** `targetDurationBandKey` (`3_5`/`5_7`/`7_9`) or `durationSeconds` ranges — `resolveStoryDurationBand`

Full sentence limit matrix: see `storySentenceLimits` / `STORY_SENTENCE_LIMITS` (N1–N5 × three bands).

### 2.4 Save vs publish

| Action | Validation |
|--------|------------|
| Draft autosave / PUT | No sentence count gate; backend may log duplicate `orderIndex` |
| Basics form save | `validateStoryTitle` / `validateStoryDescription` with `ValidationMode.draft` — `create_story_basics_form.dart` |
| Publish | `validateStoryPublishData` + backend `validateStoryPublishInput` |

---

## 3. Vocabulary current rules

### 3.1 UI readiness

**Functions:** `_validVocabCount`, `computeVocabularyStatus`, `moduleMeetsV1Completion` — `creator_completion_rules.dart`  
**Validity:** `VocabularyKanjiEntry.isValidV1` — `story_v1_model.dart` → `termJapanese` non-empty only

| Band | UI min entries |
|------|----------------|
| `3_5` | 6 |
| `5_7` | 9 |
| `7_9` | 12 |

### 3.2 Full-learn publish only

**Count gate:** `vocabularyLimits` — `learn_validators.dart` / `VOCABULARY_LIMITS` — `learn-validation.ts`  
**Function:** `validateStoryPublishData` (full learn branch) — counts entries with non-empty `termJapanese` / `term`

**Example (N5, `3_5`):** min 8, max 18 entries.

**Per-entry (skipped if `termJapanese` empty):**

| Field | Function | Rule | Severity |
|-------|----------|------|----------|
| Meaning (my or en gloss) | `validateVocabularyMeaning` — `learn_validators.dart` | Required on full learn; length 1–80; no emoji, line breaks, HTML, URL, `#` | **Blocking** |
| Reading / furigana | `validateFurigana` / `validateFuriganaReading` | Required if `type == kanji` or surface contains kanji; max 40 chars; ≤3 `/` segments; kana-only | **Blocking** |
| Example pairs | `VocabularyKanjiEntry.examplePairs` (max 3) | **Not** validated at publish | — |
| Per-entry JLPT | — | **Not** required (story-level `level` drives tables) | — |

**Editor-only:** `_maxVocabPickLength = 48` — `story_creator_vocab_kanji_editor_screen.dart` (phrase pick UI, not publish).

**Read-only publish:** vocabulary **not** required (empty learn allowed — `publish_validation_gate_test.dart`).

---

## 4. Grammar current rules

### 4.1 UI readiness

**Validity:** `GrammarEntry.isValidV1` — `story_v1_model.dart` → non-empty `headline`  
**UI mins:** `CreatorV1DurationThresholds` — e.g. `3_5` → 3 grammar entries

### 4.2 Full-learn publish only

**Count:** `grammarPatternLimits` / `GRAMMAR_PATTERN_LIMITS` — entries with non-empty `headline` or `title`  
**Example (N5, `3_5`):** min 3, max 5

**Per-entry:** `validateGrammarPatternTitle` — `learn_validators.dart` / `validateGrammarPatternTitle` — `learn-validation.ts`

| Field | Publish validated? |
|-------|-------------------|
| `headline` | Yes — required; 2–40 chars; no emoji, line breaks, HTML, URL |
| `form`, `meanings`, `usage`, `examples`, `mistakeWrong/Correct`, `relatedNote` | **No** at publish |

---

## 5. Quiz current rules

### 5.1 UI readiness

**Validity:** `QuizEntry.isValidV1` — `story_v1_model.dart`

- Non-empty `prompt`
- **Exactly 4** options, all non-empty
- `correctIndex` in 0..3

**UI mins:** e.g. `3_5` → 4 quiz entries (`CreatorV1DurationThresholds`)

**Categories (storage):** `CreatorQuizCategory` — vocabulary, kanji, grammar, sample_sentence (`story_v1_model.dart`)

### 5.2 Full-learn publish only

**Count:** `quizLimits` / `QUIZ_LIMITS`; effective max = `min(band.max, band.absoluteMax, quizGlobalHardMax)` where `quizGlobalHardMax = 24`  
**Example (N5, `3_5`):** min 6, max 10 (capped by absoluteMax 18)

**Per-item:** `validateQuizItem` — `learn_validators.dart` / `learn-validation.ts`; `parseQuizEntry` — `publish_validation.dart`

| Rule | Detail | Severity |
|------|--------|----------|
| Category | `Vocabulary`, `Grammar`, `Sentence` (maps `sample_sentence` → Sentence) | **Blocking** if invalid |
| Question | 5–120 chars; no HTML/URL | **Blocking** |
| Options | **2–4** non-empty, unique (case-insensitive) | **Blocking** |
| Correct answer | Required; must match exactly one option | **Blocking** |
| Duplicate questions | Normalized question text unique across quiz set | **Blocking** |

**Mismatch:** Creator model **asserts 4 options**; publish allows 2–4 non-empty options after normalization.

**Read-only:** quiz not required.

---

## 6. Listening current rules

| Rule | Where | Detail |
|------|--------|--------|
| UI “complete” | `computeListeningStatus` — `creator_completion_rules.dart` | ≥1 `StoryAudioAsset.isValidV1` |
| `isValidV1` | `story_v1_model.dart` | Non-empty `sourceUrl` **or** `localFileName` **or** `localPath` |
| Full-learn publish | `fullLearnModulesComplete` — `publish_validation.dart` | `moduleWorkflowStatuses['audio'] == 'completed'` | **Blocking** |
| Transcript | — | **Not** validated at publish |
| `audioUrl` / upload | Upload-time media rules — `media-validation.ts`, `media-file-limits.ts` | Separate from publish gate |
| Demo/sample audio | No explicit “demo forbidden” rule at publish | Any valid V1 asset + workflow flag suffices |
| Listening quiz questions | — | **None** at publish |

**Workflow sync:** `syncModuleWorkflowWithContent` — `creator_completion_rules.dart` auto-sets module `completed` when `moduleMeetsV1Completion(id)`.

---

## 7. Read-only publish requirements

### 7.1 Endpoints & orchestration

| Piece | Path / symbol |
|-------|----------------|
| API | `POST /v1/story-drafts/:id/publish/read-only` — `story-drafts.controller.ts` |
| Service | `StoryDraftsService.publishReadOnly` — `story-drafts.service.ts` |
| Validation | `validateStoryPublishInput(..., ValidationMode.ReadOnlyPublish)` |
| Gate | `assertNoBlockingValidationIssues` — `validation-exception.ts` |
| Client preflight | `_preflightCreatorPublish` → `ValidationMode.readOnlyPublish` — `creator_drawer_publish.dart` |
| Client readiness | `computeReadOnlyReady` → `publishReadingOnlyToDisk` — `story_creator_provider.dart` |

### 7.2 Required / blocking

- Title: `validateStoryTitle` (5–80 chars, safety rules)
- ≥1 Japanese sentence
- Sentence count + total Japanese chars when JLPT + band set
- Unsafe title HTML (blocking)

### 7.3 Warnings only (client can “Publish anyway”; server does not block)

- Empty description (`story.description.recommended`)
- Missing JLPT / missing band (skips count limits)

### 7.4 Not required

- Vocabulary, grammar, quiz, audio modules
- Category, level, duration band (for publish gate — only for limit tables)
- Sentence translation, furigana, audio timestamps

### 7.5 Snapshot behavior

`publishReadOnly` writes `content.core` (`buildPublishedCorePayloadFromDraft`); **preserves** existing `content.learn` on mono — `story-drafts.service.ts`.

---

## 8. Full-learn publish requirements

### 8.1 Endpoints & preconditions

| Piece | Path / symbol |
|-------|----------------|
| API | `POST /v1/story-drafts/:id/publish/full-learn` |
| Service | `StoryDraftsService.publishFullLearn` |
| Precondition | `publishedMonoId` must exist or `422 published_mono_missing` (not validation_failed) |
| Client | `computeFullLearnReady`, `publishFullLearnToDisk` |

### 8.2 Everything in read-only **plus**

- `fullLearnModulesComplete`: `vocabulary_kanji`, `grammar`, `quiz`, `audio` → `completed`
- Vocab / grammar / quiz **counts** in JLPT×band range
- Per vocab: meaning + furigana rules
- Per grammar: headline rules
- Per quiz: `validateQuizItem` rules + no duplicate questions

### 8.3 Snapshot behavior

Writes `publishKind: 'full_learn_v1'`, `content.core` + `content.learn` (`buildLearnSnapshotFromDraft`) — sorted vocab/grammar/quiz, `audio.storyAudio` from `kind === 'storyAudio'`.

---

## 9. Flutter / backend rule mismatch table

| Topic | Flutter | Backend | Match? |
|-------|---------|---------|--------|
| Limit tables (sentences, vocab, grammar, quiz) | `story_validators.dart`, `learn_validators.dart` | `story-validation.ts`, `learn-validation.ts` | **Yes** (explicit mirror) |
| Publish gate logic | `validateStoryPublishData` | `validateStoryPublishInput` | **Yes** (parallel structure) |
| Warning severity on publish | UI can proceed | Warnings never block HTTP | **By design** |
| UI readiness mins | `CreatorV1DurationThresholds` | Not enforced server-side | **Flutter-only** (lower mins) |
| Basics category/level/duration | Required for UI complete | Not in publish validators | **Flutter-only** |
| Vocab UI `isValidV1` | Term only | Publish: meaning + furigana | **Flutter UI looser** |
| Quiz option count | Model: exactly 4 | Publish: 2–4 | **Mismatch** |
| Sentence furigana/translation | Optional | Optional | **Match** |
| Listening content | Workflow + UI asset presence | Workflow only | **Match** (both loose) |
| Grammar body fields | Not publish-validated | Not publish-validated | **Match** |
| `creator_publish_validation.dart` | `missingForReadingOnly` etc. | N/A | **Flutter-only, unused in lib/** |
| Quota limits | UX dialogs — `quota_exceeded_dialog.dart` | `FREE_TIER_QUOTAS` — `free-tier-quotas.ts` | **Mirrored keys** (separate from content validation) |
| Draft PUT DTO | Local + remote save | `StoryDraftWriteDto` class-validator | Structural only; **not** publish rules |

---

## 10. Existing tests found

### Flutter — publish & validation

| File | Documents |
|------|-----------|
| `test/core/validation/publish_validation_gate_test.dart` | RO missing title; empty learn OK; HTML title; FL missing vocab meaning; empty description warning |
| `test/core/validation/validation_foundation_test.dart` | Title, limit table samples, `validateQuizItem` |
| `test/features/create/publish_validation_sheet_test.dart` | Blocking issue sheet UI |
| `test/features/create/story_creator_quota_publish_and_draft_test.dart` | `computeReadOnlyReady` with 8 sentences + `3_5` band |
| `test/features/create/remote_story_draft_full_learn_publish_sequence_test.dart` | Remote PUT + publish sequence |
| `test/features/create/m20e_published_edit_flow_test.dart` | Publish completion / dirty flags |
| `test/features/create/m20f_publish_stale_conflict_test.dart` | Publish conflict (orthogonal) |
| `test/features/create/story_draft_remote_publish_errors_test.dart` | Parses backend `validation_failed` JSON |

### Backend

| File | Documents |
|------|-----------|
| `nimon-backend/src/common/validation/publish-validation.spec.ts` | RO vs FL; warnings pass; adapter |
| `nimon-backend/src/common/validation/validation.spec.ts` | Title/description; limit constants |
| `nimon-backend/src/common/validation/validation-exception.spec.ts` | Blocking vs warnings |
| `nimon-backend/src/modules/story-drafts/story-drafts.basics-validation.spec.ts` | Draft unsafe title; publish missing title |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.spec.ts` | Snapshots, duplicate orderIndex handling |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.quota.spec.ts` | `fullLearnValidDraft` fixture |

### Docs (prior reports)

- `docs/M13_NIMON_VALIDATION_AND_LIMITATION_STANDARD.md`
- `docs/M13B_PUBLISH_VALIDATION_GATE_REPORT.md`
- `docs/M13A_VALIDATION_FOUNDATION_IMPLEMENTATION_REPORT.md`

---

## 11. Gaps and recommendations

### Rules only in Flutter

- `CreatorV1DurationThresholds` UI mins vs publish mins
- `computeStoryBasicsStatus` (category, level, duration required)
- `creator_publish_validation.dart` (unused in live publish path)
- Drawer button gating via `isStoryReviewModeAllowed` — `story_creator_review_display.dart`
- Editor field limits (e.g. vocab pick 48 chars)

### Rules only in backend

- `If-Match` / etag on publish — `requireIfMatch`
- `published_mono_missing` before full learn
- Sentence persistence renumbering / duplicate orderIndex logging
- Free-tier quotas on first publish — `assertCanRevealOnePublishedTabMono`, `FREE_TIER_QUOTAS`
- Media upload size/type — `media-validation.ts`

### Missing / thin test coverage

- No single test matrix for all JLPT×band limit combinations (spot checks only)
- Listening/audio content not covered at publish
- Grammar `examples` / vocab `examplePairs` not covered (correctly absent from validators)
- UI vs publish min mismatch not asserted (e.g. 8 vs 10 sentences)
- `creator_publish_validation.dart` unused — risk of drift

### Confusing / inconsistent product rules

1. User can pass **UI readiness** but fail **publish** (higher publish mins).
2. User can mark vocab “complete” with term only, then fail publish on missing meaning/furigana.
3. Quiz: UI requires 4 options; publish allows 2–4 (model prevents 2–3 in practice unless wire/API bypasses UI).
4. Missing JLPT or duration → **warnings** and **skipped** band limits (publish possible with only ≥1 sentence).
5. Backend warnings do not block; Flutter may still show “Publish anyway” for warnings — server accepts.

---

## 12. CSV import implications

For a bulk import path to succeed **read-only** and **full-learn** publish without manual fixes:

1. **Story basics:** Title 5–80 chars (publish); description ≤160 (blocking if violated); empty description allowed with warning.
2. **JLPT + duration band:** Set `basics.level` (N1–N5) and `targetDurationBandKey` (`3_5`/`5_7`/`7_9`) or imports will skip count limits (warning only) but still need ≥1 sentence.
3. **Sentences:** Map to `japaneseText` (or wire aliases); meet **publish** min/max for target JLPT×band, not UI mins; empty rows excluded; assign stable `orderIndex` (backend renumbers by array order anyway).
4. **Vocabulary:** For full learn: count in `VOCABULARY_LIMITS` range; each row needs `termJapanese`, `glosses.my` or `glosses.en`, and `reading` when kanji; `type: kanji` triggers furigana rules.
5. **Grammar:** Count in range; each row needs `headline` 2–40 chars; other grammar fields optional for publish.
6. **Quiz:** Count in range; categories mapped to Vocabulary/Grammar/Sentence; questions 5–120 chars; 2–4 unique options; single correct answer; no duplicate normalized questions; if importing via creator model, plan for **4** options.
7. **Listening:** Set `moduleWorkflowStatuses.audio = completed` and provide `audio.storyAudio` row or local/upload metadata so UI `isValidV1` passes; no transcript required for publish.
8. **Module flags:** For full learn, set all four modules to `completed` (or run `syncModuleWorkflowWithContent` equivalent after counts satisfied).
9. **Full learn order:** Read-only publish first (creates `publishedMonoId`); then full-learn publish.
10. **Quotas:** Respect `draftStories: 50`, `publishedMonos: 30` per owner — `free-tier-quotas.ts`.
11. **Do not rely on** `creator_publish_validation.dart` or UI-only thresholds for import validation — use `validateStoryPublishData` / backend `validateStoryPublishInput` as source of truth.

---

## Appendix — Key symbols quick index

| Area | Flutter | Backend |
|------|---------|---------|
| Publish gate | `validateStoryPublishData` — `publish_validation.dart` | `validateStoryPublishInput` — `publish-validation.ts` |
| Story title/desc | `validateStoryTitle`, `validateStoryDescription` — `story_validators.dart` | `story-validation.ts` |
| Learn per-item | `learn_validators.dart` | `learn-validation.ts` |
| UI readiness | `creator_completion_rules.dart`, `creator_readiness.dart` | — |
| Drawer publish | `performCreatorDrawerPublish` — `creator_drawer_publish.dart` | `publishReadOnly`, `publishFullLearn` — `story-drafts.service.ts` |
| Preflight map | `storyPublishDataFromCreator` — `creator_publish_preflight.dart` | `storyPublishInputFromDraftRow` — `publish-validation.ts` |
| Modes | `ValidationMode` — `validation_mode.dart` | `validation-mode.ts` |

### Product quotas (not content validation)

`FREE_TIER_QUOTAS` — `nimon-backend/src/common/limits/free-tier-quotas.ts`: published monos 30, draft stories 50, saved monos 50, collections 10, collection items 30.
