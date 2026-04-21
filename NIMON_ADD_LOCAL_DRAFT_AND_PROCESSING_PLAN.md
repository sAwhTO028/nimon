# Nimon — Local draft persistence, autosave & Processing (Add flow)

**Architecture analysis and cleanup planning only.** No backend, refactors, or UI changes in this document.

**Code anchors:**

- Persistence: `StoryCreatorDraftStorage`, `StoryCreatorDraftResumeStorage` — `lib/features/create/story_creator_draft_storage.dart`
- Autosave / notifier: `StoryCreatorDraftNotifier` — `lib/features/create/story_creator_provider.dart`
- “Meaningful draft” gate for Processing: `isMeaningfulDraftForProcessing` — `lib/features/create/creator_draft_validation.dart`
- Derived readiness / processing labels: `computeReadOnlyReady`, `computeFullLearnReady`, `computeProcessingState`, `CreatorProcessingState` — `lib/features/create/creator_readiness.dart`
- Processing copy (chip / secondary / button): `CreatorProcessingCopy` — `lib/features/create/creator_processing_copy.dart`
- Profile Processing UI: `_loadLocalCreatorDraftIntoProcessing`, `_ProcessingDraftManagerTab` — `lib/features/profile/profile_screen.dart`
- Add tab local list (drafts only): `_LocalDraftsSnapshot.load` — `lib/features/create/story_creator_add_tab_screen.dart`

---

## A. Current local flow summary

### How the local draft is stored today

- **Engine:** `SharedPreferences` with JSON serialization of `CreatorStoryV1` (manual `_toJson` / `_fromJson` in `StoryCreatorDraftStorage`).
- **Multi-draft:** Index key `nimon_creator_drafts_v1_index` lists draft ids; each draft has `nimon_creator_draft_v1_<id>` plus `nimon_creator_draft_v1_saved_at_<id>`.
- **Migration:** Legacy single-draft keys are migrated into the index on read.
- **Resume metadata:** Stored **separately** from the draft blob (`CreatorDraftResumeMeta`: `lastActiveModule`, `lastActiveSubPage`, timestamps) — intentional split to avoid bloating core schema.

### When a draft is created today

- **In memory:** `CreatorStoryV1.empty()` assigns a **new UUID** for `basics.storyId` (same as draft id).
- **`reset()`** (e.g. “Create new story” on Add tab): replaces provider state with a **new** empty `CreatorStoryV1` — **does not write to disk by itself**.
- **First disk write** typically happens when:
  - **`applyBasics`** runs (used after valid Story Basics submit on `CreateScreen`) → **`persistLocalNow`** immediately (`reason: basics_confirm`).
  - **`startNewLocalLocalDraft()`** (explicit path) → persists immediately (`reason: new_draft_init`).
- **Comment in code** (`create_screen.dart`): Add/Create starts an “ephemeral draft session”; **first persist when fields are applied** — matches `reset` + `applyBasics` behavior.

### When autosave happens today

| Mechanism | Default timing | Used for |
|-----------|----------------|----------|
| **`persistLocalDebounced`** | **350 ms** after last trigger | Sentence plaintext (`applySentences`), default debounced saves |
| **`applyBasicsDebounced`** | **450 ms** | Title/description-heavy basics editing |
| **`persistLocalNow`** | Immediate (async) | `applyBasics` (confirm), sentence support/furigana/single-sentence edit, **all learn-module add/update/delete/reorder**, audio set/pick/clear, `setModuleStatus`, publish transitions, `globalSaveDraftNow` |
| **Debounce cancel** | On every `persistLocalNow` | Pending debounced timer is cancelled so immediate save wins |

**`globalSaveDraftNow`:** Cancels debounce, flushes `persistLocalNow` — intended for drawer “Save draft” style reassurance.

### How Processing state is derived today

1. **Load:** Profile loads **all** ids from `StoryCreatorDraftStorage.loadAllIds()`, loads each `CreatorStoryV1`, drops any that fail **`isMeaningfulDraftForProcessing`** (empty shell drafts hidden).
2. **Bucket rows** by **`draft.publishState`** (`StoryPublishState`):
   - `draft` → section **“Drafts”**
   - `readingOnlyPublished` → **“Ready for Full Learn”**
   - `fullLearnPublished` → **“Full Learn published”**
