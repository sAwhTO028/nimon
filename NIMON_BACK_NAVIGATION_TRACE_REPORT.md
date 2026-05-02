# Nimon creator-flow back navigation trace report

**Scope:** Diagnosis-only mapping of how “back” is wired for the story creator flow (Android system back, in-app controls, dock, resume-from-Processing).  
**Out of scope:** UI redesign, backend, broad refactors.

---

## 1. Router / shell shape (what owns the stack)

Nimon’s root `GoRouter` (`lib/main.dart`) registers **sibling** top-level routes:

| Route family | Role |
|--------------|------|
| `/create` | Full-screen create hub (`StoryCreatorAddTabScreen` or `CreateScreen`) — **outside** `StatefulShellRoute` (no bottom dock). |
| `/create/story/basics`, `/create/story/sentences`, … | Full-screen story creator steps — also **outside** the shell. |
| `StatefulShellRoute.indexedStack` | Hosts `/mono` (branch 0) and `/more` (branch 1) inside `AppShell` → **`IndexedStack` keeps both branch subtrees alive**, but only one branch is “active” for `goBranch`. |
| Many other top-level routes | `/learn/...`, `/settings`, etc. |

**Important:** Entering create uses **`context.push(...)`** from the shell (or from Profile), which **stacks** a full-screen GoRouter page **above** the shell’s current location.  
**Leaving create to Mono** for the dock path uses **`GoRouter.go('/mono')`**, which **replaces** the current configuration’s location for that navigation — it is **not** a `pop` of the create page in that code path (see `AppShell` and floating header below).

---

## 2. All back-related entry points (creator + immediate parents)

### 2.1 Android / system back (predictive back–aware `PopScope`)

| Location | `canPop` | On back |
|----------|----------|---------|
| `StoryCreatorSentencesScreen` (`story_creator_sentences_screen.dart`) | `_progressDrawerController.isDismissed` | If progress **drawer is open** → `canPop: false`; `onPopInvokedWithResult` runs → `_closeProgressDrawer()` (drawer consumes back). If drawer **closed** → `canPop: true` → **default route pop** proceeds (`didPop: true`). |
| `StoryCreatorBasicsScreen` (`story_creator_basics_screen.dart`) | `false` (always intercept) | Always `onPopInvokedWithResult` → `_attemptExit()` (save / dialog / `context.pop()`). |
| `MonoScreen` (reader variant) (`mono_screen.dart`) | `!panelOpen` | If story options panel open, back closes panel instead of popping. |

**First receiver of the system back event:** Flutter’s **modal route** for the **topmost** `Page` in the root navigator. The nearest `PopScope` in that route’s subtree participates in `canPop` / `onPopInvokedWithResult`. For the sentences screen, the **owning** `PopScope` is the one wrapping the `Scaffold` (around the progress drawer), not the shell.

**No** custom `GoRouter` `backButton` override in `main.dart` — behavior is **Navigator + `PopScope` + GoRouter’s page stack**.

### 2.2 App bar / leading

| Screen | Control | Handler |
|--------|---------|---------|
| `StoryCreatorBasicsScreen` | `NimonBackButton` | `unawaited(_attemptExit())` — same as system back semantically. |
| `StoryCreatorBasicsScreen` (loading wrong draft) | `NimonBackButton` | `context.pop()` only. |
| `CreateScreen` | `NimonBackButton` (close icon) / review mode | `context.pop()`. |
| `StoryCreatorAddTabScreen` | `NimonBackButton` | `context.pop()`. |
| `StoryCreatorSentencesScreen` (draft id mismatch loading) | `NimonBackButton` | `context.pop()`. |
| Embedded module editors (vocab / grammar / quiz / audio) | `NimonBackButton` | `context.pop()` and/or `Navigator.maybePop` for **drawer** + `context.push` to module routes (see file). |

**`NimonBackButton`** (`nimon_circle_nav_button.dart`): if `onPressed` is set, it calls that; else `Navigator.of(context).maybePop()`. So explicit creator screens always use **`context.pop()`** (go_router) when a callback is provided.

