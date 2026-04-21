# Nimon — `StoryDraftRepository` boundary (Add flow)

**Architecture planning only.** No backend, refactors, or UI changes in this document.

**Related plans:** `NIMON_ADD_AUTH_OWNERSHIP_PLAN.md`, `NIMON_ADD_STORY_DRAFT_MODEL_PLAN.md`, `NIMON_ADD_LOCAL_DRAFT_AND_PROCESSING_PLAN.md`.

**Current storage entry points (reference):**

- `StoryCreatorDraftStorage` / `StoryCreatorDraftResumeStorage` — `lib/features/create/story_creator_draft_storage.dart`
- Primary coupling: `StoryCreatorDraftNotifier` — `lib/features/create/story_creator_provider.dart`
- Direct storage usage also in: `profile_screen.dart`, `story_creator_add_tab_screen.dart`, `story_creator_basics_screen.dart`, `story_creator_hub_screen.dart`, `creator_route_sync.dart`, `creator_resume_draft.dart`

---

## A. Why a repository boundary is needed

### Current storage situation

- **Draft body:** `CreatorStoryV1` serialized to JSON in `SharedPreferences`, indexed by draft id (multi-draft).
- **Resume meta:** Separate keys (`CreatorDraftResumeMeta` — last module, subpage, timestamps).
- **Ownership field:** `basics.creatorOwnerId` exists on the model but is not enforced at storage layer.

### Current provider / storage coupling

- `StoryCreatorDraftNotifier` **directly** calls `StoryCreatorDraftStorage.save/load/clear/loadSavedAt` and `StoryCreatorDraftResumeStorage.saveMeta/touchEdited` inside persistence methods.
- **UI and feature screens** also call storage static APIs directly (not only the notifier): Profile Processing, Add tab draft list, basics discard, hub “exists” checks, resume flow, route sync.

### Why backend migration gets messy without a repository

1. **No single place** to add: auth headers, conflict policy, retries, DTO mapping, or “local vs remote” orchestration.
2. **Duplicated orchestration** (save + `touchEdited`, delete + `clearMeta`) can drift when one call site is updated and another is not.
3. **Tests** cannot swap a fake repository; they must mock `SharedPreferences` or static storage.
4. **Future sync:** upload queue and `publishedMonoId` updates would scatter across widgets unless one boundary owns **draft I/O**.

A **repository** is the narrow seam: *everything that reads/writes draft-shaped data goes through one interface* (plus optional mapping layer).

---

## B. Proposed repository interface (V1)

**Name:** `StoryDraftRepository` (abstract interface; one implementation `LocalStoryDraftRepository` now, `RemoteCapableStoryDraftRepository` later).

**Domain type:** Keep using **`CreatorStoryV1`** (or a thin typedef `StoryDraft = CreatorStoryV1`) inside the app until DTOs are introduced at the API edge. Repository returns/accepts the **aggregate** the Add flow already uses.

### Core draft lifecycle

| Method | Purpose |
|--------|---------|
| `Future<CreatorStoryV1> createNewDraft({String? ownerId})` | New UUID, `publishState == draft`, optional `ownerId` on basics; **persist immediately** (matches `startNewLocalDraft` intent). |
| `Future<CreatorStoryV1?> loadDraft(String draftId)` | Load by id; `null` if missing. |
| `Future<List<CreatorStoryV1>> loadAllDrafts()` | All indexed drafts (caller may filter). |
| `Future<List<String>> listDraftIds()` | Index only — cheap for menus. |
| `Future<void> saveDraft(CreatorStoryV1 draft)` | **Atomic** write of draft JSON + **`touchEdited`** for resume (same transaction semantics as today’s `persistLocalNow` success path). |
| `Future<void> saveDraftNow(CreatorStoryV1 draft)` | Alias of `saveDraft` or explicit “flush” naming for notifier — **no second meaning** unless you add queueing later. |
| `Future<void> deleteDraft(String draftId)` | Remove draft payload + index entry + **`clearMeta`** — mirrors `StoryCreatorDraftStorage.clear` + resume clear. |
| `Future<DateTime?> savedAt(String draftId)` | Maps `StoryCreatorDraftStorage.loadSavedAt`. |
| `Future<bool> hasDraft(String draftId)` | Exists check for discard flows. |

