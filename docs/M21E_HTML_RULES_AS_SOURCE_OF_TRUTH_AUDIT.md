# M21E — HTML Rules as Source of Truth (Audit Only)

Date: 2026-06-02  
Scope: **Audit only** (no behavior changes).  
Decision: **External HTML JSON generator limitation rules are now the source of truth**; Nimon app/backend must later be changed to match them.

## Executive summary

- **HTML generator file found** at `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`.
  - This document now extracts the **exact source-of-truth** limitation rules directly from that HTML (no invented values).
- **Current Nimon limits are implemented in both Flutter and backend**, and (for publish validation) are explicitly designed to match each other:
  - Sentence+character limits by **JLPT level × duration band**.
  - Vocabulary / grammar / quiz count ranges by **JLPT × duration band**, plus a **quiz global hard max**.
  - Full Learn publish additionally enforces **module workflow statuses** (vocab/grammar/quiz/audio must be `completed`).
- **Creator UI readiness thresholds differ from publish validation limits**:
  - UI readiness uses `CreatorV1DurationThresholds` (**duration band only**, no JLPT), and is **minimum-only**.
  - Publish validation uses JLPT×band **min+max** and includes **max Japanese character count**.
- **Import validator** (`validateNimonImportPayload`) currently validates **shape + app context**, not the full publish limits; it blocks English-learning imports and enforces a strict quiz option shape (exactly 4 options, correctIndex 0–3).

---

## A. Files found (rule locations)

### Flutter — readiness / UI gating / preflight

- `lib/features/create/creator_completion_rules.dart`
  - **Found**: `CreatorV1DurationThresholds.byBand`, `resolveV1ThresholdsForDraft`, `computeStory*Status` (basics/sentences/vocab/grammar/quiz/listening), `fullLearnModulesComplete` (via extension), `targetDurationBandKey` parsing.
  - **Controls**: Creator module completion chips + readiness thresholds (minimum counts).
  - **Layer**: UI readiness (local), creator workflow gating.

- `lib/features/create/creator_readiness.dart`
  - **Found**: `computeReadOnlyReady`, `computeFullLearnReady`, `computeProcessingState`.
  - **Controls**: “Ready ReadOnly” vs “Ready FullLearn” states and unmet messages.
  - **Layer**: UI readiness (local).

- `lib/features/create/story_creator_review_display.dart`
  - **Found**: `buildStoryReviewDisplayModel`, `resolveDefaultStoryReviewMode`, `storyReviewUnmetForMode`.
  - **Controls**: Review screen readiness snapshot and mode switching.
  - **Layer**: UI readiness (local).

- `lib/features/create/creator_publish_preflight.dart`
  - **Found**: `storyPublishDataFromCreator` mapping creator draft → `StoryPublishData`.
  - **Controls**: What fields get validated by publish validation (portable snapshot).
  - **Layer**: client preflight input shaping.

- `lib/features/create/creator_drawer_publish.dart`
  - **Found**: `_preflightCreatorPublish` calls `validateStoryPublishData(...)` with `ValidationMode.readOnlyPublish` or `ValidationMode.fullLearnPublish`.
  - **Controls**: Blocking/warning UX before publish.
  - **Layer**: client preflight + publish UX.

### Flutter — portable validation tables + publish validation

- `lib/core/validation/story_duration_band.dart`
  - **Found**: `resolveStoryDurationBand`, `normalizeJlptLevel`.
  - **Controls**: Normalization of duration band and JLPT level for limit tables.
  - **Layer**: shared validation utility.

- `lib/core/validation/story_validators.dart`
  - **Found**: `storySentenceLimits` (JLPT×band), title/description validation, sentence/char constraints.
  - **Controls**: Sentence min/max, max chars table (explicitly “mirrors backend exactly”).
  - **Layer**: client validation (publish + draft text safety rules).

- `lib/core/validation/learn_validators.dart`
  - **Found**: `vocabularyLimits`, `grammarPatternLimits`, `quizLimits`, `quizGlobalHardMax`, plus per-item validators (furigana, vocab meaning, grammar title, quiz item).
  - **Controls**: Learn module count ranges and per-item validation.
  - **Layer**: client validation (publish).

- `lib/core/validation/publish_validation.dart`
  - **Found**: `validateStoryPublishData`, `extractStorySentenceMetrics`, `fullLearnModulesComplete`, quiz category mapping, and count checks vs the tables.
  - **Controls**: Main client publish gate for ReadOnly vs FullLearn publish.
  - **Layer**: client preflight validation (blocking/warning).

### Flutter — import validation / mapping

- `lib/features/create/import/nimon_import_validator.dart`
  - **Found**: `validateNimonImportPayload`, `kNimonImportSupportedSchemaVersions`, FullLearn shape requirements, quiz entry strictness (options=4).
  - **Controls**: Import JSON shape validation + app-context checks (auth + settings).
  - **Layer**: import validation (local; before mapping).

- `lib/features/create/import/nimon_import_mapper.dart`
  - **Found**: `mapNimonImportPayloadToCreatorStoryV1`, mapping of targetDurationBandKey, learn module entries, quiz entry mapping; calls `syncModuleWorkflowWithContent`.
  - **Controls**: Imported JSON → draft data; indirectly affects readiness via stored counts and `targetDurationBandKey`.
  - **Layer**: import mapping (local).

- `lib/features/create/story_creator_provider.dart`
  - **Found**: `importMappedDraft` (ensures not auto-published), publish methods gate via `computeReadOnlyReady` / `computeFullLearnReady`.
  - **Controls**: Ensures import results in draft-only state; publish still user-initiated.
  - **Layer**: creator state management (local + remote persistence).

### Backend — publish validation tables + gates (folder present)

- `nimon-backend/src/common/validation/story-duration-band.ts`
  - **Found**: `resolveStoryDurationBand`, `normalizeJlptLevel`.
  - **Controls**: Duration band + JLPT normalization for limits.
  - **Layer**: backend validation utility.

- `nimon-backend/src/common/validation/story-validation.ts`
  - **Found**: `STORY_SENTENCE_LIMITS` (JLPT×band), plus title/description validation.
  - **Controls**: Sentence min/max, max chars by JLPT×band.
  - **Layer**: backend validation.

- `nimon-backend/src/common/validation/learn-validation.ts`
  - **Found**: `VOCABULARY_LIMITS`, `GRAMMAR_PATTERN_LIMITS`, `QUIZ_LIMITS`, `QUIZ_GLOBAL_HARD_MAX` + item validators.
  - **Controls**: Learn count ranges, per-item rules.
  - **Layer**: backend validation.

