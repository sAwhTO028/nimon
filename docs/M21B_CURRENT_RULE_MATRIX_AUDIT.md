# M21B — Current Storytelling & Full Learn Rule Matrix (Audit)

**Audit only — no code changes.** Source order: backend publish validation → Flutter publish validation → tests → constants. Docs used only where they restate code already cited.

---

## 1. Executive summary

- **Publish truth (blocking HTTP):** `validateStoryPublishInput` — `nimon-backend/src/common/validation/publish-validation.ts` + `assertNoBlockingValidationIssues` — `nimon-backend/src/common/validation/validation-exception.ts`, invoked from `StoryDraftsService.publishReadOnly` / `publishFullLearn` — `nimon-backend/src/modules/story-drafts/story-drafts.service.ts`.
- **Client preflight (before POST):** `validateStoryPublishData` — `lib/core/validation/publish_validation.dart`, called from `performCreatorDrawerPublish` / `_preflightCreatorPublish` — `lib/features/create/creator_drawer_publish.dart` via `storyPublishDataFromCreator` — `lib/features/create/creator_publish_preflight.dart`.
- **JLPT × duration limits:** `STORY_SENTENCE_LIMITS` — `nimon-backend/src/common/validation/story-validation.ts` = `storySentenceLimits` — `lib/core/validation/story_validators.dart` (comment: mirrors backend). `VOCABULARY_LIMITS` / `GRAMMAR_PATTERN_LIMITS` / `QUIZ_LIMITS` + `QUIZ_GLOBAL_HARD_MAX` — `nimon-backend/src/common/validation/learn-validation.ts` = `vocabularyLimits` / `grammarPatternLimits` / `quizLimits` + `quizGlobalHardMax` — `lib/core/validation/learn_validators.dart`.
- **Warnings never block backend publish** — only `ValidationSeverity.Blocking` triggers `validation_failed`.
- **Flutter-only readiness (publish button):** `computeReadOnlyReady` / `computeFullLearnReady` — `lib/features/create/creator_readiness.dart` + `CreatorV1DurationThresholds` — `lib/features/create/creator_completion_rules.dart` (different numeric **mins** than publish limits).
- **Cover image:** Not in publish validation. Upload limits: `readCoverMaxBytesFromEnv` / `readAudioMaxBytesFromEnv` — `nimon-backend/src/modules/media/media-file-limits.ts` (defaults 10 MiB cover, 50 MiB audio); MIME rules — `nimon-backend/src/modules/media/media.validation.ts`; `MediaService.saveCover` / `saveAudio` — `nimon-backend/src/modules/media/media.service.ts`.
- **Full learn prerequisite:** `publishedMonoId` required or `422` — `story-drafts.service.ts` (`unmet: ['published_mono_missing']`), **after** `assertNoBlockingValidationIssues(learnCheck)` (validation runs first).

---

## 2. Standard rule matrix table

Column **Min/Max**: numeric limits from code, or “—” when not applicable. **Required?** = enforced as blocking for that gate unless noted. **Save** = draft PATCH / local save path. **Publish** = read-only or full-learn publish gate (`validateStoryPublishInput` / `validateStoryPublishData`).

