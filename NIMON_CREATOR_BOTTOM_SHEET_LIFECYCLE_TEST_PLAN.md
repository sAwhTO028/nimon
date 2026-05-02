# Nimon Creator — Bottom Sheet Lifecycle Tests (Plan Only)

**Mode:** test plan only — **do not** change production code or tests yet; **do not** run tests.  
**Inputs:** `NIMON_CREATOR_FEATURE_TEST_COVERAGE_MAP.md` (coverage gaps for Translate, Grammar add/edit sheets, Listening upsert, several help flows) and current implementation locations below.

## Goal

Add **focused widget tests** that prove each targeted **modal bottom sheet** can be **opened and dismissed cleanly** (and, where specified, **saved**) without leaving the creator shell in a bad state: no stuck overlay, stable `CreatorModule` / URI on the sentences host, and bounded pumps to avoid hangs.

---

## 1. Exact tests to add

All tests are intended for **`test/create_shell_parent_child_flow_test.dart`** (same harness as Translate today: `_pumpApp`, `_go`, `HttpOverrides`, `SharedPreferences` mock) **or** a new file `test/creator_bottom_sheet_lifecycle_test.dart` if you prefer isolation — the plan treats them as one logical suite.

| ID | `testWidgets` name (proposed) | Scenario | Assertions (lifecycle) |
|----|-------------------------------|----------|-------------------------|
| **BS-01** | `bottom sheet: storytelling Translate open then Cancel` | `/create/story/sentences` with ≥1 sentence → **Edit** (optional) or use existing card → **Translate** → sheet shows **Support meanings** → **Cancel** | `find.text('Support meanings')` then gone; `CreatorModule.storySentences`; URI still `/create/story/sentences` (no stray `panel=`); optional: draft sentence meanings unchanged vs pre-tap |
| **BS-02** | `bottom sheet: storytelling Translate open then Save` | Same entry → Translate → enter source meaning → **Save** | Sheet dismissed; `updateSentenceSupport` reflected in `storyCreatorDraftDataProvider` for that sentence |
| **BS-03** | `bottom sheet: Grammar Add pattern open then Cancel` | Learn on → `?panel=grammar` → **Add pattern** → sheet title **Add pattern** (inner `_GrammarPatternSheet`) → **Cancel** | Sheet gone; grammar entry count unchanged; `CreatorModule.grammar`; URI still sentences host + `panel=grammar` |
| **BS-04** | `bottom sheet: Grammar Edit pattern open then Cancel` | Seed one grammar entry via `storyCreatorDraftProvider.notifier.addGrammarEntry` → **Edit** on card → sheet title **Edit pattern** → **Cancel** | Sheet gone; entry headline (or id payload) unchanged |
| **BS-05** | `bottom sheet: Listening Add audio open then Cancel` | `?panel=listening` → **Upload audio** → sheet title **Add audio** → **Cancel** (`OutlinedButton`) | Sheet gone; `draft.audio.storyAudio` still null/absent; module `listeningPronunciation` |
| **BS-06** | `bottom sheet: Listening Replace open then Cancel` | Seed valid story audio (e.g. `setStoryAudio` with URL + validity as in persistence test) → **Replace** → sheet title **Replace audio** → **Cancel** | Sheet gone; audio attachment **unchanged** (same source or still valid) |
| **BS-07** | `bottom sheet: Story How this works open then dismiss` | Main storytelling (no `panel=`) → header **How this works** (`_showHowThisWorks`) | Sheet shows **How this works**; dismiss via **drag down on drag handle** or `Navigator.pop` equivalent; tree settled; module unchanged |
| **BS-08** | `bottom sheet: Grammar help (How to create) open then dismiss` | `?panel=grammar` → header help → `StoryCreatorGrammarOverlays.showHowTo` | Title **How to create Grammar patterns**; dismiss without leaving grammar panel |
| **BS-09** | `bottom sheet: Listening How to add audio open then Got it` | `?panel=listening` → header help (`_showListeningHowTo`) | Copy contains **How to add audio** / **Upload audio**; tap **Got it**; sheet gone |
| **BS-10** | *(optional, same class of UI as map V2)* | `?panel=vocabulary` → header help → `_showVocabHowTo` | Title **How to add vocabulary / kanji**; dismiss (scroll sheet may have no button — use drag handle like BS-07) |