### 2.3 “Home” / exit to Mono (not `pop`)

| Control | Code | Navigation API |
|---------|------|----------------|
| `StoryCreatorSentencesScreen` — `_FloatingPillHeader` back pill | `onTapBack` | **`context.go('/mono')`** — **replace-style** navigation to the shell’s Mono branch. |

This is **not** `Navigator.pop`. It is the same **class of exit** as `AppShell` dock Mono while `onCreateStack` is true: `go.go('/mono')` (`main.dart` `onDockTap` case 0).

### 2.4 Dock (Mono / Create / More)

`AppShell._` (`main.dart`):

- If current path is under **`/create`**, tapping Mono or More uses **`go.go('/mono')` / `go.go('/more')`** so the full-screen create stack is **left** (comment in code: `goBranch` only switches `IndexedStack` and does not pop `/create/...`).

### 2.5 Processing → Continue (Profile)

`ProfileScreen` processing row (`profile_screen.dart` ~3192):  
`CreatorDraftResumeFlow.resumeFromProcessing(context, draftId, publishState: ...)` (`creator_resume_draft.dart`).

- After `loadDraftById` and `_targetUri`, navigation is always **`context.push(target)`** where `target` is a **`/create/story/...`** URI (with optional `panel=` when learn mode and resume meta say so).
- So **Continue does not use back**; it **pushes** create on top of the current location (typically `/more`).

Existing traces: `[NIMON_TRACE] CreatorDraftResumeFlow...` (already in file).

### 2.6 Learn mode toggle (not “back”, but re-routes)

`applyCreatorLearnMode` (`creator_learn_mode_sync.dart`):

- Turning **learn off** while URL/session still imply a Learn panel: sets session step, then **`context.go('/create/story/sentences?...')`** to return embedded UI to Storytelling.
- Schedules `syncCreatorDrawerSessionForRouter` post-frame.

### 2.7 `CreatorRouteSyncListener`

`creator_route_sync_listener.dart`: subscribes to `GoRouter.routerDelegate` and calls `syncCreatorDrawerSessionForRouter` on any route change. This is **not** a back handler; it runs **after** `go` / `pop` / `push` updates the router.

---

## 3. Focus questions — answers

### 3.1 Which widget/layer first receives the back event?

The **active route’s** modal route. In practice: the **top** `Page` in GoRouter’s stack (e.g. `/create/story/sentences`). The innermost relevant **`PopScope`** in that page’s tree (sentences: around `Scaffold`; basics: `canPop: false`).

### 3.2 What code path handles it?

- **Sentences + drawer open:** `PopScope` with `canPop: false` → `onPopInvokedWithResult` → `_closeProgressDrawer()`.
- **Sentences + drawer closed:** `canPop: true` → **Navigator/GoRouter pops** one page → `onPopInvokedWithResult` with `didPop: true` (see new `[NIMON_BACK_TRACE]` log).
- **Basics:** always `_attemptExit()` (may `context.pop()` after save/dialog).
- **Floating pill “back”:** **not** the system back path — direct **`context.go('/mono')`**.

### 3.3 `Navigator.pop` / `maybePop` / `context.pop` / `context.go` / shell?

| Scenario | API |
|----------|-----|
| Exit create to Mono (pill or dock while on create) | **`context.go('/mono')`** |
| Android back from sentences (drawer closed) | **Route `pop`** (via `canPop: true` → go_router removes top page) |
| Basics / Create hub / add tab back | **`context.pop()`** or `_attemptExit` → `pop` |
| Learn mode off, on Learn surface | **`context.go(.../sentences...)`** |
| Processing Continue | **`context.push(...)`** |
| Module editors | Mix of **`maybePop`** (close overlay/drawer), **`context.push`**, **`context.pop`** on sub-routes |

### 3.4 What conditions decide whether back is allowed?

