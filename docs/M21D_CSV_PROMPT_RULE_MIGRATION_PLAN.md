# M21D — CSV_Prompt / HTML Rule Migration Plan

**Plan only — no code changes.**  
Companion audits: `docs/M21A_CURRENT_STORY_AND_LEARN_RULES_AUDIT.md`, `docs/M21B_CURRENT_RULE_MATRIX_AUDIT.md`, `docs/M21C_JSON_IMPORT_FLOW_IMPLEMENTATION_REPORT.md`.

---

## 1. Executive summary

Nimon today enforces content rules in **four independent layers** that share similar tables but **different numeric thresholds** and **different field coverage**:

| Layer | Role | Authoritative for HTTP publish? |
|-------|------|--------------------------------|
| UI readiness | Publish button / drawer enablement | No |
| Client publish preflight | `validateStoryPublishData` before POST | Yes (with warnings + “Publish anyway”) |
| Backend publish | `validateStoryPublishInput` on publish endpoints | Yes (blocking only) |
| Import validator | AI JSON contract + app context | Import gate only (structural today) |

The **hidden JSON import** path is complete through navigation and readiness integration tests, but **`validateNimonImportPayload` does not yet enforce the full CSV_Prompt / HTML generator matrix** (JLPT×band counts, glossary, grammar mistake fields, quiz distribution, null-minimization, etc.).

**Recommended direction:** Introduce a **single Dart rule config + rule engine** (generated or hand-maintained from CSV/HTML docs) as the long-term source of truth on the client; keep **backend TypeScript tables in parity** via shared JSON or a one-time export script. **Do not** enable English learning until a dedicated Phase G.

**Safest solo-developer path:** **Hybrid** — versioned JSON rule config in-repo + thin Dart/TS adapters (Phase B–F), not a live rule API and not duplicated hand-edited constants in three places forever.

---

## 2. Current validation layers (audit)

### 2.1 UI readiness (Flutter-only)

| Symbol | File | Behavior |
|--------|------|----------|
| `CreatorV1DurationThresholds` | `lib/features/create/creator_completion_rules.dart` | Band mins: sentences **8/14/20**, vocab **6/9/12**, grammar **3/5/7**, quiz **4/6/8**, audio **1** |
| `computeStoryBasicsStatus` | same | Requires title, category, level, description (UX) |
| `computeStorySentencesStatus` / vocab / grammar / quiz / listening | same | Count-based “complete” vs band mins |
| `syncModuleWorkflowWithContent` | same | Sets `moduleWorkflowStatuses[*] = completed` when `moduleMeetsV1Completion` |
| `computeReadOnlyReady` / `computeFullLearnReady` | `lib/features/create/creator_readiness.dart` | Aggregates basics + modules |
| `buildStoryReviewDisplayModel` | `lib/features/create/story_creator_review_display.dart` | Drawer labels; uses readiness only |
| `isStoryReviewModeAllowed` | same | Gates Read Only vs Full Learn mode in drawer |

**Not authoritative for publish HTTP.** Lower mins than publish (e.g. N5 `3_5`: UI **8** sentences vs publish **10**).

### 2.2 Client publish preflight

| Symbol | File | Behavior |
|--------|------|----------|
| `storyPublishDataFromCreator` | `lib/features/create/creator_publish_preflight.dart` | Maps `CreatorStoryV1` → wire-shaped `StoryPublishData` |
| `validateStoryPublishData` | `lib/core/validation/publish_validation.dart` | RO / FL modes; blocking + warnings |
| `performCreatorDrawerPublish` / `_preflightCreatorPublish` | `lib/features/create/creator_drawer_publish.dart` | Sheet on blocking; optional proceed on warnings |
| `publish_validation_sheet.dart` | `lib/features/create/publish_validation_sheet.dart` | UI for issues |

Uses: `story_validators.dart`, `learn_validators.dart`, `story_duration_band.dart`, limit tables in those files.

### 2.3 Backend publish validation (repo: `nimon-backend/`)

| Symbol | File | Behavior |
|--------|------|----------|
| `validateStoryPublishInput` | `nimon-backend/src/common/validation/publish-validation.ts` | Mirrors Flutter `validateStoryPublishData` structure |
| `STORY_SENTENCE_LIMITS` | `story-validation.ts` | JLPT×band sentence min/max + maxChars |
| `VOCABULARY_LIMITS` / `GRAMMAR_PATTERN_LIMITS` / `QUIZ_LIMITS` | `learn-validation.ts` | Count + per-item rules |
| `assertNoBlockingValidationIssues` | `validation-exception.ts` | HTTP `400 validation_failed` |
| `StoryDraftsService.publishReadOnly` / `publishFullLearn` | `story-drafts.service.ts` | Invokes validation; FL needs `publishedMonoId` (422, not validation_failed) |