### Resume metadata (same repository)

Keeping resume in the **same** repository keeps “one draft id, two stores” an **implementation detail** of the local adapter.

| Method | Purpose |
|--------|---------|
| `Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId)` | |
| `Future<void> saveResumeMeta(CreatorDraftResumeMeta meta)` | Replace/upsert. |
| `Future<void> updateResumeMeta(String draftId, …)` | Optional convenience wrapping `recordLastActive` / `touchEdited` patterns. |
| `Future<void> clearResumeMeta(String draftId)` | On delete draft. |

### Publish (local-first; backend-ready names)

These **mutate `CreatorStoryV1.publishState`** and persist — same as `publishReadingOnlyToDisk` / `publishFullLearnToDisk` / `markDraftAndPersistNow` today. Validation stays **outside** repository (readiness), or repository calls a shared validator — **V1 recommendation:** notifier validates, repository only saves result.

| Method | Purpose |
|--------|---------|
| `Future<void> publishReadOnly(CreatorStoryV1 draft)` | Expects caller to have set state + passed readiness; or accept draft already updated. **Simplest V1:** `saveDraft` after notifier sets `publishState`. |
| `Future<void> publishFullLearn(CreatorStoryV1 draft)` | Same. |
| `Future<void> markAsDraft(CreatorStoryV1 draft)` | `publishState == draft`. |

**Alternative minimal API:** Only expose **`saveDraft`** for publish transitions and keep publish methods on the **notifier** — acceptable if repository is strictly persistence. The table above is slightly richer for **remote** implementations that need a dedicated **`POST …/publish`** later.

**Recommendation:** Expose **`saveDraft`** as the single write primitive **plus** optional **`publishReadOnly` / `publishFullLearn`** that delegate to `saveDraft` locally but map to HTTP later. Avoid duplicating validation in two layers.

### Filtering helpers (optional on repository vs pure function)

- `bool isMeaningfulForProcessing(CreatorStoryV1 d)` — today `isMeaningfulDraftForProcessing` in `creator_draft_validation.dart`.

**Recommendation:** Keep as a **pure function** in domain layer; repository does **not** need to own business rules. Repository may offer **`loadDraftsForProcessing()`** that applies the filter for convenience — optional.

### Explicitly **out of scope** for V1 repository

- Debounce timers (stay in **notifier**).
- Riverpod `dirty` / `saveStatus` (stay in **notifier**).
- `computeReadOnlyReady` / `computeFullLearnReady` (stay in **domain/helpers**).
- UI strings (`CreatorProcessingCopy`).

---

## C. Local implementation plan

### `LocalStoryDraftRepository`

- **Delegates to** existing `StoryCreatorDraftStorage` and `StoryCreatorDraftResumeStorage` — **no behavior change** on day one, only **indirection**.
- **Draft JSON:** `save` / `load` / `loadAllIds` / `clear` as today.
- **Resume meta:** Co-locate calls: every successful `saveDraft` should **`touchEdited`** (or equivalent) like current `persistLocalNow` path in `story_creator_provider.dart`.
- **Meaningful draft filtering:** Not required inside repository; **Profile / Add tab** continue to use `isMeaningfulDraftForProcessing` **or** call a repository helper that composes `loadAllDrafts()` + filter.
- **`loadAllDrafts`:** `loadAllDrafts()` from storage (already exists) — return full aggregates.
- **Save behavior:** Single code path: update `basics.updatedAt` in notifier before save (as today), then `repository.saveDraft(draft)`.
- **Publish behavior:** After notifier applies `publishState` and readiness checks, **`repository.saveDraft(draft)`** — identical bytes to disk as today.

---

## D. Future remote implementation plan

### Methods that stay the same (signature-wise)

- `loadDraft`, `loadAllDrafts`, `saveDraft`, `deleteDraft`, resume meta methods — **same app-facing contract**. Internally they may call API + local cache.

### Methods that need remote DTO mapping

- **`saveDraft` / publish:** Map `CreatorStoryV1` ↔ `StoryDraftDto` / JSON body per `NIMON_ADD_STORY_DRAFT_MODEL_PLAN.md`; strip `localPath` fields on upload.
- **`createNewDraft`:** May become `POST /drafts` with server-issued id — **or** client UUID accepted by server (plan already allows client `draftId`).