3. **Card copy** uses **`CreatorProcessingCopy`**: primary chip from `publishState`; **secondary line** blends `publishState` with **`computeFullLearnReady`** (e.g. Read Only row can say “Ready to publish Full Learn” or “Learn upgrade available”).
4. **Readiness badge** on list items uses **`computeProcessingState`** (`creator_readiness.dart`) — maps content completeness to `localDraft` / `localReadyReadOnly` / `localReadyFullLearn` **without** upload states (upload enum values exist but are **not** returned by `computeProcessingState` today).

### Where confusion / overlap exists

| Topic | What happens | Risk |
|-------|----------------|------|
| **`StoryPublishState` vs `CreatorProcessingState`** | Publish state is **persisted**; processing readiness label is **derived** from content thresholds | Two “states” sound similar (“ready for read-only”) but mean different things |
| **Section title “Ready for Full Learn”** | Applies to **`readingOnlyPublished`** | Name describes *next* step, not the fact the user already did “Read Only published” — can confuse |
| **Add tab vs Processing** | Add tab list **filters `publishState == draft` only**; Processing includes **published** rows too | Correct product split, but easy to forget when reasoning about “where is my draft?” |
| **Empty draft shell** | `reset()` creates new id in memory; if user leaves without persisting meaningful content, **nothing** should appear in Processing (`isMeaningfulDraftForProcessing`); stale indexed empty payloads are possible if writes fail mid-flight |
| **Upload-related `CreatorProcessingState` values** | `uploadQueued` / `uploading` / … exist but **not** used in `computeProcessingState` | Dead path until backend — risk of misleading UI if mixed prematurely |

---

## B. Clean local draft lifecycle (V1 stages)

Canonical stages for **local-first**, **backend-ready** mental model:

| Stage | Meaning | Local truth |
|-------|---------|-------------|
| **1. Untouched create session** | User opened Add flow; **in-memory** `CreatorStoryV1` may exist after `reset()` with **new id**, **no** meaningful content, **no** requirement to persist | Not listed in Processing; may not be on disk |
| **2. Dirty local draft** | User edited; provider `dirty` may be true; debounced or pending persist | Still `publishState == draft` |
| **3. Saved local draft** | At least one successful **`persistLocalNow`** (or debounced flush) wrote JSON; content may still be incomplete | `publishState == draft`; appears in Processing iff **`isMeaningfulDraftForProcessing`** |
| **4. Read-only published (local / demo)** | User passed read-only validation; **`StoryPublishState.readingOnlyPublished`** set and persisted | Same draft record; **no server** — semantic is “published **locally**” or “released Read Only **tier**” |
| **5. Full-learn published (local / demo)** | Full learn validation passed; **`StoryPublishState.fullLearnPublished`** | Same; still local-only until API exists |

### Rules of thumb

- **When should a draft first be created (on disk)?**  
  **When the user commits meaningful input** that should survive app restart: e.g. confirmed Story Basics (`applyBasics`), or explicit `startNewLocalDraft` if you want “empty draft file” early (today the main Create path uses **reset + applyBasics** so first persist aligns with first committed basics).

- **When should it first appear in Processing?**  
  When **`isMeaningfulDraftForProcessing`** is true **and** the draft is loadable from storage — i.e. not an empty shell. This matches current Profile behavior.

- **When should autosave start?**  
  After the first time the aggregate is **mutated** (`_setDraft` / `markDirty`): debounced paths for high-frequency typing; immediate for structural edits and publish.

- **When should it remain local-only?**  
  **Always** until a backend sync layer exists. `publishState` changes are **local lifecycle flags**, not proof of network publish.

- **When should `publishState` change?**  
  Only via **explicit publish actions** (or explicit “mark as draft” if product adds revert). Implementation today: `publishReadingOnlyToDisk` / `publishFullLearnToDisk` / `markDraftAndPersistNow` etc., after readiness checks.

---

## C. Autosave rules (recommended canonical behavior)

Align with **current implementation** unless you intentionally change product rules.

### Basics