- `nimon-backend/src/common/validation/publish-validation.ts`
  - **Found**: `validateStoryPublishInput`, `extractStorySentenceMetrics`, `fullLearnModulesComplete`, range checks vs tables.
  - **Controls**: Central backend publish gate for ReadOnly vs FullLearn.
  - **Layer**: backend publish validation.

---

## B. Current Nimon rule summary (Flutter + backend)

### B1. Duration + level normalization (shared)

- **Duration band keys**: `3_5`, `5_7`, `7_9`
- **Band inference** (if `targetDurationBandKey` missing but `durationSeconds` present):
  - 3 ≤ minutes < 5 → `3_5`
  - 5 ≤ minutes < 7 → `5_7`
  - 7 ≤ minutes ≤ 9 → `7_9`
  - otherwise → `null` (limits skipped in publish validation)
- **JLPT normalization**: level string containing `n1..n5` → `N1..N5`, else `null` (limits skipped in publish validation)

### B2. Story sentence & character limits (publish validation)

Applies when JLPT and duration band are both resolved. Otherwise publish validation emits warnings and **skips JLPT×band limits**.

| JLPT | Band | Min sentences | Max sentences | Max total JP chars |
|---|---:|---:|---:|---:|
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

### B3. Vocabulary count limits (Full Learn publish only)

| JLPT | Band | Min vocab | Max vocab |
|---|---:|---:|---:|
| N5 | 3_5 | 8 | 18 |
| N5 | 5_7 | 12 | 28 |
| N5 | 7_9 | 18 | 40 |
| N4 | 3_5 | 10 | 22 |
| N4 | 5_7 | 15 | 32 |
| N4 | 7_9 | 22 | 45 |
| N3 | 3_5 | 12 | 25 |
| N3 | 5_7 | 18 | 38 |
| N3 | 7_9 | 25 | 55 |
| N2 | 3_5 | 10 | 24 |
| N2 | 5_7 | 16 | 36 |
| N2 | 7_9 | 22 | 50 |
| N1 | 3_5 | 8 | 20 |
| N1 | 5_7 | 14 | 32 |
| N1 | 7_9 | 20 | 45 |

### B4. Grammar count limits (Full Learn publish only)

| JLPT | Band | Min grammar | Max grammar |
|---|---:|---:|---:|
| N5 | 3_5 | 3 | 5 |
| N5 | 5_7 | 4 | 7 |
| N5 | 7_9 | 5 | 9 |
| N4 | 3_5 | 4 | 6 |
| N4 | 5_7 | 5 | 8 |
| N4 | 7_9 | 6 | 10 |
| N3 | 3_5 | 4 | 7 |
| N3 | 5_7 | 6 | 9 |
| N3 | 7_9 | 7 | 12 |
| N2 | 3_5 | 3 | 6 |
| N2 | 5_7 | 5 | 8 |
| N2 | 7_9 | 6 | 10 |
| N1 | 3_5 | 3 | 5 |
| N1 | 5_7 | 4 | 7 |
| N1 | 7_9 | 5 | 9 |

### B5. Quiz count limits (Full Learn publish only)

Notes:
- There is a per-band `absoluteMax` and a separate product-wide `QUIZ_GLOBAL_HARD_MAX = 24`.
- Effective allowed max used in validation is:
  - `min(absoluteMax, quizGlobalHardMax, band.max)`

| JLPT | Band | Min quiz | Max quiz (band) | Absolute max |
|---|---:|---:|---:|---:|
| N5 | 3_5 | 6 | 10 | 18 |
| N5 | 5_7 | 9 | 14 | 18 |
| N5 | 7_9 | 12 | 18 | 18 |
| N4 | 3_5 | 7 | 11 | 20 |
| N4 | 5_7 | 10 | 16 | 20 |
| N4 | 7_9 | 14 | 20 | 20 |
| N3 | 3_5 | 8 | 12 | 24 |
| N3 | 5_7 | 12 | 18 | 24 |
| N3 | 7_9 | 16 | 24 | 24 |
| N2 | 3_5 | 7 | 11 | 22 |
| N2 | 5_7 | 10 | 16 | 22 |
| N2 | 7_9 | 14 | 22 | 22 |
| N1 | 3_5 | 6 | 10 | 20 |
| N1 | 5_7 | 9 | 15 | 20 |
| N1 | 7_9 | 12 | 20 | 20 |

### B6. Quiz category distribution (publish validation)

- **No distribution rules** (no required minimum per category) are enforced by current publish validation.
- Quiz validation normalizes categories for validation:
  - Backend: `grammar` → Grammar; `sample_sentence`/`sentence` → Sentence; `kanji`/`vocabulary` → Vocabulary (fallback Vocabulary)
  - Flutter: `grammar` → Grammar; `sample_sentence`/`sentence` → Sentence; fallback Vocabulary

### B7. Audio requirement (Full Learn readiness vs publish validation)

- **Creator readiness**: Full Learn requires “Attach 1 audio file” (minimum audio items = 1) via `CreatorV1DurationThresholds` and `computeListeningStatus`.
- **Publish validation**: There is **no explicit audio-content validation** in `validateStoryPublishData` / `validateStoryPublishInput`.
  - Instead, publish validation blocks Full Learn publish if `moduleWorkflowStatuses.audio != completed`.

### B8. ReadOnly vs FullLearn differences (current)

- **ReadOnly readiness** (`computeReadOnlyReady`):
  - Requires Story basics complete (title/desc/level/category/duration band selected)
  - Requires story sentence minimum (from `CreatorV1DurationThresholds` by duration band only)

- **FullLearn readiness** (`computeFullLearnReady`):
  - Requires ReadOnly readiness
  - Plus minimums for vocab, grammar, quiz, and audio (from `CreatorV1DurationThresholds`)

- **Publish validation**:
  - ReadOnly publish: title/description checks + story sentence/char limits (JLPT×band) when resolvable
  - FullLearn publish: additionally enforces module statuses + vocab/grammar/quiz count ranges (JLPT×band) when resolvable + per-item validations

### B9. Manual mode vs AI mode differences (current)

- There are **no publish/readiness limit differences** based on Manual vs AI mode in current Flutter/backend publish validation.
- The import metadata *tracks* prompt data tab (`Manual_mode` vs `AI_mode`) and requires it be recognized, but it does not alter limits.

### B10. JP vs EN differences (current)

