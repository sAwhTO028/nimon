# Nimon Insert / Create — rebuild execution plan

**Type:** Implementation sequencing (no code in this file).  
**Authoritative inputs:** [NIMON_INSERT_FLOW_FULL_AUDIT.md](NIMON_INSERT_FLOW_FULL_AUDIT.md), [NIMON_INSERT_FLOW_V1_LOCKED_SPEC.md](NIMON_INSERT_FLOW_V1_LOCKED_SPEC.md), [NIMON_CREATE_V1_LOCKED_DECISIONS.md](NIMON_CREATE_V1_LOCKED_DECISIONS.md).  
**Out of scope for the rebuild itself (unless a separate project):** visual redesign, backend API changes, new product features.

**Goals**

- Remove prototype leftovers **safely** (tier 1/2/3 in spec).  
- **Preserve** existing look-and-feel of creator screens (layout, copy-level patterns, not “new art direction”).  
- **Avoid** new `ElementLifecycle` / `GlobalKey` / duplicate-tree issues.  
- **Minimize** regression: small PRs, tests before deletes.  
- **Separate** “remove old / unreachable” from “build new / consolidate authority” so rollbacks are possible.

**Strategy:** Prefer **stabilize contracts first** (entry context, back policy, router SOT) → then **delete dead** → then **merge duplicate sync** → then **tighten CI**. Do **not** do a big-bang delete of `story_creator_sentences_screen.dart` in phase 1.

---

## 1. Implementation phases (ordered)

| Phase | Name | Purpose |
|------:|------|--------|
| **0** | **Baseline & harness** | Lock current behavior with tests/notes; one “golden” manual script (Processing → S0, panel, publish, back). No production behavior change. |
| **1** | **Entry context: complete & named** | Add `PUBLISHED_REOPEN` (or equivalent) + tag every external `/create/...` launch. Migrate off `unknown` in **release** paths. |
| **2** | **Back policy: single source** | Ensure all create exits that the spec covers use `creator_back_policy` only; no new stray `go('/mono')` in feature files. **Do not** change `PopScope` semantics in a way that alters “drawer first” without tests. |
| **3** | **Router = canonical module; session = derived** | One reconciliation path: **after** `go`/`push`, session matches `?panel=` + `draftId`. Reduce manual `setSentencesMainStep` + `go` in parallel (incremental). |
| **4** | **Remove prototype / dead (tier 1)** | `StoryCreatorHubScreen` and any true dead scaffolds; **no** router to hub; grep-clean. |
| **5** | **Learn / resume / publish: behavior-preserving refactors** | `applyCreatorLearnMode`, `creator_resume_draft`, `performCreatorDrawerPublish` — only structural moves with identical outputs. |
| **6** | **Unify route sync (tier 3)** | `syncCreatorDrawerSessionForRouter` vs `FromContext` → one path after verification. |
| **7** | **Tighten session path legacy (tier 3)** | Shrink or remove `/create/story/learn/...` string branches in `creator_drawer_session` when e2e proves `?panel=` + redirects are sufficient. |
| **8** | **Final: zero `unknown`, CI** | Remove `CreatorEntryChannel.unknown` (or make unrepresentable). Optional CI assert. **Sign-off** per spec. |

**Cross-cutting:** After phases 1–3, each merge should run **targeted** `flutter test` (creator) + the manual script. Phases 4+ add **per-item** device smoke for deleted symbols.

**Separation of “remove old” vs “build new”**

- **Phases 0–2:** Mostly **new constraints** on existing code (tagging, policy calls). **Low** structural delete.  
- **Phases 3–4:** **Remove** dead and **simplify** authority — old duplicate paths can go **only after** 1–2 prove stable.  
- **Phases 5–7:** **Refactor in place** (same I/O, same navigation outcome). **Not** “new UI”.  
- **Phase 8:** **Contract closure**, not a feature.

---

## 2. Files / areas to remove or clean first (after baseline)

**Principle:** Nothing here deletes large hosts (`story_creator_sentences_screen`, `story_creator_provider`) until the contract in phases 1–3 is stable. **Tier 1** from spec, applied **when** safe (often phase 4).

