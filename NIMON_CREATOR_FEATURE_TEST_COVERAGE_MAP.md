# Nimon Creator — Feature ↔ Test Coverage Map (Audit)

**Audit date:** 2026-04-25  
**Scope:** Creator flow only (story sentences host + embedded learn modules). **No production or test code was modified** for this document.

## Test corpus reviewed

| File | Role |
|------|------|
| `test/create_shell_parent_child_flow_test.dart` | Full-app widget tests: create shell entry, story sentences composer + translate, vocabulary Details + optional Save, grammar/quiz/listening “primary action” sheets opening without cross-module navigation, cross-panel URL persistence, back to Mono, deep quiz tab/add/edit/reorder/test-play/help/save-draft. |
| `test/creator_progress_drawer_module_switching_widget_test.dart` | Full-app widget tests: progress drawer opens learn rows, switches Vocabulary ↔ Grammar ↔ Quiz ↔ Listening, learn-mode-off collapses `panel=`, spot-checks that local buttons (`Add entry`, `Add pattern`, `Add quiz`, `Upload audio`) do not change URI. |
| `test/creator_drawer_session_vocab_embed_test.dart` | **Unit** tests (no full UI): `CreatorDrawerSessionNotifier.reportRoute` / `retainSentencesHostEmbeddedStep` for vocabulary embed and simulated action ids (`vocab_add_from_story`, `vocab_edit_save`, …). |
| `test/remote_add_flow_smoke_test.dart`, `test/remote_delete_honesty_test.dart` | Draft storage / remote honesty — **out of scope** for UI feature checklist below (not mapped per row). |

**Primary implementation surfaces**

- **Host / storytelling / floating header:** `lib/features/create/story_creator_sentences_screen.dart` (`_FloatingPillHeader`, `_showReaderPreview`, `_showHowThisWorks`, `_showVocabReview`, `_showVocabHowTo`, `_showGrammarTestPlay`, `_showGrammarHowTo`, `_showQuizTestPlay`, `_showQuizHowTo`, `_showListeningPreview`, `_showListeningHowTo`, sentence list + `_SentenceComposerItem`, `_reorderSentence`, `_deleteSentenceAt`, `_editSupportAt`, `_QuizTestPlaySheet`).
- **Semantics (vocabulary) module:** `lib/features/create/story_creator_vocab_kanji_editor_screen.dart` (`StoryCreatorVocabKanjiModuleBody`, editor screen app bar, `_showVocabReview`, reorder/delete/details/edit flows).
- **Grammar module:** `lib/features/create/story_creator_grammar_editor_screen.dart` (`StoryCreatorGrammarModuleBody`, pattern cards, reorder/delete); overlays: `lib/features/create/story_creator_grammar_overlays.dart` (`StoryCreatorGrammarOverlays.showHowTo` / `showTestPlay`).
- **Quiz module:** `lib/features/create/story_creator_quiz_editor_screen.dart` (`StoryCreatorQuizModuleBody`, tabs, add/edit sheet, reorder); quiz tab index: `lib/features/create/creator_quiz_ui_state.dart` (`quizTabIndexProvider`); filtering helpers in `lib/features/create/story_creator_provider.dart`.
- **Listening module:** `lib/features/create/story_creator_audio_editor_screen.dart` (`StoryCreatorListeningModuleBody`, `_showUpsertSheet`, `_confirmRemove`, standalone `StoryCreatorAudioEditorScreen`).
- **Embed routing:** `lib/features/create/creator_workspace_module_placeholder.dart` (selects module body by `CreatorWorkspaceStep`).
- **Draft mutations:** `lib/features/create/story_creator_provider.dart` (`StoryCreatorDraftNotifier` — add/delete/reorder/set audio, etc.).

---

## Coverage matrix

**Legend — coverage:** **Covered** = exercised in a widget test with meaningful assertion on outcome; **Partial** = touched (opens UI, notifier-only, or narrow branch) but not an end-to-end assertion for that feature; **Missing** = no automated test found for the user-visible path.

**Legend — lifecycle risk:** **High** = async navigation, `PopScope`/back, reorderables, file I/O or platform channels, or multi-step overlays easy to regress; **Medium** = CRUD sheets/dialogs tied to draft state; **Low** = mostly static copy or session flags already guarded elsewhere.

**Priority** = suggested order to add tests (**1** = do first).