- Publish validation tables are expressed in terms of:
  - Japanese sentence text extraction (`extractJapanesePrimaryText`) and “total Japanese chars”.
- JSON import validator currently **blocks English learning** imports (`import.context.englishComingSoon`).
- No alternative English-learning limit tables exist in this codebase as inspected.

### B11. Creator UI “V1 thresholds” (readiness minimums)

These are **UI readiness thresholds**, not the publish min/max tables above, and they do not vary by JLPT.

| Duration band | Min story sentences | Min vocab | Min grammar | Min quiz | Min audio |
|---|---:|---:|---:|---:|---:|
| 3_5 | 8 | 6 | 3 | 4 | 1 |
| 5_7 | 14 | 9 | 4 | 6 | 1 |
| 7_9 | 20 | 12 | 6 | 8 | 1 |

---

## C. HTML source-of-truth rule summary (extracted from HTML)

Source file: `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`

### C0. Core concepts / keys (as implemented in HTML)

- **Prompt mode tabs**:
  - Manual tab sets `currentMode = "Manual"`
  - AI tab sets `currentMode = "AI"`
- **Upload types** (`learnMode` radio):
  - `READ_ONLY` vs `FULL` (shown as “FULL LEARN” in UI)
- **Slider keys** (AI selection only): `sliderKeys = ["minimum","default","optimal","maximum"]`
  - Default slider index on load: `currentSliderIndex = 1` → **`default`**
  - **Slider enabled only when**: upload type is `FULL` **and** mode is `AI`
    - `isSliderEnabled() => cleanUploadType() === "FULL" && currentMode === "AI"`

### C1. Normalization logic (HTML)

- **Level normalization**: `normalizeLevel(v)` strips leading `"<number>."` then trims.
  - Example: `"1.N5/A1" → "N5/A1"`
- **JLPT-only level**: `jlptOnly(level)` returns the part before `/`
  - Example: `"N5/A1" → "N5"`
- **Duration normalization**: `normalizeDuration(v)` maps any input containing `3-5` / `5-7` / `7-9` into:
  - `"3-5 mins"`, `"5-7 mins"`, `"7-9 mins"`
- **Duration band key**: `durationBandKey(duration)` converts to:
  - `"3_5"`, `"5_7"`, `"7_9"` via `.replace("-", "_").replace(" mins", "")`
- **Language normalization**: `normalizeLanguage(v)`:
  - if value contains `"En"` → `"EN"` else `"JP"`
- **Category normalization**: `cleanCategory(v)` strips leading `"<number>."` then trims.

### C2. `sentenceLimits` (sentence + character limits)

`sentenceLimits[mode][language][duration][level] = [minSent, maxSent, minChar, maxChar]`

Notes:
- In **Manual** mode, the HTML validates the pasted story text against these **min/max** bounds.
- In **AI** mode, these are used as the required sentence/character range constraints for generated story sentences.

#### Manual — JP

| Duration | Level | Sentence min | Sentence max | Char min | Char max |
|---|---|---:|---:|---:|---:|
| 3-5 mins | N5/A1 | 18 | 30 | 250 | 450 |
| 3-5 mins | N4/A2 | 20 | 34 | 350 | 600 |
| 3-5 mins | N3/B1 | 22 | 36 | 500 | 800 |
| 3-5 mins | N2/B2 | 20 | 34 | 650 | 1050 |
| 3-5 mins | N1/C1 | 18 | 32 | 800 | 1300 |
| 5-7 mins | N5/A1 | 28 | 45 | 400 | 650 |
| 5-7 mins | N4/A2 | 32 | 50 | 550 | 900 |
| 5-7 mins | N3/B1 | 34 | 55 | 750 | 1150 |
| 5-7 mins | N2/B2 | 32 | 52 | 1000 | 1550 |
| 5-7 mins | N1/C1 | 30 | 50 | 1250 | 1900 |
| 7-9 mins | N5/A1 | 40 | 60 | 600 | 900 |
| 7-9 mins | N4/A2 | 45 | 65 | 800 | 1200 |
| 7-9 mins | N3/B1 | 48 | 70 | 1050 | 1550 |
| 7-9 mins | N2/B2 | 45 | 68 | 1350 | 2050 |
| 7-9 mins | N1/C1 | 42 | 65 | 1650 | 2500 |

#### Manual — EN

| Duration | Level | Sentence min | Sentence max | Char min | Char max |
|---|---|---:|---:|---:|---:|
| 3-5 mins | N5/A1 | 18 | 30 | 900 | 1600 |
| 3-5 mins | N4/A2 | 20 | 34 | 1200 | 2200 |
| 3-5 mins | N3/B1 | 22 | 36 | 1600 | 2800 |
| 3-5 mins | N2/B2 | 20 | 34 | 2000 | 3400 |
| 3-5 mins | N1/C1 | 18 | 32 | 2400 | 4200 |
| 5-7 mins | N5/A1 | 28 | 45 | 1400 | 2400 |
| 5-7 mins | N4/A2 | 32 | 50 | 1900 | 3300 |
| 5-7 mins | N3/B1 | 34 | 55 | 2500 | 4200 |
| 5-7 mins | N2/B2 | 32 | 52 | 3300 | 5400 |
| 5-7 mins | N1/C1 | 30 | 50 | 4200 | 6800 |
| 7-9 mins | N5/A1 | 40 | 60 | 2200 | 3500 |
| 7-9 mins | N4/A2 | 45 | 65 | 3000 | 4800 |
| 7-9 mins | N3/B1 | 48 | 70 | 4000 | 6200 |
| 7-9 mins | N2/B2 | 45 | 68 | 5200 | 7800 |
| 7-9 mins | N1/C1 | 42 | 65 | 6500 | 9500 |

#### AI — JP

| Duration | Level | Sentence min | Sentence max | Char min | Char max |
|---|---|---:|---:|---:|---:|
| 3-5 mins | N5/A1 | 24 | 38 | 350 | 550 |
| 3-5 mins | N4/A2 | 28 | 42 | 500 | 750 |
| 3-5 mins | N3/B1 | 30 | 45 | 650 | 950 |
| 3-5 mins | N2/B2 | 28 | 42 | 850 | 1250 |
| 3-5 mins | N1/C1 | 26 | 40 | 1050 | 1550 |
| 5-7 mins | N5/A1 | 38 | 55 | 550 | 800 |
| 5-7 mins | N4/A2 | 42 | 60 | 750 | 1100 |
| 5-7 mins | N3/B1 | 45 | 65 | 950 | 1400 |
| 5-7 mins | N2/B2 | 42 | 62 | 1250 | 1800 |
| 5-7 mins | N1/C1 | 40 | 60 | 1550 | 2250 |
| 7-9 mins | N5/A1 | 55 | 75 | 800 | 1100 |
| 7-9 mins | N4/A2 | 60 | 82 | 1050 | 1500 |
| 7-9 mins | N3/B1 | 62 | 88 | 1350 | 1900 |
| 7-9 mins | N2/B2 | 58 | 84 | 1700 | 2450 |
| 7-9 mins | N1/C1 | 55 | 80 | 2100 | 3000 |