| Priority | Item | Action | Typical phase |
|----------|------|--------|---------------|
| A | `lib/features/create/story_creator_hub_screen.dart` | **Delete** or strip exports if any test import exists — update test first. | 4 |
| A | In-app / router references to hub (should be **none** today) | Grep; remove dead `GoRoute` or comments pointing at hub. | 4 |
| A | `CreatorEntryChannel.unknown` in **production** setters | Remove assignments; each launcher sets a **named** channel. | 1 → 8 |
| B | Redundant public `*EditorScreen` if proven unused and not tests | **Tier 1–2:** remove dead `Scaffold` *class* only; **keep** `*ModuleBody` in same or split file. | 4 (after test grep) |
| C | `kCreatorProgressDrawerKey` (deprecated alias) in `creator_progress_drawer.dart` | **Tier 3:** delete alias after all imports use per-slot keys. | 7 |

**Do not delete early:** `lib/main.dart` `learn/*` **redirects** (replace with consolidated redirect, then optional cleanup — spec tier 1 or 3).

**Clean first (hygiene, low risk) — optional phase-0.5:** Remove duplicate imports / dead `debugPrint` in creator files *only* if no behavior change (ninja-style — optional).

---

## 3. Files to “rebuild” or refactor next (in practice: consolidate, not rewrite UI)

| Order | Area / file(s) | Outcome (not a UI redesign) |
|------:|------------------|----------------------------|
| 1 | `creator_back_policy.dart` + all launch call sites in `main`, `mono_screen`, `profile_screen`, `profile_navigation_drawer`, `creator_resume_draft` | Named entry context; **PUBLISHED_REOPEN**; exit table matches spec. |
| 2 | `story_creator_sentences_screen.dart` | Rely on policy only for exit; keep guards for inactive context; **keep** `CreatorRouteSyncListener` until phase 6. |
| 3 | `creator_drawer_session.dart` + `creator_route_sync*.dart` + `story_creator_sentences` drawer callbacks | One-way sync: router → session. |
| 4 | `creator_learn_mode_sync.dart` + learn toggle sites | Same product behavior, single normalization path. |
| 5 | `creator_resume_draft.dart` | Same URIs, explicit context every `push`. |
| 6 | `creator_drawer_publish.dart` + `story_creator_provider` publish | Preserve RO / FL / post-nav; no new navigators. |

**Explicitly *not* “rewrite from scratch”:** `create_story_basics_form.dart` widget tree, module **body** layouts in `*editor_screen.dart` module bodies, `CreatorProgressDrawer` look — unless a bug fix requires a surgical edit.

---

## 4. Migration order (dependencies)

```
Phase 0 (tests + script)
    ↓
Phase 1 (entry context: name all launches + PUBLISHED_REOPEN)
    ↓
Phase 2 (back policy: enforce single exit API for spec-covered paths)
    ↓
Phase 3 (session ↔ router: one reconciler, incremental)
    ↓
Phase 4 (delete hub / dead scaffolds — small PRs)
    ↓
Phase 5 (learn + resume + publish: structural only, same behavior)
    ↓
Phase 6 (merge sync helpers)
    ↓
Phase 7 (shrink legacy path strings in session)
    ↓
Phase 8 (remove `unknown` from type system + CI)
```

**Rule:** If phase 3 conflicts with a large delete, **defer** delete. **Rule:** Rebase conflicts favor **keeping** `NoTransitionPage` and path guards for shell/create transitions (lifecycle safety).

---

## 5. Regression risks

| Risk | Why | Mitigation |
|------|-----|------------|
| **Exit** goes to wrong tab (Mono vs More vs Processing) | Entry context tag missing or wrong | Phase 1 checklist; integration test for each **named** context. |
| **Panel / session** mismatch after `go` | Two writers update session | Phase 3: one post-navigation sync; avoid double `setState` from different sources in same frame. |
| **Inactive** `BuildContext` in `build` or after `go` | Inherited / `ref` read before route guard | Keep **early** path guard on sentences/basics; do not remove without replacement. |
| **Duplicate** `ValueKey` / `KeyedSubtree` | Overlap during transition | Keep per-slot drawer keys; avoid new shared `GlobalKey` on drawer. |
| **Processing list** not refreshing | Provider callbacks order | Publish/ resume flows: run existing `profile_processing_refresh` contract tests. |
| **RO / FL** publish | Validation or state machine regression | Golden-path manual + existing publish tests. |
| **Deep links** to `/create/story/learn/...` | Redirect removed or broken | Phase 7 only after deep-link test. |
| **Back** closes app or pops wrong | `PopScope` + policy drift | Android + pill back both run policy tests. |