- **Confirm / submit from Story Basics form (valid payload):** **immediate** save (`applyBasics` → `persistLocalNow`).  
- **Live editing in form (text-heavy):** **debounced** (`applyBasicsDebounced`, **450 ms** default in code).

### Storytelling (sentences)

- **Plaintext merge / line edits:** **debounced** (`applySentences` → `persistLocalDebounced`, **350 ms** default).

### Learn modules (vocab, grammar, quiz, audio)

- **Add / update / delete / reorder:** **immediate** `persistLocalNow` (current code).

### Rename / edit (single sentence field)

- **Support meanings, furigana spans, combined text+furigana:** **immediate** (`updateSentenceSupport`, `updateSentenceFurigana`, `updateSentenceTextAndFurigana`).

### Publish actions

- **Read-only / full-learn publish:** **await** `persistLocalNow` in `publishReadingOnlyToDisk` / `publishFullLearnToDisk` (completion signal for UI).

### Global

- **“Save draft” / leaving flow / drawer:** **`globalSaveDraftNow`** — cancel debounce + **immediate** persist.

### No-save situations

- **Invalid basics submit** — no `applyBasics`; nothing new on disk.
- **No-op mutations** (e.g. empty sentence text rejected) — no state change / no persist.
- **Pure navigation** without mutating draft — no persist (resume meta may still update separately).

### Untouched session

- **`reset()` alone** — no persist; **no Processing row** until meaningful content + successful save.

---

## D. Separate state types (what persists where)

| # | State type | What it is | Persist where |
|---|------------|------------|----------------|
| **1** | **Canonical local draft data** | `CreatorStoryV1` JSON (basics, sentences, learn layers, `publishState`, `moduleWorkflowStatuses`) | `StoryCreatorDraftStorage` |
| **2** | **Local save status** | `dirty`, `CreatorDraftSaveStatus`, `lastSavedAt`, `lastSaveError` | **Provider only** (`StoryCreatorDraftState`) — **not** in draft JSON |
| **3** | **Resume / navigation state** | Last module, subpage, entered/edited times | `StoryCreatorDraftResumeStorage` (separate keys) |
| **4** | **Derived readiness** | `computeReadOnlyReady`, `computeFullLearnReady`, `computeProcessingState` | **Not persisted** — recompute from draft + rules |
| **5** | **Processing display state** | Section buckets, highlight id, pulse | **UI / route query** (`highlightDraftId`), not draft payload |

**Should not be stored inside the main draft blob:** Riverpod save flags, scroll positions, transient form controllers, derived readiness booleans (unless you add an optional denormalized cache later with versioning).

---

## E. Processing state model (local-first V1)

### Expected categories (align with `StoryPublishState`)

| Category | `StoryPublishState` | When it appears |
|----------|---------------------|-----------------|
| **Draft** | `draft` | Meaningful local draft not yet read-only published |
| **Read Only published** | `readingOnlyPublished` | User completed read-only publish path locally |
| **Full Learn published** | `fullLearnPublished` | User completed full-learn publish path locally |

**Current UI section titles** (`profile_screen.dart`): **“Drafts”**, **“Ready for Full Learn”** (for `readingOnlyPublished`), **“Full Learn published”**.  

- **Plan:** Keep three buckets; consider renaming **“Ready for Full Learn”** to something that also reads as **“Read Only published”** (e.g. **“Read Only published”** + subtitle “Continue Learn”) to reduce naming confusion — **wording-only** change later.

### Action text (from `CreatorProcessingCopy.primaryButton`)

| `publishState` | Primary button |
|----------------|----------------|
| `draft` | **Continue** |
| `readingOnlyPublished` | **Continue Learn** |
| `fullLearnPublished` | **Edit** |

### Secondary line (derived)

- From **`CreatorProcessingCopy.secondaryLine`**: depends on `publishState` **and** `computeFullLearnReady(draft)` for the read-only case.

### Stored vs derived

- **Stored:** `publishState` on `CreatorStoryV1` (single source of truth for “which tier was released”).
- **Derived:** Readiness for next action (`computeFullLearnReady`, `computeReadOnlyReady`), `computeProcessingState` for summary chip (“Draft only” / “Ready for Read-only” / “Ready for Full Learn” style labels in `computeProcessingState`).

