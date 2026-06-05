# M23A-4 — Publish + Readiness HTML Language Branching Report

**Phase:** M23A-4 (implementation)  
**Scope:** Creator readiness, publish preflight, client/server publish validation, import HTML rules — **no** feed, catalog, collections, reader, furigana UI, HTML generator source files, DB schema, or publish stamping changes  
**Prerequisites:** [`M23A35_PUBLISH_LAYER_AUDIT_AFTER_DRAFT_FOUNDATION.md`](M23A35_PUBLISH_LAYER_AUDIT_AFTER_DRAFT_FOUNDATION.md)

---

## Executive summary

Publish and readiness now derive **`HtmlLearningLanguage` from `learningLanguage` wire** (`ja` → `jp`, `en` → `en`, null/unknown → `jp`). Japanese drafts keep JP HTML limits; English drafts use EN limits on client, server, readiness, and import.

---

## A. Files changed

### Shared resolver

| File | Change |
|------|--------|
| `lib/core/limits/html_generator_limits.dart` | `resolveHtmlLearningLanguageFromWire()` |
| `nimon-backend/src/common/limits/html-generator-limits.ts` | `resolveHtmlLearningLanguageFromWire()` |

### Publish validation

| File | Change |
|------|--------|
| `lib/core/validation/publish_validation.dart` | `StoryPublishData.learningLanguage`; `htmlLanguage` from resolver |
| `nimon-backend/src/common/validation/publish-validation.ts` | `StoryPublishValidationInput.learningLanguage`; resolver on all HTML limit lookups |
| `lib/features/create/creator_publish_preflight.dart` | Copies `draft.basics.learningLanguage` into `StoryPublishData` |
| `lib/features/create/creator_drawer_publish.dart` | Debug preflight uses resolver from publish data |

### Readiness

| File | Change |
|------|--------|
| `lib/features/create/creator_completion_rules.dart` | `resolveHtmlCreatorReadinessContext` sets `language` from `draft.basics.learningLanguage` |

### Import

| File | Change |
|------|--------|
| `lib/features/create/import/nimon_import_validator.dart` | Removed EN early-return skips in read-only and full-learn HTML rule paths |

### Tests

| File | Change |
|------|--------|
| `test/core/limits/html_generator_limits_wire_test.dart` | **New** — resolver |
| `test/core/validation/publish_html_rules_validation_test.dart` | EN/JP branching cases M–P |
| `test/features/create/creator_html_rules_readiness_test.dart` | EN readiness + JP fallback |
| `test/features/create/nimon_import_html_rules_validator_test.dart` | J / J2 EN import limits |
| `nimon-backend/src/common/limits/html-generator-limits.spec.ts` | Resolver test |
| `nimon-backend/src/common/validation/publish-html-rules-validation.spec.ts` | M–P EN/JP cases |
| `nimon-backend/src/common/validation/publish-validation.spec.ts` | `storyPublishInputFromDraftRow` includes `en` |

### Documentation

| File | Change |
|------|--------|
| `docs/M23A4_PUBLISH_AND_READINESS_HTML_LANGUAGE_BRANCHING_REPORT.md` | This report |

**Not modified:** `story-drafts.service.ts` publish stamping, feed/catalog, collections, `tool/html_generator/*`, furigana validators, Prisma schema.

---

## B. Resolver design

```text
learningLanguage wire (prefs / draft basics)
        │
        ▼
resolveHtmlLearningLanguageFromWire()
        │
   en ──┼──► HtmlLearningLanguage.en / 'en'
   ja ──┼──► HtmlLearningLanguage.jp / 'jp'
 null ──┼──► jp (fallback)
unknown─┘
```

- **Flutter:** `resolveHtmlLearningLanguageFromWire` in `html_generator_limits.dart`
- **Backend:** `resolveHtmlLearningLanguageFromWire` in `html-generator-limits.ts`
- Does **not** mutate stored draft rows; validation/readiness context only.
- Distinct from `normalizeHtmlLanguage()` (broader import/meta strings); wire codes use strict `ja`/`en` only.

---

## C. Publish input changes

| Model | Field added | Source |
|-------|-------------|--------|
| `StoryPublishData` (Flutter) | `learningLanguage?: String?` | `draft.basics.learningLanguage` via `storyPublishDataFromCreator` |
| `StoryPublishValidationInput` (backend) | `learningLanguage?: string \| null` | `draft.learningLanguage` via `storyPublishInputFromDraftRow` |

