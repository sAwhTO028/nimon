# M4b3 Learn Screen Hydration Plan

**Report date:** 2026-05-03  
**Type:** Milestone plan / audit only — **no code or command changes in this file.**

**References:** [M4B_FULL_LEARN_PUBLISH_SNAPSHOT_PLAN.md](M4B_FULL_LEARN_PUBLISH_SNAPSHOT_PLAN.md), [M4B1_FULL_LEARN_BACKEND_SNAPSHOT_REPORT.md](M4B1_FULL_LEARN_BACKEND_SNAPSHOT_REPORT.md), [M4B2_FLUTTER_LEARN_SNAPSHOT_PARSER_REPORT.md](M4B2_FLUTTER_LEARN_SNAPSHOT_PARSER_REPORT.md).

**Code anchors:** `lib/features/profile/data/published_mono_learn_snapshot_parser.dart`, `lib/features/learn/**`, `lib/main.dart` (Learn `GoRoute`s), `lib/features/mono/mono_screen.dart`, `lib/features/profile/data/published_mono_detail_parser.dart`, `lib/features/profile/data/published_mono_dto.dart`.

---

## 1. Executive Summary

**M4b1** persists **`content.learn`** on full-learn publish. **M4b2** parses it into **`LearnPublishedSnapshot`** with typed **`VocabularyKanjiEntryDto`**, **`GrammarEntryDto`**, **`QuizEntryDto`**, and **`StoryAudioDto`**.

Learn **UI** still reads **hard-coded mocks** (`mockItems`, `mockPatterns`, **`QuizMockBank`**, **`ListeningSampleData`**) keyed only by route **`:id`** (mono id string). Without hydration, users never see catalog learn data even when the snapshot exists.

**M4b3** connects **PublishedMono / Mono detail** → **snapshot** → **Learn routes** so each module can render **real** entries or **honest empty** states, with **read-only vs full-learn** gating so **`read_only_v1`** never pretends learn was published.

---

## 2. Current Learn Routes / Screens

| Route (from `main.dart`) | Screen |
|--------------------------|--------|
| **`/learn/:id`** | **`LearnHubScreen`** — receives **`contentId`** (= `:id`), optional **`extra`** map (`coverImageUrl`, `storyTitle`, `level`, …) from Mono push. |
| **`/learn/:id/vocabulary`** | **`VocabKanjiListScreen`** |
| **`/learn/:id/grammar`** | **`GrammarPatternListScreen`** |
| **`/learn/:id/grammar/detail`** | **`GrammarPatternDetailScreen`** — optional **`GrammarPattern`** via **`extra`**. |
| **`/learn/:id/quiz`** | **`QuizSetupScreen`** |
| **`/learn/:id/quiz/play`** | **`QuizPlayScreen`** — **`QuizSessionStartArgs`** via **`extra`**. |
| **`/learn/:id/quiz/result`** | **`QuizResultScreen`** |
| **`/learn/:id/listening`** | **`ListeningPronunciationScreen`** — optional **`extra`** map (`storyTitle`, `audioUrl`, `explanationLanguage`). |
| **`LearnScreen`** | Exists as generic article-style screen; not wired in the main Learn `GoRoute` table audited above (hub-centric flow today). |

**Note:** Creator **`/create/story/learn/*`** routes redirect into sentences panels — out of scope for catalog Learn hydration.

---

## 3. Current Mock Data Usage

| Screen | Mock / static source |
|---------|----------------------|
| **`VocabKanjiListScreen`** | **`mockItems`** (`VocabKanjiItem` list). |
| **`GrammarPatternListScreen`** | **`mockPatterns`** (`GrammarPattern` list). |
| **`GrammarPatternDetailScreen`** | Pattern from **`extra`** or **null** → falls back to first mock pattern (see list screen navigation). |
| **`QuizSetupScreen` / `QuizPlayScreen`** | **`QuizMockBank.pickQuestions`** when not given custom args. |
| **`ListeningPronunciationScreen`** | **`ListeningSampleData.mockLines`**, **`defaultAudioUrl`**, unless **`audioUrl`** / **`lines`** passed via **`extra`**. |
| **`LearnHubScreen`** | Static tiles; default **`onTap`** can show SnackBar when not overridden by labeled branch. |
| **`LearnScreen`** | **`_mockLearnContent(contentId)`** — demo blocks. |

