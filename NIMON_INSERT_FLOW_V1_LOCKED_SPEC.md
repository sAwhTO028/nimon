# Nimon Insert / Create flow — V1 locked specification (rebuild contract)

**Document type:** Normative spec for a future rebuild.  
**Not included:** Code changes, UI redesign, backend changes (this file only).

**Prerequisites:** Business rules for copy, exact validation thresholds, and API payloads remain as today unless listed here. This spec defines **flow, authority, and behavioral contracts**.

**Locked product constraints (V1):**

- UI/UX **appearance and interaction patterns** stay the same; this spec refactors **logic and data flow** under the hood.  
- Deterministic behavior: same user intent + same starting data → same route + same exit + same side effects.  
- **One** back policy, **one** route/session authority model, **one** learn-module addressing scheme (`?panel=`).  
- **Core screens:** Story Basics and Story Sentences; Learn is **direct module editors** on the sentences host, **not** a separate “Learn modules” landing.  
- **Read Only**, **update Read Only** (core changes after RO publish), and **Full Learn** product semantics are **preserved** (see publish table).  
- **Processing / Continue / Resume** must restore the correct draft + module + learn mode.  
- Dead prototype branches are **out of** the v1 product surface (see section H).  
- **Final V1 target: zero `UNKNOWN` entry context** — every external launch into create sets a **named** context (ADD, SHELL_MORE, PROCESSING, PUBLISHED_REOPEN, or a defined extension). The `unknown` / `UNKNOWN` value may exist only during a **staged** migration; it must be **unreachable in release** and **asserted in tests** before V1 is signed off.  

---  

## Rebuild plan: what to do with old surfaces (three tiers)

Use this for sequencing work. Items are **normative for the plan**; exact file names may be adjusted in implementation with the same intent.

| Tier | Meaning | Exit criteria |
|------|---------|---------------|
| **1. Remove immediately** | Delete or strip from the nav graph in the first merge that lands the new flow. No quarantine, no “maybe later” if safe. | Search shows **no** `import` to dead screens; router has **no** `GoRoute` to removed pages; no references in tests (update tests first or same PR). |
| **2. Keep temporarily but unreachable** | File or class may **remain in the tree** (or behind `@Deprecated`) for one release **only** if: it is not linked from the router, not importable from production `main`, and is tagged with a `TODO(v1-creator-cleanup): remove by YYYY-MM` comment. | Removed in a follow-up within the same major release, or the tier is **bumped** to tier 1 in the same rebuild PR if it causes confusion. |
| **3. Verify and delete later** | Compatibility code (redirects, idempotent sync), duplicate helpers, or `grep`-ambiguous paths that need a **test pass** (device, deep link, back stack) before delete. | Owner records verification (manual or automated) in issue/ADR; then delete. |

**Examples (current codebase — illustrative):**

| Item | Suggested tier | Notes |
|------|----------------|--------|
| User-visible **Learn modules hub** as a `Page` / destination | **1. Remove immediately** | Already not in product; ensure **no** route *builds* a hub. |
| **`StoryCreatorHubScreen` widget** (unused in `main.dart`) | **1** (preferred) or **2** if tests reference it; then delete after test update. | Zero nav references. |
| `GoRoute` child routes under `learn/…` that only **redirect** to `?panel=` | **1** (keep *redirect* logic, collapse to one `redirect` callback if desired) or **2** (keep redirects, delete redundant `builder: SizedBox.shrink` *routes* in favor of parent redirect only) — *implementation choice*. | Product URL remains canonical. |
| `*EditorScreen` **Scaffold** classes in same file as `*ModuleBody` (not registered in `main.dart`) | **1** (delete dead `Scaffold` if truly unused) or **2** (keep unexported) until `verify` that no test/deeplink references them. | **3** if any external team depends on a symbol name. |
| `CreatorEntryChannel.unknown` | **1** in final V1: **remove** from the enum (or use compile-time `sealed` exhaustiveness) **after** all call sites are tagged. **During** migration, **2** in spirit: not set on any new path. | **Final: zero** unknown usage. |
| Legacy `creator_drawer_session` path branches for `/create/story/learn/...` **strings** | **3. Verify and delete** after e2e proves only `?panel=` and redirects hit production. | Reduces session complexity. |
| `syncCreatorDrawerSessionFromContext` vs `syncCreator…ForRouter` duality | **3** | Merge to one after verification. |
| Deprecation comment `kCreatorProgressDrawerKey` (alias) | **3** | After swap all references. |

---  

