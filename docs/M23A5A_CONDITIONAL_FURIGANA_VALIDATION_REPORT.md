# M23A-5A — Conditional Furigana Validation Report

**Phase:** M23A-5A (implementation)  
**Scope:** Shared `isJapaneseLearningWireCode` helper and Full Learn publish furigana gating on Flutter + backend only  
**Out of scope:** Feed, catalog, collections, search, reader, mono/listening, furigana/vocabulary editor UI, module labels, HTML generator source, publish stamping, Prisma schema, migrations  
**Prerequisites:** [`M23A0_LEARNING_ENGLISH_EXPANSION_AUDIT.md`](M23A0_LEARNING_ENGLISH_EXPANSION_AUDIT.md), [`M23A1_ENGLISH_LEARNING_IMPLEMENTATION_PLAN.md`](M23A1_ENGLISH_LEARNING_IMPLEMENTATION_PLAN.md), [`M23A4_PUBLISH_AND_READINESS_HTML_LANGUAGE_BRANCHING_REPORT.md`](M23A4_PUBLISH_AND_READINESS_HTML_LANGUAGE_BRANCHING_REPORT.md), [`M23A50_CONDITIONAL_FURIGANA_KANJI_ENGLISH_UX_AUDIT.md`](M23A50_CONDITIONAL_FURIGANA_KANJI_ENGLISH_UX_AUDIT.md)

---

## Executive summary

English Full Learn publish no longer runs furigana / kana-reading validators. Japanese behavior is unchanged: only explicit wire code `en` skips validation; `null`, empty, `ja`, and unknown codes still enforce furigana (legacy-safe fallback, distinct from HTML limit resolver which maps unknown → `jp`).

---

## A. Files changed

| File | Change |
|------|--------|
| `lib/core/settings/language_pair.dart` | `isJapaneseLearningWireCode()` |
| `nimon-backend/src/common/validation/language-pair-validation.ts` | `isJapaneseLearningWireCode()` |
| `lib/core/validation/publish_validation.dart` | Gate `validateFurigana` on helper |
| `nimon-backend/src/common/validation/publish-validation.ts` | Gate `validateFuriganaReading` on helper |
| `test/core/settings/language_pair_test.dart` | Helper unit test |
| `nimon-backend/src/common/validation/language-pair-validation.spec.ts` | Helper unit test |
| `test/core/validation/publish_furigana_learning_language_test.dart` | **New** — JA regression + EN publish matrix |
| `nimon-backend/src/common/validation/publish-validation.spec.ts` | JA regression + EN publish cases |

**Not changed (by design):** `validateVocabularyMeaning`, `validateGrammarPatternTitle`, `validateQuizItem`, HTML limits, import validator, creator UI, reader, feed, schema.

---

## B. Helper design

### API

| Wire input | `isJapaneseLearningWireCode` | Furigana validation |
|------------|------------------------------|---------------------|
| `ja` | `true` | Runs |
| `en` | `false` | Skipped |
| `null` | `true` | Runs (legacy drafts) |
| `''` | `true` | Runs |
| unknown (e.g. `ko`) | `true` | Runs |

### Locations

- Flutter: `lib/core/settings/language_pair.dart` — `isJapaneseLearningWireCode`
- Backend: `nimon-backend/src/common/validation/language-pair-validation.ts` — `isJapaneseLearningWireCode`

### Reasoning

- **`en` only opts out** — product rule: English learning content does not require ruby readings or kana-shaped `reading` fields.
- **`null` / unknown → `true`** — drafts saved before `learningLanguage` was persisted must keep today’s Japanese publish behavior; avoids silently allowing invalid JA content.
- **Differs from `resolveHtmlLearningLanguageFromWire`** — HTML limits use `jp` for unknown wire codes; furigana uses “validate unless explicitly `en`” so missing tags do not disable JA furigana checks.

`safeLearningLanguageWireCode` / `safeV1LearningLanguage` still normalize unknown → `ja` for **storage defaults**; the furigana helper does not call those normalizers.

---

## C. Backend validation flow

**File:** `nimon-backend/src/common/validation/publish-validation.ts`  
**Function:** `validateStoryPublishInput` → Full Learn vocab loop (~545–557)

For each vocab row with non-empty `termJapanese`:

1. Always: `validateVocabularyMeaning`
2. **Only if** `isJapaneseLearningWireCode(input.learningLanguage)`: `validateFuriganaReading(reading, termJapanese, furiganaKind)`
3. Unchanged: grammar headline, quiz items, HTML limits (use `resolveHtmlLearningLanguageFromWire`)

---

## D. Flutter validation flow

**File:** `lib/core/validation/publish_validation.dart`  
**Function:** `validateStoryPublishData` → Full Learn vocab loop (~589–604)

Mirror of backend:

1. Always: `validateVocabularyMeaning`
2. **Only if** `isJapaneseLearningWireCode(input.learningLanguage)`: `validateFurigana`
3. Unchanged: grammar, quiz, HTML limits

`creator_publish_preflight.dart` already passes `draft.basics.learningLanguage` into `StoryPublishData` (M23A-4); no preflight change required for M23A-5A.