---

## 6. Verification checklist per phase

### Phase 0 — Baseline

- [ ] Document 15–20 step **manual** script (dock create, more create, processing continue, panel switch, learn off, RO publish, FL publish, back).  
- [ ] `flutter test` on `test/creator_*.dart` — all green.  
- [ ] Screenshot or note **current** shell/create transitions (for visual regression: “looks same”).

### Phase 1 — Entry context

- [ ] Every `push`/`opener` to `/create` and `/create/story/...` from **outside** the flow sets a **named** context (add **PUBLISHED_REOPEN** for published path when implemented).  
- [ ] **Release** build: grep **no** `.state = …unknown` (or equivalent) in production `lib/`.  
- [ ] Re-run manual script: exit from sentences lands **expected** destination per context.  

### Phase 2 — Back policy

- [ ] Grep: no new `go('/mono')` / `go('/more')` in `story_creator_*` except in `creator_back_policy` (or listed exceptions in one comment block).  
- [ ] Android back + header back: drawer intercepts first; then panel strip; then exit.  

### Phase 3 — Authority

- [ ] After `go` to S1–S4, session’s active module / step matches `panel=`.  
- [ ] Fuzz: rapid `panel` switches — no assert in debug.  

### Phase 4 — Remove dead

- [ ] Grep: `StoryCreatorHub` — 0 references (or only deprecated shim).  
- [ ] `flutter test` + manual script.  

### Phase 5 — Learn / resume / publish (structural)

- [ ] Same `StoryPublishState` outcomes for RO/FL as before.  
- [ ] Resume: same **target** URIs for same `resume` meta (compare logs or test fixtures).  

### Phase 6 — Sync merge

- [ ] Single sync entry used by listener and post-`go` code paths.  
- [ ] No new post-frame **double** sync for same `sig` (regression on duplicate work).  

### Phase 7 — Legacy path shrink

- [ ] Device: **legacy** deep link URL in spec still lands correct `?panel=`.  
- [ ] `creator_drawer_session` unit tests updated.  

### Phase 8 — Final contract

- [ ] Enum: **no** `unknown` (or private sentinel only in test).  
- [ ] Optional: CI **grep** / `dart analyze` custom lint.  
- [ ] Sign-off: product accepts exit matrix.  

---

## 7. What should **not** be changed during the rebuild (unless unblocking a P0)

- **Widget layout / design tokens** of Story Basics, Story Sentences main, floating header, **progress drawer** list structure (spacing can be fixed for bugs, not redesign).  
- **Copy** strings in **UX** (button labels, snackbars) except typo fixes.  
- **Backend** DTOs, `remote_*` repository **contracts** — this plan is in-app only.  
- **Mono/Profile** **shell** `IndexedStack` model — do not “fix” with broad shell refactors.  
- **`ui/create`** one-short widgets used by **add mono** — **out of** creator flow scope; don’t merge into `features/create` in this program.  
- **Random** `refactor` of `story_creator_provider` **persistence** semantics — only **move** code to match spec, not new save rules.  
- **NoTransitionPage** for create/shell **exit** (lifecycle): do not remove to “add animation” in the same program.

---

## 8. PR sizing recommendation

- **Small** PRs: one phase or one tier-1 delete per PR where possible.  
- **Feature flag:** Not required if behavior is provably identical; if behavior risk, use short-lived internal flag for **new** sync path only (not for UI).  

---

## 9. Document map

| Doc | Use |
|-----|-----|
| [NIMON_INSERT_FLOW_V1_LOCKED_SPEC](NIMON_INSERT_FLOW_V1_LOCKED_SPEC.md) | Contract, tiers, `UNKNOWN` zero, tables. |
| [NIMON_CREATE_V1_LOCKED_DECISIONS](NIMON_CREATE_V1_LOCKED_DECISIONS.md) | `?panel=` only, one back policy, entry context. |
| [NIMON_INSERT_FLOW_FULL_AUDIT](NIMON_INSERT_FLOW_FULL_AUDIT.md) | File inventory, duplicate authority list. |
| *This file* | **Order of operations** and verification. |

---

*End of execution plan. Update this file when a phase is completed or scope changes.*
