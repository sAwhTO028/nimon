# Nimon Insert / Create flow — full pre-rebuild audit

**Date:** 2026-04-23  
**Scope:** Map only — **no fixes**, **no UI redesign**, **no backend changes**.  
**Goal:** Full inventory to support a future locked rebuild of Insert/Create.

---

## Executive summary

The V1 create flow is centered on **GoRouter** top-level routes under `/create/...` (outside `StatefulShellRoute`), **Riverpod** for draft + drawer session, and **embedded Learn modules** on `/create/story/sentences?panel=…`. Several **legacy paths** (`/create/story/learn/...`, standalone `*EditorScreen` scaffolds, `StoryCreatorHubScreen`) are **redirected, unused in `main.dart`, or only embedded** as *module bodies* — not separate router pages. **Multiple authorities** (URL `?panel=`, `creatorDrawerSessionProvider`, drawer callbacks with `go`/`push`, `syncCreator*`, learn-mode) can **drift**; stabilization has accumulated **guards, listeners, and post-frame syncs**.

---

## 1. Route map (app shell + create)

| Location | Behavior |
|----------|----------|
| `lib/main.dart` | `/create` (NoTransitionPage) → add tab or `CreateScreen` (edit basics). |
| | `/create/story` → redirect bare `/create/story` to `/create`; child routes `basics`, `sentences`, `learn/…`. |
| | `/create/story/learn` root → redirect to `/create/story/sentences` (+ optional `draftId`). |
| | `learn/vocabulary` … `audio` child routes → **redirect** to `/create/story/sentences?panel=…` (not separate `Page`s for editors in router). |
| | `StatefulShellRoute` → `/mono`, `/more` with `NoTransitionPage` for shell; `AppShell` + dock `go` / `push` to create. |

**Conclusion:** There is **no** registered `GoRoute` in `main.dart` that builds `StoryCreatorGrammarEditorScreen` / `StoryCreatorHubScreen` as top-level pages. Module UIs are **bodies** inside the sentences host + redirects.

---

## 2. Full file list (participates in Insert/Create behavior)

### 2.1 `lib/features/create/` (all 65 `.dart` files in tree — see glob)

**Representative list by area** (duplicates in glob are same path, different `/` style):

- **Entry / shell:** `create_screen.dart`, `story_creator_add_tab_screen.dart`, `story_creator_basics_screen.dart`, `story_creator_sentences_screen.dart`, `story_creator_hub_screen.dart`, `creator_back_policy.dart`
- **State:** `story_creator_provider.dart`, `story_creator_draft_storage.dart` (re-export types), `story_v1_model.dart`, `story_creator_models.dart`, `data/story_draft_repository.dart`, `data/*_repository*.dart`, `data/dto/*`, `data/story_draft_mapper.dart`, `data/remote_backend_config.dart`
- **Session / step:** `creator_drawer_session.dart`, `creator_workspace_step.dart`, `creator_step_id.dart`
- **Routing & sync:** `creator_route_sync.dart`, `creator_route_sync_listener.dart`, `creator_back_policy.dart`, `creator_learn_mode_sync.dart`
- **UI chrome:** `creator_progress_drawer.dart`, `creator_reorder_handle.dart`, `create_story_basics_form.dart`, `story_creator_progress_checklist.dart` (if referenced), `story_creator_review_display.dart`, `creator_workspace_module_placeholder.dart`
- **Module bodies (shared with optional full-screen scaffolds):** `story_creator_vocab_kanji_editor_screen.dart`, `story_creator_grammar_editor_screen.dart`, `story_creator_quiz_editor_screen.dart`, `story_creator_audio_editor_screen.dart` (exports `*ModuleBody` used by placeholder + optional `*Screen` widgets)
- **Overlays / text:** `story_creator_grammar_overlays.dart`, `story_creator_furigana_tokens.dart`, `story_creator_grammar_overlays.dart`
- **Publish / RO:** `creator_drawer_publish.dart`, `creator_read_only_publish_tracking.dart`, `creator_publish_validation.dart` (as used)
- **Resume / copy:** `creator_resume_draft.dart`, `creator_processing_copy.dart`, `creator_readiness.dart`, `creator_draft_validation.dart`, `creator_labels.dart`, `creator_completion_rules.dart` (from progress), `creator_progress_logic.dart`, `creator_navigation_debug.dart`, `creator_progress_drawer.dart` (drawer “progress” model is built in multiple places — see story_creator_review_display)

