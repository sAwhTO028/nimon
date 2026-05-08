# Sentence Translation Furigana Save Audit

**Scope:** DEBUG / AUDIT ONLY (no code changes).  
**Issue:** Source / English meanings and furigana edits appear not to persist after save.

---

## 1. Issue Summary

Reported behavior: user fills **Source Meaning** and **English Meaning** in the story sentence support sheet (or edits furigana), taps **Save**, but values do not survive. P1 reader/parser expects `meanings.{en,my}` and `furiganaSpans` in published / draft sentence JSON.

This audit traces UI → provider → local disk → remote HTTP → backend storage and compares JSON shapes.

---

## 2. Translation Editor UI Path

| Question | Finding |
|----------|---------|
| **Which widget opens the editor?** | `StoryCreatorSentencesScreen` → `_editSupportAt(int index)` opens a modal bottom sheet widget **`_SupportMeaningsSheet`** (`story_creator_sentences_screen.dart`). |
| **Where are Source / English stored in UI?** | **`TextEditingController`** instances **`_sourceCtrl`** and **`_enCtrl`**, initialized from `initialSourceMeaning` / `initialEnglishMeaning` (from `StorySentenceItem.meanings?.my` / `?.en`). |
| **Save button behavior** | **`FilledButton`** calls `Navigator.pop(context, _SupportMeaningsResult(sourceMeaning: _sourceCtrl.text, englishMeaning: _enCtrl.text))` — values **are** passed on Save (not discarded by closing without result). Cancel pops `null`. |

**Guard before opening sheet:** `_editSupportAt` calls `applySentences(_body.text)` then requires `draft.sentences[index].japaneseText == lines[index]`. If plaintext lines and draft sentences disagree (e.g. race with debounced body sync), the method **returns early** and **does not open** the sheet — user might perceive “save doesn’t work” if they mean “couldn’t open” vs “opened but lost data.”

---

## 3. Furigana Editor UI Path

| Question | Finding |
|----------|---------|
| **Which widget handles furigana edit?** | **`_FuriganaManageInlinePanel`** (same file), shown from **`_buildFuriganaManagePanel`** when `_editingSentenceId != null`. |
| **Apply path** | **`onApplyFurigana`** → **`_commitSentenceTextAndFurigana`** → **`storyCreatorDraftProvider.notifier.updateSentenceTextAndFurigana`** with `_composer.text.trim()` and new spans. |

So furigana **is** wired to the notifier with spans; the question is persistence downstream (especially remote).

---

## 4. Flutter Sentence Model Findings

| Question | Finding |
|----------|---------|
| **Mapped into `StorySentenceItem`?** | **Yes.** Meanings use **`LocalizedMeanings`** (`en`, `my`). Furigana uses **`List<FuriganaSpan>`** (`start`, `end`, `reading`). |
| **Keys `meanings.my` / `meanings.en` / `sourceMeaning` / `englishMeaning` written in creator JSON?** | **Local persistence** (`story_creator_draft_storage.dart` **`_toJsonSentence`**) writes **`meanings`** as `{ en, my, byLanguage }` and **`furiganaSpans`** as `{ start, end, reading }`. It does **not** write top-level `sourceMeaning` / `englishMeaning` strings — those are **P1 parser fallbacks only** for published payloads. |
| **Alignment with P1 parser** | **Yes for creator-shaped JSON:** P1 `published_mono_detail_parser` expects `meanings.en` / `meanings.my` and `furiganaSpans` — **matches local draft serialization**. |

---

## 5. Provider Save Flow Findings

| Method | Behavior |
|--------|----------|
| **`updateSentenceSupport`** | Updates matching sentence id with **`meanings`**; **`persistLocalNow(reason: 'sentence_support')`**. |
| **`updateSentenceFurigana` / `updateSentenceTextAndFurigana`** | Updates **`furiganaSpans`** / text; **`persistLocalNow`**. |
| **`applySentences`** | Rebuilds list via **`storySentencesFromPlaintextMerge`** — reuses rows when **`japaneseText`** matches a prior line so metadata can survive line edits; **duplicate identical lines** can cause pool reuse bugs (first match wins). |

**Conclusion:** In-memory and **local repository** save paths **include** meanings and furigana in the domain model.

---

## 6. Local Storage Serialization Findings

| Question | Finding |
|----------|---------|
| **Does local save serialize meanings / furigana?** | **Yes.** `StoryCreatorDraftStorage` / **`_toJsonSentence`** includes **`furiganaSpans`** and **`meanings`**. |

---

## 7. Remote Save Payload Findings

**Critical finding:** `RemoteStoryDraftRepository` builds PUT JSON with **`_sentenceToJson`**, which currently emits:

```dart
'furiganaSpans': const [],
'meanings': null,
```

for **every sentence**, regardless of `StorySentenceDto` values (`remote_story_draft_repository.dart`).

So **`StoryDraftMapper.fromDomainRemoteSafe`** produces full DTOs, but the **remote layer overwrites** sentence payload fields when encoding JSON for **`PUT /v1/story-drafts/:id`**.

