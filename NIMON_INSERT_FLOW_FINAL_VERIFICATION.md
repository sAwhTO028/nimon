# Nimon Insert/Create — Final verification report (V1 rebuild)

**Type:** Post-rebuild verification (phases 1–5 complete).  
**Date:** 2026-04-23  
**Scope:** Verification and documentation only — no product code changes in this pass.

**How this report was produced**

- **Static code audit** of the current `lib/` tree against the locked V1 contract (entry context, back policy, router → session, resume resolution, routes, publish entry points).
- **Repository checks:** `rg` for removed symbols (e.g. `StoryCreatorHubScreen`), route tables in `main.dart`, and key implementation files.
- **Automated tests:** `flutter test` for existing creator tests (see §3).  
- **Not performed in this pass:** on-device or manual UI walkthrough of scenarios 1–28. Those remain the **acceptance QA** layer before shipping.

---

## 1. Scenario matrix

Legend:

| Symbol | Meaning |
|--------|---------|
| **S** | Aligned with implementation in codebase (static verification). |
| **T** | Covered by automated tests (partial overlap). |
| **M** | Requires manual / device QA to claim “passed”. |

---

### A. Core creator flow

| # | Scenario | Result | Evidence / notes |
|---|----------|--------|------------------|
| 1 | Open Create from Add entry | **S** | `/create` uses `StoryCreatorAddTabScreen`; Mono/`main.dart` sets `creatorEntryChannelProvider` before pushing create where applicable. |
| 2 | Story Basics → Story Sentences | **S** | `StoryCreatorBasicsScreen._continue` pushes `/create/story/sentences?draftId=…`. |
| 3 | Back from Story Sentences → correct parent by entry context | **S** | `performCreatorBackFromSentencesHost` → `_goToParentForEntryChannel` (`add` → `/mono`, `processing` → `/more?tab=processing`, `publishedReopen` → Published tab, etc.). **M** to confirm on device. |
| 4 | Story Basics back behavior correct | **S** | `performPopCreateSubrouteIfPossible` / `PopScope` paths in basics screen per phase 2. **M** for feel/regressions. |

---

### B. Learn mode / module flow

| # | Scenario | Result | Evidence / notes |
|---|----------|--------|------------------|
| 5 | Learn mode ON from Story Sentences | **S** | `setLearnMode` on `creatorDrawerSessionProvider`; drawer enables Full Learn affordances. |
| 6 | Open direct module editor (Vocab / Grammar / Quiz / Listening) | **S** | Navigation uses `/create/story/sentences?draftId=…&panel=…` from drawer (`story_creator_sentences_screen`); sync via `CreatorRouteSyncListener` / `syncCreatorDrawerSessionForRouter`. **T** (drawer module switching test). |
| 7 | Back from module → Story Sentences main (S0) | **S** | `creatorRouteShowsLearnModulePanel` → `normalizeLearnModuleToStorySentencesMain` → `creatorStorySentencesMainLocation` + session sync. **M** tap order. |
| 8 | Learn mode OFF on learn surface → normalize to S0 | **S** | `applyCreatorLearnMode` → `normalizeLearnModuleToStorySentencesMain` when on learn surface. |
| 9 | After normalization, back behaves correctly | **S** | Same back stack as S0 host; channel unchanged. **M** |

---

### C. Continue / resume / published reopen

| # | Scenario | Result | Evidence / notes |
|---|----------|--------|------------------|
| 10 | Processing Continue, Learn OFF → S0 | **S** | `_v1ResumeTargetUriForDraft`: `!learnOn` → `creatorStorySentencesMainLocation` only (no `?panel=`). |
| 11 | Processing Continue, Learn ON + valid last module → `?panel=` | **S** | Same resolver: semantics/grammar/quizzes/listening → canonical `panel` query on `/create/story/sentences`. |
| 12 | Published reopen, Learn OFF → S0 | **S** | Same `_v1ResumeTargetUriForDraft`; `tryResumeFromPublishedSurface` → `resume(..., publishedReopen)`. |
| 13 | Published reopen, Learn ON + valid module → `?panel=` | **S** | Same as 11. |
| 14 | Back after Processing Continue | **S** | Entry channel set to `processing` before `push`; exit uses `_goToParentForEntryChannel`. **M** |
| 15 | Back after Published reopen | **S** | Channel `publishedReopen`; exit goes to Published tab (`tab=uploaded`). **M** |

---

### D. Publish behavior

| # | Scenario | Result | Evidence / notes |
|---|----------|--------|------------------|
| 16 | First-time Read Only publish | **S/M** | `performCreatorDrawerPublish` → `publishReadingOnlyToDisk`; snack + `openPublishedTabForRouter`. **M** for full disk/network story. |
| 17 | Already published + unchanged → RO up-to-date; no duplicate first-time publish | **S** | `CreatorProgressDrawer` uses `_readOnlyUpToDate` / publish helper text (“Published version exists…”). **M** copy exactness. |
| 18 | Published + edited → Update Read Only | **S** | `_readOnlyUpToDate` false when dirty; label **“Update Read Only”** when enabled (`creator_progress_drawer.dart`). **M** |
| 19 | Update Read Only works; preserves `publishedMonoId` behavior | **S/M** | Logic lives in `story_creator_provider` publish/update paths — **M** for idempotency across re-publish. |
| 20 | Full Learn publish when ready | **S/M** | `publishFullLearnToDisk` + same navigation pattern as RO. **M** when gates satisfied. |