| Area | Section | Field/Item | Min | Max | Required? | Optional? | Blocking? | Warning? | Save Rule | Publish Rule | Flutter Source | Backend Source | Tests | Notes |
|------|---------|------------|-----|-----|-----------|-----------|-----------|----------|-----------|--------------|----------------|----------------|-------|-------|
| Story basics | Title | `title` (publish length) | 5 chars | 80 chars | Yes (RO/FL publish) | — | Yes | Empty title: warn draft only | `validateStoryTitle` draft: unsafe/linebreak block only | Non-empty + length + safety | `validateStoryTitle` — `lib/core/validation/story_validators.dart` | `validateStoryTitle` — `nimon-backend/src/common/validation/story-validation.ts` | `publish_validation_gate_test.dart`; `story-drafts.basics-validation.spec.ts`; `validation.spec.ts` | Emoji ≤1, no numbers-only, symbols-only, 4+ repeat (publish) |
| Story basics | Title | `title` (draft) | — | — | Recommended | — | Partial | Yes if empty | Unsafe HTML/script, line breaks block | — | same | same | `publish_validation_gate_test.dart` | Empty → warning `story.title.recommended` |
| Story basics | Description | `description` (publish) | — | 160 chars | No (empty allowed) | Yes | If violated | Yes if empty | Unsafe/linebreak block draft | Max len + URL≤1 + hashtag≤4 + emoji≤2 + repeat rules | `validateStoryDescription` — `story_validators.dart` | `validateStoryDescription` — `story-validation.ts` | `publish_validation_gate_test.dart` | Empty description → **warning** on publish |
| Story basics | Description | `description` (draft) | — | — | — | — | Partial | — | Unsafe/linebreak block | — | same | same | `validation.spec.ts` | |
| Story basics | JLPT | `level` / `levelRaw` | — | — | For **band limits** | Yes | — | Yes if unmapped | Not validated length on publish | Needed to apply sentence/vocab/grammar/quiz tables | `normalizeJlptLevel` — `lib/core/validation/story_duration_band.dart` | `normalizeJlptLevel` — `nimon-backend/src/common/validation/story-duration-band.ts` | `publish-validation.spec.ts` | Unmapped → warning `story.limits.skippedNoJlpt`; limits skipped |
| Story basics | Category | `category` | — | — | **Not** in publish gate | — | — | — | DTO: string required on write | Not in publish validators | — (publish) | `StoryDraftBasicsWriteDto` — `nimon-backend/src/modules/story-drafts/dto/story-draft.requests.ts` | — | **Flutter UI** requires for `computeStoryBasicsStatus` — `creator_completion_rules.dart` |
| Story basics | Duration band | `targetDurationBandKey` | — | — | For **band limits** | Yes | — | Yes if unresolved | Parsed or key `3_5`/`5_7`/`7_9` | Needed for limits | `resolveStoryDurationBand` — `story_duration_band.dart` | `resolveStoryDurationBand` — `story-duration-band.ts` | `publish-validation.spec.ts` | Legacy parse `promptSourceNote` — same Dart/TS helpers |
| Story basics | Cover | `coverImageUrl` | — | — | No (publish) | Yes | Upload only | — | Optional string on DTO | **Not** in `validateStoryPublish*` | Persist via basics | `StoryDraftBasicsWriteDto.coverImageUrl` | `media.service.spec.ts`; `media.controller.spec.ts` | Publish does not require cover |
| Story basics | Cover upload | file size | 1 B | `MEDIA_COVER_MAX_BYTES` or default **10485760** | For upload | — | Yes if exceeded | — | — | — | — | `readCoverMaxBytesFromEnv` — `media-file-limits.ts`; `MediaService.coverMaxBytes` — `media.service.ts` | `media.service.spec.ts` | Default 10 MiB |
| Story basics | Cover upload | MIME | — | — | jpeg/png/webp (+jpg alias) | — | Yes if invalid | — | — | — | — | `assertSupportedCoverMime` — `media.validation.ts` | `media.service.spec.ts` | |
| Storytelling | Sentence count | per JLPT×band | **See Appendix A** | **See Appendix A** | If JLPT+band+≥1 sentence | — | Yes if outside range | If JLPT/band missing | Not in publish gate | Applied | `storySentenceLimits` + `validateStoryPublishData` — `story_validators.dart`; `publish_validation.dart` | `STORY_SENTENCE_LIMITS` + `validateStoryPublishInput` — `story-validation.ts`; `publish-validation.ts` | `validation.spec.ts` (samples); `publish-validation.spec.ts` | Example N5 `3_5`: min **10**, max **35**, max chars **900** |
| Storytelling | Sentence body | Japanese primary text | 1 (non-empty) | — | ≥1 sentence story-wide | — | Yes if zero valid | — | Always storable | ≥1 valid row | `extractStorySentenceMetrics` — `publish_validation.dart` | `extractStorySentenceMetrics` — `publish-validation.ts` | `publish_validation_gate_test.dart` | Keys: `japanese`,`japaneseText`,`jp`,`textJa`,`text`,`value` |
| Storytelling | Per sentence | `japaneseText` (UI validity) | 1 char (trim) | — | For `isValidV1` counts | — | — | — | — | — | `StorySentenceItem.isValidV1` — `lib/features/create/story_v1_model.dart` | — | `story_creator_quota_publish_and_draft_test.dart` | Publish uses wire `content` map, not only model |
| Storytelling | Per sentence | `reading`, `furiganaSpans`, `meanings` | — | — | No | Yes | — | — | Allowed | Not validated publish | — | — | — | Optional |
| Storytelling | Order | `orderIndex` | — | — | — | — | — | — | Persisted | Not validated publish | — | `story-drafts.service.ts` (reindex / duplicate log) | `story-drafts.service.spec.ts` | Duplicates logged; DB order by save order |
| Storytelling | Body chars | sum of primary Japanese lines | — | **per Appendix A `maxChars`** | If limits apply | — | Yes if exceeded | — | — | Same | `publish_validation.dart` | `publish-validation.ts` | `validation.spec.ts` | `charLength` — `text_normalization.dart` / `text-normalization.ts` |
| Storytelling | UI min sentences | by duration band only | **8 / 14 / 20** | — | For drawer readiness | — | — | — | — | Not publish gate | `CreatorV1DurationThresholds.byBand` — `creator_completion_rules.dart` | — (missing) | `story_creator_quota_publish_and_draft_test.dart` | **Mismatch** vs publish min (e.g. 8 vs 10 N5 `3_5`) |
| Vocabulary | Count | entries with `termJapanese` | **Appendix B `min`** | **Appendix B `max`** | FL publish if JLPT+band | — | Yes | — | — | Full learn only | `publish_validation.dart` | `publish-validation.ts` | `validation.spec.ts` | Read-only: not checked |
| Vocabulary | Meaning | gloss my/en | 1 | 80 chars | Per row with term | — | Yes FL | — | Optional if no term | Required if term non-empty | `validateVocabularyMeaning` — `learn_validators.dart` | `validateVocabularyMeaning` — `learn-validation.ts` | `publish_validation_gate_test.dart` | No emoji/URL/#/HTML/linebreak |
| Vocabulary | Reading | `reading` | 1 (if required) | 40 chars | If kanji type or surface has kanji | — | Yes | — | — | Same | `validateFurigana` — `learn_validators.dart` | `validateFuriganaReading` — `learn-validation.ts` | `publish-validation.spec.ts` | ≤3 `/` segments; kana regex |
| Vocabulary | Term | `termJapanese`/`term` | — | — | For counting row | — | — | — | — | Empty term → row skipped for meaning/furigana | `parseVocabEntry` — `publish_validation.dart` | `parseVocabEntry` — `publish-validation.ts` | — | |
| Vocabulary | Type | `type`/`entryType` | — | — | — | — | — | — | — | `kanji` → furigana kind kanji | same | same | — | |
| Vocabulary | Examples | `examplePairs` / legacy | — | **3** pairs max (model) | No | Yes | — | — | — | Not publish-validated | `VocabularyKanjiEntry.effectiveExamplePairs` — `story_v1_model.dart` | — | — | |
| Vocabulary | UI min count | by band | **6 / 9 / 12** | — | Readiness only | — | — | — | — | Not backend | `CreatorV1DurationThresholds` — `creator_completion_rules.dart` | — | — | **Mismatch** vs publish min |
| Grammar | Count | rows with headline | **Appendix C `min`** | **Appendix C `max`** | FL if JLPT+band | — | Yes | — | — | Full learn | `publish_validation.dart` | `publish-validation.ts` | `validation.spec.ts` | |
| Grammar | Title | `headline`/`title` | 2 | 40 chars | **Every row** in list | — | Yes (empty fails) | — | — | `validateGrammarPatternTitle` always called per row | `publish_validation.dart` loop | `publish-validation.ts` loop | — | Empty headline → `learn.grammar.title.required` |
| Grammar | Other fields | form, meanings, usage, examples | — | — | No | Yes | — | — | — | Not publish gate | — | — | — | |
| Quiz | Count | parsed rows | **Appendix D `min`** | **`min(max, absoluteMax, 24)`** | FL if JLPT+band | — | Yes | — | — | Full learn | `publish_validation.dart` (`math.min`) | `publish-validation.ts` | `validation.spec.ts`; `publish-validation.spec.ts` | `quizGlobalHardMax` / `QUIZ_GLOBAL_HARD_MAX` = **24** |
| Quiz | Question | `prompt`/`question` | 5 | 120 chars | Yes | — | Yes | — | — | Same | `validateQuizItem` — `learn_validators.dart` | `validateQuizItem` — `learn-validation.ts` | `validation_foundation_test.dart` | |
| Quiz | Options | non-empty options | **2** | **4** | Yes | — | Yes | — | — | Same | same | same | same | Duplicate options (case-insensitive) **block** |
| Quiz | Answer | `correctAnswer` / `correctIndex` | — | — | Yes | — | Yes | — | — | Must be exactly one matching option | same | same | same | |
| Quiz | Category | wire keys | — | — | Yes | — | Yes if invalid | — | — | Allowed: Vocabulary, Grammar, Sentence (mapped) | `mapQuizCategoryToValidatorCategory` — `publish_validation.dart` | `mapQuizCategoryToValidatorCategory` — `publish-validation.ts` | — | Backend maps `kanji`/`vocabulary`→Vocabulary; Flutter default→Vocabulary |
| Quiz | Explanations | `explanations` | — | — | No | Yes | — | — | — | Not in `validateQuizItem` | — | — | — | |
| Quiz | UI model | `QuizEntry.options` | **4** | **4** | Creator asserts | — | — | — | — | — | `QuizEntry` constructor assert — `story_v1_model.dart` | — | — | **Mismatch** vs publish 2–4 |
| Quiz | UI min count | by band | **4 / 6 / 8** | — | Readiness | — | — | — | — | — | `CreatorV1DurationThresholds` | — | — | **Mismatch** vs publish |
| Listening | Module gate | `moduleWorkflowStatuses.audio` | — | — | FL: must be `completed` | — | Yes | — | — | Case-insensitive compare | `fullLearnModulesComplete` — `publish_validation.dart` | `fullLearnModulesComplete` — `publish-validation.ts` | `publish-validation.spec.ts` | No transcript/url/size at publish |
| Listening | UI asset | `StoryAudioAsset` | 1 (count) | — | Readiness | — | — | — | — | `isValidV1`: url or local name/path | `StoryAudioAsset.isValidV1` — `story_v1_model.dart` | — | — | |
| Listening | Audio upload | file size | 1 B | default **52428800** | Upload | — | Yes | — | — | — | — | `readAudioMaxBytesFromEnv` — `media-file-limits.ts`; `MediaService.audioMaxBytes` | `media.service.spec.ts` | Default 50 MiB |
| Publish | Read-only | entire gate | — | — | title + sentences + limits | desc optional | Blocking set | Warn set | DTO save separate | `ValidationMode.readOnlyPublish` | `validateStoryPublishData` | `validateStoryPublishInput` | `publish-validation.spec.ts` | |
| Publish | Full learn | entire gate | — | — | RO + modules + learn counts + per-item | desc optional | Blocking set | Warn set | Same | `ValidationMode.fullLearnPublish` | same | same | same | |
| Publish | Full learn | `publishedMonoId` | — | — | Yes | — | **422** (not validation_failed) | — | — | Before mono write | `publishFullLearnToDisk` checks server state — `story_creator_provider.dart` | `story-drafts.service.ts` | `story-drafts.service.quota.spec.ts` | After `assertNoBlockingValidationIssues` |
| Product | Drafts | count cap | — | **50** | — | — | Quota error | — | — | — | — | `FREE_TIER_QUOTAS.draftStories` — `nimon-backend/src/common/limits/free-tier-quotas.ts` | Quota specs | Flutter: `quota_exceeded_dialog.dart` keys |
| Product | Published monos | cap | — | **30** | — | — | Quota | — | — | Reveal tab | — | same `publishedMonos` | same | `assertCanRevealOnePublishedTabMono` — `story-drafts.service.ts` |
| Product | Saved monos / collections | — | — | **50 / 10** | — | — | Quota | — | — | — | — | `FREE_TIER_QUOTAS` | — | Out of scope for story body but in same file |

