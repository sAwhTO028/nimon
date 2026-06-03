# M21F — HTML Rules Parity Final Audit (Config → Import → Readiness → Preflight → Backend)

Date: 2026-06-02  
Scope: **Audit only** (no behavior changes requested/performed in this phase)

## A. Final rule chain status

**Status: PARITY ACHIEVED (JP-only)** across the complete chain:

1. **HTML source-of-truth**: `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`
2. **Flutter typed config**: `lib/core/limits/html_generator_limits.dart`
3. **Flutter import validator** (blocks invalid imports): `lib/features/create/import/nimon_import_validator.dart`
4. **Flutter creator readiness + drawer** (UI readiness): `lib/features/create/creator_completion_rules.dart`, `lib/features/create/story_creator_review_display.dart`
5. **Flutter publish preflight** (client-side publish gate): `lib/core/validation/publish_validation.dart`
6. **Backend typed config**: `nimon-backend/src/common/limits/html-generator-limits.ts`
7. **Backend publish validation** (server-side publish gate): `nimon-backend/src/common/validation/publish-validation.ts`

All layers now enforce the **same numeric limits** (sentences, chars, vocab, grammar, quizzes) using the HTML generator rule tables and the same AI/Manual behavior, while preserving:
- existing issue/result shapes,
- existing per-item validators (vocab/grammar/quiz content checks),
- existing FullLearn module-workflow gating,
- JP-only product behavior (English not enabled).

## B. Layer-by-layer parity table

| Rule / Behavior | HTML v7 | Flutter config | Flutter import validator | Flutter readiness/drawer | Flutter publish preflight | Backend config | Backend publish validation |
|---|---|---:|---:|---:|---:|---:|---:|
| Sentence count min/max | `sentenceLimits[mode][lang][duration][level]` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Character count min/max | `sentenceLimits` (minChars/maxChars) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Char counting method | implicit “character count” | N/A | ✅ trim + remove whitespace + grapheme count | ✅ trim + remove whitespace + grapheme count | ✅ trim + remove whitespace + grapheme count | N/A | ✅ trim + remove whitespace + JS `charLength` |
| Vocab count rules | `learnLimits` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Grammar count rules | `learnLimits` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Quiz total rules | `quizLimits` Total Quiz | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Quiz distribution rules | Vocabulary/Grammar/Sentence Quiz | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| AI preset behavior | sliderKeys + selected logic | ✅ | ✅ default preset | ✅ default preset | ✅ default preset | ✅ | ✅ default preset |
| Manual range behavior | Manual_Min/Manual_Max | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Prompt mode detection | UI tab / meta (`AI_mode` / `Manual_mode`) | ✅ normalization helpers | ✅ from `nimonImportMeta.promptDataTab` | ✅ from `draft.promptSourceNote` | ✅ from `StoryPublishData.promptSourceNote` | ✅ normalization helpers | ✅ from `promptSourceNote` (optional) |
| ReadOnly behavior | story only | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FullLearn behavior | story + learn + quiz + audio | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Audio behavior | required for FullLearn publish | ✅ | ✅ (import preview-only when missing) | ✅ (not ready when missing) | ✅ (blocks via module workflow) | ✅ | ✅ (blocks via module workflow) |
| English behavior | generator supports EN tables | ✅ (config lookup only) | ✅ blocked at app-context | ✅ JP-only | ✅ JP-only | ✅ JP-only | ✅ JP-only |
| Kanji quiz handling | not explicitly distributed | N/A | ✅ kanji counts to total only | ✅ counts to total only | ✅ counts to total only | N/A | ✅ counts to total only |

## C. Remaining mismatch list

**Mismatch count: 0** for the audited items in scope.

### Notes / clarifications (not mismatches)

- **Quiz “kanji” category**:
  - HTML exposes distribution limits for `Vocabulary Quiz`, `Grammar Quiz`, `Sentence Quiz`, and `Total Quiz`, but does not explicitly define “Kanji Quiz” as a distributed category.
  - The implemented contract in validator/readiness/preflight/backend is:
    - `kanji` (and unknown categories) count toward **Total Quiz only**.
    - Distribution enforcement applies only to `vocabulary`, `grammar`, `sample_sentence`.
  - This is required to satisfy combinations where **Total Quiz default** exceeds the sum of the three distributed defaults (e.g. N4 5–7 AI default total 21 vs 11+5+4=20).

- **Prompt mode detection signal**:
  - Import validator uses the explicit meta enum (`nimonImportMeta.promptDataTab`) → strongest signal.
  - Readiness & publish validation use `promptSourceNote` substring checks for `AI_mode` / `Manual_mode`.
  - Default remains **Manual** when missing.

## D. Old / legacy rule table status

### Flutter

- **`CreatorV1DurationThresholds`** (`lib/features/create/creator_completion_rules.dart`)
  - **Still used**: duration presence in Story Basics (the “5 required fields” check) and legacy helpers that call `resolveV1ThresholdsForDraft`.
  - **Legacy only for numeric limits**: sentences/vocab/grammar/quiz/audio completion now comes from HTML rules.
  - **Safe to keep**: yes.
  - **Safe to deprecate later**: yes (once duration presence check is moved to HTML context resolution directly).
  - **Unsafe to delete now**: yes (still referenced by UI/drawer plumbing and basic status helpers).