| # | Feature | Implementation (file / symbol) | Coverage | Lifecycle risk | Recommended test to add | Priority |
|---|---------|----------------------------------|----------|----------------|-------------------------|----------|
| **Storytelling** |
| S1 | Preview | `story_creator_sentences_screen.dart` — `_showReaderPreview` (sheet title `Preview`) | Missing | Medium | Widget: seed sentences → tap header primary (“Preview story”) → expect preview sheet + at least one `NimonJapaneseSentenceLine`. | 2 |
| S2 | How this works | `story_creator_sentences_screen.dart` — `_showHowThisWorks` | Missing | Low | Widget: on main story workspace → tap help → expect `How this works` + bullet copy. | 6 |
| S3 | Translate | `story_creator_sentences_screen.dart` — `_SentenceComposerItem.onTranslate` → `_editSupportAt` (support meanings / “Support meanings” UI) | Covered | Medium | Extend: assert save path on support meanings if needed. | — |
| S4 | Delete | `story_creator_sentences_screen.dart` — `_deleteSentenceAt` (invoked from sentence row UI) | Missing | Medium | Widget: add two lines → delete one → expect plaintext/draft line count. | 3 |
| S5 | Sort order | `story_creator_sentences_screen.dart` — `ReorderableListView` + `_reorderSentence` | Missing | High | Widget: drag `CreatorReorderHandle` / `Reorder sentence` semantics (same pattern as quiz reorder test). | 1 |
| **Semantics (vocabulary / kanji)** |
| V1 | Review created vocabulary | Host: `_showVocabReview`; standalone: `StoryCreatorVocabKanjiEditorScreen._showVocabReview` | Missing | Low | Widget: embed vocabulary → tap primary (fact-check) → expect sheet title + count line. | 4 |
| V2 | How to add vocabulary / kanji | Host: `_showVocabHowTo`; module: `StoryCreatorVocabKanjiEditorScreen._showVocabHowTo` | Missing | Low | Widget: vocabulary embed → tap help → expect title `How to add vocabulary / kanji`. | 7 |
| V3 | Details | `story_creator_vocab_kanji_editor_screen.dart` — details sheet + save | Partial | Medium | Widget: assert details fields round-trip after Save (not only presence of Save). | 3 |
| V4 | Edit vocabulary | Same file — Edit entry flow + save | Missing | Medium | Widget: open Edit, change reading/meaning, Save → list reflects change. | 2 |
| V5 | Select vocabulary from story | `StoryCreatorVocabKanjiModuleBody` — `SelectableText` / selection pipeline (`vocab_add_from_story` retain tested only in **unit** `creator_drawer_session_vocab_embed_test.dart`) | Missing | High | Widget: seed story text → select substring → Add entry path → draft gains entry (complements session unit test). | 1 |
| V6 | Delete | `_confirmDelete` + list removal | Missing | Medium | Widget: delete via overflow (or stable finder); if flaky, assert via notifier **after** documenting UI gap. | 4 |
| V7 | Sort order | `ReorderableListView` + `onReorder` in vocab editor | Missing | Medium | Widget: drag reorder on two seeded entries; assert order in `storyCreatorDraftDataProvider`. | 5 |
| **Grammar** |
| G1 | Test play grammar | `story_creator_grammar_overlays.dart` — `StoryCreatorGrammarOverlays.showTestPlay` (invoked from host `_showGrammarTestPlay`) | Missing | Medium | Widget: seed `addGrammarEntry` → open test-play from header → expect overlay content. | 4 |
| G2 | How to create grammar pattern | `StoryCreatorGrammarOverlays.showHowTo` (`_showGrammarHowTo` on host) | Missing | Low | Widget: grammar embed → help tooltip path → expect overlay copy. | 8 |
| G3 | Edit pattern | `story_creator_grammar_editor_screen.dart` — edit sheet | Missing | Medium | Widget: open Edit on seeded pattern → change headline → Save → draft updated. | 2 |
| G4 | Add pattern | Grammar module — “Add pattern” sheet | Partial | Low | Widget: complete add (fill + save) and assert new entry in draft (today: open + Cancel only in shell test). | 3 |
| G5 | Delete | `_confirmDelete` + removal | Missing | Medium | Widget: confirm delete dialog end-to-end. | 5 |
| G6 | Sort order | `ReorderableListView` in grammar module | Missing | Medium | Widget: drag reorder; assert `grammar.entries` order. | 6 |
| **Quizzes** |
| Q1 | Test Play: Semantics | `story_creator_sentences_screen.dart` — `_showQuizTestPlay` + `_QuizTestPlaySheet` | Partial | Medium | Widget: Semantics tab with ≥1 item → test-play → expect `Test-play:` + vocab prompts visible (today: Grammar tab exercised; Sentence empty only). | 3 |
| Q2 | Test Play: Grammar | Same | Covered (in `create_shell_parent_child_flow_test.dart` “Preview Grammar”) | Medium | — | — |
| Q3 | Test Play: Sentence | Same | Partial | Low | Widget: add sentence-category item → test-play Sentence tab → non-empty list behavior. | 5 |
| Q4 | How to create quiz items | `_showQuizHowTo` | Covered | Low | — | — |
| Q5 | Add quiz item: Semantics / Grammar / Sentence | `story_creator_quiz_editor_screen.dart` + add sheet | Covered | Medium | — | — |
| Q6 | Edit quiz item: Semantics / Grammar / Sentence | Edit sheet (`Save changes`) | Partial | Medium | Widget: repeat edit for Grammar-tab and Sentence-tab items (today: one Kanji/Semantics edit). | 6 |
| Q7 | Delete item: Semantics / Grammar / Sentence | Popup `Delete item` → `_confirmDelete` | Partial | Medium | Widget: stable menu delete **or** document notifier workaround and add UI test when menu fixed (shell test comment: “popup menu is flaky”). | 4 |
| Q8 | Sort order: Semantics | `StoryCreatorDraftNotifier` reorder + drag handle | Covered | High | — | — |
| Q9 | Sort order: Grammar | Same reorder pipeline for grammar-only filter | Missing | High | Widget: on Grammar tab, drag reorder; assert relative order in draft for grammar category. | 4 |
| Q10 | Sort order: Sentence | Same for sentence category | Missing | High | Widget: same on Sentence tab. | 4 |
| **Listening / pronunciation** |
| L1 | Listening preview | `story_creator_sentences_screen.dart` — `_showListeningPreview`, `_ListeningPreviewSheet` | Missing | High | Widget: `setStoryAudio` with valid V1-like fixture (or mock) → tap “Listening preview” → sheet opens (not snackbar “No audio attached”). | 2 |
| L2 | How to add audio | `_showListeningHowTo` | Missing | Low | Widget: listening embed → help → expect copy about Upload audio / Replace / Remove. | 8 |
| L3 | Replace audio | `story_creator_audio_editor_screen.dart` — `_showUpsertSheet` title `Replace audio` | Missing | High | Widget: seed existing `storyAudio` → tap Replace → assert sheet title (file picker mocked). | 1 |
| L4 | Add audio | `StoryCreatorListeningModuleBody` — `Upload audio` → upsert sheet | Partial | High | Widget: mock `FilePicker` / platform channel, complete add, assert `draft.audio`. | 1 |
| L5 | Remove | `StoryCreatorAudioEditorScreen._confirmRemove` / listening body remove action | Missing | Medium | Widget: seed audio → Remove → confirm → `storyAudio` null. | 3 |