---

## 3. Story basics rules

| Field | Publish blocking | Publish warning | Draft / save | Constants / functions |
|-------|------------------|-----------------|--------------|-------------------------|
| `title` | Length 5–80; HTML/script; line breaks; emoji>1; numbers-only; symbols-only; excessive repeat | Empty → recommended (draft only) | Draft: empty title warning; unsafe/linebreak blocking | `validateStoryTitle` — `story_validators.dart` / `story-validation.ts` |
| `description` | Max 160 chars; HTML; line breaks; URLs>1; hashtags>4; emoji>2; excessive repeat | Empty description | Draft: unsafe/linebreak blocking | `validateStoryDescription` — same files |
| `level` | — (no length check in publish validators) | Unmapped JLPT → skip limits | Flutter UI: required in `computeStoryBasicsStatus` | `normalizeJlptLevel` — `story_duration_band.dart` / `story-duration-band.ts` |
| `category` | — | — | Flutter UI: required basics | Not in `validateStoryPublish*` |
| `targetDurationBandKey` / legacy duration | — | Unresolved band → skip limits | Flutter UI: required basics | `resolveStoryDurationBand` |
| `coverImageUrl` | — | — | Optional `@IsString` on write DTO | `StoryDraftBasicsWriteDto` — `story-draft.requests.ts` |
| Cover **upload** | Size / MIME at `/v1/media/upload/cover` | — | — | `media.service.ts`, `media.validation.ts`, `media-file-limits.ts` |