### Methods that remain **local-first** for a long time

- **Resume meta** may stay **device-only** until product requires cross-device resume; remote impl can no-op or sync to a small `draft_client_meta` endpoint later.
- **Debounced typing** still lands in notifier; remote may batch or send diffs later — **not V1**.

### Methods that may become sync-aware later

- **`saveDraft`:** Add optimistic concurrency (`If-Match` / `updatedAt`).
- **`publishReadOnly` / `publishFullLearn`:** Become network calls that return **`publishedMonoId`** + timestamps, then **local cache update**.

---

## E. Separation of concerns

| Layer | Responsibility |
|-------|------------------|
| **Provider / `StoryCreatorDraftNotifier`** | In-memory `CreatorStoryV1`; debounce; `dirty` / `saveStatus` / `lastSavedAt`; orchestrate **readiness** before publish; call **repository** for I/O; no raw `SharedPreferences`. |
| **`StoryDraftRepository`** | **All** draft + resume persistence operations; single place for future API + cache policy. |
| **Storage adapter (optional inner class)** | Thin wrapper over `StoryCreatorDraftStorage` JSON read/write — only if you want to test JSON without repository; otherwise local repository implements directly. |
| **Readiness** | `creator_readiness.dart`, `creator_completion_rules.dart` — **pure functions**; not in repository. |
| **UI copy** | `CreatorProcessingCopy`, Profile widgets — **no** persistence. |

---

## F. Risks in current code

1. **Many call sites** use `StoryCreatorDraftStorage` / `ResumeStorage` directly — migration to repository requires **touching each** (Profile is large surface area).
2. **Resume meta split** — Easy to **save draft** without **touchEdited** if a new code path is added; repository should **bundle** the happy path.
3. **Publish consistency** — Publish must always end in persisted `publishState`; centralizing in notifier + `saveDraft` reduces gaps.
4. **Local-only assumptions** — `publishedMonoId` absent; repository interface should leave room for **return values** on publish later without breaking `saveDraft`.
5. **Duplicated save paths** — e.g. Profile may **load/save** draft for edits — should eventually go through **notifier** or **repository only**, not both ad hoc.

---

## G. Recommended migration order

1. **Introduce `StoryDraftRepository` interface** (abstract class in `lib/features/create/` or `lib/data/`).
2. **Add `LocalStoryDraftRepository`** delegating to existing storage classes — **no UI change** yet if unused.
3. **Move `StoryCreatorDraftNotifier`** to use repository for all load/save/delete/resume operations it currently does.
4. **Isolate DTO mapping** — When API exists, add `StoryDraftMapper` at repository implementation boundary, not in widgets.
5. **Migrate remaining direct storage usages** (Profile, Add tab, basics, hub, resume, route sync) to **repository** or **notifier** — **one screen cluster at a time**, starting with highest churn (Profile Processing).
6. **Prepare remote implementation** — Swap implementation via Riverpod `Provider<StoryDraftRepository>` with environment flag.

---

## Top 10 repository decisions to lock now

1. **One interface** `StoryDraftRepository` owns **draft JSON + resume meta** I/O for the Add flow.
2. **Notifier keeps debouncing and dirty state** — repository is **not** a `ChangeNotifier`.
3. **`saveDraft` is the canonical persist primitive**; publish transitions are **content + `publishState` + save** unless you add explicit publish methods for future HTTP.
4. **Readiness checks stay out of the repository** (call before save from notifier).
5. **`isMeaningfulDraftForProcessing` stays a pure function** — not repository core logic.
6. **Delete draft** must always **clear resume meta** in one place (repository implementation).
7. **Future `publishedMonoId`** — add to model + repository **response** from remote publish; local repo returns void for now.
8. **Riverpod:** Provide repository with `Provider` / `ProviderScope` override for tests and fake backends.
9. **Do not** put UI strings or `CreatorProcessingCopy` in the repository.
10. **Migration strategy:** Implement local repository first, **wire notifier only**, then **strangle** direct `StoryCreatorDraftStorage` usage from other files.

---

*End of report.*