## A. Creator states (V1)

States are **abstractions** for the contract; the implementation may map them to a single host widget with sub-state.

| ID | State name | Canonical location (when applicable) | Notes |
|----|------------|----------------------------------------|--------|
| **C0** | **Create root** | `/create` | Add-tab hub and/or `CreateScreen` (e.g. edit-basics from review). |
| **B1** | **Story basics** | `/create/story/basics?draftId=…` | User edits title, level, description, etc. |
| **S0** | **Sentences — storytelling (main)** | `/create/story/sentences?draftId=…` | No `panel`, or `panel` absent / not a learn module. |
| **S1** | **Sentences — vocabulary** | `…&panel=vocabulary` | Direct module editor embed. |
| **S2** | **Sentences — grammar** | `…&panel=grammar` | |
| **S3** | **Sentences — quiz** | `…&panel=quiz` | |
| **S4** | **Sentences — listening** | `…&panel=listening` | |
| **D\*** | **Progress drawer (overlay)** | Same route as S\* | Modal overlay; not a separate route. **D open** is orthogonal to S0–S4 (can attach to any). |
| **L** | **Draft load pending** | Same as target route | Mismatch or async load: UI may show loading until draft id aligns with provider. |

**Not states:** a standalone “Learn modules hub” page, or a separate full-screen “pick module” step between S0 and S1–S4.

**Session fields that accompany states (V1, see section I):**

- **Learn mode** (boolean): Read Only / Full Learn affordances in drawer and learn rows.  
- **Entry context** (enum, **no UNKNOWN in final V1**): set once per *session entry* from outside the in-flow stack (see C).  
- **Publish state** (on draft): `draft` | `readingOnlyPublished` | `fullLearnPublished` — affects what publish actions exist, not the state IDs above.  

---

## B. Allowed transitions (V1)

**Rule:** All learn-module moves use **`go` or `push` to the canonical URI** in section 1 of `NIMON_CREATE_V1_LOCKED_DECISIONS.md` (sentences + `?panel=`), with **`draftId`** stable for the working draft.

| From | User / system action | To | Notes |
|------|----------------------|----|--------|
| C0 | Start new (clean session) | B1 | After ephemeral draft id exists, push with `draftId` as today. |
| C0 | Continue local draft (list) | B1 or S0 or S1–S4 | Resume table (F) picks target. |
| B1 | Continue to storytelling | S0 | Push or replace per stack rules; `draftId` in query. |
| S0 | Open a learn module (drawer, chip, or deep link) | S1–S4 | `go` / `push` to same path + `&panel=`. **No** hub. |
| S1–S4 | Back (policy) to main story surface | S0 | Strip `panel` from URI; session step = storytelling. |
| S0 or S1–S4 | Toggle **learn mode** OFF while “on” a learn surface | S0 + normalized session | If URL or panel implies a learn module but mode is off, **normalize to storytelling** (one authority updates URI + session). |
| S0 or S1–S4 | Open/close **drawer** | D open / D closed | Does not change B1/S\* unless a navigation is triggered. |
| Any in `/create/…` | **Exit** creator (back policy, dock) | Shell: `/mono`, `/more`, or `/more?tab=processing` | `go` replaces create stack; entry context drives target (section D). |
| Deep link: legacy `/create/story/learn/…` | System | S0 or S1–S4 | **Redirect only** to sentences + `draftId` + `panel=`. No user-visible hub. |

**Forbidden in v1 product:** transitions to a **standalone** Learn modules catalog page; transitions that leave **two** “authoritative” module indicators (e.g. conflicting `panel` and session) without a single reconciler.

---

## C. Entry contexts (V1)

Every time the app **opens** a create path from the **rest of the app** (not an in-flow `pop` between basics and sentences), the runtime must set **exactly one** of the **named** contexts below.  

**V1 sign-off condition:** In release (and in CI for creator integration tests), **no path** may set or default to an **UNKNOWN** / `unknown` entry context. If the runtime cannot determine context, the implementation must **fix the launch site** (add tagging) or **treat it as a bug** — not ship a silent default.