---

## 4. Storytelling rules

| Topic | Value / rule | Flutter | Backend |
|-------|----------------|---------|---------|
| Min/max sentences | Appendix A per JLPT×`3_5`/`5_7`/`7_9` | `storySentenceLimits` | `STORY_SENTENCE_LIMITS` |
| Max total Japanese chars | Appendix A `maxChars` | same | same |
| When counts apply | JLPT mapped **and** band resolved **and** `validCount > 0` | `validateStoryPublishData` L254–285 | `publish-validation.ts` L234–277 |
| ≥1 sentence | Blocking | L243–251 | L221–231 |
| Required Japanese field | Any of wire keys with non-empty trim | `extractJapanesePrimaryText` | same |
| Optional fields | `reading`, `furiganaSpans`, `meanings`, `audioStartMs`/`audioEndMs` | Not in publish gate | Not in publish gate |
| Empty sentences | Excluded from `validCount` | `extractStorySentenceMetrics` | same |
| Duplicate `orderIndex` | Allowed on save; server reindexes | N/A | `story-drafts.service.ts`; test `story-drafts.service.spec.ts` “duplicate incoming orderIndex” |
| UI min sentences | 8 / 14 / 20 by band | `CreatorV1DurationThresholds` | **Not present** |

---

## 5. Vocabulary rules