### 2.2 Outside `features/create/` but in flow

| File | Role |
|------|------|
| `lib/main.dart` | Router, `AppShell`, `_openCreate`, `NoTransitionPage` for create + shell. |
| `lib/features/mono/mono_screen.dart` | Push `/create`, sets `creatorEntryChannel` (shell). |
| `lib/features/profile/profile_screen.dart` | Processing, `CreatorDraftResumeFlow`, empty state push `/create`. |
| `lib/features/profile/profile_navigation_drawer.dart` | Story Creator push, entry channel. |
| `lib/features/profile/profile_navigation_helpers.dart` | Post-publish navigation to Profile tabs. |
| `lib/features/profile/profile_processing_refresh.dart` | Referenced from draft provider for list bumps. |
| `lib/ui/app_messenger.dart` | Snackbars from publish path. |
| `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart` | Uses `lib/ui/create/widgets/one_short_paper_card.dart` — **separate** “one short / add mono” product path, not story creator router. |
| `lib/ui/create/*` | Widgets; primary consumer in-repo appears to be **add mono** sheet, not `main.dart` create routes. |
| `test/creator_*.dart` | Widget / session tests for creator. |

---

## 3. Responsibility by file (category → owner)

| Category | Primary owners |
|----------|----------------|
| **Persistent draft + publish** | `story_creator_provider.dart`, `data/*repository*`, `story_creator_draft_storage.dart` / DTOs / mapper, `story_v1_model.dart` / `story_creator_models.dart` |
| **Session / which panel & learn** | `creator_drawer_session.dart` (`StateNotifier` + `reportRoute`, `setLearnMode`, `setSentencesMainStep`, `retainSentencesHostEmbeddedStep`) |
| **Routing / URL** | `main.dart`, in-screen `go`/`push` in `story_creator_sentences_screen.dart`, `creator_resume_draft.dart`, `creator_back_policy.dart`, `creator_learn_mode_sync.dart` (learn off) |
| **Back navigation** | `creator_back_policy.dart` + `PopScope` / headers in `story_creator_sentences_screen.dart`; `story_creator_basics_screen.dart` / `create_screen.dart` / add tab (partial); shell `AppShell` |
| **Learn mode** | `creator_learn_mode_sync.dart` → `applyCreatorLearnMode` + `creator_drawer_session` |
| **Continue / resume** | `creator_resume_draft.dart` + `profile_screen` call sites |
| **Publish (RO / Full Learn)** | `creator_drawer_publish.dart` → `performCreatorDrawerPublish` + `story_creator_provider` publish methods; navigation via `ProfileNavigation` |
| **RO signature tracking** | `creator_read_only_publish_tracking.dart`, `story_creator_provider` `readOnlyPublishedCoreSig` |
| **Checklist / gating** | `creator_progress_logic.dart`, `creator_completion_rules.dart`, `creator_draft_validation.dart` |
| **Debug** | `creator_navigation_debug.dart`, scattered `[NIMON_TRACE]` |

---

## 4. Duplicated or conflicting authority

1. **Embedded step vs URL vs session**  
   - `?panel=` on `/create/story/sentences` (route SOT in comments in `story_creator_sentences_screen.dart`)  
   - `creatorDrawerSessionProvider.sentencesMainStep` + `activeModule`  
   - `creatorDrawerSession.reportRoute` vs manual `setSentencesMainStep` / `go` in drawer and learn-mode paths  
   **Risk:** one updates without the other during fast transitions; code uses `retainSentencesHostEmbeddedStep` and route guards to mitigate.