| Context | User meaning | Back / exit default (from sentences main S0; after closing drawer) |
|---------|----------------|---------------------------------------------------------------------|
| **ADD** | “New story” or primary create from **Mono shell** (dock). | `go('/mono')` (or product-defined add home). |
| **SHELL\_MORE** | Create opened while user’s shell anchor is **More/Profile** tab (e.g. empty state “Start new story”, nav drawer to creator). | `go('/more')` |
| **PROCESSING** | **Continue** from a row in **Profile > Processing** (incl. primary CTA on draft card). | `go('/more?tab=processing')` |
| **PUBLISHED\_REOPEN** | Opened from **Published** (or post-publish) to edit, update Read Only, or move toward Full Learn per rules. | `go` to **Published** tab (or `more` + published) with optional **highlight** draft id — same **contract** as current `ProfileNavigation.openPublishedTab*`. |

**Staged migration (optional, time-limited):** A **temporary** `UNKNOWN` may exist only in non-release builds or behind an **assert** that never fires in tests; the **rebuild is not complete** until the enum and analytics contain **no** “unknown” branch in production.  

**Refinement (implementation):** May map 1:1 to `CreatorEntryChannel` (with `PUBLISHED_REOPEN` and **no** `unknown`) or a renamed sealed type; the **product table above** is the **contract**.

---

## D. Back behavior (by state) — V1

All rows below are implemented **only** through the **single back policy** (see [NIMON_CREATE_V1_LOCKED_DECISIONS.md](NIMON_CREATE_V1_LOCKED_DECISIONS.md) §3).

| User location | Android / system back & equivalent in-app back | Order of handling |
|---------------|-----------------------------------------------|-------------------|
| **D** drawer open (any S\*) | First: **close drawer** only; do not exit create. | 1) Close animation 2) Future back uses row below. |
| **S1–S4** (learn `panel=`) | **Normalize** to **S0**: remove `panel`, set workspace step to storytelling, sync via one pipeline. | After normalize, same as S0. |
| **S0** (no learn panel) | **Exit** create: `go` to target from **entry context** (section C), not a blind `pop` of arbitrary depth. | Replaces full-screen create stack. |
| **B1** (basics) | V1: **in-flow** back = leave basics toward previous **in-stack** (e.g. C0) via agreed mechanism (`pop` is OK for inner stack); **exiting** entirely still uses same **entry context** as if leaving from S0 (policy or shared helper). *Spec: no second “exit to mono” that bypasses entry context.* |
| **C0** (create root) | Close/exit: same **entry context** mapping as S0 when leaving create entirely (`performExitFromCreateRoot` class). | |
| **L** (draft id loading) | **Pop** or minimal exit if the only sensible action is to dismiss the route (loading scaffold); if policy cannot know draft, **do not** run heavy subtree. | |

**Non-goals for back policy:** it does **not** own **inline** `Navigator.pop` of dialogs/sheets; those stay local. It **does** own **create-flow exit** and **learn surface normalization**.

### Back policy table (summary)

| Step condition | Result |
|----------------|--------|
| Drawer not fully dismissed | Close drawer, stop. |
| Path = sentences + `panel` in learn set | `go` to `…/sentences?draftId=` (no `panel=`), set storytelling step, post-frame **session sync** once. |
| Path = sentences + no learn panel | `go` exit from **named** entry context (C) — no UNKNOWN. |
| Create root close | `go` exit from **named** entry context (C). |
| Path not sentences (edge) | `canPop` → `pop` only as escape hatch. |

---

## E. Learn mode ON / OFF (V1)

**Learn mode** (boolean) controls whether Learn **module work** is allowed and how the **drawer** presents **Read Only** vs **Full Learn** publish actions. It is **not** a separate route.

| Mode | User-visible intent | Routing |
|------|----------------------|---------|
| **ON** | Full Learn path: user can use vocabulary/grammar/quiz/listening **editors** and (when ready) **Full Learn** publish. | Navigating to S1–S4 is **allowed** via `?panel=`. |
| **OFF** | Read Only–oriented: focus on **story**; if the user is still on a learn **URL** (panel) or **session** says “on learn surface”, V1 must **reconcile** to **S0** (no `panel=`) and storytelling step, without leaving the draft. | **Single authority** applies: turning OFF triggers **one** `go` + session update (same as today’s `applyCreatorLearnMode` *intent*). |

**Invariants**

- Toggling learn mode does **not** add a new “intermediate” page.  
- With mode OFF, the user must not “stick” on a learn panel route without normalization.

---

## F. Continue / resume (V1)

| Entry | Preconditions | Result |
|------|----------------|--------|
| **Processing → Continue** (row primary) | Draft exists locally (or rehydration path); `publishState` may vary. | Load draft by id; set **entry context = PROCESSING**; `push` to **resolved target URI** (basics, S0, or S1–S4 from **resume metadata** + learn mode + publish rules). |
| **Resume** (generic, e.g. draft list **Continue** in sheet) | Same | Set **SHELL\_MORE** or **ADD**-equivalent per launch site; `push` to **resolved target** from `resume` meta. |
| **Add tab → new** | New ephemeral draft | B1, then S0 as today. |
| **Deep link** to legacy learn path | — | **Redirect** to S0 or S1–S4; never show hub. |