- **Sentences:** progress drawer must be **fully dismissed** for `canPop: true`. Otherwise back is **stolen** to close the drawer.
- **Basics:** `canPop: false` — every back goes through `_attemptExit()` (dirty checks, persist, dialog).
- **Mono reader:** panel must be closed for `canPop: true` (separate from creator).

### 3.5 Route stack before / after back (typical)

**Example A — User: `/more` → Processing → Continue → `push` `/create/story/sentences?...`**

- Before: stack includes … `/more` … then pushed creator page(s).
- After **Android back** (drawer closed): **one `pop`** → usually returns toward **`/more`**, not necessarily `/mono`, unless intermediate pops empty the stack that way.

**Example B — User: Mono dock → `push` `/create` → … → sentences; then floating pill back**

- Before: location was `/create/story/sentences?...`.
- After: **`go('/mono')`** — shell shows Mono; create routes are **dropped** from the match (not “one pop” — full location replace to `/mono`).

**Example C — Dock Mono while on create**

- Same as B: **`go('/mono')`**, not `goBranch(0)` (when `onCreateStack`).

### 3.6 `PopScope` / `WillPopScope` / custom leading / listener / shell?

- **Yes** `PopScope`: sentences, basics, mono reader options.
- **Shell** does not wrap creator; creator is **sibling** full-screen routes. **`IndexedStack` only applies inside** `StatefulShellRoute` when the active location is **under that shell** (e.g. `/mono`, `/more`). When you are on `/create/...`, you are **not** inside the shell’s body for that top-level page.

### 3.7 Why can `StoryCreatorSentencesScreen` still `build` after the route became `/mono`?

Not a second “logical” route; it is **widget lifecycle ordering**:

1. `context.go('/mono')` updates **GoRouter state** immediately (location string is already `/mono` — your logs show `syncCreatorDrawerSessionForRouter SKIP ... uri=/mono`).
2. The **previous** `Page`’s subtree (sentences) can still be **mounted for part of a frame** while the navigator swaps / finalizes the outgoing `Page` (and any **no-transition** or overlap window).
3. In that window, `StoryCreatorSentencesScreen.build` can run **once** on an **inactive** `Element` if the widget is still in the tree — hence the need for an **early path guard** (`GoRouter.maybeOf` + prefix `/create/story`) and avoiding **inherited / `ref` work before the guard**.

`CreatorRouteSyncListener` correctly **skips** session sync for `/mono`, but it **does not** prevent the last `build` of a deactivating subtree.

---

## 4. Repro-path back chain (requested: Processing → Continue, Learn ON, back, crash)

**Concrete chain in code (not generic Flutter):**

1. **User taps Continue** on a Processing row → `CreatorDraftResumeFlow.resumeFromProcessing` → `context.push('/create/story/sentences?draftId=…&panel=…')` (if learn mode + meta point at a Learn module the URL includes `panel=`; with learn on, RO published path may still `push` a resolved `target` from `_targetUri`).
2. **Learn mode ON** — embedded Learn UI inside sentences host; session + URL `panel` align (see `creator_learn_mode_sync` / drawer).
3. **User presses Android back** (assuming progress drawer is closed) → `PopScope` on sentences has **`canPop: true`** → **GoRouter/Navigator pops one page** — *not* `go('/mono)`* — destination depends on what was pushed (often back toward **`/more`**, or an earlier create step if you had pushed multiple).
4. **Crash** (if still observed) lines up with **transition overlap** (outgoing creator page + incoming route) and/or **duplicate `GlobalKey`** in shared chrome (e.g. progress drawer keys) during that **brief** co-existence — **not** because `go('/mono` failed to run.

**Causal template (for pill/dock exit to Mono, which matches your `/mono` logs):**

> User exits creator → **`context.go('/mono')`** (`_FloatingPillHeader.onTapBack` or `AppShell` dock) → **GoRouter location becomes `/mono`** while **sentences `Page` is still tearing down** → **`StoryCreatorSentencesScreen.build` runs one last time** (possibly inactive) → if heavy subtree / keys still run here → **`inactive` assert / duplicate `GlobalKey`**.