Flutter comments state tables **mirror** backend; drift is a known risk (furigana regex, future edits).

### 2.4 Import validator (today)

| Symbol | File | Behavior |
|--------|------|----------|
| `validateNimonImportPayload` | `lib/features/create/import/nimon_import_validator.dart` | Meta, context, RO/FL shape, quiz 4 options, FL audio missing → `missingPublishRequirements` |
| `mapNimonImportPayloadToCreatorStoryV1` | `lib/features/create/import/nimon_import_mapper.dart` | Wire-compat fields (`japaneseText`, `termJapanese`) |
| `importMappedDraft` | `lib/features/create/story_creator_provider.dart` | Local save; `json_import` → no publish POST |

**Does not** call `validateStoryPublishData` or JLPT×band appendices.

### 2.5 Legacy / unused

| Symbol | File | Notes |
|--------|------|-------|
| `creator_publish_validation.dart` | `lib/features/create/creator_publish_validation.dart` | **Not imported** in live publish path; looser checklist — do not extend; deprecate in Phase A doc |
| `creator_publish_preflight.dart` | Thin adapter only — keep |

### 2.6 Module workflow vs audio

- **Publish FL:** `fullLearnModulesComplete` requires `vocabulary_kanji`, `grammar`, `quiz`, `audio` all `completed` (string match).
- **UI readiness:** `computeListeningStatus` uses `StoryAudioAsset.isValidV1` (URL or local file metadata).
- **Import:** Missing audio → import OK, `import.fullLearn.audioRequired` in `missingPublishRequirements`; does not auto-complete audio workflow.

---

## 3. Old rules vs CSV_Prompt / HTML target matrix

**Legend**

- **App publish** = `validateStoryPublishData` / `validateStoryPublishInput` today.
- **UI readiness** = `CreatorV1DurationThresholds` + `compute*Ready`.
- **Import today** = `validateNimonImportPayload`.
- **CSV/HTML target** = desired generator contract (stricter on structure/nulls; may align counts with publish tables or generator-specific tables — **decide in Phase A** against actual CSV/HTML spec files outside this repo).

### A. Story / core

| Topic | App publish | UI readiness | Import today | CSV/HTML target (recommended) |
|-------|-------------|--------------|--------------|-----------------------------|
| Sentence count | JLPT×band Appendix A (e.g. N5 `3_5` min **10**) | Band mins **8/14/20** only | ≥1 sentence, no band counts | **Match publish Appendix A** for import + eventual publish alignment |
| Character sum | `maxChars` per Appendix A | Not checked | Not checked | Enforce on import JSON + publish |
| Duration band | `targetDurationBandKey` `3_5`/`5_7`/`7_9` | Required for UI mins | From `core` | Required; warn if missing (limits skipped) |
| JLPT / level | `normalizeJlptLevel` N1–N5 | Required in basics UI | Parsed meta | Required; reject unknown |
| Title / description | Title 5–80; desc max 160 + safety rules | Basics required | Partial via `core` | Full meta + `core` rules |
| Meanings / translation | Not required at publish | Optional | Mapped if present | Require `en`+`my` (or community rules) per product |
| Furigana | Optional at publish | Optional | Mapped | JP: require or allow empty spans per generator spec |
| Primary text field | `japaneseText` wire keys | `japaneseText` only | `japaneseText` compat | Logical `primaryText`; wire stays `japaneseText` until Phase G |

### B. Vocabulary / Kanji

| Topic | App publish | UI readiness | Import today | CSV/HTML target |
|-------|-------------|--------------|--------------|-----------------|
| Count | Appendix B (FL) | UI mins 6/9/12 | ≥1 entry | Appendix B on import |
| Gloss / meaning | `validateVocabularyMeaning` 1–80, my/en | Non-empty `termJapanese` only | `glosses` parsed | **Glossary required** (generator); block null glosses |
| Reading / furigana | Required if kanji / kanji type | Not checked | Optional | Generator: reading rules for kanji rows |
| examplePairs | Not publish-validated | Max 3 in model | Mirrored to legacy fields | **Require ≥1 pair** or explicit legacy mirror rules |
| exampleSentence / exampleMeanings | Not publish-validated | Not checked | Mirror from pair[0] | Non-null when pairs exist; minimize null keys |
| Null minimization | Partial (empty term skipped) | N/A | Partial | Reject explicit `null` strings in required paths |