---

### E. Removed / old prototype flow

| # | Scenario | Result | Evidence / notes |
|---|----------|--------|------------------|
| 21 | Standalone Learn Modules page never appears | **S** | `/create/story/learn` and `/create/story/learn/` **redirect** to sentences (hub removed); no `LearnHubScreen` in creator routes. |
| 22 | `StoryCreatorHubScreen` unreachable | **S** | **No matches** for `StoryCreatorHubScreen` / `story_creator_hub` in `lib/`. |
| 23 | No old hub/intermediate route in creator flow | **S** | `/create/story` redirects to `/create`; learn children redirect to `?panel=`; resume never targets `/create/story/learn` as destination. |
| 24 | Canonical learn routing uses `?panel=` for V1 product behavior | **S** | Drawer and sync use sentences + `panel`; legacy `/create/story/learn/*` redirects to canonical URIs only. |

---

### F. Stability / lifecycle

| # | Scenario | Result | Evidence / notes |
|---|----------|--------|------------------|
| 25 | No stale creator subtree after exit | **S** | Single route→session reconciler (`syncCreatorDrawerSessionForRouter`); guards on sentences build when not under `/create/story`. **M** stress transitions. |
| 26 | No duplicate GlobalKey during exit/module transitions | **S/T** | Per-slot drawer keys (`kCreatorProgressDrawerKeySentences|Vocabulary|Grammar`); deprecated alias removed. Widget tests exercise drawer scope. |
| 27 | No deactivated-ancestor assertions | **M** | Code uses safe lookups / guards per audits; **no automated assertion runner** — device QA. |
| 28 | No build-time side-effect regressions | **S** | Draft load/reconcile confined to reconciler (`creator_route_sync`); basics/sentences avoid mutating draft from `build()` (phase 3). |

---

## 2. Passed scenarios (summary)

- **Fully supported by static audit:** **21 / 28** checklist items marked **S** above (prototype removal, routing, resolver, back policy wiring, keyed drawer).
- **Backed by automated tests (partial):** drawer module switching, session `reportRoute` vocab embed (**T** subset).
- **Passed in the sense “no code contradiction found”** for interactive items — final **pass/fail** still requires **M** runs.

---

## 3. Failed scenarios

**None identified** from **code vs locked V1 intent** during this audit.

Failures during **manual QA** should be filed as bugs with repro steps (not tracked here).

---

## 4. Exact remaining issues (if any)

From **code inspection only**:

| Issue | Severity | Notes |
|-------|-----------|-------|
| **Legacy `/create/story/learn/...` redirect tree** still in `main.dart` | Low | Required for deep links and tier-3 compatibility; product flow uses **`?panel=`**; hub route does not render Learn Modules standalone page. |
| **`creatorNavDebug`** call sites remain; default **verbose off** (`kCreatorNavigationDebugVerbose`) | Low | Optional diagnostics; zero runtime effect when false. |
| **`publishState` parameter** on `resumeFromProcessing` unused for routing | Low | Reserved API; does not violate V1. |

---

## 5. Is old prototype flow fully removed from the creator flow?

**Yes, for creator product navigation:**

- No `StoryCreatorHubScreen` in the codebase.
- Creator **resume** resolves to **`/create/story/basics`**, **`/create/story/sentences`**, or **`?panel=`** on sentences — not to a standalone learn hub.
- **`LearnHubScreen`** remains elsewhere (e.g. story reader / episodes) — **outside** insert/create — by design.

---

## 6. Is Insert/Create stable enough to move on?

**Recommendation:** **Yes for engineering handoff**, with **mandatory manual QA** on scenarios marked **M** before release.

| Gate | Status |
|------|--------|
| Architecture (single reconciler, single back policy, deterministic resume) | **Meets V1 rebuild goals** |
| Automated creator tests | **Passing** (last run: `creator_drawer_session_vocab_embed_test.dart`, `creator_progress_drawer_module_switching_widget_test.dart`) |
| Full regression | **Requires** scripted manual pass for **D** (publish) and **F** (lifecycle assertions) |

---

## 7. Acceptable remaining technical debt (V1)

| Debt | Why acceptable |
|------|------------------|
| Legacy **path strings** for `/create/story/learn/*` in `creator_drawer_session` | Redirect compatibility + flicker preservation until tier-3 cleanup (per rebuild plan). |
| **`CreatorModule.learnHub` / `CreatorStepId.learnHub`** | Rare legacy/unknown segment handling; mapped to sentences in effective step where needed. |
| **Docs** (`NIMON_*.md`) may lag code | Non-blocking; update when convenient. |
| **Broader test suite** | Only targeted creator tests run in CI context of this verification; expand e2e as bandwidth allows. |

---

## 8. Manual QA script (recommended next step)

Run once on device/simulator in order:

1. **A:** Add → Create new → Basics → Sentences → back → lands Mono (or configured add parent).
2. **B:** Sentences → Learn ON → open each panel → back strips `panel` → back exits per channel.
3. **C:** Processing Continue (learn OFF / ON with saved module); Published Edit from mono sheet (same).
4. **D:** RO publish → reopen → verify update RO when dirty; FL when gates green.
5. **E:** Navigate to `/create/story/learn` with `draftId` → verify redirect to sentences without hub UI.
6. **F:** Rapid back/panel switches; watch for asserts / duplicate keys.

Record results in issue tracker or append a “Manual QA sign-off” subsection to this file.

---

*End of report.*