2. **Route sync: two entry points**  
   - `CreatorRouteSyncListener` (router delegate listener) → `syncCreatorDrawerSessionForRouter`  
   - `syncCreatorDrawerSessionFromContext` (context-based)  
   Both dedupe with `Expando` / string sigs and **post-frame** work.

3. **Learn surface detection**  
   - `creator_learn_mode_sync.dart`: `creatorSessionIsOnLearnSurface`, `creatorGoRouterOnLearnCreatePath` (URL)  
   - `creator_drawer_session.dart`: path segments for `/create/story/learn/…` and `?panel=`  
   Overlap is intentional (defense in depth) but **must stay aligned** on rebuild.

4. **“Progress” / checklist model**  
   - `buildCreatorDrawerProgressModel` and related (drawer)  
   - `CreatorStoryV1Progress` in `creator_progress_logic.dart`  
   - `story_creator_review_display.dart` for review card  
   Same business rules may be **expressed in multiple** helper layers.

5. **Back**  
   - Centralized `performCreatorBackFromSentencesHost` / entry channel vs **older** `context.pop` stacks on basics and internal `Navigator.pop` in dialogs. Intentional split, but two mental models ( **`go` replace** vs **stack pop**).

6. **Module implementation**  
   - `CreatorWorkspaceModulePlaceholder` embeds `*ModuleBody` from `*_editor_screen.dart` files.  
   - Those files **also** define `*Screen` (full `Scaffold`) for doc comments as “/create/story/learn/... route screen” — **not** actually registered in `main.dart`. **Dual API** in one file increases confusion.

---

## 5. Dead, legacy, or prototype branches

| Item | Evidence | Notes |
|------|----------|--------|
| **`StoryCreatorHubScreen`** | `grep` only references the file itself | **Not** in `main.dart` routes; product flow uses `/create` + redirects from bare `/create/story`. **Likely dead** for current app entry. |
| **Standalone Learn hub route** | `main.dart` redirect `/create/story/learn` → sentences | **Removed** from product; deep links still normalize. |
| **Router pages for** `*EditorScreen` | **No** `GoRoute` in `main.dart` for grammar/vocab/quiz/audio *screens* | Editors exist as **widgets**; `main` only has **redirect** children. |
| **`/create/story/basics` vs hub** | Redirect of `/create/story` to `/create` | Old “hub” as landing replaced by add tab. |
| **`ui/create` one-short widgets** | Used from `add_mono_bottom_sheet` | **Parallel** “add mono / one short” path — name collision with `features/create`; not the story creator stack. |
| **Deprecated** `kCreatorProgressDrawerKey` | Comment in `creator_progress_drawer.dart` | Replaced by per-host `ValueKey`s. |

---

## 6. Routes / screens to **consider removing** in a clean rebuild

*(Audit-only recommendation — not implemented.)*

1. **`StoryCreatorHubScreen`** (if no external deep link or test requires it)  
2. **Unused** `*Screen` scaffold wrappers in editor files — keep **one** module surface (embedded **or** routed, not both shapes in one file unless clearly separated).  
3. **Redundant** redirect chains under `/create/story/learn/*` — could collapse to a single “normalize learn deep link” helper.  
4. **Legacy** path string branches in `creator_drawer_session` for `/create/story/learn/...` **if** the app guarantees only `?panel=` forever (requires product decision on deep links).  
5. **`NIMON_TRACE` / debug-only** code paths in production if rebuild tightens logging.

---

## 7. GlobalKey / key usage (create flow)

| Place | What |
|-------|------|
| `create_screen.dart` | Two `GlobalKey<CreateStoryBasicsFormState>` (create vs review edit) to avoid key collision when branches overlap. |
| `story_creator_basics_screen.dart` | `GlobalKey<CreateStoryBasicsFormState>` for basics form. |
| `story_creator_sentences_screen.dart` | `ValueKey(effectiveStep)` on a workspace child (panel switches). |
| `creator_progress_drawer.dart` | `ValueKey` constants `kCreatorProgressDrawerKeySentences` / `Vocabulary` / `Grammar`; `KeyedSubtree`; deprecated alias `kCreatorProgressDrawerKey`. |
| `story_creator_*_editor_screen.dart` (lists) | `ValueKey` on rows (`e.id`, `q.id`, etc.) |
| Vocab | `ValueKey('pick_story_text')` in editor file |