| Topic | Detail | Source |
|-------|--------|--------|
| Count min/max | Appendix B | `vocabularyLimits` / `VOCABULARY_LIMITS` |
| When count applies | Full learn + JLPT + band | `publish_validation.dart` L292–346 |
| Row skipped for per-item rules | `termJapanese.trim().isEmpty` | L348–350 |
| Meaning | Required (non-empty) for FL if term present; 1–80 chars; content rules | `validateVocabularyMeaning` — `learn_validators.dart` / `learn-validation.ts` |
| Reading | Required if `type===kanji` **or** surface contains kanji; max 40; ≤3 segments; kana regex | `validateFurigana` / `validateFuriganaReading` |
| JLPT/category per entry | Not validated | — |
| Example sentences | Not in publish validators | `VocabularyKanjiEntry` model only |
| UI min count | 6 / 9 / 12 | `CreatorV1DurationThresholds` |

---

## 6. Grammar rules

| Topic | Detail | Source |
|-------|--------|--------|
| Count min/max | Appendix C | `grammarPatternLimits` / `GRAMMAR_PATTERN_LIMITS` |
| Headline | Every `grammarEntries` row: `validateGrammarPatternTitle(headline)` — empty **blocks** | `publish_validation.dart` L364–367; `learn_validators.dart` L299–365 |
| Length | 2–40 chars (non-empty path) | `validateGrammarPatternTitle` |
| Optional | `form`, `meanings`, `usage`, `examples`, mistakes, `relatedNote` | Not in publish gate |

---