---

## 4. Proposed Data Flow

1. **Source of truth:** **`PublishedMonoDetailDto.content`** (public **`GET /v1/mono/:id`** or owner **`GET /v1/published-monos/:id`**) — same JSON root the reader already uses for **`core`**.  
2. **Parse:** **`learnPublishedSnapshotFromContent(dto.content)`** or **`learnPublishedSnapshotFromPublishedMonoDetail(dto)`** ([M4b2](M4B2_FLUTTER_LEARN_SNAPSHOT_PARSER_REPORT.md)).  
3. **Cache / expose:** A **Riverpod** (or existing mono detail pipeline) layer holds **`LearnPublishedSnapshot?`** keyed by **`monoId`** so **`/learn/:id/*`** child routes do not each re-fetch unless invalidated.  
4. **Consume:** Vocab / Grammar / Quiz / Listening screens **read** snapshot (or mapped view-models) by **`contentId`** from provider; **mappers** convert DTO rows → existing UI models where possible.

---

## 5. Route / Provider Strategy

| Option | Pros | Cons |
|--------|------|------|
| **Pass full snapshot in `extra`** | No extra fetch | Large payload; easy to exceed **`extra`** ergonomics; lost on deep link refresh. |
| **Re-fetch detail on every Learn screen** | Simple | Duplicate network; janky if four tabs each hit API. |
| **Provider keyed by `monoId` (recommended)** | Single parse per mono session; child routes share data; survives **`context.push`** without bloating **`extra`**. | Requires **invalidation** when user pulls to refresh mono detail. |

**Recommended (minimal + safest):**

- Add **`learnPublishedSnapshotForMonoProvider`** (or merge into an existing **mono detail** `AsyncNotifier` / `FutureProvider.family`) that:
  - Depends on **already-fetched** mono detail when available **or**
  - Performs **one** **`GET /v1/mono/:id`** (catalog) / owner detail when Learn is entered and detail is missing.
- **Do not** pass the entire snapshot through every **`context.push`**; keep **`extra`** for **small** presentation-only fields (cover URL, title) as today.
- **Grammar detail:** keep passing **`GrammarPattern`** (or slim id) via **`extra`** from list row tap — list is built from snapshot, so data is consistent.

---

## 6. Vocabulary Hydration Plan

**Map `VocabularyKanjiEntryDto` → `VocabKanjiItem`:**

- **`term`** ← **`termJapanese`**
- **`reading`** ← **`reading`** (default `''` if null)
- **`meaningMm`** ← **`glosses?.my`** (default `''`)
- **`meaningEn`** ← **`glosses?.en`**
- **`type`** ← **`VocabularyKanjiEntryTypeLabels.fromStorageKey(type)`** → **`VocabKanjiType`**
- **`exampleSentence`** ← **`exampleSentence`**
- **`exampleMeaningMm` / `exampleMeaningEn`** ← **`exampleMeanings`** my/en
- **`storySource`** ← optional from hub title / mono title (not in DTO)
- **`audioUrl`** ← reserved / null unless future transcript pipeline

**Empty state:** **`hasAnyLearnData`** false **or** vocab list empty → show “No vocabulary for this story yet” (and do **not** show **`mockItems`** when **`publishKind`** is **`read_only_v1`** or snapshot missing for **`full_learn_v1`**).

---

## 7. Grammar Hydration Plan

**Map `GrammarEntryDto` → `GrammarPattern`:**

