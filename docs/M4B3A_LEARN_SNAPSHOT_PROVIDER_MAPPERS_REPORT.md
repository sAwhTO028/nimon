# M4b3a Learn Snapshot Provider Mappers Report

**Report date:** 2026-05-03  
**Scope:** Riverpod catalog detail cache + **`LearnPublishedSnapshot`** exposure + DTO→Learn UI mappers. **No** Learn screen UI, **`MonoScreen`**, routing, or backend changes.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/learn/learn_published_snapshot_providers.dart` | **New** — `catalogPublishedMonoDetailProvider` (`FutureProvider.autoDispose.family`), `learnPublishedSnapshotProvider` (`Provider.autoDispose.family<AsyncValue<LearnPublishedSnapshot?>, String>`). |
| `lib/features/learn/learn_published_snapshot_mappers.dart` | **New** — `vocabKanjiItemFromPublishedEntry`, `grammarPatternFromPublishedEntry`, `quizMcqItemFromPublishedEntry`, `shouldUsePublishedLearnSnapshot`. |
| `test/features/learn/learn_published_snapshot_mappers_test.dart` | **New** — mapper + gating tests. |
| `test/features/learn/learn_published_snapshot_providers_test.dart` | **New** — provider fetch/parse/cache/error/empty-id tests. |

---

## Provider Strategy

- **`catalogPublishedMonoDetailProvider(monoId)`** — single **`GET /v1/mono/:id`** via **`remoteMonoFeedRepositoryProvider`** → **`PublishedMonoDetailDto`**. **`autoDispose.family`** matches existing mono stack style.
- **`learnPublishedSnapshotProvider(monoId)`** — **`ref.watch`** detail provider and maps with **`learnPublishedSnapshotFromPublishedMonoDetail`**. Surfaces **loading / error / data** as **`AsyncValue`**. Empty or whitespace **`monoId`** → **`AsyncData(null)`** without HTTP.
- **Reuse:** Learn snapshot **never** calls the repo directly; second consumer of the same **`monoId`** shares the same cached **`FutureProvider`** result (verified in tests).

---

## Vocab Mapper

**`vocabKanjiItemFromPublishedEntry`:** `termJapanese` → **`term`**, **`reading`**, **`glosses.my/en`** → **`meaningMm` / `meaningEn`**, **`exampleSentence`**, **`exampleMeanings`**, type storage key → **`VocabKanjiType`** (`kanji` vs default vocabulary). Null-safe trimming; **`meaningMm`** falls back to **`''`**.

---

## Grammar Mapper

**`grammarPatternFromPublishedEntry`:** **`headline`** → **`title`**, **`meanings` / `usage` / `relatedNote`** → primary/EN fields, **`examples`** → **`GrammarPatternExample`** (JP + myanmar + optional English), **`mistakeWrong`/`mistakeCorrect`** → single **`GrammarPatternMistake`** when both set, **`usageHint`** from **`form`** string.

---

## Quiz Mapper

**`quizMcqItemFromPublishedEntry`:** Pads **`options`** to **4** strings, **`correctIndex`** **`clamp(0, 3)`**, maps **`category`** storage keys to **`LearnQuizCategory`**, **`explanations`** → **`explanation` / `explanationMy`**, optional **`sourceStoryId`**.

---

## Tests Added

| Area | Coverage |
|------|----------|
| **Mappers** | Vocab glosses/examples; kanji type; grammar full shape; quiz pad/clamp/explanations; **`shouldUsePublishedLearnSnapshot`** |
| **Providers** | Parse with learn; null learn; single fetch on double await; whitespace id skips fetch; error propagation |

---

## Flutter Analyze Result

```bash
flutter analyze lib/features/learn/learn_published_snapshot_mappers.dart \
  lib/features/learn/learn_published_snapshot_providers.dart \
  test/features/learn/learn_published_snapshot_mappers_test.dart \
  test/features/learn/learn_published_snapshot_providers_test.dart
```

**Result:** No issues found.

---

## Flutter Test Result

```bash
flutter test test/features/learn/learn_published_snapshot_*.dart
flutter test
```

**Result:** All tests passed (**167** total).

---

## Remaining Risks

- **Owner profile path** uses **`GET /v1/published-monos/:id`** — this provider is **catalog-only**; Profile-published Learn may need a parallel provider or shared DTO parse in M4b3b.
- **Invalidation:** Pull-to-refresh on Mono detail must **invalidate** **`catalogPublishedMonoDetailProvider(monoId)`** when that UI is wired.
- **Mocks:** Screens still use mocks until M4b3b; **`shouldUsePublishedLearnSnapshot`** is available to gate wiring.

---

## Recommended Next Step

**M4b3b:** Consume **`learnPublishedSnapshotProvider`** + mappers in **`VocabKanjiListScreen`** / **`GrammarPatternListScreen`**, with empty states when **`AsyncData(null)`** or **`!shouldUsePublishedLearnSnapshot`**.