**Result:** The backend receives **empty** furigana and **null** meanings for all sentences. Any “persist” that depends on the server copy will show **missing** translations and furigana after sync or reload from API.

**GET / parse path:** **`_sentenceDtoFromJson`** similarly sets **`furiganaSpans: const []`** and **`meanings: null`**, so reloading a draft from the server **drops** those fields in the client DTO even if DB JSON contained richer data.

---

## 8. Backend Draft Sentence Storage Findings

| Question | Finding |
|----------|---------|
| **`draft_sentences.content` shape** | Prisma **`DraftSentence.content`** is **`Json`** — stores **each sentence object** as sent by the client (`story-drafts.service.ts`: `content: s as Prisma.InputJsonValue`). |
| **Does backend strip meanings/furigana?** | **No** — it persists the JSON blob as provided. Stripping happens **client-side** in **`_sentenceToJson`**. |

---

## 9. Publish Snapshot Findings

**Publish read-only** copies **`draft.sentences`** into **`published_monos.content.core.sentences`** with **`content: s.content`** per sentence row (`story-drafts.service.ts`, publish path). So **whatever is stored in `DraftSentence.content`** (including or excluding meanings/spans) flows to **`published_monos`**.

If remote saves never stored meanings/spans, **publish snapshots them as empty** too.

---

## 10. JSON Shape Mismatch

| Area | Finding |
|------|---------|
| **P1 parser vs creator local JSON** | **Aligned:** `meanings.{en,my}`, `furiganaSpans`, `japaneseText`. |
| **P1 parser vs remote PUT payload** | **Misaligned:** Remote PUT sends **`furiganaSpans: []`** and **`meanings: null`** — not because Prisma rejects fields, but because **Flutter remote serializer omits them**. |

---

## 11. Most Likely Root Cause

1. **Primary:** **`RemoteStoryDraftRepository._sentenceToJson`** (and **`_sentenceDtoFromJson`**) **hard-reset** `furiganaSpans` and `meanings`, so **remote draft sync never persists** translations or furigana and **reload from API wipes** them in the DTO layer.

2. **Secondary (UX):** **`_editSupportAt`** early-exit when **`s.japaneseText != lines[index]`** after **`applySentences`** can prevent opening the support sheet if body vs draft are out of sync.

3. **Secondary (edge):** **`storySentencesFromPlaintextMerge`** matching duplicate identical `japaneseText` lines can attach metadata to the wrong row — rare but possible confusion.

---

## 12. Recommended Fix Order

1. **Fix remote sentence serialization/deserialization** to pass through **`furiganaSpans`** and **`meanings`** (and optionally **`provenance`**) consistently with **`StoryDraftMapper`** / DTO definitions — or **delegate** JSON encoding to the same helpers the mapper uses instead of a parallel minimal serializer.

2. **Re-test** PUT → GET round-trip for a draft with meanings + furigana; then **publish** and confirm **`published_monos.content`** contains the same keys P1 reads.

3. Optionally harden **`_editSupportAt`** alignment logging or merge rules if users still hit the early-return path.

---

## 13. Exact Cursor Prompt For Fix

```
Fix remote story draft sentence sync so furigana and translations persist.

In lib/features/create/data/remote_story_draft_repository.dart:
- Replace _sentenceToJson stub fields (furiganaSpans: const [], meanings: null) with full serialization matching StoryDraftMapper / StorySentenceDto (furiganaSpans list, meanings object with en/my/byLanguage as in dto).
- Extend _sentenceDtoFromJson to parse furiganaSpans and meanings from API maps (reuse StoryDraftMapper patterns or call shared mappers if extracted).

Ensure PUT payload matches what nimon-backend stores in draft_sentences.content and what publish copies to published_monos.

Add focused tests: round-trip StorySentenceDto with meanings + spans through _sentenceToJson → JSON → _sentenceDtoFromJson without loss.

Do not change backend schema. Run flutter test for create/data tests if present.
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Source meaning save path found?** | **Yes** — `LocalizedMeanings.my` via `updateSentenceSupport` → local disk **yes**; **remote PUT currently drops it.** |
| **English meaning save path found?** | **Same** — `meanings.en`; **local yes**, **remote stripped.** |
| **Furigana save path found?** | **Yes** — `updateSentenceTextAndFurigana` / `updateSentenceFurigana`; **local yes**; **remote PUT sends empty `furiganaSpans`.** |
| **Fields persisted to `draft_sentences.content`?** | **Only as sent by client.** Backend stores full JSON; **Flutter remote client currently sends incomplete sentence objects.** |
| **Parser expected shape matches creator shape?** | **Yes locally.** **Mismatch is remote wire serializer vs P1/creator.** |
| **Most likely root cause** | **`RemoteStoryDraftRepository` sentence JSON encode/decode stubs** clearing **`furiganaSpans`** and **`meanings`.** |
| **Recommended fix** | **Implement full sentence field round-trip in remote repository** (align with `StoryDraftMapper`). |
