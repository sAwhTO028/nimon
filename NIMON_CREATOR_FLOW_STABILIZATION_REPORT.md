# Nimon Creator Flow Stabilization Pass

Date: 2026-04-22  
Scope: internal stability only (no UI redesign, no backend changes, no new features).

## 1) Unstable patterns found (root causes)

- **Side effects from `build()`**: multiple creator screens were calling route/session sync helpers directly inside `build()`. That meant any rebuild (keyboard, media query, drawer animation, Riverpod updates) could re-trigger sync work.
- **Sync fan-out**: route/session sync could be triggered from many surfaces (screens, learn toggle, drawer taps, post-frame helpers), producing repeated post-frame scheduling and “ENTER/postFrame” flooding even when the route/panel/draft hadn’t changed.
- **Panel step re-application**: on `/create/story/sentences?panel=...`, `didChangeDependencies` could keep scheduling `setSentencesMainStep(step)` even when the panel was unchanged.
- **Lifecycle risk multiplier**: repeated post-frame callbacks increased the chance that callbacks fire after route transitions (publish → `/more`, fast back presses), amplifying “inactive element” and messenger/scaffold timing failures.

## 2) Files changed

- `lib/features/create/creator_route_sync.dart`
- `lib/features/create/creator_route_sync_listener.dart` *(new)*
- `lib/features/create/story_creator_sentences_screen.dart`
- `lib/features/create/story_creator_basics_screen.dart`
- `lib/features/create/story_creator_hub_screen.dart`
- `lib/features/create/story_creator_learn_hub_screen.dart`
- `lib/features/create/story_creator_audio_editor_screen.dart`
- `lib/features/create/story_creator_quiz_editor_screen.dart`
- `lib/features/create/story_creator_vocab_kanji_editor_screen.dart`
- `lib/features/create/story_creator_grammar_editor_screen.dart`

## 3) Build-time side effects removed

Removed creator route/session sync calls from `build()` in:

- `StoryCreatorHubScreen`
- `StoryCreatorLearnHubScreen`
- `StoryCreatorAudioEditorScreen`
- `StoryCreatorQuizEditorScreen`
- `StoryCreatorVocabKanjiEditorScreen`
- `StoryCreatorGrammarEditorScreen`

Replaced with a transparent wrapper:

- `CreatorRouteSyncListener(child: ...)`

so `build()` returns UI only.

## 4) didChangeDependencies / post-frame loops removed or reduced

- **`StoryCreatorBasicsScreen`**: removed route/session sync from `didChangeDependencies` (now owned by `CreatorRouteSyncListener`).
- **`StoryCreatorSentencesScreen`**:
  - removed route/session sync from `initState` post-frame and from `didChangeDependencies`
  - kept only necessary `draftId` loading + panel parsing behavior
  - added a small dedupe to avoid re-applying `setSentencesMainStep` on the same `?panel=` repeatedly.

## 5) Route dedupe/signature mechanism added

In `creator_route_sync.dart`:

- Added a **signature** keyed by:
  - route `uri.toString()`
  - `matchedLocation`
  - effective `draftId`
  - `learnModeEnabled`
- `syncCreatorDrawerSessionForRouter(...)` now **no-ops** if the signature is unchanged.
- Added **post-frame scheduling dedupe** so the same signature doesn’t queue multiple post-frame callbacks.
- Context-based fallback sync is also deduped (used only in no-GoRouter contexts).

## 6) Learn mode OFF/ON semantics stabilization

No UX changes were made here, but stability improves because:

- learn-mode toggles no longer fight with build-triggered route sync loops
- route sync now applies only on real router changes (and dedupes), reducing “learn mode re-application” churn.

## 7) Publish/back safety improvements (secondary effect)

This pass reduces the background callback volume during publish/back overlaps by:

- removing build-triggered sync fan-out
- deduping route sync + post-frame scheduling
- ensuring creator sync only reacts to real route changes (via router-delegate listener + signature no-op)

This does not change publish navigation behavior; it reduces the probability of stale callbacks firing during teardown.

## 8) Remaining known risks

- Some creator flows still do necessary async work in response to user actions (publish, save, toggle learn). Those are expected; they should be audited only if new concrete logs show a problem.
- `story_creator_grammar_editor_screen.dart` has pre-existing `unused_element` warnings (unrelated to stability).