### C. Grammar

| Topic | App publish | UI readiness | Import today | CSV/HTML target |
|-------|-------------|--------------|--------------|-----------------|
| Count | Appendix C | UI min 3/5/7 | ≥1 entry | Appendix C |
| headline | 2–40 required per row | Non-empty headline for valid row | Required | Required |
| form, usage, meanings, examples | Not publish-validated | Not checked | Mapped if present | Validate shape; optional vs required per generator |
| relatedNote | Not publish-validated | Not checked | Preserved | **Required** when generator emits block |
| mistakeWrong / mistakeCorrect | Not publish-validated | Not checked | Preserved | **Required pair** when generator emits mistakes block |
| Null minimization | Empty headline blocks | N/A | Partial | Minimize null objects in required subtrees |

### D. Quiz

| Topic | App publish | UI readiness | Import today | CSV/HTML target |
|-------|-------------|--------------|--------------|-----------------|
| Count | Appendix D (+ cap 24) | UI mins 4/6/8 | ≥1 entry, **exactly 4** options | Appendix D; options **exactly 4** |
| correctIndex | 0..3, one match | Same | Same | Same; **no “always index 0”** generator rule |
| Category / subtype | Vocabulary, Grammar, Sentence | Not checked | `vocabulary` string | **Distribution** across categories (generator); validate `sourceNote` subtype if present |
| sourceNote | Not validated | Not checked | Preserved | Parse consistency: answer vs options |
| Answer order | Duplicate options block | N/A | No shuffle in mapper | **Do not shuffle** in mapper (already true) |

### E. Audio

| Topic | App publish | UI readiness | Import today | CSV/HTML target |
|-------|-------------|--------------|--------------|-----------------|
| Read Only | Not required | N/A | No learn required | No audio required |
| Full Learn publish | `audio` module `completed` | `isValidV1` for readiness | Missing URL → import OK, `import.fullLearn.audioRequired` | Preview without audio; publish blocked until upload |
| Import layer | N/A | N/A | `canPublishImmediately` false if no audio | Unchanged semantics |

### F. App context

| Topic | Import today | CSV/HTML target |
|-------|--------------|-----------------|
| learningLanguage | Must match `prefs.learningLanguage`; English blocked | `ja` only until Phase G; English → `import.context.englishComingSoon` |
| contentCommunity | Maps to `contentLocale` | Same |
| createdForEmail | Match authenticated email | Same (UX only; JWT owns backend) |
| English enablement | Blocked | Phase G: `primaryText` + empty furigana policy |

---

## 4. Source-of-truth design options

| Option | Pros | Cons | Solo-dev fit |
|--------|------|------|--------------|
| **A. Hardcoded Dart constants only** | Simple; fast tests | Duplicated in TS backend; drift | Poor long-term |
| **B. Shared JSON config in repo** | One file; import + publish + tests read same data | Backend still needs sync step | **Best** |
| **C. Backend-owned rule endpoint** | Single live source | Network; versioning; import offline | Overkill now |
| **D. Duplicated Dart + TS by hand** | Current state | Already causing UI vs publish mismatch | Avoid |
| **E. Hybrid: JSON config + adapters** | Import uses engine first; manual creator migrates in phases; script exports TS | One-time codegen discipline | **Recommended** |

### Recommendation

1. **`assets/rules/nimon_content_rules_v1.json`** (or `tool/generator_rules/`) — JLPT×band matrices, field rules, severity, mode flags (`import` / `publish` / `readiness`).
2. **`lib/core/validation/nimon_content_rule_config.dart`** — typed loader + immutable config.
3. **`lib/core/validation/nimon_content_rule_engine.dart`** — pure functions: `validateStoryCore`, `validateVocab`, … producing `ValidationIssue` / `NimonImportIssue`.
4. **Import adapter** — `nimon_import_rule_validator.dart` calls engine on `Map` JSON before map to `CreatorStoryV1`.
5. **Backend parity** — Phase F: `scripts/export_rules_to_ts.ts` or manual sync checklist against same JSON until monorepo codegen is worth it.

**Do not** enable English in config until Phase G (`learningLanguages: ["ja"]` only).

---

## 5. Migration phases

### Phase A — Document mismatches (no behavior change)