**No** second global `GlobalKey` for the whole app drawer (previously a stability issue); per-slot `ValueKey` / `KeyedSubtree` pattern.

---

## 8. Build-time & lifecycle side effects, post-frame sync (high-signal)

| File | Pattern |
|------|---------|
| `story_creator_sentences_screen.dart` | `initState` post-frame **seed** body from draft; **`didChangeDependencies` loads draft** when `routeDraftId` ≠ current; many `addPostFrameCallback` for scroll/focus/scroll-after-insert. |
| `create_story_basics_form.dart` | `addPostFrameCallback` (e.g. scroll / focus) |
| `story_creator_basics_screen.dart` | `didChangeDependencies` — comment: sync owned by `CreatorRouteSyncListener` (minimal/no-op pattern). |
| `creator_route_sync.dart` / `creator_route_sync_listener.dart` | Router listener + **post-frame** `reportRoute` and resume metadata writes. |
| `creator_learn_mode_sync.dart` | `applyCreatorLearnMode` — `context.go` + **post-frame** `syncCreatorDrawerSessionForRouter`. |
| `creator_drawer_publish.dart` | After publish, **post-frame** `ProfileNavigation.open*Tab` + root snackbar. |
| `creator_back_policy.dart` | Post-frame `sync` after `go` strip `panel=`. |
| `story_creator_quiz_editor_screen.dart` | Post-frame callback in at least one path |

**Implication for rebuild:** Centralize “after navigation settles” in **one** coordinator or keep strict ordering (router state → post-frame → sync → no inherited lookups from inactive context).

---

## 9. Tests (creator)

- `test/creator_drawer_session_vocab_embed_test.dart`  
- `test/creator_progress_drawer_module_switching_widget_test.dart`  

Useful as **regression** anchors when replacing internals.

---

## 10. Top 10 rebuild priorities (ordered)

1. **Lock a single SOT** for “where is the user in the story creator?” — **URL** vs **provider** vs **draft resume meta** — and define migration from current triple.  
2. **Collapse navigation API** for Learn embed: one of **panel query**, session step, or both, with a **single** sync function (replace `reportRoute` + `retain*` + multiple `go` sites).  
3. **Unify module packaging**: split **embedded** `*ModuleBody` from optional **routed** `*Screen` or delete unused scaffolds; **remove** `StoryCreatorHubScreen` or wire it officially.  
4. **Entry / exit contract**: one document for `CreatorEntryChannel` (or successor) and **all** create launchers (shell, profile, processing, resume).  
5. **Publish pipeline**: one module for `performCreatorDrawerPublish` + provider publish + `ProfileNavigation` + snackbars; clarify **idempotent** post-publish navigation.  
6. **Lifecycle hardening**: replace `didChangeDependencies` draft load with **explicit** route-observer or `GoRouter` refresh notifiers where possible.  
7. **Reduce post-frame** fan-out: batch “after route change” work (drawer session + resume record + profile bump).  
8. **Data layer**: keep `data/` repositories as boundary; **avoid** `story_creator_provider` growing with UI concerns.  
9. **Kill dead code** after feature freeze: `story_creator_hub_screen`, duplicate learn path strings, deprecated drawer key alias.  
10. **Tests**: promote widget tests for every **locked** transition (basics → sentences, panel changes, learn off, publish, back) before deleting old code.

---

## 11. Open questions for product / tech lock

- Should **any** first-class **route** exist for individual Learn module editors, or is **only** `?panel=` the supported model?  
- Is **`ui/create`** to remain a separate “one short” product line with a name refactor to avoid confusion?  
- **Published reopen / update** (beyond `resume` meta and Processing): list exact entry points in Profile and any deep links.  

---

*End of audit. No code changes in this phase.*
