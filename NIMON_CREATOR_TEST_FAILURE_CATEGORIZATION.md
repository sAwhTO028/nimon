# Nimon — creator test failure categorization

**Source:** `NIMON_CREATOR_TEST_FAILURE_LIST.md` (Groups A and B only).  
**Rules followed:** no code changes, no fixes, no additional test runs — categorization is from that failure list plus static review of `test/create_shell_parent_child_flow_test.dart`.

---

## Group A — `activeModule` vs learn drawer navigation

**Tests**

1. `3-4. Switch to Vocabulary; Vocabulary local actions stay local` — expected `CreatorModule.vocabulary`, actual `CreatorModule.storySentences`.
2. `5-10. Switch to Grammar/Quiz/Listening; local actions stay local` — expected `CreatorModule.grammar`, actual `CreatorModule.vocabulary` (first failing assertion in that test).

### Likely category

**Real product bug** (with a **test harness caveat** worth validating).

### Reasoning

- **Not “outdated test expectation” (primary):** The assertions match the documented V1 intent: after the user opens a learn module from the progress drawer, `creatorDrawerSessionProvider.activeModule` should align with the embedded learn surface (and the router `?panel=` where applicable). There is no indication the product intentionally keeps `activeModule` on `storySentences` while the user is in Vocabulary, or on `vocabulary` when navigating to Grammar.
- **Not “label/widget mismatch”:** Failures are on `CreatorModule` / `activeModule`, not on finders for row titles or buttons. Earlier steps in the same tests (`expect(card, findsOneWidget)`, `expect(open, findsOneWidget)`) would typically fail first if the wrong card or action label were targeted.
- **Not primarily “navigation/back flow change”:** These steps are **forward** navigation from the progress drawer (Open → host URL with `?panel=`), not system back or the centralized back policy. A regression in “back flow” is not the direct label for this symptom.
- **Real product bug:** The observable state is inconsistent: the session’s `activeModule` does not follow the learn module the user chose via the drawer. That is a reconciliation bug between **router / `context.go`** and **`creatorDrawerSessionProvider`** (e.g. route listener timing, missing eager sync after drawer `go`, or another writer resetting session) — i.e. production responsibility unless proven otherwise.

**Test harness caveat (secondary):** `_enableLearnMode` only calls `creatorDrawerSessionProvider.notifier.setLearnMode(true)` and pumps; the real UI path may use `applyCreatorLearnMode` (or equivalent) with extra side effects. If production **requires** that path for drawer opens to be valid, the test could be **partially** misaligned (**test setup drift**) while still surfacing a real gap if the app should tolerate `setLearnMode` alone. Static review alone cannot prove that; treat as a **validation** step before changing tests.

### Recommended fix target

**Production code first** (route → session sync and/or progress-drawer `onOpen` / `go` pairing).  
**Tests second** only if you confirm the harness must mirror the exact learn-mode toggle entry path (`applyCreatorLearnMode` vs `setLearnMode`).

---

## Group B — Back to Mono (`12. Back exits to Home Mono`)

**Test**

- `12. Back exits to Home Mono` — after two backs, `expect(_uri(tester).startsWith('/mono'), isTrue)` failed; last location remained `/create/story/sentences?draftId=…`.

### Likely category

**Real product bug** (locked back / exit path not completing to `/mono`).

### Reasoning

- **Locked rule (given):** Back → flush meaningful state → reset ephemeral UI → exit by `CreatorEntryChannel`. For **`CreatorEntryChannel.add`**, exit target is **`/mono`**.
- **Entry context:** The test **explicitly** sets `creatorEntryChannelProvider` to `CreatorEntryChannel.add` before the back sequence (`create_shell_parent_child_flow_test.dart` around the back taps). So this is **not** a case of “forgot to set entry channel” / **test setup drift** for channel semantics.
- **First back vs second back:** The failure list describes the **second** back not reaching `/mono` while still on story sentences with `draftId` (main host, no learn `panel=`). That matches “sentences main” exit, which should run flush → reset → `_goToParentForEntryChannel` → `router.go('/mono')` for `add`. Staying on `/create/story/sentences?…` contradicts the locked rule **if** flush completed and no blocking dialog path left the user on the page.
- **Outdated test expectation:** Would only apply if the product **no longer** promises Mono exit for `add` from sentences main — not asserted here.
- **Label/widget mismatch:** Not applicable; failure is on **route string**, not widget finders.
- **“Navigation/back flow change”:** If the **spec** intentionally changed (e.g. new intermediate surface), that would be a **product spec / test** alignment task; the user’s locked rule frames this as **bug** until spec says otherwise.

**Residual ambiguity (cannot resolve without runtime UI):** If the second back **blocked** on a save-failure dialog and the harness only taps **Retry** once (`_pumpIfSaveFailedDialog`), one could argue **test harness** insufficiency. The reported failure is only “not `/mono`” with no dialog text in the list; categorization stays **real product bug** for the exit pipeline, with a **note** to confirm no modal blocked completion.

### Recommended fix target

**Production code** (`handleCreatorBackPressed` / sentences-main branch: ensure flush outcome, ephemeral reset, and **reliable** navigation to `/mono` for `CreatorEntryChannel.add` — including avoiding silent no-ops after `await`, e.g. navigation via a captured `GoRouter` instance per policy comments).  
**Tests** only if you later prove a modal or pump budget was the sole blocker and the app already navigates when the dialog is cleared.

---

## Summary table

| Failure group | Likely category | Fix target (primary) |
|---------------|-----------------|----------------------|
| A — `activeModule` vs drawer learn navigation | Real product bug (session ↔ route after drawer `Open`) | Production |
| B — Back to Mono with `CreatorEntryChannel.add` | Real product bug (exit to `/mono` not reached) | Production |