- Freeze **M21A / M21B / M21D** as baseline.
- Add column to internal spreadsheet: **Current app** vs **CSV generator spec** (from HTML/CSV prompt docs).
- List explicit gaps: UI mins, grammar/vocab rich fields, quiz distribution, import-only checks.
- Mark `creator_publish_validation.dart` as deprecated.

**Exit:** Signed-off diff table; no user-visible change.

### Phase B — Rule config types (Dart only)

- Add `NimonContentRuleConfig` + JSON loader (no wiring to publish yet).
- Unit tests: load JSON, lookup N5 `3_5` sentence limits, quiz global max 24.

**Exit:** Config loads; zero production behavior change.

### Phase C — Import validator uses new config

- Extend `validateNimonImportPayload` (or `nimon_import_rule_validator.dart`) to run engine on raw JSON sections.
- Keep **manual creator** on old validators.
- Import still: context gates (email, locale, English blocked).
- Outcome: AI JSON that fails generator rules **cannot import**; may still fail publish later until user edits in app.

**Exit:** Golden import fixtures; hidden import shows new blocking codes.

### Phase D — Creator UI readiness aligns

- `computeReadOnlyReady` / `computeFullLearnReady` read **same config** with `mode: readiness` (optionally same mins as publish or documented stricter subset).
- Update `CreatorProcessingCopy` only if needed for clarity.
- Drawer: `isStoryReviewModeAllowed` follows new readiness.

**Exit:** Readiness tests; reduced “button enabled but publish fails” cases.

### Phase E — Client publish preflight aligns

- `validateStoryPublishData` delegates to shared engine (`mode: publish`) or shares implementation with import.
- Keep warning vs blocking semantics and “Publish anyway”.
- Extend `publish_validation_gate_test.dart` + import readiness tests.

**Exit:** Flutter preflight matches import for same payload shape.

### Phase F — Backend validation parity

- Generate or manually sync `publish-validation.ts` / limit tables from JSON.
- Run existing `publish-validation.spec.ts` + add cross-fixture cases.
- CI check (optional): script fails if JSON hash ≠ exported TS hash.

**Exit:** Server 400 matches client for same draft wire shape.

### Phase G — English enablement (later)

- Config: `learningLanguages: ["ja", "en"]` when product ready.
- Mapper: `primaryText` → still serialize `japaneseText` for API until backend bilingual wire.
- Furigana: empty for English in engine.
- Import meta: accept `learningLanguage: English` when enabled.
- **Do not start Phase G** until product + backend reader path agreed.

---

## 6. Risk report

| Risk | Mitigation |
|------|------------|
| Breaking manual creation flow | Phased rollout: import first (C), then readiness (D), then preflight (E); feature flag `NIMON_USE_CONTENT_RULE_ENGINE` default false until E stable |
| Flutter/backend mismatch | Single JSON source; Phase F parity tests; shared issue codes |
| Import passes, publish fails | Import C can mirror publish rules OR document “publish gaps remain”; success copy stays “ready to preview”; drawer uses preflight |
| Japanese-only field naming | Phase G only; engine uses logical names; mapper keeps wire keys |
| English accidentally enabled | Config allowlist; import meta guard; tests `english_coming_soon_rejected` |
| Count matrix confusion | One appendix in JSON; never duplicate in three handwritten files |
| FullLearn audio confusion | Keep `canPublishImmediately` (import) vs `computeFullLearnReady` (UI) vs `fullLearnModulesComplete` (publish) documented in UI copy |
| Generator extra fields unsupported | Engine ignores unknown keys; warnings for unsupported required generator keys |
| Client “ready”, server 422/400 | Preflight before POST; document `publishedMonoId` for FL; no auto-publish on import |
| UI readiness regression | Compare before/after on quota publish tests; keep `story_creator_quota_publish_and_draft_test` green |
| Large JSON fixtures in repo | Start minimal golden set; grow per phase |

---

## 7. Test strategy

### Unit tests

| Area | Files |
|------|--------|
| Rule config load | `test/core/validation/nimon_content_rule_config_test.dart` |
| Rule engine | `test/core/validation/nimon_content_rule_engine_test.dart` |
| Import validator | extend `test/features/create/nimon_import_validator_test.dart` |
| Mapper | `test/features/create/nimon_import_mapper_test.dart` |
| Readiness | `test/features/create/nimon_import_publish_readiness_test.dart` + readiness unit tests |
| Preflight | `test/core/validation/publish_validation_gate_test.dart` |

### Golden JSON fixtures (`test/fixtures/import/`)