---

## Cross-cutting coverage (not a checklist row)

| Concern | Where implemented | Coverage | Notes |
|---------|-------------------|----------|-------|
| Create shell / `?panel=` URI ↔ `CreatorModule` | `creator_drawer_session.dart`, `creator_route_sync*.dart`, host screen | Covered | `create_shell_parent_child_flow_test.dart`, `creator_progress_drawer_module_switching_widget_test.dart`, `creator_drawer_session_vocab_embed_test.dart` |
| Progress drawer module switching | `creator_progress_drawer.dart` | Covered | Multiple entry points (Vocab/Grammar/Quiz/Listening) |
| Learn mode gate | Drawer `Switch`, session | Partial / Covered | “Learn off exits learn panel” covered in progress drawer test; broader publish/readiness not mapped above |
| Back navigation (learn panel → sentences → Mono) | `creator_back_policy.dart`, host `PopScope` | Partial / Covered | `create_shell` test 12 (async back + save dialog edge) |
| “Local action must not switch module” | Host + modules | Partial | Shell tests assert no module jump after specific taps; not every button covered |

---

## Summary counts (checklist rows only; 33 rows in matrix)

- **Covered:** 5 rows — S3 (Translate), Q2 (Test play Grammar), Q4 (How to create quiz), Q5 (Add quiz item all tabs), Q8 (Sort order Semantics).
- **Partial:** 7 rows — V3 (Details), G4 (Add pattern), Q1 (Test play Semantics), Q3 (Test play Sentence), Q6 (Edit quiz item), Q7 (Delete quiz item), L4 (Add audio).
- **Missing:** 21 rows — all other matrix entries.

Highest leverage gaps: **story sentence reorder/delete**, **vocabulary “select from story”**, **listening add/replace/preview with file/mock**, **grammar test-play and full CRUD**, **quiz delete UI and per-tab reorder + Semantics test-play with items**.

---

## References (key test anchors)

```317:352:c:\Users\owner\Desktop\SAW_PROJ\nimon\test\create_shell_parent_child_flow_test.dart
    testWidgets('2. Story Sentences local actions stay local', (tester) async {
      // ...
      // Translation/support meanings dialog (Translate button).
      final translate = find.widgetWithText(TextButton, 'Translate').first;
      // ...
```

```677:862:c:\Users\owner\Desktop\SAW_PROJ\nimon\test\create_shell_parent_child_flow_test.dart
    testWidgets('A. Add per tab, filter, switch tabs, edit, delete, reorder, preview/help, save draft', (tester) async {
      // Quiz: add / edit / notifier delete / reorder / test-play Grammar & empty Sentence / help / save draft
```

```1547:1611:c:\Users\owner\Desktop\SAW_PROJ\nimon\lib\features\create\story_creator_sentences_screen.dart
        Positioned(
          // ...
          child: _FloatingPillHeader(
            // primary + help tooltips switch by embedded module (story / vocab / grammar / quiz / listening)
```