**If the repro uses Android back after Continue** (not the pill), the “after” route is a **`pop`**, not **`go('/mono)`** — stack differs from the pill/dock case; use `[NIMON_BACK_TRACE] PopScope` to see `didPop=true` and the URI at invoke time.

---

## 5. Is current back behavior “correct” or structurally odd?

- **Structurally split semantics:**
  - **In-app “leave to Mono”** (pill, dock) → **`go('/mono')`** (replace location).
  - **Android back** (sentences, drawer closed) → **`pop`** (LIFO of pushed routes).
- That split is **valid** if product intent is: “system back = undo navigation within the session”, while “pill/dock = exit to home feed”. It **does** mean **different** stacks/destinations from the same screen depending on **which** “back” the user uses.
- **IndexedStack** is a **red herring for `/create`**: while on create you are on a **different** top-level branch than the shell; overlap issues are primarily **root navigator page swap** (create full-screen vs shell), not “Mono vs Profile” keep-alive.

---

## 6. Minimal fix recommendation (aligned with prior work)

1. **Keep** early route guards in `build` for creator hosts (path must still be under `/create/story` before `ref` / heavy children).
2. **Keep** `NoTransitionPage` on create + shell `/mono` / `/more` to **shorten** page overlap on exit (already in `main.dart`).
3. **Keep** per-slot drawer `GlobalKey`s so two hosts never share one key in an overlap frame.
4. **Optional (product, not required for stability):** unify “exit creator to Mono” and “Android back from sentences” if you want identical destinations — e.g. `PopScope` custom handler calling `go('/mono')` when stack depth = 1 — **would** change UX vs standard back stack; treat as a deliberate product decision.

---

## 7. `/mono` transition: pop or replace?

| Mechanism | Mechanism |
|----------|------------|
| **Floating pill back, dock Mono while on create** | **`GoRouter.go('/mono')`** — **replace**-style (new matched location; create routes no longer top). |
| **Android back from sentences (drawer closed)** | **Pop** of the current top **Page** (unless you add a custom `PopScope` to redirect). |

---

## 8. Temporary trace logs added (`[NIMON_BACK_TRACE]`)

| File | When |
|------|------|
| `story_creator_sentences_screen.dart` | `PopScope.onPopInvokedWithResult` — `didPop`, `result`, `drawerDismissed`, `uri` |
| `story_creator_sentences_screen.dart` | `_FloatingPillHeader.onTapBack` — logs **before** `context.go('/mono')` |
| `story_creator_basics_screen.dart` | `PopScope` before `_attemptExit` |

All gated with **`kDebugMode`**. Pair these with existing `[NIMON_TRACE] CreatorDraftResumeFlow...` and `syncCreatorDrawerSessionForRouter` lines when capturing a logcat.

---

## 9. Files referenced in this trace

- `lib/main.dart` — `GoRouter` routes, `NoTransitionPage`, `AppShell` / `onDockTap` (`go` vs `goBranch`)
- `lib/features/create/story_creator_sentences_screen.dart` — `PopScope`, floating header `go('/mono')`, `CreatorRouteSyncListener`
- `lib/features/create/story_creator_basics_screen.dart` — `PopScope` + `_attemptExit`
- `lib/features/create/creator_learn_mode_sync.dart` — `applyCreatorLearnMode` + `go`
- `lib/features/create/creator_resume_draft.dart` — `context.push` resume paths
- `lib/features/create/creator_route_sync.dart` / `creator_route_sync_listener.dart` — post-route sync (not back)
- `lib/features/profile/profile_screen.dart` — Processing **Continue** → `resumeFromProcessing`
- `lib/ui/widgets/nimon_circle_nav_button.dart` — `NimonBackButton` / `maybePop` default
- `lib/features/mono/mono_screen.dart` — reader `PopScope` (orthogonal to creator, but also consumes back)

---

## 10. User-visible behavior note

The **[NIMON_BACK_TRACE]** and this document **do not** change runtime behavior in release builds (`kDebugMode`-only).  