**Out of scope for this plan (but related bottom sheets):** Quiz add/edit sheet (`story_creator_quiz_editor_screen.dart`) — already heavily exercised in `create_shell_parent_child_flow_test.dart` group “Quiz module strict verification” including help **Got it**. Grammar **Test-play** sheet (`story_creator_grammar_overlays.dart`) is a bottom sheet but **not** in the user’s named list; add later if desired.

---

## 2. Existing helper functions that can be reused

From **`test/create_shell_parent_child_flow_test.dart`**:

| Helper | Use |
|--------|-----|
| `_pumpApp` | Boot `NimonApp` + fake assets + HTTP overrides |
| `_go(tester, location)` | `GoRouter.go` + bounded frame pumps |
| `_ctx` / `_container` | `ProviderScope` + `storyCreatorDraftProvider` / notifiers |
| `_uri(tester)` | Assert shell URI after sheet closes |
| `_session(tester)` | `creatorDrawerSessionProvider` → `activeModule` |
| `_enableLearnMode(tester)` | Required for grammar/listening/vocab embed rows |
| `_pumpNavigationSettle` / bounded `pump` loops | After dismiss; avoid `pumpAndSettle` hangs |
| `_pumpIfSaveFailedDialog` | If future sheets trigger save side-effects |

From **`test/creator_progress_drawer_module_switching_widget_test.dart`** (if consolidating):

| Helper | Use |
|--------|-----|
| `_go`, `_openCreatorDrawer`, `_seedLearnModeOn`, `_currentUri` | Alternative harness — less ideal if duplicate; prefer extending shell test helpers |

**Existing pattern to mirror:** Test **2** (Translate + two `Cancel` disambiguation) and tests **5–10** (open sheet + Cancel for grammar/quiz/listening).

---

## 3. New helper functions needed

| Helper (proposed) | Responsibility |
|-------------------|----------------|
| `Future<void> pumpUntilSheetGone(WidgetTester tester, Finder sheetAnchor, {int maxFrames = 30})` | After **Cancel** / **Got it** / drag dismiss, pump until `sheetAnchor` (e.g. `find.text('Support meanings')`) finds **nothing** |
| `Future<void> dismissModalBottomSheetByDrag(WidgetTester tester)` | Optional: `tester.drag` from sheet area downward for sheets **without** an explicit Close/Got it (story **How this works**, grammar help) |
| `Future<void> openStorySentencesWithLine(WidgetTester tester, String line)` | `_go` + composer enter + send — reduces duplication for BS-01/02 |
| `Future<void> goGrammarWithLearn(WidgetTester tester)` | `_enableLearnMode` + `_go('/create/story/sentences?panel=grammar')` + bounded pumps |
| `Future<void> goListeningWithLearn(WidgetTester tester)` | Same for `panel=listening` |
| `void seedValidStoryAudio(WidgetTester tester)` | Wrap `setStoryAudio(...)` for BS-06 so “Replace” path is reachable without file picker |

---

## 4. Production files each test protects

| Test ID | Primary production surface |
|---------|----------------------------|
| **BS-01, BS-02** | `lib/features/create/story_creator_sentences_screen.dart` — `_editSupportAt`, `_SupportMeaningsSheet`, `Navigator.pop` with `null` vs `_SupportMeaningsResult`; downstream `story_creator_provider.dart` `updateSentenceSupport` |
| **BS-03, BS-04** | `lib/features/create/story_creator_grammar_editor_screen.dart` — `StoryCreatorGrammarEditorScreen._showUpsertSheet`, `_GrammarPatternSheet` (titles **Add pattern** / **Edit pattern**, **Cancel** / primary button) |
| **BS-05, BS-06** | `lib/features/create/story_creator_audio_editor_screen.dart` — `_showUpsertSheet`, `_AudioUpsertSheet` (**Add audio** / **Replace audio**, **Cancel**); `StoryCreatorListeningModuleBody` button wiring |
| **BS-07** | `story_creator_sentences_screen.dart` — `_showHowThisWorks` |
| **BS-08** | `lib/features/create/story_creator_grammar_overlays.dart` — `StoryCreatorGrammarOverlays.showHowTo` + host `_showGrammarHowTo` |
| **BS-09** | `story_creator_sentences_screen.dart` — `_showListeningHowTo` |
| **BS-10** | `story_creator_sentences_screen.dart` — `_showVocabHowTo` (and mirrored copy in `story_creator_vocab_kanji_editor_screen.dart` for standalone route — optional) |