#### AI — EN

| Duration | Level | Sentence min | Sentence max | Char min | Char max |
|---|---|---:|---:|---:|---:|
| 3-5 mins | N5/A1 | 24 | 38 | 1200 | 2100 |
| 3-5 mins | N4/A2 | 28 | 42 | 1600 | 2800 |
| 3-5 mins | N3/B1 | 30 | 45 | 2200 | 3600 |
| 3-5 mins | N2/B2 | 28 | 42 | 2800 | 4400 |
| 3-5 mins | N1/C1 | 26 | 40 | 3400 | 5400 |
| 5-7 mins | N5/A1 | 38 | 55 | 2000 | 3200 |
| 5-7 mins | N4/A2 | 42 | 60 | 2600 | 4200 |
| 5-7 mins | N3/B1 | 45 | 65 | 3400 | 5200 |
| 5-7 mins | N2/B2 | 42 | 62 | 4400 | 6600 |
| 5-7 mins | N1/C1 | 40 | 60 | 5600 | 8200 |
| 7-9 mins | N5/A1 | 55 | 75 | 3000 | 4500 |
| 7-9 mins | N4/A2 | 60 | 82 | 4000 | 6000 |
| 7-9 mins | N3/B1 | 62 | 88 | 5200 | 7600 |
| 7-9 mins | N2/B2 | 58 | 84 | 6800 | 9500 |
| 7-9 mins | N1/C1 | 55 | 80 | 8500 | 12000 |

### C3. `learnLimits` (vocabulary + grammar limits)

Each `learnLimits` row is keyed by:
- Duration (`"3-5 mins" | "5-7 mins" | "7-9 mins"`)
- Level (`"N5/A1" ... "N1/C1"`)
- Language (`"JP" | "EN"`)
- Module (`"Vocabulary" | "Grammar"`)

For a matching row:
- **Manual mode** uses `Manual_Min` and `Manual_Max` as an allowed range.
- **AI mode (FULL only)** uses the slider-selected key (`minimum`/`default`/`optimal`/`maximum`) as a single **selected count**.

#### Learn limits table (verbatim values)