- **`title`** ← **`headline`**
- **`form`** ← **`form`** ?? `''`
- **`meaning` / `meaningEn`** ← **`meanings`** my/en (grammar UI is Myanmar-primary; align with **`learn_explanation_language`** toggles)
- **`whenToUse` / `whenToUseEn`** ← **`usage`** my/en
- **`examples`** ← map each **`GrammarExampleDto`**: **`japanese`** + myanmar/english from **`example.meanings`**
- **`commonMistakes`** ← single pair from **`mistakeWrong` / `mistakeCorrect`** when both non-empty
- **`relatedNote` / `relatedNoteEn`** ← **`relatedNote`** my/en
- **`usageHint`** ← optional short line from **`form`** or first example JP

**Empty state:** No grammar entries → empty list message; detail route should not silently substitute **mock** pattern when snapshot-backed list is empty.

---

## 8. Quiz Hydration Plan

**Map `QuizEntryDto` → `QuizMcqItem` / session:**

- **`LearnQuizCategory`** ← map from **`category`** storage key (`vocabulary`, `grammar`, `sample_sentence`, `kanji`) — reuse **`CreatorQuizCategoryLabels.fromStorageKey`** semantics or a thin Learn-side enum mapper.
- **`options`**: **`QuizMcqItem`** asserts **4** options — **pad** with `''` to length 4 (same as **`StoryDraftMapper._fourOptions`**).
- **`correctIndex`**: **clamp** to **`0..3`** after pad.
- **`explanation` / `explanationMy`** ← **`explanations`** en/my.

**Empty / disabled:** No quiz entries → **`QuizSetupScreen`** disables start or shows empty; **never** mix **`QuizMockBank`** with real **`monoId`** when **`publishKind`** indicates no learn.

**Fewer than four authored options:** pad; if **`correctIndex`** out of range after pad, clamp (mapper responsibility + test).

---

## 9. Listening / Audio Hydration Plan

**Map `StoryAudioDto` → `ListeningPronunciationScreen`:**

- **`audioUrl`**: use **`sourceUrl`** only if **`https://`** (or **`http://`** if product allows — prefer **HTTPS** for real playback).
- **`storyTitle`**: from mono / hub (already passed).
- **`lines` / transcript:** **Not** in M4b1 snapshot — V1 can ship **audio-only** (no transcript lines) or keep sample lines only when no timed transcript exists (product choice). Plan default: **no fake transcript** when hydrating real audio; show player + empty transcript message.

