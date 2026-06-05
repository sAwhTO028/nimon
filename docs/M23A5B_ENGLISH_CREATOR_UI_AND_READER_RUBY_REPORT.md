# M23A-5B — English Creator UI + Reader Ruby Suppression Report

**Phase:** M23A-5B (implementation)  
**Scope:** Creator sentence/vocab UI, module labels, publish missing labels, reader + listening ruby display  
**Out of scope:** Feed/catalog/collections/search filtering, publish validation, HTML limits, schema, migrations, HTML generator source  
**Prerequisites:** [`M23A5A_CONDITIONAL_FURIGANA_VALIDATION_REPORT.md`](M23A5A_CONDITIONAL_FURIGANA_VALIDATION_REPORT.md)

---

## Executive summary

English learning drafts (`learningLanguage=en`) no longer show Japanese-only furigana/kanji creator controls. Published reader and listening paths suppress ruby when `learningLanguage=en`, while still preserving `furiganaSpans` in stored JSON. Japanese behavior is unchanged.

---

## A. Files changed

| File | Change |
|------|--------|
| `lib/features/create/creator_learning_language.dart` | **New** — `isJapaneseLearningDraft` / `isEnglishLearningDraft` |
| `lib/features/create/story_v1_model.dart` | `LearnModuleId.displayTitleForLearning()` |
| `lib/features/create/story_creator_sentences_screen.dart` | Furigana manage + ruby preview gated |
| `lib/features/create/story_creator_vocab_kanji_editor_screen.dart` | Vocab title, kanji/reading UI, pick-from-story |
| `lib/features/create/creator_publish_validation.dart` | Language-aware missing-item labels |
| `lib/features/create/story_creator_review_display.dart` | Language-aware unmet copy |
| `lib/features/create/story_creator_progress_checklist.dart` | LM1 label from `displayTitleForLearning` |
| `lib/features/profile/data/published_mono_detail_parser.dart` | Ruby suppression in mono build |
| `lib/features/profile/data/published_mono_dto.dart` | `learningLanguage` on detail DTO |
| `lib/features/profile/data/published_mono_reader_mapper.dart` | Pass `learningLanguage` to parser |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | Pass `learningLanguage` to parser |
| `lib/features/mono/data/remote_mono_feed_repository.dart` | Parse `learningLanguage` on detail |
| `lib/features/profile/data/remote_published_mono_repository.dart` | Parse `learningLanguage` on detail |
| `lib/features/learn/listening_transcript_from_published.dart` | `learningLanguage` param |
| `lib/features/learn/listening_pronunciation_screen.dart` | Pass detail `learningLanguage` |
| `test/features/create/m23a5b_english_creator_ui_test.dart` | **New** |
| `test/features/create/creator_learning_language_test.dart` | **New** |
| `test/features/profile/published_mono_ruby_suppression_test.dart` | **New** |

**Not changed:** `publish_validation.dart`, `publish-validation.ts`, feed/catalog filters, Prisma, import validators (EN imports may still carry `furiganaSpans`).

---

## B. UI helper design

| Helper | Location | Rule |
|--------|----------|------|
| `isJapaneseLearningWireCode` | `lib/core/settings/language_pair.dart` (M23A-5A) | `en` → false; else true |
| `isJapaneseLearningDraft` | `creator_learning_language.dart` | Delegates to wire helper on `draft.basics.learningLanguage` |
| `isEnglishLearningDraft` | `creator_learning_language.dart` | Explicit `en` only |
| `displayTitleForLearning` | `LearnModuleIdLabels` | `vocabulary_kanji` → **Vocabulary** when not JA |

---

## C. Sentence editor behavior

**File:** `story_creator_sentences_screen.dart`

| `learningLanguage` | Behavior |
|--------------------|----------|
| `ja` / null / unknown | Furigana button, manage panel, ruby previews on cards and reader preview |
| `en` | `canManageFurigana=false`; empty spans on `NimonJapaneseSentenceLine`; no manage panel |

Existing `furiganaSpans` on sentences are **not** deleted.

---

## D. Vocabulary editor behavior

**File:** `story_creator_vocab_kanji_editor_screen.dart`