**Resume target resolution (behavioral, not reimplemented here):**  
- Honor **last active module** in storage (e.g. storytelling vs vocabulary vs …) when **learn mode ON**; when **learn mode OFF** and last module was a learn module, V1 may send user to **S0** or **basics** per existing product rules (e.g. RO + learn off in current code) — **preserve** current semantics until product revises them.

**Invariant:** Resume always sets **entry context** before `push` so back from S0 is correct.

---

## G. Publish / update (V1)

| Action | When available (high level) | Post-success navigation (V1) |
|--------|--------------------------------|--------------------------------|
| **Read Only publish** | **Learn mode OFF**; draft meets RO validation; not already in a disallowed state. | Navigate to **Published** (or **Processing** for continuity per current product) + snackbar; **no** ad-hoc duplicate navigators. **Preserve** `ProfileNavigation.openPublishedTab*`-class behavior. |
| **Update Read Only** (core changed after RO) | `readingOnlyPublished` and signature mismatch / dirty per rules. | Re-publish or save path per existing rules; **no** new hub. |
| **Full Learn publish** | **Learn mode ON**; draft meets full-learn gates. | Post-success flow **preserves** current behavior (tab highlight, etc.). |

**StoryPublishState (domain, unchanged names):** `draft` → `readingOnlyPublished` → `fullLearnPublished` (forward-only in normal product progression; exceptions stay as today).

**Invariant:** A single **drawer** publish entry point in UI → one **orchestrated** publish function that captures sync dependencies **before** async work and does **not** use stale `BuildContext` after `go` away from create.

---

## H. Routes / pages that must not exist in the v1 creator *product* flow

These must **not** be user-reachable as first-class surfaces (redirect or delete dead code in implementation).

| Item | v1 contract |
|------|----------------|
| **Standalone “Learn modules” hub** under `create` | **Removed**; any URL normalizes to **S0** or **S1–S4** only. |
| **`/create/story` as a standalone hub** | **Removed**; redirect to `/create` (or `basics`) as today. |
| **`StoryCreatorHubScreen` (or equivalent)** | **Not** in the nav graph for v1. |
| **Full-screen `*EditorScreen` routes** that duplicate embeds | **Not** in v1; only **ModuleBody**-style content **inside** sentences, unless product later adds a deliberate second surface (out of v1). |
| **Parallel “learn route” and `?panel` authority** | **Not allowed**; router query is canonical (section I). |

---

## I. Ownership: draft notifier vs session vs router

| Concern | Owner of record (V1) | What others may do |
|---------|------------------------|--------------------|
| **Authoritative story data** (text, module payloads, publish flags, `StoryPublishState`) | **Draft notifier** (+ repository persistence) | Session **reads** to drive UI; router **must not** be the only place draft text lives. |
| **“Where in the product UI am I” for creator** (active module, learn mode, visited learn modules, **matched** path for drawer UI) | **Creator session** (`CreatorDrawerSession`-class state) | **Derived** from router + user actions, then **written** in one place after transitions settle. |
| **Canonical “which screen in the app” (deep link, OS back, tab restore)** | **GoRouter** location: **`/create/...` with `?panel=` and `?draftId=`** | Session **reconciled** to match; **if conflict**, a **single** reconciler runs (e.g. post-frame sync from router → session, not the reverse in multiple ad-hoc places). |

**Single authority (contract):**  
**The router URI** for the sentences host is the **source of truth for which module panel is active** (`vocabulary` | `grammar` | `quiz` | `listening` | *none*). The **session** stores **redundant** but **reconcilable** state (step, `learnMode`, active module) that **must** converge after every navigation. **No** long-lived “panel” that exists only in session and not in the URI in v1.

**Draft id:** Always carried in query for story routes when a draft is bound, except ephemeral pre-id edge cases that are still resolved to a concrete id before S0 is stable (implementation detail).

---

## 1. State machine table (compact)

|  | C0 | B1 | S0 | S1–S4 | Exit |
|--|----|----|----|--------|------|
| **C0** | — | ① | — | — | ② to shell |
| **B1** | ③ | — | ④ to S0 | — | ② |
| **S0** | — | ⑤ | — | ⑥ to S1–S4 | ② |
| **S1–S4** | — | — | ⑦ back policy | ⑧ between panels | ② (after ⑦ to S0 if user exits from panel first) |