---

## F. Publish behavior before backend

**Principle:** Local publish is a **tier transition on the same draft record**, not a network event.

### What changes in local storage

- **`publishState`** updated to `readingOnlyPublished` or `fullLearnPublished`.
- **`basics.updatedAt`** bumped.
- Full JSON rewritten via **`persistLocalNow`** (same as today).

### What Processing should show

- Row moves from **Drafts** to the appropriate published section (same `draftId`).
- Snackbar / navigation after publish (`creator_drawer_publish.dart`) should continue to avoid claiming **server** upload — e.g. **“Read Only saved locally”** / **“Read Only published (this device)”** if copy is ever tightened.

### What should **not** pretend to be server sync

- No “Uploaded”, “Syncing”, or **live** `CreatorProcessingState.upload*` until backend + outbox exist.
- Optional future: explicit **`localPublish`** vs **`serverPublish`** flags — **out of scope** for V1 wording unless product adds confusion.

### Avoid misleading semantics

- Prefer **“published”** in UI to mean **“release tier applied to draft”**, not **“public on internet”**, until CDN/API exists.
- Empty state copy already says **“Local drafts…”** — keep that honesty.

---

## G. Current risks / cleanup needed

1. **Ephemeral `reset()` + new UUID** — Abandoned sessions leave **no** disk row (good), but rapid reset cycles can confuse debugging; document that **draft id is not stable until first save**.
2. **Indexed drafts vs meaningful filter** — Orphan or partial writes could theoretically index an id that fails “meaningful” — defensive filtering is correct; occasional **index cleanup** job may be needed later.
3. **`publishState` without `publishedMonoId`** — No linkage field locally yet; future migration should add nullable id without breaking local tier flags.
4. **Dual readiness signals** — `moduleWorkflowStatuses` vs threshold-based readiness — publish gates use **`computeReadOnlyReady` / `computeFullLearnReady`**; workflow flags can drift — document **which gates publish** (readiness functions).
5. **Upload enum unused** — Either remove from user-visible paths or introduce a separate **SyncState** model when backend lands.
6. **Debounce-only data loss risk** — App kill before debounce flush loses last keystrokes — mitigated by `globalSaveDraftNow` on exit; **worth enforcing** on route `PopScope` / app lifecycle later.

---

## H. Recommended implementation order (after this plan)

1. **Local draft lifecycle cleanup** — Document and optionally enforce: first persist timing, `reset` vs `startNewLocalDraft`, single definition of “meaningful draft.”
2. **Autosave cleanup** — Centralize debounce constants; ensure **lifecycle flush** on background/kill where feasible.
3. **Processing state cleanup** — Align section labels with `publishState` + `CreatorProcessingCopy`; separate **derived** chip strings from **stored** `publishState` in code comments.
4. **Repository abstraction** — `StoryDraftRepository` wrapping `StoryCreatorDraftStorage` + resume meta; provider talks to repository only.
5. **Backend-ready adapter** — Same repository interface; remote implementation later; add `publishedMonoId` when API exists.

---

## Top 10 local-draft decisions to lock now

1. **Canonical on-disk record = `CreatorStoryV1` JSON** (+ separate resume meta) until API exists.
2. **`publishState` is the only persisted “processing tier”** — not `computeProcessingState`.
3. **Derived readiness functions gate publish** — keep a single documented rule for which function gates which button.
4. **Debounced save: 350 ms default; basics text: 450 ms** — or unify to one constant if product prefers.
5. **Immediate persist** for structural edits, learn modules, publish, and **global save**.
6. **Processing list** = all meaningful drafts **regardless** of publish state; **Add tab list** = **`publishState == draft` only** (current behavior).
7. **`isMeaningfulDraftForProcessing` gates visibility** in Processing — empty shells never show.
8. **Local publish** = tier change + disk persist — **not** network; copy must not imply server.
9. **Provider `dirty` / `saveStatus`** stay **out of** SharedPreferences JSON.
10. **Future backend:** introduce **`publishedMonoId` + sync state** without renaming `publishState` semantics — additive migration.

---

*End of report.*