| Duration | Level | Lang | Module | Manual min | Manual max | AI minimum | AI default | AI optimal | AI maximum |
|---|---|---|---|---:|---:|---:|---:|---:|---:|
| 3-5 mins | N5/A1 | EN | Grammar | 2 | 5 | 2 | 3 | 4 | 5 |
| 3-5 mins | N5/A1 | EN | Vocabulary | 6 | 13 | 6 | 8 | 10 | 13 |
| 3-5 mins | N5/A1 | JP | Grammar | 2 | 5 | 2 | 3 | 4 | 5 |
| 3-5 mins | N5/A1 | JP | Vocabulary | 6 | 12 | 6 | 8 | 10 | 12 |
| 3-5 mins | N4/A2 | EN | Grammar | 3 | 7 | 3 | 4 | 5 | 7 |
| 3-5 mins | N4/A2 | EN | Vocabulary | 8 | 17 | 8 | 11 | 13 | 17 |
| 3-5 mins | N4/A2 | JP | Grammar | 3 | 7 | 3 | 4 | 5 | 7 |
| 3-5 mins | N4/A2 | JP | Vocabulary | 8 | 16 | 8 | 11 | 13 | 16 |
| 3-5 mins | N3/B1 | EN | Grammar | 4 | 10 | 4 | 6 | 8 | 10 |
| 3-5 mins | N3/B1 | EN | Vocabulary | 11 | 24 | 11 | 16 | 19 | 24 |
| 3-5 mins | N3/B1 | JP | Grammar | 4 | 10 | 4 | 6 | 8 | 10 |
| 3-5 mins | N3/B1 | JP | Vocabulary | 10 | 22 | 10 | 14 | 17 | 22 |
| 3-5 mins | N2/B2 | EN | Grammar | 5 | 13 | 5 | 8 | 10 | 13 |
| 3-5 mins | N2/B2 | EN | Vocabulary | 15 | 32 | 15 | 21 | 25 | 32 |
| 3-5 mins | N2/B2 | JP | Grammar | 5 | 13 | 5 | 8 | 10 | 13 |
| 3-5 mins | N2/B2 | JP | Vocabulary | 12 | 28 | 12 | 18 | 22 | 28 |
| 3-5 mins | N1/C1 | EN | Grammar | 6 | 16 | 6 | 10 | 12 | 16 |
| 3-5 mins | N1/C1 | EN | Vocabulary | 20 | 42 | 20 | 28 | 33 | 42 |
| 3-5 mins | N1/C1 | JP | Grammar | 6 | 16 | 6 | 10 | 12 | 16 |
| 3-5 mins | N1/C1 | JP | Vocabulary | 15 | 36 | 15 | 22 | 28 | 36 |
| 5-7 mins | N5/A1 | EN | Grammar | 3 | 7 | 3 | 4 | 5 | 7 |
| 5-7 mins | N5/A1 | EN | Vocabulary | 10 | 20 | 10 | 14 | 16 | 20 |
| 5-7 mins | N5/A1 | JP | Grammar | 3 | 7 | 3 | 4 | 5 | 7 |
| 5-7 mins | N5/A1 | JP | Vocabulary | 9 | 18 | 9 | 12 | 14 | 18 |
| 5-7 mins | N4/A2 | EN | Grammar | 4 | 10 | 4 | 6 | 8 | 10 |
| 5-7 mins | N4/A2 | EN | Vocabulary | 13 | 26 | 13 | 18 | 21 | 26 |
| 5-7 mins | N4/A2 | JP | Grammar | 4 | 10 | 4 | 6 | 8 | 10 |
| 5-7 mins | N4/A2 | JP | Vocabulary | 12 | 24 | 12 | 16 | 19 | 24 |
| 5-7 mins | N3/B1 | EN | Grammar | 5 | 14 | 5 | 8 | 10 | 14 |
| 5-7 mins | N3/B1 | EN | Vocabulary | 18 | 36 | 18 | 24 | 29 | 36 |
| 5-7 mins | N3/B1 | JP | Grammar | 5 | 14 | 5 | 8 | 10 | 14 |
| 5-7 mins | N3/B1 | JP | Vocabulary | 16 | 32 | 16 | 22 | 26 | 32 |
| 5-7 mins | N2/B2 | EN | Grammar | 7 | 18 | 7 | 11 | 14 | 18 |
| 5-7 mins | N2/B2 | EN | Vocabulary | 24 | 48 | 24 | 32 | 38 | 48 |
| 5-7 mins | N2/B2 | JP | Grammar | 7 | 18 | 7 | 11 | 14 | 18 |
| 5-7 mins | N2/B2 | JP | Vocabulary | 20 | 42 | 20 | 28 | 33 | 42 |
| 5-7 mins | N1/C1 | EN | Grammar | 9 | 22 | 9 | 14 | 17 | 22 |
| 5-7 mins | N1/C1 | EN | Vocabulary | 32 | 64 | 32 | 43 | 51 | 64 |
| 5-7 mins | N1/C1 | JP | Grammar | 9 | 22 | 9 | 14 | 17 | 22 |
| 5-7 mins | N1/C1 | JP | Vocabulary | 26 | 55 | 26 | 36 | 43 | 55 |
| 7-9 mins | N5/A1 | EN | Grammar | 4 | 9 | 4 | 6 | 7 | 9 |
| 7-9 mins | N5/A1 | EN | Vocabulary | 14 | 28 | 14 | 19 | 22 | 28 |
| 7-9 mins | N5/A1 | JP | Grammar | 4 | 9 | 4 | 6 | 7 | 9 |
| 7-9 mins | N5/A1 | JP | Vocabulary | 12 | 24 | 12 | 16 | 19 | 24 |
| 7-9 mins | N4/A2 | EN | Grammar | 5 | 13 | 5 | 8 | 10 | 13 |
| 7-9 mins | N4/A2 | EN | Vocabulary | 18 | 36 | 18 | 24 | 29 | 36 |
| 7-9 mins | N4/A2 | JP | Grammar | 5 | 13 | 5 | 8 | 10 | 13 |
| 7-9 mins | N4/A2 | JP | Vocabulary | 16 | 32 | 16 | 22 | 26 | 32 |
| 7-9 mins | N3/B1 | EN | Grammar | 7 | 18 | 7 | 11 | 14 | 18 |
| 7-9 mins | N3/B1 | EN | Vocabulary | 25 | 50 | 25 | 34 | 40 | 50 |
| 7-9 mins | N3/B1 | JP | Grammar | 7 | 18 | 7 | 11 | 14 | 18 |
| 7-9 mins | N3/B1 | JP | Vocabulary | 22 | 42 | 22 | 29 | 34 | 42 |
| 7-9 mins | N2/B2 | EN | Grammar | 9 | 24 | 9 | 14 | 18 | 24 |
| 7-9 mins | N2/B2 | EN | Vocabulary | 34 | 66 | 34 | 45 | 53 | 66 |
| 7-9 mins | N2/B2 | JP | Grammar | 9 | 24 | 9 | 14 | 18 | 24 |
| 7-9 mins | N2/B2 | JP | Vocabulary | 28 | 55 | 28 | 37 | 44 | 55 |
| 7-9 mins | N1/C1 | EN | Grammar | 12 | 30 | 12 | 18 | 23 | 30 |
| 7-9 mins | N1/C1 | EN | Vocabulary | 45 | 85 | 45 | 59 | 69 | 85 |
| 7-9 mins | N1/C1 | JP | Grammar | 12 | 30 | 12 | 18 | 23 | 30 |
| 7-9 mins | N1/C1 | JP | Vocabulary | 36 | 70 | 36 | 48 | 56 | 70 |

### C4. `quizLimits` (quiz counts + distribution)

Each `quizLimits` row is keyed by:
- duration + level + quiz_category

Categories:
- `Vocabulary Quiz`
- `Grammar Quiz`
- `Sentence Quiz`
- `Total Quiz`

For a matching row:
- **Manual mode** uses `manual_min`–`manual_max` ranges.
- **AI mode (FULL only)** uses the slider-selected key as a single selected count.

Additionally, for **AI + FULL LEARN**, the HTML declares a hard contract requiring **exact quiz distribution**:
- vocabulary quiz count == selected `Vocabulary Quiz`
- grammar quiz count == selected `Grammar Quiz`
- sample_sentence quiz count == selected `Sentence Quiz`
- total quiz count == selected `Total Quiz`

#### Quiz limits table (verbatim values)