| Fixture | Purpose |
|---------|---------|
| `read_only_valid_min.json` | RO import + eventual publish path (may still fail counts if minimal) |
| `read_only_too_short.json` | Below sentence min → blocking |
| `full_learn_valid_without_audio_preview_only.json` | `canImport` true, audio missing |
| `full_learn_valid_with_audio.json` | Audio URL present |
| `full_learn_missing_rich_vocab_fields.json` | Null glosses / missing glossary |
| `full_learn_missing_grammar_mistake_fields.json` | Missing mistake pair |
| `quiz_wrong_correctIndex.json` | Invalid index / options length |
| `english_coming_soon_rejected.json` | Meta English → blocked |

### Integration tests (existing — keep green)

- `nimon_import_read_only_flow_test.dart`
- `nimon_import_full_learn_flow_test.dart`
- `nimon_import_publish_readiness_test.dart`
- `story_creator_import_draft_notifier_test.dart`

### Backend parity (Phase F)

- Extend `nimon-backend/src/common/validation/publish-validation.spec.ts`
- Optional: fixture JSON shared with Flutter tests (symlink or copy in CI)

### Manual / E2E (out of scope for automated plan)

- Hidden import → Open preview → manual publish attempt (debug only).

---

## 8. Recommended future file map (do not create yet)

| Path | Responsibility |
|------|----------------|
| `assets/rules/nimon_content_rules_v1.json` | JLPT×band matrices + field rules |
| `lib/core/validation/nimon_content_rule_config.dart` | Typed config + loader |
| `lib/core/validation/nimon_content_rule_engine.dart` | Pure validation engine |
| `lib/features/create/import/nimon_import_rule_validator.dart` | JSON → engine → `NimonImportValidationResult` |
| `lib/features/create/import/nimon_import_validator.dart` | Structural + context; delegates rich rules to rule validator |
| `test/fixtures/import/*.json` | Golden payloads |
| `test/core/validation/nimon_content_rule_engine_test.dart` | Engine unit tests |
| `scripts/sync_content_rules_to_backend.ts` | Phase F export (optional) |
| `nimon-backend/src/common/validation/content-rules.generated.ts` | Phase F generated limits (optional) |
| `docs/M21D_CSV_PROMPT_RULE_MIGRATION_PLAN.md` | This document |

**Touch in place (later phases):**

- `lib/core/validation/publish_validation.dart`
- `lib/features/create/creator_completion_rules.dart`
- `lib/features/create/creator_readiness.dart`
- `nimon-backend/src/common/validation/publish-validation.ts`
- `nimon-backend/src/common/validation/story-validation.ts`
- `nimon-backend/src/common/validation/learn-validation.ts`

**Do not wire:** `creator_publish_validation.dart` (remove or archive).

---

## 9. Current import feature status (unchanged by this plan)

Completed and tested separately:

- Import models, validator (structural), mapper, `importMappedDraft`
- Hidden UI (`NimonImportDevConfig`, long-press, file picker)
- Navigation to `/create/story/sentences?draftId=…`
- ReadOnly / FullLearn pipeline and publish readiness integration tests

**Distinction to preserve in docs and UI copy:**

| Flag | Meaning |
|------|---------|
| `NimonImportValidationResult.canImport` | Import-layer gate (structure + context + future CSV rules) |
| `NimonImportValidationResult.canPublishImmediately` | No import-layer missing publish reqs (e.g. audio) |
| `computeFullLearnReady` / `validateStoryPublishData` | Creator/publish authority today |

---

## 10. Recommended next implementation prompt

**Prompt: Phase B — Add `nimon_content_rules_v1.json` + Dart config loader + engine skeleton (no publish/readiness wiring)**

1. Add JSON with Appendix A–D tables copied from M21B (identical to current publish tables as baseline).
2. Add `NimonContentRuleConfig.fromAsset()` with tests.
3. Add `nimon_content_rule_engine.dart` with stub validators returning empty issues (no behavior change when unwired).
4. Document issue code namespace: `content.*` vs existing `story.*` / `learn.*` — plan mapping table in Phase C.

**Following prompt: Phase C — Wire `nimon_import_rule_validator` only.**

---

## 11. Route / session note (post-import navigation)

- `creator_route_sync.dart` loads draft by `draftId` query; same id as `importMappedDraft` does not reload from disk (`loadDraftById` skip).
- Optional later: `?panel=listening` after import when `import.fullLearn.audioRequired` — not required for migration plan.

---

*End of M21D plan.*