## 7. Quiz rules

| Topic | Detail | Source |
|-------|--------|--------|
| Count min/max | Appendix D; effective max `min(quiz.max, absoluteMax, 24)` | `publish_validation.dart` L328–344 |
| Categories (validator) | `Vocabulary`, `Grammar`, `Sentence` | `validateQuizItem` L376–384 |
| Wire mapping | `grammar`→Grammar; `sample_sentence`/`sentence`→Sentence; `kanji`/`vocabulary`→Vocabulary (backend explicit L127–128) | `publish-validation.ts` `mapQuizCategoryToValidatorCategory` |
| Question | 5–120 chars | `validateQuizItem` |
| Options | 2–4 non-empty, unique case-insensitive | same |
| Answer | Non-empty; must appear exactly once in options | same L446–473 |
| Duplicate questions | Normalized lower question unique | same L476–484 |
| Explanations | Not validated | — |
| Creator model | Exactly 4 options, `correctIndex` 0–3 | `QuizEntry` — `story_v1_model.dart` L520–551 |

---

## 8. Listening rules

| Topic | Detail | Source |
|-------|--------|--------|
| Publish | `audio` module key must be `'completed'` (case-insensitive) | `fullLearnModulesComplete` |
| Transcript | **Not** in publish validation | — |
| `audioUrl` / story audio payload | **Not** validated at publish | — |
| Upload | Size default 50 MiB; MIME/type rules in media module | `media-file-limits.ts`, `media.service.ts`, `media.validation.ts` |
| Demo/sample URL | No special-case in publish validators | — |
| UI readiness | ≥1 `StoryAudioAsset.isValidV1` | `computeListeningStatus` — `creator_completion_rules.dart` |

---

## 9. Read-only publish gate

**Entry:** `StoryDraftsService.publishReadOnly` — `story-drafts.service.ts`  
**Validation:** `validateStoryPublishInput(..., ValidationMode.ReadOnlyPublish)` — `publish-validation.ts`  
**Blocking enforcement:** `assertNoBlockingValidationIssues` — `validation-exception.ts`

**Blocking:** `validateStoryTitle`; description rules (not empty-desc — that is warning); `story.sentences.required`; when jlpt+band+validCount>0: `tooFew` / `tooMany` / `body.tooLong`.  
**Warning:** empty description; `skippedNoJlpt`; `skippedNoBand`.  
**Not included:** category, cover, learn layers, module workflow.

**Flutter mirror:** `validateStoryPublishData(..., readOnlyPublish)` — `publish_validation.dart`.

---

## 10. Full-learn publish gate

**Additional blocking (same file):** `fullLearnModulesComplete` for `vocabulary_kanji`, `grammar`, `quiz`, `audio`; vocab/grammar/quiz **counts** when jlpt+band; per-vocab meaning+furigana; per-grammar title; per-quiz `validateQuizItem`; duplicate quiz questions.

**422 (non-validation):** `publishedMonoId` missing — `story-drafts.service.ts` L1209–1215.

**Flutter:** `validateStoryPublishData(..., fullLearnPublish)`.

---

## 11. Flutter vs Backend mismatch table

| Rule | Flutter Behavior | Backend Behavior | Risk | Recommendation |
|------|------------------|------------------|------|----------------|
| Readiness min counts | `CreatorV1DurationThresholds` lower mins (sentences/vocab/quiz) | Publish uses higher tables | User can enable publish only after preflight; may pass preflight if warnings only | Align UI mins to publish tables or document in CSV tool |
| Category / duration for “basics complete” | Required in `computeStoryBasicsStatus` | Not blocking in publish validators | Confusion | Treat as UX-only in matrix |
| Quiz options | Model forces 4 options | Validator allows 2–4 | Low (wire always 4 from app) | CSV import: accept 2–4 or normalize to 4 |
| `mapQuizCategory` | Default unknown → `Vocabulary` | Explicit `kanji`/`vocabulary`→Vocabulary | None | Keep aligned (already equivalent) |
| Grammar empty rows | Same: validate every row | Same | CSV must omit or fill headlines | Filter empty rows on import |
| Warning vs HTTP | User can “Publish anyway” on warnings | Warnings do not block | User publishes with skipped limits | Surface warnings in import preview |
| `publishedMonoId` | Client checks after save | 422 if missing | Full learn fails late | Import flow: RO publish first |
| Furigana regex | Dart `_furiganaAllowed` | TS `FURIGANA_ALLOWED` | Subtle charset drift | Golden-file test cross-platform |