| Duration | Level | Category | Manual min | Manual max | AI minimum | AI default | AI optimal | AI maximum |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 3-5 mins | N5/A1 | Vocabulary Quiz | 3 | 6 | 4 | 5 | 6 | 8 |
| 3-5 mins | N5/A1 | Grammar Quiz | 1 | 3 | 2 | 3 | 3 | 4 |
| 3-5 mins | N5/A1 | Sentence Quiz | 1 | 3 | 2 | 3 | 3 | 4 |
| 3-5 mins | N5/A1 | Total Quiz | 5 | 12 | 8 | 11 | 13 | 16 |
| 3-5 mins | N4/A2 | Vocabulary Quiz | 4 | 8 | 5 | 7 | 8 | 10 |
| 3-5 mins | N4/A2 | Grammar Quiz | 2 | 4 | 2 | 3 | 4 | 5 |
| 3-5 mins | N4/A2 | Sentence Quiz | 2 | 4 | 2 | 3 | 4 | 5 |
| 3-5 mins | N4/A2 | Total Quiz | 8 | 16 | 9 | 13 | 16 | 20 |
| 3-5 mins | N3/B1 | Vocabulary Quiz | 5 | 10 | 6 | 8 | 10 | 13 |
| 3-5 mins | N3/B1 | Grammar Quiz | 2 | 5 | 3 | 4 | 5 | 6 |
| 3-5 mins | N3/B1 | Sentence Quiz | 2 | 5 | 3 | 4 | 5 | 6 |
| 3-5 mins | N3/B1 | Total Quiz | 9 | 20 | 12 | 17 | 20 | 25 |
| 3-5 mins | N2/B2 | Vocabulary Quiz | 6 | 12 | 8 | 11 | 13 | 16 |
| 3-5 mins | N2/B2 | Grammar Quiz | 3 | 6 | 4 | 5 | 6 | 8 |
| 3-5 mins | N2/B2 | Sentence Quiz | 3 | 6 | 3 | 4 | 5 | 7 |
| 3-5 mins | N2/B2 | Total Quiz | 12 | 24 | 15 | 21 | 25 | 31 |
| 3-5 mins | N1/C1 | Vocabulary Quiz | 7 | 14 | 10 | 14 | 16 | 20 |
| 3-5 mins | N1/C1 | Grammar Quiz | 3 | 7 | 5 | 7 | 8 | 10 |
| 3-5 mins | N1/C1 | Sentence Quiz | 3 | 7 | 4 | 5 | 6 | 8 |
| 3-5 mins | N1/C1 | Total Quiz | 13 | 28 | 19 | 26 | 30 | 38 |
| 5-7 mins | N5/A1 | Vocabulary Quiz | 5 | 9 | 6 | 8 | 10 | 12 |
| 5-7 mins | N5/A1 | Grammar Quiz | 2 | 4 | 3 | 4 | 5 | 6 |
| 5-7 mins | N5/A1 | Sentence Quiz | 2 | 4 | 3 | 4 | 5 | 6 |
| 5-7 mins | N5/A1 | Total Quiz | 9 | 17 | 12 | 16 | 19 | 24 |
| 5-7 mins | N4/A2 | Vocabulary Quiz | 6 | 12 | 8 | 11 | 13 | 16 |
| 5-7 mins | N4/A2 | Grammar Quiz | 2 | 5 | 4 | 5 | 6 | 8 |
| 5-7 mins | N4/A2 | Sentence Quiz | 3 | 5 | 3 | 4 | 5 | 7 |
| 5-7 mins | N4/A2 | Total Quiz | 11 | 22 | 15 | 21 | 25 | 31 |
| 5-7 mins | N3/B1 | Vocabulary Quiz | 8 | 16 | 10 | 14 | 16 | 20 |
| 5-7 mins | N3/B1 | Grammar Quiz | 3 | 7 | 5 | 7 | 8 | 10 |
| 5-7 mins | N3/B1 | Sentence Quiz | 3 | 7 | 4 | 5 | 6 | 8 |
| 5-7 mins | N3/B1 | Total Quiz | 14 | 30 | 19 | 26 | 30 | 38 |
| 5-7 mins | N2/B2 | Vocabulary Quiz | 10 | 20 | 13 | 18 | 21 | 26 |
| 5-7 mins | N2/B2 | Grammar Quiz | 4 | 9 | 6 | 8 | 10 | 13 |
| 5-7 mins | N2/B2 | Sentence Quiz | 4 | 8 | 5 | 7 | 8 | 10 |
| 5-7 mins | N2/B2 | Total Quiz | 18 | 37 | 24 | 33 | 39 | 49 |
| 5-7 mins | N1/C1 | Vocabulary Quiz | 12 | 24 | 16 | 22 | 26 | 32 |
| 5-7 mins | N1/C1 | Grammar Quiz | 5 | 11 | 8 | 11 | 13 | 16 |
| 5-7 mins | N1/C1 | Sentence Quiz | 5 | 10 | 6 | 8 | 10 | 12 |
| 5-7 mins | N1/C1 | Total Quiz | 22 | 45 | 30 | 41 | 48 | 60 |
| 7-9 mins | N5/A1 | Vocabulary Quiz | 6 | 12 | 8 | 11 | 13 | 16 |
| 7-9 mins | N5/A1 | Grammar Quiz | 2 | 5 | 4 | 5 | 6 | 8 |
| 7-9 mins | N5/A1 | Sentence Quiz | 3 | 5 | 4 | 5 | 6 | 8 |
| 7-9 mins | N5/A1 | Total Quiz | 11 | 22 | 16 | 22 | 26 | 32 |
| 7-9 mins | N4/A2 | Vocabulary Quiz | 8 | 16 | 10 | 14 | 16 | 20 |
| 7-9 mins | N4/A2 | Grammar Quiz | 3 | 6 | 5 | 7 | 8 | 10 |
| 7-9 mins | N4/A2 | Sentence Quiz | 3 | 7 | 5 | 7 | 8 | 10 |
| 7-9 mins | N4/A2 | Total Quiz | 14 | 29 | 20 | 27 | 32 | 40 |
| 7-9 mins | N3/B1 | Vocabulary Quiz | 10 | 20 | 13 | 18 | 21 | 26 |
| 7-9 mins | N3/B1 | Grammar Quiz | 4 | 9 | 6 | 8 | 10 | 13 |
| 7-9 mins | N3/B1 | Sentence Quiz | 4 | 9 | 6 | 8 | 10 | 12 |
| 7-9 mins | N3/B1 | Total Quiz | 18 | 38 | 25 | 34 | 41 | 51 |
| 7-9 mins | N2/B2 | Vocabulary Quiz | 13 | 26 | 17 | 23 | 27 | 34 |
| 7-9 mins | N2/B2 | Grammar Quiz | 5 | 12 | 8 | 11 | 13 | 17 |
| 7-9 mins | N2/B2 | Sentence Quiz | 5 | 11 | 7 | 9 | 11 | 14 |
| 7-9 mins | N2/B2 | Total Quiz | 23 | 49 | 32 | 44 | 52 | 65 |
| 7-9 mins | N1/C1 | Vocabulary Quiz | 16 | 32 | 22 | 29 | 34 | 42 |
| 7-9 mins | N1/C1 | Grammar Quiz | 6 | 15 | 10 | 14 | 17 | 21 |
| 7-9 mins | N1/C1 | Sentence Quiz | 6 | 13 | 8 | 11 | 13 | 16 |
| 7-9 mins | N1/C1 | Total Quiz | 28 | 60 | 40 | 54 | 63 | 79 |

### C5. Selected-count logic (HTML)

`getSelectedCounts()`:
- Looks up limits using `findLearnLimit(...)` / `findQuizLimit(...)`.
- In **Manual** mode returns display strings like `"min-max"` (e.g. `"6-12"`).
- In **AI** mode returns a single value `row[aiLimit]` where `aiLimit` is the selected slider key.

### C6. ReadOnly vs FullLearn behavior (HTML)

- **ReadOnly**:
  - Uses only `sentenceLimits` (sentence count + character range)
  - No learn limits / quiz limits are part of the ReadOnly limitation contract.