---

## E. Japanese regression matrix

| Case | `learningLanguage` | Expected |
|------|-------------------|----------|
| JA + MY, kanji vocab, no `reading` | `ja` | **Block** — `learn.vocab.reading.required` |
| JA + MY, kanji, Latin `reading` | `ja` | **Block** — `learn.vocab.reading.invalidChars` |
| Legacy draft, kanji, no `reading` | `null` | **Block** — furigana still enforced |
| Prior spec: invalid furigana | `ja` (explicit) | **Block** — unchanged |

---

## F. English publish matrix

| Case | `learningLanguage` | Body | Expected |
|------|-------------------|------|----------|
| EN + MY, kanji, no `reading` | `en` | EN AI N5 3_5 full-learn (8 vocab, 3 grammar, 11 quiz, 24×50 chars) | **Pass** |
| EN + JA (same gate; pair not on publish snapshot) | `en` | Same | **Pass** |
| EN, all vocab without `reading` | `en` | Same counts | **Pass** |
| EN, kanji + Latin `reading` | `en` | Same | **Pass** (no `learn.vocab.reading.*`) |

Publish validation does not receive `contentLocale`; EN+MY vs EN+JA denotes intended language **pairs** with `learningLanguage: 'en'` only.

---

## G. Tests added

### Helper

| Suite | Test |
|-------|------|
| `language_pair_test.dart` | `isJapaneseLearningWireCode gates furigana by explicit en only` |
| `language-pair-validation.spec.ts` | `isJapaneseLearningWireCode gates furigana by explicit en only` |

### Publish furigana gating

| Suite | Tests |
|-------|-------|
| `publish_furigana_learning_language_test.dart` | 7 (JA×3, EN×4) |
| `publish-validation.spec.ts` | +4 (`JA kanji without reading`, `legacy null`, `EN without reading`, `EN Latin reading`); existing furigana test renamed with `learningLanguage: 'ja` |

---

## H. Exact test commands

From repo root (`nimon`):

**Backend (27 tests — language-pair + publish-validation):**

```powershell
cd nimon-backend
node_modules\.bin\jest.cmd src/common/validation/language-pair-validation.spec.ts src/common/validation/publish-validation.spec.ts --no-cache
```

**Flutter (34 tests — language_pair + furigana + gate + html rules):**

```powershell
cd ..
flutter test test/core/settings/language_pair_test.dart test/core/validation/publish_furigana_learning_language_test.dart test/core/validation/publish_validation_gate_test.dart test/core/validation/publish_html_rules_validation_test.dart
```

---

## I. Pass counts

| Command | Result |
|---------|--------|
| Backend Jest (above) | **27 passed**, 0 failed |
| Flutter (above) | **34 passed**, 0 failed |

No estimated counts; run on 2026-06-03 after M23A-5A implementation.

---

## J. Remaining M23A-5B work

Per [`M23A50_CONDITIONAL_FURIGANA_KANJI_ENGLISH_UX_AUDIT.md`](M23A50_CONDITIONAL_FURIGANA_KANJI_ENGLISH_UX_AUDIT.md) §J (steps 4–9), after M23A-5A validation parity:

| Step | Work |
|------|------|
| **4** | Sentence creator — hide furigana manage / ruby previews when `learningLanguage == en` |
| **5** | Vocab editor — hide kanji type + reading field for English learning |
| **6** | `LearnModuleIdLabels` + creator publish copy (e.g. LM1 **Vocabulary** not Kanji) |
| **7** | Reader / listening — suppress ruby when story `learningLanguage` is `en` |
| **8** | Broader UI/integration tests for creator + reader paths |
| **9** | Wire-name debt doc (`japaneseText`, `termJapanese`, `vocabulary_kanji`) |

**Still deferred:** feed/catalog/collections (M23A-6), import furigana warnings, sentence-span publish validation, field renames, schema.

---

## Parity audit (Task 4)

| Concern | Backend | Flutter |
|---------|---------|---------|
| Predicate | `isJapaneseLearningWireCode` in `language-pair-validation.ts` | Same logic in `language_pair.dart` |
| Gate site | `publish-validation.ts` vocab loop | `publish_validation.dart` vocab loop |
| Condition | `if (isJapaneseLearningWireCode(input.learningLanguage))` | Identical |
| Skipped validators | `validateFuriganaReading` only | `validateFurigana` only |

Meaning, grammar, quiz, and HTML limit branches are untouched and remain aligned from M23A-4.

---

## References

- M23A-4 explicit non-change of furigana: [`M23A4_PUBLISH_AND_READINESS_HTML_LANGUAGE_BRANCHING_REPORT.md`](M23A4_PUBLISH_AND_READINESS_HTML_LANGUAGE_BRANCHING_REPORT.md) §J  
- Audit blocker: [`M23A50_CONDITIONAL_FURIGANA_KANJI_ENGLISH_UX_AUDIT.md`](M23A50_CONDITIONAL_FURIGANA_KANJI_ENGLISH_UX_AUDIT.md) §B–C