---

## 12. CSV import implications

| CSV Section | Required Columns | Optional Columns | Blocking Import Errors | Warnings | Maps To | Publish Impact |
|-------------|------------------|------------------|------------------------|----------|---------|----------------|
| Story meta | `title` (≥5 for publish), `level` (N1–N5 mappable), `targetDurationBandKey` | `description`, `category`, `promptSourceNote`, `coverImageUrl` | Title <5; desc rules; invalid band key | Empty desc; missing level/band (limits skipped) | `StoryDraftBasicsWriteDto` / `StoryPublishValidationInput` | RO+FL |
| Sentences | `japaneseText` (or wire alias) per row | `orderIndex`, `reading`, `meanings`, `furiganaSpans` | Count outside Appendix A; zero valid; `maxChars` exceeded | — | `sentences[]` | RO+FL |
| Vocabulary | `termJapanese`; `glosses.my` or `glosses.en`; `reading` if kanji | `type`, examples | Meaning/furigana violations; count outside Appendix B | — | `vocabularyKanji.entries` | FL only |
| Grammar | `headline` (2–40) per non-skipped row | all other grammar fields | Empty headline row; count outside Appendix C | — | `grammar.entries` | FL only |
| Quiz | `prompt`, `options[]`, correct index/answer, `category` | explanations | Question length; option count 2–4; dup options; answer; dup question; count Appendix D | — | `quiz.entries` | FL only |
| Listening / workflow | `moduleWorkflowStatuses` keys | `audio.storyAudio` URL/path | Missing `completed` on any of four modules | — | `moduleWorkflowStatuses`, `audio` | FL only |
| Cover file | — | binary upload separate | MIME/size from env | — | `POST /v1/media/upload/cover` | Optional for publish |

**Enable full learn publish after import:** RO publish succeeded (`publishedMonoId`), all four modules `completed`, JLPT+band set, counts and per-item rules pass, quiz≤effective max.

---

## 13. Excel matrix fill guide

| Excel column | What to enter |
|--------------|----------------|
| **Min limitation** | Numeric minimum from Appendix A–D or field rule (e.g. title `5`, question `5`, grammar headline `2`). Use “—” if not applicable. |
| **Max limitation** | Numeric maximum (e.g. title `80`, description `160`, meaning `80`, reading `40`, quiz question `120`). For counts use band table max. |
| **Required fields** | Comma-list of fields that **must** be non-empty for that gate (e.g. publish: `title`; FL vocab row: `termJapanese, meaning (my|en), reading if kanji`). |
| **Warning** | List warning codes only: e.g. `story.description.recommended`, `story.limits.skippedNoJlpt`, `story.limits.skippedNoBand`. |
| **Blocking** | `yes` if `ValidationSeverity.Blocking` / `validation_failed` / HTTP 422 for `published_mono_missing`; `no` for warning-only rows. |
| **Notes** | Cite `file path` + `function`/`constant`; add “Flutter-only” or “Backend-only”; add “DTO” for `StoryDraftWriteDto`; add “Upload” for media env defaults. |

---

## 14. Open questions

*(None identified that are unanswerable from code — business intent for “demo listening URL”, product marketing copy, and production env values for `MEDIA_*_MAX_BYTES` are deployment-specific, not hardcoded single constants.)*

---

## 15. Recommended technical additions for CSV import

