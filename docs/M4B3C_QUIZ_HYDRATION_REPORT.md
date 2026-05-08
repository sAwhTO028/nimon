# M4b3c Quiz Hydration Report

**Report date:** 2026-05-03  
**Scope:** Hydrate **Quiz setup** and **Quiz play** from **`LearnPublishedSnapshot`** + catalog **`publishKind`** via **`shouldUsePublishedLearnSnapshot`**. Listening and other Learn tabs unchanged.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/learn/quiz_session.dart` | Added **`pickPublishedQuizQuestionsForSession`**, optional **`publishedQuizPool`** on **`QuizSessionStartArgs`**. |
| `lib/features/learn/quiz_setup_screen.dart` | **`ConsumerStatefulWidget`**; watches **`catalogPublishedMonoDetailProvider`** + **`learnPublishedSnapshotProvider`**; maps quiz rows with **`quizMcqItemFromPublishedEntry`** on Start; loading/error/retry; empty states; **`learnDemoMocksAllowed`** keeps legacy mock-only setup without providers. |
| `lib/features/learn/quiz_play_screen.dart` | Builds deck from **`publishedQuizPool`** when present; otherwise **`QuizMockBank`** only if **`learnDemoMocksAllowed`**; catalog UUID without pool → empty deck + honest copy; clearer messages when args missing on catalog ids. |
| `test/features/learn/quiz_hydration_widget_test.dart` | **New.** Setup read-only / full-learn+quiz / empty-quiz; play UUID without pool skips mock prompt. |
| `test/features/learn/quiz_session_test.dart` | **New.** Unit tests for **`pickPublishedQuizQuestionsForSession`**. |

---

## Quiz Setup Behavior

- **Route:** `contentId` is the catalog mono id from **`/learn/:id/quiz`**.
- **Providers:** **`catalogPublishedMonoDetailProvider(contentId)`** ( **`publishKind`** ), **`learnPublishedSnapshotProvider(contentId)`**.
- **Loading:** Center **`CircularProgressIndicator`** while detail or snapshot async is loading.
- **Error:** Short message + detail + **Retry** (invalidates **`catalogPublishedMonoDetailProvider`**).
- **Gating:** **`shouldUsePublishedLearnSnapshot(detail.publishKind, snap)`** and at least one **`snap.quizEntries`** row.
  - **Read-only / unusable learn:** Empty body explaining read-only vs full learn; **no** Start button.
  - **Full learn but no quiz rows:** **“No quiz for this story yet.”** (requires some other learn section so **`hasAnyLearnData`** stays consistent with M4b3b — empty learn object yields unusable snapshot).
- **Eligible:** Same category + count UI as before; **Start Quiz** pushes **`QuizSessionStartArgs`** with **`publishedQuizPool`** set from mapped snapshot rows.
- **Debug non-UUID ids:** **`learnDemoMocksAllowed`** → previous interactive UI without provider fetch; pool omitted so play uses **`QuizMockBank`**.

---

## Quiz Play Behavior

- **Deck order:** **`pickPublishedQuizQuestionsForSession`** filters by selected **`LearnQuizCategory`**, shuffles, takes **`questionCount`** (cycles if count > pool size — same behavior as **`QuizMockBank.pickQuestions`**).
- **Published path:** Non-null non-empty **`publishedQuizPool`** → no mocks.
- **Demo path:** Null pool + **`learnDemoMocksAllowed(contentId)`** → **`QuizMockBank`**.
- **Catalog UUID, null/empty pool:** No mocks; empty deck → explanatory body (not mock prompts).
- **Missing args:** Catalog UUID gets copy pointing users to setup; non-catalog keeps legacy wording.
- **Result / navigation:** Unchanged; **`QuizResultSummary`** still uses **`args.category`** and scores.

---

## Mock Fallback Policy

| `contentId` | `publishedQuizPool` | Deck source |
|-------------|---------------------|-------------|
| Catalog UUID | Non-empty from setup | Published snapshot rows |
| Catalog UUID | Missing / empty | No mocks; empty-state UI |
| Debug non-UUID (`learnDemoMocksAllowed`) | Null (setup omits) | **`QuizMockBank`** |

Release builds never use demo mocks for UUID-shaped ids.

---

## Tests Added

| File | Coverage |
|------|----------|
| `test/features/learn/quiz_hydration_widget_test.dart` | Read-only setup message; full-learn with quiz shows setup chrome; full-learn with vocab but empty quiz shows empty copy; play UUID + args without pool does not show mock **`図書館`** prompt. |
| `test/features/learn/quiz_session_test.dart` | Published quiz picker filters by category and length. |

---

## Flutter Analyze Result

```bash
flutter analyze lib/features/learn/quiz_session.dart lib/features/learn/quiz_play_screen.dart lib/features/learn/quiz_setup_screen.dart test/features/learn/quiz_session_test.dart test/features/learn/quiz_hydration_widget_test.dart
```

**Result:** No issues found.

---

## Flutter Test Result

```bash
flutter test test/features/learn
flutter test
```

**Results:** `test/features/learn`: **21** tests passed. Full suite: **177** tests passed.

---

## Remaining Risks

- **Deep link to `/learn/:id/quiz/play`** without **`QuizSessionStartArgs`:** Honest “missing session” state — by design.
- **Category with zero published questions:** Empty deck after filter → same as mock bank empty category; message distinguishes catalog vs demo where applicable.
- **Retry** only invalidates catalog detail; rare parse-only issues might need explicit snapshot invalidation later.

---

## Recommended Next Step

**M4b3d:** Hydrate **Listening** (`ListeningPronunciationScreen`) from **`LearnPublishedSnapshot`** (e.g. **`storyAudio`** / line payloads per **`M4B3_LEARN_SCREEN_HYDRATION_PLAN.md`**), with the same **`learnDemoMocksAllowed`** / UUID rules as vocab, grammar, and quiz.