**Local paths (`localPath`, file://):** **Not valid** for other devices — treat as **no public URL**; show “Audio unavailable” or prompt republish with hosted URL.

**Fallback:** No **`storyAudio`** or invalid URL → honest empty / sample **only** if product explicitly allows demo mode for non-catalog ids (avoid **`monoId`** collisions with mocks).

---

## 10. Read-only vs Full-learn Gating

| Condition | Behavior |
|-----------|----------|
| **`publishKind` / `displayPublishKind`** = **read-only** | **No** catalog learn: **do not** show **`mockItems`** as if they were the story. Empty states + copy (“Publish full learn to unlock modules”) or hide tiles. |
| **full_learn** + **`LearnPublishedSnapshot?.hasAnyLearnData == true`** | Use **real** per-module data. |
| **full_learn** + **no `learn` / parse null / empty snapshot** | **Legacy / incomplete publish** — message to republish or contact support; **no mocks**. |
| **Unknown publish kind** | Conservative: treat as **no learn**. |

**Source for `publishKind`:** **`PublishedMonoDetailDto.publishKind`** (or **`content`** root) alongside snapshot parse.

---

## 11. Recommended Implementation Split

| Phase | Scope |
|-------|--------|
| **M4b3a** | **Provider/cache** keyed by **`monoId`** + **DTO → UI mappers** (pure Dart / small Riverpod); wire invalidation when mono detail refresh fires. **No** large **`MonoScreen`** refactor — optional one-line **seed** of provider after detail load if already available. |
| **M4b3b** | **`VocabKanjiListScreen`** + **`GrammarPatternListScreen`** / **detail** — consume provider + empty states. |
| **M4b3c** | **`QuizSetupScreen`** / **`QuizPlayScreen`** — build session from snapshot list. |
| **M4b3d** | **`ListeningPronunciationScreen`** — HTTPS **`sourceUrl`** + empty transcript policy. |
| **M4b3e** | **Manual smoke:** full learn publish → open hub → each module; read-only mono → no fake learn. |

---

## 12. Tests Needed

| Layer | Tests |
|-------|--------|
| **Mappers** | Vocab / grammar / quiz DTO → UI model (edge: empty meanings, pad options, clamp index). |
| **Provider** | Given mock HTTP JSON → snapshot cached; refresh clears/reloads; `read_only` yields null learn usage. |
| **Widget (optional)** | List screen shows empty text when snapshot empty; one golden path with one vocab row. |

---

## 13. Risks

- **Route complexity:** Many **`GoRoute`**s share **`:id`**; inconsistent provider scope causes **flash of mocks** then real data — mitigate with **`AsyncValue`** loading UI.
- **Stale snapshot:** User edits draft after publish — **`content`** on device may be old until detail refresh; show **updatedAt** or refresh affordance later.
- **Payload size:** Large learn arrays in memory when caching full detail — acceptable V1; watch low-memory devices.
- **Audio URLs:** Local paths break public listening — must set expectations in UI copy.
- **Mock fallback confusion:** If mocks remain for **dev-only mono id**, guard with **`kDebugMode`** + explicit fake id — never for real UUID catalog ids.

---

## 14. Exact Cursor Prompt For M4b3a

Use for **provider/cache + mappers only** (no Learn screen UI edits in same PR if you want strict layering):

---

**M4b3a — Learn snapshot provider + DTO→UI mappers (Flutter)**

**Constraints:** Do **not** change Nest backend. Do **not** refactor **`MonoScreen`** beyond a minimal optional call to seed cache (prefer zero Mono changes: hydrate provider on first Learn route read). Do **not** change **`LearnScreen`** or full quiz/listening UI yet.

**Goals:**

1. Add a **Riverpod** `family` provider (or extend existing mono-detail provider) that exposes **`LearnPublishedSnapshot?`** for a **`monoId`** string, using **`learnPublishedSnapshotFromContent`** from `published_mono_learn_snapshot_parser.dart`.

2. **Data loading:** If no cached **`PublishedMonoDetailDto`** / content for that id, perform **one** `GET /v1/mono/:id` (reuse existing remote mono detail repository + DTO parsing used by Mono home/detail). Parse snapshot from **`content`**. Use **`autoDispose`** or explicit invalidation tied to mono detail refresh events.

3. Add **pure Dart mappers** (new file under `lib/features/learn/` or `lib/features/profile/`):
   - `VocabularyKanjiEntryDto` → **`VocabKanjiItem`**
   - `GrammarEntryDto` → **`GrammarPattern`**
   - `QuizEntryDto` → **`QuizMcqItem`** (pad options to 4, clamp **`correctIndex`**)

4. **Unit tests** for mappers + provider parsing (mock client / fixture JSON).

5. **`flutter analyze`** on touched paths.

**Out of scope for M4b3a:** Editing **`VocabKanjiListScreen`** / **`GrammarPatternListScreen`** / quiz/listening widgets (M4b3b–d).

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Safest data flow** | **Single snapshot per `monoId`** in a **family provider** (or piggyback on mono detail cache) — avoid large **`extra`** payloads and per-screen duplicate fetches. |
| **Screens to hydrate first** | **Vocab** + **Grammar** lists (highest visible value, simplest list UIs), then **Quiz**, then **Listening** (URL + transcript policy). |
| **Mock fallback policy** | **No mocks** for real catalog **`monoId`** when **`read_only_v1`** or missing learn; optional **dev-only** mocks behind **`kDebugMode`** + non-UUID id only. |
| **Biggest risk** | **Flash or accidental mock** when snapshot async loads — use **loading / empty** states and strict **publishKind** gating. |
| **First implementation step** | **M4b3a:** Provider + mappers + unit tests; then wire **one** list screen end-to-end in **M4b3b** before quiz/audio. |