| Topic | Recommendation |
|-------|------------------|
| CSV parser | Prefer **`package:csv`** (Dart) for RFC-style parsing with configurable `eol`; pure `String.split` insufficient for quoted commas. Alternative: **`csv`** + small custom row normalizer. |
| UTF-8 BOM | Strip leading `\uFEFF` once after file read (`utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), '')`). |
| Quoted commas / newlines | Use a real CSV parser with `shouldParseNumbers: false` and text fields as strings; never split on `,` alone. |
| Row-level validation | Build `List<ValidationIssue>` per logical row with `field`, `code`, `severity` mirroring `ValidationIssue` — `lib/core/validation/validation_issue.dart`. |
| Preview-before-import | Run `validateStoryPublishData` on assembled `StoryPublishData` for RO and FL modes; show blocking vs warning columns like `publish_validation_sheet.dart`. |
| Section overwrite | Policy flag per section: `replace` vs `merge` for sentences/vocab/grammar/quiz; document that grammar **empty rows block** publish — filter or fill. |
| Transaction / rollback | Import into **staging** `CreatorStoryV1` in memory → validate → single `saveDraft` / remote PUT; avoid partial PATCH series without user confirm. |
| Backend revalidation | Always rely on server `validation_failed` on publish; client validators can drift — call `validateStoryPublishInput` server-side only via publish endpoint (already true). |
| Demo listening `audioUrl` | No code policy; recommend: **allow** any `https?` URL that passes `StoryAudioAsset.isValidV1` for drafts; document malware/CDN policy separately. |

---

## Appendix A — `STORY_SENTENCE_LIMITS` / `storySentenceLimits` (identical)

| JLPT | Band | minSentences | maxSentences | maxChars |
|------|------|--------------|--------------|----------|
| N5 | 3_5 | 10 | 35 | 900 |
| N5 | 5_7 | 18 | 50 | 1250 |
| N5 | 7_9 | 25 | 65 | 1600 |
| N4 | 3_5 | 8 | 30 | 1000 |
| N4 | 5_7 | 15 | 45 | 1400 |
| N4 | 7_9 | 22 | 60 | 1800 |
| N3 | 3_5 | 7 | 25 | 1150 |
| N3 | 5_7 | 12 | 38 | 1600 |
| N3 | 7_9 | 18 | 52 | 2100 |
| N2 | 3_5 | 6 | 20 | 1300 |
| N2 | 5_7 | 10 | 32 | 1850 |
| N2 | 7_9 | 15 | 45 | 2350 |
| N1 | 3_5 | 5 | 18 | 1500 |
| N1 | 5_7 | 8 | 28 | 2100 |
| N1 | 7_9 | 12 | 38 | 2700 |

---

## Appendix B — Vocabulary count limits (`vocabularyLimits` / `VOCABULARY_LIMITS`)

| JLPT | 3_5 (min,max) | 5_7 | 7_9 |
|------|---------------|-----|-----|
| N5 | 8,18 | 12,28 | 18,40 |
| N4 | 10,22 | 15,32 | 22,45 |
| N3 | 12,25 | 18,38 | 25,55 |
| N2 | 10,24 | 16,36 | 22,50 |
| N1 | 8,20 | 14,32 | 20,45 |

---

## Appendix C — Grammar count limits

| JLPT | 3_5 | 5_7 | 7_9 |
|------|-----|-----|-----|
| N5 | 3–5 | 4–7 | 5–9 |
| N4 | 4–6 | 5–8 | 6–10 |
| N3 | 4–7 | 6–9 | 7–12 |
| N2 | 3–6 | 5–8 | 6–10 |
| N1 | 3–5 | 4–7 | 5–9 |

---

## Appendix D — Quiz count limits (`min`, `max`, `absoluteMax`; effective max = min(`max`, `absoluteMax`, **24**))

| JLPT | 3_5 | 5_7 | 7_9 |
|------|-----|-----|-----|
| N5 | 6,10,18 | 9,14,18 | 12,18,18 |
| N4 | 7,11,20 | 10,16,20 | 14,20,20 |
| N3 | 8,12,24 | 12,18,24 | 16,24,24 |
| N2 | 7,11,22 | 10,16,22 | 14,22,22 |
| N1 | 6,10,20 | 9,15,20 | 12,20,20 |

---

### Key test file names (non-exhaustive)

- `test/core/validation/publish_validation_gate_test.dart`
- `test/core/validation/validation_foundation_test.dart`
- `nimon-backend/src/common/validation/publish-validation.spec.ts`
- `nimon-backend/src/common/validation/validation.spec.ts`
- `nimon-backend/src/modules/story-drafts/story-drafts.basics-validation.spec.ts`
- `nimon-backend/src/modules/media/media.service.spec.ts`