- **FullLearn**:
  - Uses `sentenceLimits` + `learnLimits` + `quizLimits`
  - Audio: explicitly allows import with `learn.audio.storyAudio` present but with `sourceUrl` null and `localPath` null (so the app imports as Ready to Preview and user uploads audio later).

### C7. Manual vs AI mode behavior (HTML)

- **Manual mode**:
  - The prompt area is actual story text; HTML validates it against `sentenceLimits` ranges.
  - FullLearn counts are specified as **ranges** (`min-max`).
- **AI mode**:
  - FullLearn counts become **selected exact counts** (slider-selected).
  - A “HARD COUNT CONTRACT” is declared to force exact array lengths and quiz distribution in the generated JSON.

### C8. JP vs EN behavior (HTML)

- Both JP and EN are supported by rule tables.
- Sentence/character limits differ by language.
- For EN-learning flows, the HTML still instructs using `content.japaneseText` for current Nimon import compatibility (key-name compatibility).

---

## D. Exact mismatch table (HTML vs current Nimon rules)

### D0. Comparison scope

- **HTML source-of-truth**: `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html` (Sections C1–C8).
- **Current Nimon rules**: as documented in Section B (Flutter + backend publish validation tables + creator readiness minimums).
- Because Nimon currently blocks English-learning import, mismatches are evaluated primarily on **JP**; EN rules are still listed as **future scope**.

### D1. Mismatches

| Rule area | Current Nimon value | HTML value | Affected layer | File path(s) | Recommended change | Risk |
|---|---|---|---|---|---|---|
| Story sentence limits (JP) | JLPT×band min/max (no Manual/AI difference). Example N5 `3_5`: 10–35 | **Manual JP** N5/A1 `3-5 mins`: 18–30; **AI JP** N5/A1 `3-5 mins`: 24–38 | Flutter+backend publish validation; creator readiness; preflight | `lib/core/validation/story_validators.dart`, `lib/core/validation/publish_validation.dart`, `nimon-backend/src/common/validation/story-validation.ts`, `nimon-backend/src/common/validation/publish-validation.ts`, `lib/features/create/creator_completion_rules.dart` | Replace Nimon sentence min/max tables with HTML `sentenceLimits` projected into app keys (JLPT-only + band) and include mode handling where applicable | High |
| Character limits (JP) | Publish blocks only on **maxChars**; no char minimum. Example N5 `3_5`: maxChars 900 | HTML enforces **minChar and maxChar**. Example Manual JP N5/A1 `3-5 mins`: 250–450; AI JP: 350–550 | Flutter+backend publish validation; (optional) readiness UX | `lib/core/validation/story_validators.dart`, `lib/core/validation/publish_validation.dart`, backend equivalents | Introduce char-min enforcement (where HTML requires) and adjust maxChar to HTML values | High |
| Manual vs AI mode rule dimension | No Manual/AI dimension in Nimon limits | `sentenceLimits` differ between Manual and AI; FULL+AI uses slider-selected exact counts | Import validation, readiness, preflight, backend validation | Import meta files + validation layers listed in A | Add a shared rule lookup keyed by (mode, language, duration, level) and preserve current behavior until wiring phases | High |
| Learn (vocab/grammar) count limits | FullLearn publish validates ranges by JLPT×band. Example N5 `3_5`: vocab 8–18, grammar 3–5 | HTML FullLearn uses **ranges in Manual** and **selected exact count in AI**. Example JP N5/A1 `3-5 mins`: vocab 6–12, grammar 2–5 (and AI slider selects 6/8/10/12 etc.) | Flutter+backend publish validation; creator readiness thresholds | `lib/core/validation/learn_validators.dart`, `lib/core/validation/publish_validation.dart`, backend equivalents, `lib/features/create/creator_completion_rules.dart` | Replace JLPT×band learn tables with HTML `learnLimits` (JP only for now), including slider logic for AI | High |
| Quiz total count limits | FullLearn publish validates total quiz range by JLPT×band. Example N5 `3_5`: 6–10 | HTML uses Manual ranges and AI selected totals. Example JP N5/A1 `3-5 mins` Total Quiz: 5–12 (AI selected 8/11/13/16) | Flutter+backend publish validation; creator readiness | `lib/core/validation/learn_validators.dart`, `lib/core/validation/publish_validation.dart`, backend equivalents | Replace quiz total range tables with HTML `quizLimits` Total Quiz for JP | High |
| Quiz category distribution | No per-category distribution rules | AI + FULL requires **exact category counts** for vocab/grammar/sentence quizzes that sum to Total Quiz | Import validation (Phase 2), publish validation (later), tests | `lib/features/create/import/nimon_import_validator.dart` (later wiring), validation layers | Add support for category distribution limits in shared config; enforce in import validation first (Phase 2) | Medium |
| ReadOnly rule coverage | ReadOnly readiness uses duration-only minimum sentences (8/14/20) and ignores chars | ReadOnly requires sentence+char range by (mode, language, duration, level) | UI readiness + publish UX alignment | `lib/features/create/creator_readiness.dart`, `lib/features/create/creator_completion_rules.dart`, publish preflight | Move ReadOnly readiness to HTML sentence+char rules (JP only) in Phase 3 (keep manual flow stable until then) | Medium |
| Audio requirement semantics | UI readiness requires 1 audio; publish gate checks module status completed | HTML FullLearn import allows audio present with null URLs/paths (“Ready to Preview”, upload later) | Readiness + import validation UX | `lib/features/create/creator_readiness.dart`, `lib/features/create/import/nimon_import_validator.dart` | Keep current Nimon semantics for now; when wiring HTML, ensure FullLearn readiness/import aligns with “audio may be null but present” contract | Medium |
| English-learning support | Import validator blocks English learning (`coming soon`) | HTML includes EN rule tables + EN template names and char limits | Import validation / future product scope | `lib/features/create/import/nimon_import_validator.dart`, HTML generator | **Do not enable EN** yet; keep HTML EN rules in config for future but behind feature gate | Low |

Mismatch count vs current Nimon (rule areas): **9**

### D2. Internal mismatch table (current Nimon UI readiness vs publish validation)

These are differences **within current Nimon** (independent of HTML), retained here because they affect migration risk.

