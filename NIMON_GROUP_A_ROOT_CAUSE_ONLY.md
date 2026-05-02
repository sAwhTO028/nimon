# Group A only — `activeModule` vs drawer “Open” (root cause, no code changes)

**Scope:** Diagnosis per `NIMON_CREATOR_TEST_FAILURE_CATEGORIZATION.md` Group A only.  
**Rules followed:** no code modifications, no fixes, no test runs in this pass (one-run evidence below is from an earlier `flutter test` with `warnIfMissed: true` on the drawer `Open` tap).

---

## 1. Exact failing test names (Group A)

- `3-4. Switch to Vocabulary; Vocabulary local actions stay local`  
  - First failure: `expect(_session(tester).activeModule, CreatorModule.vocabulary)` — actual `CreatorModule.storySentences` (`test/create_shell_parent_child_flow_test.dart` ~345).
- `5-10. Switch to Grammar/Quiz/Listening; local actions stay local`  
  - First failure: `expect(_session(tester).activeModule, CreatorModule.grammar)` — actual `CreatorModule.vocabulary` (same file ~390) after the Grammar drawer “Open” step.

(Tests `1`, `2`, and `11` in the same file are not part of the Group A mismatch as categorized; they can pass while A fails.)

---

## 2. Exact file / function where drawer “Open” is handled

| Location | Role |
|----------|------|
| `lib/features/create/creator_progress_drawer.dart` | `_CreatorProgressRow.build`: `TextButton` `onPressed: isCurrent ? null : () => onOpenStep(item.route)` (see ~655–661). |
| `lib/features/create/story_creator_sentences_screen.dart` | `CreatorProgressDrawer( … onOpenStep: (route) { … } )`: resolves the route, and for the sentences host with a learn panel calls `_goStorySentencesFromDrawerUri` with `_sentencesHostDrawerUri(…, panel: …)` (~1926+ and `_goStorySentencesFromDrawerUri` at ~1307). |

`onOpenStep` is the **only** product path for “Open” on learn rows in this host; there is no separate `openModule` that bypasses it for those rows.

---

## 3. Exact file / function where `?panel=` is converted to `activeModule`

| Location | Role |
|----------|------|
| `lib/features/create/creator_drawer_session.dart` | `CreatorDrawerSessionNotifier.reportRoute`: reads `locationUri?.queryParameters`, sets `fromPanel` via `creatorWorkspaceStepForSentencesPanel` when on the sentences host (~177–188), then `nextActiveModule` via `_activeModuleForPath` → `creatorWorkspaceStepForSentencesPanel` + `_moduleFromSentencesWorkspaceStep` (~115–129, ~195). |
| `lib/features/create/creator_workspace_step.dart` | `creatorWorkspaceStepForSentencesPanel(String? panelRaw)` — maps `vocabulary` / `grammar` / `quiz` / `listening` to `CreatorWorkspaceStep` (~81–89). |
| `lib/features/create/creator_route_sync.dart` | `syncCreatorDrawerSessionForResolvedLocation` — after a resolved `go` target, calls `reportRoute(matched, locationUri: locationUri)` (~112–145). |
| `lib/features/create/creator_route_sync.dart` | `syncCreatorDrawerSessionForRouter` — post-frame `reportRoute` with `router.state.uri` (~153–216). |
| `lib/features/create/creator_route_sync_listener.dart` | `CreatorRouteSyncListener` — attaches to the router and calls `syncCreatorDrawerSessionForRouter` on route changes (~24–52). |

So **`activeModule` tracks `?panel=` when `reportRoute` runs with a `locationUri` that includes `panel=…` on `/create/story/sentences`.** There is no other canonical converter for that mapping in the listed pipeline.

---

## 4. Why `activeModule` stays `storySentences` or the previous module

**Primary cause (verified by `widget_tester` behavior, not by guessing route sync):**  
The **drawer “Open” tap does not deliver the pointer to the `TextButton` that calls `onOpenStep`.**

When `_tapDrawerOpen` runs `tester.tap(open, warnIfMissed: true)` (center of the `TextButton` for “Open” on the Vocabulary card), Flutter reports that the **hit test at that offset resolves to a different target**—notably a **`TextSpan` with a Material icon** (Composer / bottom row area on the **translated** story page), with a `RenderIgnorePointer` / `RenderStack` path through the **same** `StoryCreatorSentencesScreen` body stack, **not** the drawer’s `TextButton`. So:

- `onOpenStep` **is not invoked** (or not reliably),
- `context.go` to `/create/story/sentences?…&panel=…` **does not run** for that user action,
- `syncCreatorDrawerSessionForResolvedLocation` and `reportRoute` for the new `panel` **are not driven by the drawer action**,
- `creatorDrawerSessionProvider.activeModule` **remains** `CreatorModule.storySentences` (test `3-4`) or the **previous** module, e.g. `vocabulary` (test `5-10` after the route was set to vocabulary by `_go` but Grammar “Open” did not run).

**Secondary (would matter only if `onOpenStep` had run):** The route → session path (`reportRoute` / `syncCreatorDrawerSessionForRouter`) is consistent with the locked spec; Group A’s symptom in these tests is **not** first explained by “post-frame clobbering” alone, because the **user gesture never bound to** `onOpenStep` in the failure runs captured above.

---

## 5. Smallest recommended production fix (do not implement yet)

**Address pointer routing when the progress drawer is open** so the **drawer strip and its tappable `TextButton`s** win the hit test over the **translated page** (in particular the bottom row / composer region that shares the same screen Y band as a scrolled “Open” target):

- Tighten hit-test behavior of the **outer `GestureDetector`** on the translated page (e.g. `HitTestBehavior.deferToChild` while the drawer is open, and/or `IgnorePointer` on the page subtree for `t` above a small open threshold), **or**
- Add an **opaque, full-bounds hit target** under the drawer’s scroll content in the **drawer** `Stack` so the drawer area never “falls through” to the page for taps.

Goal: one minimal change in **one** place (`story_creator_sentences_screen.dart` body/drawer stack as currently structured), without a second “authority” for `activeModule` (router + `reportRoute` remain canonical once `go` + sync actually run from the tap).

---

## 6. No implementation

Per instructions, **no code was changed** and **no new test run** was executed for this document.
