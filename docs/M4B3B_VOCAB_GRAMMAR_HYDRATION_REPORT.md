# M4b3b Vocab Grammar Hydration Report

**Report date:** 2026-05-03  
**Scope:** Hydrate **Vocabulary**, **Grammar list**, and **Grammar detail** from **`LearnPublishedSnapshot`** + catalog **`publishKind`** gating. Quiz and Listening unchanged.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/learn/learn_catalog_content_gate.dart` | **New.** `catalogMonoIdLooksLikeUuid`, dev-only `learnDemoMocksAllowed`. |
| `lib/features/learn/vocab_kanji_list_screen.dart` | **`ConsumerWidget`**; watches `catalogPublishedMonoDetailProvider` + `learnPublishedSnapshotProvider`; maps vocab via `vocabKanjiItemFromPublishedEntry`; loading/error/empty; dev mocks only when gate allows. |
| `lib/features/learn/grammar_pattern_list_screen.dart` | Same pattern for grammar via `grammarPatternFromPublishedEntry`; row tap still passes real **`GrammarPattern`** in **`extra`**. |
| `lib/features/learn/grammar_pattern_detail_screen.dart` | **`pattern == null`**: UUID catalog id → honest “open from list” message; non-UUID demo → generic missing copy. No silent mock fallback for catalog ids. |
| `test/features/learn/vocab_grammar_hydration_widget_test.dart` | **New.** Widget tests for vocab empty/full-learn, grammar list headline, detail without extra. |

---

## Vocabulary Screen Behavior

- **Route:** `contentId` is the catalog mono id (`:id` from `/learn/:id/vocabulary`).
- **Providers:** `catalogPublishedMonoDetailProvider(contentId)` for **`publishKind`**; `learnPublishedSnapshotProvider(contentId)` for **`LearnPublishedSnapshot?`**.
- **Loading:** Center **`CircularProgressIndicator`** while detail or snapshot async is loading.
- **Error:** Friendly message + **Retry** invalidating **`catalogPublishedMonoDetailProvider`** (reparses learn from refreshed detail).
- **Gating:** **`shouldUsePublishedLearnSnapshot(detail.publishKind, snap)`**. When false (read-only publish, missing learn, or empty learn payload): empty body with explanation that read-only stories do not expose learn modules until full learn is published.
- **When gated on but vocab empty:** **“No vocabulary for this story yet.”**
- **When gated on and entries present:** List built from **`snap!.vocabularyKanjiEntries.map(vocabKanjiItemFromPublishedEntry)`**.

---

## Grammar Screen Behavior

- Same provider stack and loading/error/retry pattern as vocabulary.
- **Gating:** Same **`shouldUsePublishedLearnSnapshot`**.
- **Empty:** Appropriate empty copy when learn not usable or **`grammarEntries`** is empty.
- **Data:** **`grammarPatternFromPublishedEntry`** over **`snap.grammarEntries`**.
- **Navigation:** Row tap pushes detail with **`extra: pattern`** (real mapped pattern).

---

## Grammar Detail Behavior

- When **`pattern`** is non-null: unchanged rich layout for that **`GrammarPattern`**.
- When **`pattern`** is null and **`contentId`** looks like a catalog UUID: explicit message to go back and choose a pattern from the list — **no** first-mock substitution.
- Non-UUID / demo ids: short **“No pattern data.”** for legacy demo routes.

---

## Mock Fallback Policy

- **`mockItems`** / **`mockPatterns`** remain **only** when **`learnDemoMocksAllowed(contentId)`** is true: **`kDebugMode`** **and** (`empty`, **`mono`**, or non-UUID id). **Release builds never use these mocks.**
- Real catalog UUIDs always use provider + snapshot path — **no** mock list for production-shaped ids.

---

## Tests Added

| Test file | Cases |
|-----------|--------|
| `test/features/learn/vocab_grammar_hydration_widget_test.dart` | Read-only / no learn → vocab empty message; full-learn fixture → **猫** term visible; grammar list shows **について**; detail without **`pattern`** → catalog missing instruction text. |

Existing mapper/provider tests in `learn_published_snapshot_*_test.dart` remain the unit backbone.

---

## Flutter Analyze Result

Command:

```bash
flutter analyze lib/features/learn/learn_catalog_content_gate.dart lib/features/learn/vocab_kanji_list_screen.dart lib/features/learn/grammar_pattern_list_screen.dart lib/features/learn/grammar_pattern_detail_screen.dart test/features/learn/vocab_grammar_hydration_widget_test.dart
```

**Result:** No issues found.

---

## Flutter Test Result

Commands:

```bash
flutter test test/features/learn
flutter test
```

**Results:**

- `test/features/learn`: **15 tests passed** (includes new hydration widget tests).
- Full suite: **171 tests passed**.

---

## Remaining Risks

- **Retry on snapshot-only failure:** Retry currently invalidates **catalog** detail; if detail is cached and learn parse fails independently, a dedicated **`learnPublishedSnapshotProvider`** invalidation might be clearer (future polish).
- **Deep link to grammar detail:** Opening **`/learn/:id/grammar/detail`** without **`extra`** shows the honest empty state — by design unless a future milestone hydrates by id from snapshot.
- **Widget coverage:** Full golden/e2e paths for every **`publishKind`** combination could be added later; mapper tests cover **`shouldUsePublishedLearnSnapshot`** logic.

---

## Recommended Next Step

**M4b3c:** Hydrate **Quiz** and/or **Listening** from **`LearnPublishedSnapshot`** per **`M4B3_LEARN_SCREEN_HYDRATION_PLAN.md`** (replace **`QuizMockBank`** / **`ListeningSampleData`** where appropriate, same gating and empty states), leaving **`LearnHubScreen`** tile wiring as a separate small pass if needed.