---

## D. Backend validation changes

`validateStoryPublishInput`:

- Replaced `const language: HtmlLearningLanguage = 'jp'` with `resolveHtmlLearningLanguageFromWire(input.learningLanguage)`.
- Applied to `sentenceLimit`, `vocabularyLimit`, `grammarLimit`, `selectedFullLearnLimits`.
- Furigana / learn item validators **unchanged** (M23A-5).

---

## E. Flutter validation changes

`validateStoryPublishData`:

- Resolves `htmlLanguage` from `input.learningLanguage`.
- Same limit call sites as backend (sentence, vocab, grammar, selected full-learn).
- Furigana path **unchanged**.

---

## F. Readiness changes

`resolveHtmlCreatorReadinessContext`:

```dart
language: resolveHtmlLearningLanguageFromWire(draft.basics.learningLanguage),
```

`computeStorySentencesStatus` / vocab / grammar / quiz already use `ctx.language` — now receives `en` when draft is English.

**Copy debt:** Unmet strings still say “Japanese chars” (e.g. `Need at least 1200 Japanese chars` while EN min is applied). Behavior is correct; labels not updated per scope.

`story_creator_review_display.dart` — **no code change**; uses `computeReadOnlyReady` / `computeFullLearnReady` which inherit new rules.

---

## G. Import HTML rule changes

Removed:

1. Read-only path: `if (learningLanguage == HtmlLearningLanguage.en) return;`
2. Full-learn path: same early return

English imports now run sentence/char (and full-learn learn) checks against **EN** tables when meta maps to `HtmlLearningLanguage.en`.

---

## H. Tests added / updated

| Area | Cases |
|------|--------|
| Backend Jest | EN char too few; EN pass above JP max; JA fails on EN-sized body; `ja` regression; `storyPublishInputFromDraftRow` + `en`; resolver |
| Flutter | Same publish cases M–P; readiness EN min/ready/fallback; import J/J2; resolver wire test |

---

## I. Exact test commands and pass counts

**Backend (PowerShell):**

```powershell
cd nimon-backend
node_modules\.bin\jest.cmd "publish-html-rules-validation.spec" "publish-validation.spec" "html-generator-limits.spec" --no-cache
```

| Result |
|--------|
| **40 passed** (3 suites) |

**Flutter:**

```powershell
cd ..
flutter test test/core/validation/publish_html_rules_validation_test.dart test/core/limits/html_generator_limits_wire_test.dart test/features/create/creator_html_rules_readiness_test.dart test/features/create/nimon_import_html_rules_validator_test.dart
```

| Result |
|--------|
| **42 passed** |

---

## J. Remaining blockers (later phases)

| Blocker | Phase |
|---------|--------|
| Conditional furigana / kanji validation for `learningLanguage=en` | M23A-5 |
| Creator UI copy (“Japanese chars”, sentence labels) | M23A-5 / UX |
| Feed / catalog `learningLanguage` filtering | M23A-6 |
| Collections locale rules | M23A-6 |
| Reader / ruby suppression | M23A-5b |
| Search / profile parity | Later |
| English Full Learn may still fail on JP-specific `validateFurigana` / `termJapanese` | M23A-5 (documented; not changed in M23A-4) |

---

## Final verification (M23A-4 scope boundary)

| Check | Confirmed |
|-------|-----------|
| 1. No feed/catalog code changed | ✓ |
| 2. No collection code changed | ✓ |
| 3. No furigana/kanji conditional logic implemented | ✓ |
| 4. No HTML generator file under `tool/html_generator/` changed | ✓ |
| 5. No DB schema / migration created | ✓ |
| 6. Publish stamping (`resolvePublishLanguageTagsForDraft`, `publishedMono.create`) unchanged | ✓ |

---

## Success criteria

| Criterion | Status |
|-----------|--------|
| Japanese drafts use JP HTML rules | ✓ |
| English drafts use EN HTML rules | ✓ |
| Client and backend publish validation agree | ✓ |
| Creator readiness matches publish language selection | ✓ |
| Import EN HTML limits enforced | ✓ |
| No feed/collection/reader/furigana UI changes | ✓ |
| Tests pass with documented counts | ✓ |
