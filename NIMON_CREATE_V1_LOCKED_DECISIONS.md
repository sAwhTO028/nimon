# Nimon Creator V1 — locked product / navigation decisions

**Status:** **LOCKED for V1** (change only for a very strong technical reason, documented in ADR or this file).  
**Scope:** Insert / Create flow, Learn embeds, back navigation, entry context.

---

## 1. Learn module routing (single model)

**Lock:** The **only** supported way to address Learn module UIs in the V1 story creator is:

`/create/story/sentences?draftId=…&panel=…`  
with `panel` in `{ vocabulary, grammar, quiz, listening }` as product-defined.

- No first-class child routes for “full-page” learn editors in the v1 product flow. Any legacy or deep-link paths (e.g. under `/create/story/learn/…`) may exist only as **redirects** to the canonical `?panel=` form.

**Rationale:** One URL shape → one place to sync session, drawer, and back policy.

---

## 2. Standalone Learn Modules hub (removed)

**Lock:** There is **no** standalone “Learn modules” hub page inside the creator flow. It does not appear in navigation, drawer highlight as a destination, or first-class product entry.

- Redirects that strip the old hub URL are **compatibility** only, not a supported surface.

**Rationale:** Avoid split mental models (hub vs sentences host).

---

## 3. Back behavior (single policy)

**Lock:** All creator back decisions that **leave** the Story sentences host or **normalize** learn panels must go through **one** policy API (V1: `lib/features/create/creator_back_policy.dart` — e.g. `performCreatorBackFromSentencesHost`, `performExitFromCreateRoot`, draft-loading helper).

- No new ad-hoc `context.go('/mono')` / `context.pop()` for those outcomes from feature screens without extending the same policy.

**Rationale:** Deterministic exit targets, fewer inactive-element / duplicate-key windows, testable behavior.

---

## 4. Entry context (explicit)

**Lock:** Every time the app **enters** a create session from outside the in-flow wizard, the app must set an **explicit entry context** so back / exit can target the correct parent (shell Mono, More, Processing, published surface, etc.).

**Required V1 context categories (product names → intent):**

| Context | Intent |
|--------|--------|
| **Add (create entry)** | User opened Create from the shell / primary “add” path (e.g. dock) — not from Processing list rows. |
| **Processing** | User continued a draft from **Profile > Processing** (incl. primary Continue on a row). |
| **Published reopen** | User opened a published / read-only story to edit or follow up from a **published** or post-publish surface. |
| **Shell** | User is under the main app shell (`/mono` / `/more` branches) as the **launch host**; subtype may be Mono vs More. |

**Final V1 target (rebuild sign-off):** **Zero** `unknown` / `UNKNOWN` entry-context usage in production. Every external launch into create must set a **named** context (Add, Shell/More, Processing, Published reopen, or their implementation enum equivalents). A temporary `unknown` is allowed **only** during a bounded migration, after which the enum value is **removed** and CI may forbid assignments.

**Implementation note:** The codebase may currently use `CreatorEntryChannel` including `unknown`. The rebuild must add **`publishedReopen`** (or map **Published reopen** to an existing value) and **delete** `unknown` from the public contract once all launchers are instrumented. See [NIMON_INSERT_FLOW_V1_LOCKED_SPEC.md](NIMON_INSERT_FLOW_V1_LOCKED_SPEC.md) (*Rebuild plan: three tiers*, section C, §7).

**Rationale:** Replaces implicit stack behavior with a contract that the back policy can implement without guessing from `GoRouter` depth alone.

---

## Cross-check (non-normative)

- **Locked decisions 1–2** are reflected in `main.dart` (redirects to `?panel=`; learn hub not a product page).
- **Locked decision 3** is centered on `creator_back_policy.dart` + sentence/create hub call sites; further work should **remove** stragglers, not add parallel exits.
- **Locked decision 4** requires **complete** tagging for Add / Processing / Published reopen / Shell — track remaining `unknown` as tech debt if any path still omits a tag.

---

*Amend this file only with team agreement and a short “why we broke the lock” note.*