| `learningLanguage` | Behavior |
|--------------------|----------|
| `ja` | Title **Vocabulary / Kanji**; reading field; Kanji/Vocabulary segmented control; type badge on cards |
| `en` | Title **Vocabulary**; hide reading + type UI in edit sheet; hide type badge + reading on list cards; pick-from-story does not auto-fill reading |

Stored `reading` values on EN entries are preserved on save (edit sheet does not clear them).

---

## E. Module label behavior

| Surface | JA | EN |
|---------|----|----|
| `LearnModuleId.vocabularyKanji` | Vocabulary / Kanji | Vocabulary |
| Progress checklist LM1 | Via `displayTitleForLearning` | Vocabulary |
| Publish missing / blocked reason | Vocabulary / Kanji | Vocabulary |
| Review unmet humanize | Complete Vocabulary / Kanji | Complete Vocabulary |

Internal id remains `vocabulary_kanji`.

---

## F. Reader ruby suppression

**Earliest safe point:** `buildMonoContentFromPublishedCore` in `published_mono_detail_parser.dart`

- When `isJapaneseLearningWireCode(learningLanguage)` is false → `tokens = []`, `plainText` unchanged.
- `rubyTokensFromPublishedSentenceContent` is not called for EN.
- `learningLanguage` from API detail DTO or `content.learningLanguage` / `content.basics.learningLanguage`.

`mono_screen.dart` / `NimonRubyText` unchanged — they render plain text when tokens are empty.

---

## G. Listening ruby suppression

**File:** `listening_transcript_from_published.dart`

Passes `learningLanguage` into `buildMonoContentFromPublishedCore`, so `ListeningTranscriptLine.rubyTokens` is null for EN.

**File:** `listening_pronunciation_screen.dart` — passes `detail.learningLanguage` from catalog detail.

`ListeningTranscriptSentenceBlock` already falls back to plain `Text` when `rubyTokens` is null/empty.

---

## H. Tests added

| Suite | Tests |
|-------|-------|
| `m23a5b_english_creator_ui_test.dart` | 8 (labels, vocab UI, gate helpers) |
| `creator_learning_language_test.dart` | 2 |
| `published_mono_ruby_suppression_test.dart` | 4 |
| M23A-5A regression (included in full run) | `publish_furigana_learning_language_test.dart` (7), `language_pair_test.dart` (8) |

Sentence **widget** tests for the full `StoryCreatorSentencesScreen` were not used (GoRouter/host setup); furigana affordance is covered by gate unit tests plus code path in `story_creator_sentences_screen.dart`.

---

## I. Exact test commands and pass counts

**M23A-5B only (15 passed):**

```powershell
flutter test test/features/create/m23a5b_english_creator_ui_test.dart test/features/create/creator_learning_language_test.dart test/features/profile/published_mono_ruby_suppression_test.dart
```

| Result |
|--------|
| **15 passed**, 0 failed |

**M23A-5B + M23A-5A regression (30 passed):**

```powershell
flutter test test/features/create/m23a5b_english_creator_ui_test.dart test/features/create/creator_learning_language_test.dart test/features/profile/published_mono_ruby_suppression_test.dart test/core/validation/publish_furigana_learning_language_test.dart test/core/settings/language_pair_test.dart
```

| Result |
|--------|
| **30 passed**, 0 failed |

---

## J. Remaining blockers

| Item | Notes |
|------|-------|
| Feed/catalog `learningLanguage` filtering | M23A-6 — not in 5B |
| Search / profile parity | Still pending if not on catalog rows |
| Wire field name debt | `japaneseText`, `termJapanese`, `vocabulary_kanji` unchanged |
| HTML generator prompt QA | Authoring tool copy still JP-oriented |
| Full sentence-screen widget test | Optional — needs GoRouter host fixture |

---

## Final verification checklist

| Check | Status |
|-------|--------|
| No backend `publish-validation.ts` logic change | ✓ |
| No Flutter `publish_validation.dart` logic change | ✓ |
| No feed/catalog filter code change | ✓ |
| No collection code change | ✓ |
| No DB schema / migration | ✓ |
| No HTML generator source change | ✓ |
| No wire field renames | ✓ |

---

## Import compatibility (Task 8)

Import validators unchanged. English JSON may include `furiganaSpans`; they persist in draft storage but are ignored for EN display and publish furigana checks (M23A-5A).