| Rule area | Current Nimon value | Other current Nimon value | Affected layer | File path(s) | Recommended future change | Risk |
|---|---|---|---|---|---|---|
| Story sentence minimum (3_5) | UI readiness min = 8 | Publish min varies by JLPT: N5=10, N4=8, N3=7, N2=6, N1=5 | UI readiness vs publish | `lib/features/create/creator_completion_rules.dart`, `lib/core/validation/story_validators.dart` | Move UI readiness to the HTML-authoritative rule model | High |
| Story sentence maximum | UI readiness has no max | Publish has max by JLPT×band | UI readiness vs publish | `lib/features/create/creator_completion_rules.dart`, `lib/core/validation/story_validators.dart` | Add max handling where HTML requires it (readiness copy + preflight parity) | Medium |
| Story max chars | UI readiness ignores char length | Publish blocks on `maxChars` by JLPT×band | UI readiness vs publish | `lib/features/create/creator_completion_rules.dart`, `lib/core/validation/publish_validation.dart` | Add char-count readiness visibility and align to HTML min/max chars | Medium |
| Vocab/Grammar/Quiz mins | UI readiness min-only by band | Publish min+max by JLPT×band | UI readiness vs publish | `lib/features/create/creator_completion_rules.dart`, `lib/core/validation/learn_validators.dart` | Migrate readiness and publish to the same HTML config | High |
| Audio requirement | UI readiness requires 1 audio item | Publish gate uses module status `audio=completed` (not explicit audio validation) | UI readiness vs publish | `lib/features/create/creator_readiness.dart`, `lib/core/validation/publish_validation.dart` | Align audio semantics to HTML FullLearn import contract (audio may be null-but-present until upload) | Medium |
| Quiz options shape (import) | Import blocks unless exactly 4 options | Publish validator allows 2–4 options | Import vs publish | `lib/features/create/import/nimon_import_validator.dart` vs `lib/core/validation/learn_validators.dart` | Align import contract and publish validator expectations when wiring HTML rules | Medium |

Internal mismatch count (Nimon vs Nimon): **6**

---

## E. Proposed migration strategy (HTML authoritative, safe phases)

### Phase 1 — Add shared rule config extracted from HTML (no behavior change)

- Add a **single shared “HTML rules” model** (Flutter + backend) that represents:
  - language (JP/EN), prompt mode (Manual/AI), readOnly/fullLearn
  - level normalization and duration normalization
  - limits: sentences, chars, vocab, grammar, quiz (by category + total)
- Add tests proving the config loads and normalizes inputs, but **do not wire it into validators yet**.

### Phase 2 — Wire import validator to HTML rules first

- Enforce HTML limits at import time for import-ready JSON:
  - Imported JSON violating HTML rules must be blocked (or “preview only” if the HTML model supports that concept).
- Do **not** alter manual creator readiness yet.

### Phase 3 — Wire UI readiness (ReadOnly/FullLearn) to HTML rules

- ReadOnly readiness uses HTML sentence rules (and any HTML-defined core requirements).
- FullLearn readiness uses HTML sentence + vocab + grammar + quiz + audio rules.
- Keep copy/UX behavior consistent (“Ready to Preview”, not “Ready to Publish” for import).

### Phase 4 — Wire client publish preflight to HTML rules

- Replace current preflight numeric tables with HTML-based config, retaining existing warning/blocking UX patterns.

### Phase 5 — Wire backend validation to the same values

- Backend must not reject content that Flutter says is valid.
- Ensure backend uses exactly the same extracted values and normalization logic as Flutter.

---

## F. Implementation file map for next prompt (no changes in this prompt)

### Phase 1 only (config-only; no wiring; no behavior change)

#### Flutter-only

- Create:
  - `lib/core/limits/html_generator_limits.dart`
    - Embed `sentenceLimits`, `learnLimits`, `quizLimits`, `sliderKeys`
    - Expose typed lookup APIs and normalization helpers mirroring HTML (`normalizeLevel`, `normalizeDuration`, `normalizeLanguage`, `durationBandKey`, `jlptOnly`, `cleanCategory`)
  - `test/core/limits/html_generator_limits_test.dart`
    - Pure tests for config values + lookups (no validator wiring)

#### Backend-only

- Create:
  - `nimon-backend/src/common/limits/html-generator-limits.ts`
  - `nimon-backend/src/common/limits/html-generator-limits.spec.ts`
  - These should match the Flutter config data exactly (copied values; no wiring yet).

### Tests

Phase 1 adds config-only tests only (see Section G).

### Docs

- This doc now includes HTML-extracted tables from `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`.

---

## G. Phase 1 tests needed (config-only; no wiring)

### Flutter tests (new)

- `test/core/limits/html_generator_limits_test.dart`
  - **config values**: spot-check a handful of canonical cells for `sentenceLimits`, `learnLimits`, `quizLimits` (JP + at least one EN cell to ensure it is present but not enabled)
  - **normalization**:
    - `normalizeLevel("1.N5/A1") == "N5/A1"`
    - `jlptOnly("N5/A1") == "N5"`
    - `normalizeDuration("1. 3-5 mins") == "3-5 mins"`
    - `durationBandKey("1. 3-5 mins") == "3_5"`
    - `normalizeLanguage("1. Jp (Japanese)") == "JP"`
    - `cleanCategory("10.Mystery") == "Mystery"`
  - **selected slider logic**:
    - slider keys are exactly `["minimum","default","optimal","maximum"]`
    - default slider index maps to `default`
    - AI selection returns a single count for FULL+AI (do not wire; just test lookup helpers)
  - **ReadOnly vs FullLearn rule lookup**:
    - ReadOnly uses only sentence/char rule lookup
    - FullLearn lookup returns sentence+char + vocab + grammar + quiz limits object (even if not used yet)
  - **Manual vs AI rule lookup**:
    - Manual lookup returns ranges (min/max)
    - AI lookup returns selected counts by slider key
  - **JP-only behavior for current app**:
    - ensure the config layer has a “language enabled” gate defaulting to JP-only (Phase 1 can expose a helper; behavior must not be wired)

### Backend tests (new)

- `nimon-backend/src/common/limits/html-generator-limits.spec.ts`
  - Mirror the same spot checks + normalization tests so backend config matches Flutter.

---

## H. Safety rules for the next implementation prompt

- Do **not** enable English learning unless the app already supports it (current import validator blocks English).
- Do **not** break manual creation flow.
- Do **not** change hidden import UI.
- Do **not** change JSON import mapper except if counts/readiness require it.
- Do **not** touch old unused `creator_publish_validation.dart` unless explicitly requested to deprecate/remove.
- Do **not** auto-publish imported content.
- Keep import success copy as **“Ready to Preview”**, not “Ready to Publish”.

---

## Appendix — HTML generator file used

- `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`