- **Old JLPT×band tables**
  - `storySentenceLimits` in `lib/core/validation/story_validators.dart`
  - `vocabularyLimits`, `grammarPatternLimits`, `quizLimits` in `lib/core/validation/learn_validators.dart`
  - **Still used**: not by publish preflight numeric gating anymore; however the files remain part of the validation module surface and may be used by other paths/tests.
  - **Safe to keep**: yes.
  - **Safe to deprecate later**: yes (after confirming no other callsites rely on them).
  - **Unsafe to delete now**: yes (broad impact; not proven unused everywhere).

### Backend

- **Old JLPT×band tables**
  - `STORY_SENTENCE_LIMITS` in `src/common/validation/story-validation.ts`
  - `VOCABULARY_LIMITS`, `GRAMMAR_PATTERN_LIMITS`, `QUIZ_LIMITS` in `src/common/validation/learn-validation.ts`
  - **Still used**: as constants and referenced in `src/common/validation/validation.spec.ts` (constant tests).
  - **Not used for publish numeric gating** anymore (publish validation now uses HTML config).
  - **Safe to keep**: yes.
  - **Safe to deprecate later**: yes (after constant test updates/removal and repo-wide usage scan).
  - **Unsafe to delete now**: yes (tests + unknown external references).

## E. Test coverage summary

### Flutter (high-signal parity tests)
- `test/features/create/nimon_import_html_rules_validator_test.dart` (import validator enforces HTML limits)
- `test/features/create/creator_html_rules_readiness_test.dart` (readiness uses HTML limits)
- `test/core/validation/publish_html_rules_validation_test.dart` (client preflight uses HTML limits)
- Pipeline/flow tests (import → map → draft):
  - `test/features/create/nimon_import_full_learn_flow_test.dart`
  - `test/features/create/nimon_import_read_only_flow_test.dart`
  - `test/features/create/nimon_import_publish_readiness_test.dart`

### Backend (high-signal parity tests)
- `src/common/limits/html-generator-limits.spec.ts` (config parity + sample values)
- `src/common/validation/publish-html-rules-validation.spec.ts` (publish validation enforces HTML limits)
- `src/common/validation/publish-validation.spec.ts` (publish gate + validators sanity)

## F. Recommended cleanup plan (future work; no code changes here)

1. **Deprecate legacy numeric tables** (keep until proven unused):
   - Flutter: `storySentenceLimits`, `vocabularyLimits`, `grammarPatternLimits`, `quizLimits`
   - Backend: `STORY_SENTENCE_LIMITS`, `VOCABULARY_LIMITS`, `GRAMMAR_PATTERN_LIMITS`, `QUIZ_LIMITS`
2. **Centralize prompt mode detection** into one shared helper per platform, and ensure the creator data model carries the signal explicitly (optional) instead of substring parsing long-term.
3. **Document kanji quiz semantics** as an explicit product rule (total-only) to avoid future confusion.
4. **Add “one golden fixture”** (imported N4 5–7 AI default) shared across Flutter+backend tests (optional, low risk).

## G. Risk list before release

- **PromptSourceNote substring detection false positives**: any unrelated `ai_mode` text could flip to AI rules. (Mitigation: constrain formatting or store a dedicated mode field later.)
- **Char-count edge cases**: grapheme counting is used in Flutter; JS `charLength` behavior must remain equivalent for Japanese content (currently consistent in tests).
- **Kanji quiz rule implicitness**: total-only treatment is correct for current HTML tables but should be explicitly acknowledged as product behavior.
- **Legacy table confusion**: old tables remain present and can mislead future changes if referenced accidentally.

Overall release risk level (rules parity only): **Low** (tests cover import + readiness + client preflight + backend publish gate).

## H. Manual QA checklist

1. **Import ReadOnly** (AI_mode, JP, N4, 5_7):
   - Try a JSON with 41 sentences → import blocked (too few).
   - Try with 42 sentences and <750 chars total → import blocked (too few chars).
   - Try with 42 sentences and 750–1100 chars → import OK.
2. **Import FullLearn** (AI_mode, JP, N4, 5_7, default):
   - With correct counts but missing audio → import OK, preview-only, publish disabled.
3. **Creator readiness**:
   - Same imported draft should show ReadOnly ready when story meets limits.
   - FullLearn should remain not-ready until audio is attached and counts match.
4. **Client publish preflight**:
   - FullLearn publish should block when audio module not completed.
   - FullLearn should pass when counts + workflow statuses are correct.
5. **Backend publish**:
   - Attempt publish with one-off mismatch (e.g., vocab 15 instead of 16) should be rejected with `publish.htmlRules.vocabularyCountMismatch`.
6. **English**:
   - Ensure English learning import remains blocked and no English publish path is enabled.

---

### Output summary
- **Files inspected**: HTML v7 generator, Flutter config, Flutter import validator, Flutter readiness, Flutter preflight, backend config, backend publish validation, plus legacy table locations.
- **Parity status**: **PASS** (JP-only).
- **Mismatch count**: **0**.
- **Legacy cleanup recommendations**: deprecate later; unsafe to delete now.
- **Release risk level**: **Low** for rules parity (with the noted promptSourceNote/kanji semantics caveats).