① Start new / open basics ② Exit via back policy (entry context)  
③ Back from B1 in stack ④ Continue to sentences ⑤ Return to basics in stack (optional)  
⑥ `go`+`panel` ⑦ Normalize to S0 ⑧ `go` change `panel`

---

## 2. Back policy table (condensed)

*(See section D; implementation is one module.)*

| From | First handler | Then |
|------|---------------|------|
| Drawer open | Close | — |
| S1–S4 | `go` strip panel → S0 | If user backs again, exit |
| S0 | `go` by entry context | — |
| C0 | `go` by entry context | — |
| B1 | In-stack: pop; **full exit** uses entry context | — |

---

## 3. Continue / resume table

| Source | Entry context | Target resolution |
|--------|--------------|-------------------|
| Processing row Continue | `PROCESSING` | Meta + `publishState` + `learnMode` → B1, S0, or S* |
| Generic resume (list/sheet) | `SHELL_MORE` or per launch | Same |
| New story (dock) | `ADD` | C0 → B1 |
| Published reopen | `PUBLISHED_REOPEN` | Editor entry per rules; draft loaded |

---

## 4. Learn mode table

|  | **Learn mode ON** | **Learn mode OFF** |
|---|------------------|--------------------|
| Drawer | Full Learn + learn rows active | Read Only + learn as read-only or disabled per UX |
| Navigate to S1–S4 | **Allowed** | If landing on learn URL, **normalize to S0** (policy) when turning off or on entry |
| Publish | **Full Learn** when ready | **Read Only** when ready |

---

## 5. Publish / update table

| Publish / update | learnMode (typical) | `StoryPublishState` result | After success |
|------------------|---------------------|----------------------------|---------------|
| Read Only publish | OFF (drawer) | `readingOnlyPublished` | Open Published tab, highlight |
| Re-publish RO after core edit | OFF | Stays / updates per rules | Same class as today |
| Full Learn publish | ON | `fullLearnPublished` | Same class as today |

*(Exact gating and validation: preserve existing `creator_readiness` / provider checks unless product supersedes.)*

---

## 6. Removed routes / pages (checklist for implementation)

Classify each line as **tier 1 / 2 / 3** (see *Rebuild plan* at top).

- [ ] **(1)** Standalone Learn **hub** as a user-facing *page* — **remove immediately**; redirects only if spec requires deep-link compatibility (redirect can be **tier 1** merge, branch cleanup **tier 3**).  
- [ ] **(1)** `/create/story` *non-redirect hub* user surface — must not exist.  
- [ ] **(1–2)** `StoryCreatorHubScreen` — **remove** if unused (**1**), or make unreachable and delete in same release (**2**).  
- [ ] **(1–3)** Full-screen `*EditorScreen` **GoRoute** registrations (if any remain) — **remove immediately**; **ModuleBody** embeds **keep**; dead `Scaffold` wrappers after **verify (3)**.  
- [ ] **(1)** Any dock/shell “leave create” that uses `goBranch` only — must use `go` to leave full-screen create; already a shell rule; delete wrong calls **immediately** if reintroduced.  

---

## 7. Implementation rules (V1)

1. **No new** exit to `/mono` / `/more` from creator screens **outside** the back policy and shared exit helper.  
2. **Set a named entry context** on every **external** entry to `/create/...` (section C) — **never** `UNKNOWN` in the **final** build; add launch-site tags until the enum has **no** unknown branch.  
3. **One** reconciliation path from **router** → **session** after `go`/`push` (no duplicate `reportRoute` semantics).  
4. **`?panel=`** is the only learn **module** address; redirects normalize all legacy URLs.  
5. **Build / lifecycle:** avoid inherited lookups on **inactive** `BuildContext` in `build`; guards apply before `ref` read in hosts (existing stabilization rule).  
6. **Tests:** for each row in the **back policy** and **resume** table, at least one automated test; **assert** no `UNKNOWN` entry context in creator integration test harnesses.  
7. **Dead code & prototypes:** use **tier 1** by default; **tier 2** only with a dated TODO; **tier 3** with an owner and verification log.  
8. **CI (recommended):** fail build if `unknown` is assigned to `CreatorEntryChannel` / equivalent outside test-only fakes, once migration is done.  

---

*This document is the rebuild contract. Changes require explicit version bump and changelog.*