**Indirectly protected:** `creator_drawer_session.dart` (module must stay aligned with `?panel=` after overlay closes), `creator_workspace_module_placeholder.dart` (embed still showing correct module body).

---

## 5. Risk level

| Test ID | Risk | Rationale |
|---------|------|-----------|
| **BS-01** | **Medium** | `InputDecorator` / bottom sheet teardown ordering (see existing `FlutterError.onError` filter in quiz test); two **Cancel** buttons possible when edit mode open — disambiguate like test 2 (`find.last` or scoped finder) |
| **BS-02** | **Medium** | Save path triggers draft mutation + `setState`; ensure pumps before reading provider |
| **BS-03, BS-04** | **Low–Medium** | Cancel returns `null` → no `addGrammarEntry` / `updateGrammarEntry`; low logic risk, medium UI timing |
| **BS-05** | **Medium** | `_AudioUpsertSheet` uses `TextEditingController`; sheet lifecycle similar to other forms |
| **BS-06** | **Medium** | Depends on valid `storyAudio` without invoking `FilePicker`; Cancel must not clear audio |
| **BS-07, BS-08** | **Low** | Mostly static content; dismiss UX may rely on drag handle only |
| **BS-09** | **Low** | Explicit **Got it** |
| **BS-10** | **Low** | Same as BS-07 if no explicit button |

---

## 6. Recommended implementation order

1. **BS-03** — Grammar Add **Cancel** only (simplest new sheet; aligns with coverage map **G4** partial).  
2. **BS-05** — Listening Add **Cancel** (coverage map **L4**; no file pick).  
3. **BS-01** — Translate **Cancel** (extends **S3** with explicit lifecycle assertion).  
4. **BS-09** — Listening help **Got it** (deterministic dismiss).  
5. **BS-04** — Grammar Edit **Cancel** (needs seed).  
6. **BS-06** — Listening Replace **Cancel** (needs seeded audio).  
7. **BS-02** — Translate **Save** (assert draft).  
8. **BS-08** — Grammar help dismiss.  
9. **BS-07** — Story **How this works** dismiss (drag / ambiguous).  
10. **BS-10** — Vocab how-to (optional).

---

## 7. Do not implement tests yet

This document is the **spec only**. When implementing:

- Re-read **`NIMON_CREATOR_FEATURE_TEST_COVERAGE_MAP.md`** rows **S3, G4, L4, S2, G2, L2, V2** for alignment with broader coverage goals.  
- Prefer **bounded** `tester.pump` loops over unbounded `pumpAndSettle` after sheet close (consistent with existing creator tests).  
- If `FlutterError.onError` filtering is required, keep it **narrow** and **documented** (same rationale as quiz test).

---

## Appendix: Dismiss controls (implementation truth)

| Sheet | Dismiss path |
|-------|----------------|
| **Support meanings** (Translate) | `TextButton` **Cancel** → `Navigator.pop(null)`; **Save** → `Navigator.pop(result)` |
| **Grammar pattern** (Add / Edit) | `TextButton` **Cancel** → `Navigator.pop(null)`; primary **Add pattern** / **Save changes** |
| **Audio upsert** | `OutlinedButton` **Cancel** → `Navigator.pop(null)`; submit uses `FilePicker` — **not** required for Cancel-only lifecycle tests |
| **Story How this works** | No **Got it** in-sheet; use drag handle / back gesture / `pop` via tester |
| **Grammar how-to** (`grammar_overlays.dart`) | No in-sheet button in current builder; drag handle / pop |
| **Listening how-to** | `FilledButton` **Got it** → `Navigator.pop` |
