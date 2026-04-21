# Nimon Add flow — final coding execution order

**Analysis / roadmap only.** No code changes, repository implementation, or UI edits in this document.

**Inputs:** `NIMON_ADD_AUTH_OWNERSHIP_PLAN.md`, `NIMON_ADD_STORY_DRAFT_MODEL_PLAN.md`, `NIMON_ADD_LOCAL_DRAFT_AND_PROCESSING_PLAN.md`, `NIMON_ADD_STORY_DRAFT_REPOSITORY_PLAN.md`, `NIMON_ADD_DTO_AND_API_CONTRACT_PLAN.md`, `NIMON_ADD_DIRECT_STORAGE_USAGE_CLEANUP_MAP.md`.

---

## A. Executive summary

### What the Add flow cleanup is trying to achieve

- **Single persistence boundary** (`StoryDraftRepository`) so **local `SharedPreferences` JSON** today and **HTTP + cache** tomorrow share one contract.
- **One authoritative write path** for draft + resume side effects (`save` + `touchEdited`, `delete` + `clearMeta`) — today split across `story_creator_provider.dart` and **`profile_screen.dart`**.
- **Backend-ready naming and DTO hooks** (`draftId`, `ownerId`, publish linkage fields) **without** shipping a real API yet.
- **Predictable Processing / Add tab / resume** behavior after refactors — verified by manual QA between checkpoints.

### What should NOT be touched yet

- **Real backend**, auth UI, login flows.
- **Mono feed** wiring, public profile server data, non–Add-flow features.
- **Broad UI redesign** of Processing / Add tab (copy/layout) unless required by a persistence fix.
- **Performance sweeps** unrelated to draft I/O (see section G).

### Safest implementation philosophy

1. **Add abstraction before moving call sites** — interface + local adapter that delegates to existing `StoryCreatorDraftStorage` / `StoryCreatorDraftResumeStorage` with **no behavior change**.
2. **Migrate the notifier first** — it already owns most writes; reduces duplicate saves early.
3. **Strangle direct storage** from **high-risk UI** (`profile_screen.dart`) next, **low-risk readers** (`story_creator_hub_screen.dart`) later.
4. **Small PR-sized slices** with **manual verification** at each checkpoint (section E–F).
5. **DTO/mappers optional stubs** — types or mapper module that compile but are unused until remote exists.

---

## B. Final implementation phases

| Phase | Name | Goal |
|-------|------|------|
| **1** | Foundation | Lock types, add `StoryDraftRepository` **interface** + **local** implementation wrapping current storage; wire Riverpod provider for repository. |
| **2** | Notifier migration | `StoryCreatorDraftNotifier` uses repository only — no static storage calls. |
| **3** | Profile / Processing migration | `profile_screen.dart` stops direct load/save/delete/rename on storage; uses repository or notifier methods. |
| **4** | Add tab migration | `story_creator_add_tab_screen.dart` draft list uses repository. |
| **5** | Basics / hub cleanup | `story_creator_basics_screen.dart` discard path; `story_creator_hub_screen.dart` `exists` / `loadSavedAt` via repository. |
| **6** | Route / resume cleanup | `creator_route_sync.dart`, `creator_resume_draft.dart` call repository for resume meta. |
| **7** | DTO prep hooks | Add `story_draft_mapper.dart` (or similar) + optional DTO classes **aligned with** `NIMON_ADD_DTO_AND_API_CONTRACT_PLAN.md`; used only at repository boundary when you add remote impl. |
| **8** | Backend-ready stabilization | Optional: add nullable `publishedMonoId` / timestamps to domain or a thin `DraftSyncMeta` sidecar; dev `ownerId` stub per auth plan; final QA. |

---

## C. Exact file-by-file order (recommended)

**Create first (new files):**

1. `lib/features/create/data/story_draft_repository.dart` — abstract class (or typedef + abstract) per repository plan.
2. `lib/features/create/data/local_story_draft_repository.dart` — delegates to `StoryCreatorDraftStorage` + `StoryCreatorDraftResumeStorage`.
3. `lib/features/create/data/story_draft_repository_provider.dart` — Riverpod `Provider<StoryDraftRepository>` (or override-friendly).

**Then modify in this order:**

4. `lib/features/create/story_creator_provider.dart` — inject/use repository; remove direct `StoryCreatorDraftStorage` / `ResumeStorage` usage.

5. `lib/features/profile/profile_screen.dart` — replace all draft/resume static calls in Processing (`_loadLocalCreatorDraftIntoProcessing`, `_ProcessingDraftCard._rename` / `_delete`, `_showProcessingDraftSheet`).

6. `lib/features/create/story_creator_add_tab_screen.dart` — `_LocalDraftsSnapshot.load` → repository.

7. `lib/features/create/story_creator_basics_screen.dart` — `hasDraft` / `clear` / `clearMeta` on discard → repository.

8. `lib/features/create/story_creator_hub_screen.dart` — `FutureBuilder` storage → repository helpers.

9. `lib/features/create/creator_resume_draft.dart` — `ensureInit` / `loadMeta` → repository.

10. `lib/features/create/creator_route_sync.dart` — `recordLastActive` → repository.

**Defer structural edits (adapter only touches internally):**

11. `lib/features/create/story_creator_draft_storage.dart` — **minimize changes**; remains implementation detail behind `LocalStoryDraftRepository`. Only adjust if repository needs a package-private hook (prefer none).

**Later (phase 7–8):**

12. `lib/features/create/data/story_draft_mapper.dart` (new) — domain ↔ DTO shapes per DTO plan.
13. Optional: small edits to `lib/features/create/story_v1_model.dart` for nullable publish linkage fields — **only** when you commit to additive fields (can wait until stabilization phase).

**Note:** `story_creator_draft_storage.dart` is **not** deleted; it becomes **private** to the local repository.

---

## D. Per-step goal (why / change / keep / risk)

### Phase 1 — New repository files

- **Why first:** Establishes seam without moving UI.
- **Change:** Interface + `LocalStoryDraftRepository` delegating to existing statics; Riverpod registration.
- **Keep:** JSON shape in `story_creator_draft_storage.dart` unchanged.
- **Risk reduced:** Future API swap is one implementation class.

### Phase 2 — `story_creator_provider.dart`

- **Why second:** Single writer for autosave/publish/debounce.
- **Change:** Replace `StoryCreatorDraftStorage.*` / `ResumeStorage.*` with repository calls.
- **Keep:** Public notifier API for screens; debounce timings; `StoryCreatorDraftState` fields.
- **Risk reduced:** Downstream screens still talk to notifier only for mutations they already use.

### Phase 3 — `profile_screen.dart`

- **Why third:** Highest duplicate I/O and **stale provider** risk on rename/save.
- **Change:** List loads via `repository.loadAllDrafts()` (or equivalent); rename/delete via **`notifier` methods** (e.g. `updateTitleForDraftId` + persist) **or** repository + explicit `loadDraftById` refresh — pick one pattern and stick to it.
- **Keep:** `isMeaningfulDraftForProcessing` filtering; UI structure; `CreatorProcessingCopy`.
- **Risk reduced:** Disk and in-memory draft stay aligned.

### Phase 4 — `story_creator_add_tab_screen.dart`

- **Why fourth:** Read-only list; depends on repository list API from phase 1.
- **Change:** `_LocalDraftsSnapshot.load` uses repository.
- **Keep:** Filter `publishState == draft`.
- **Risk reduced:** Same data as Processing for a given id.

### Phase 5 — `story_creator_basics_screen.dart` + `story_creator_hub_screen.dart`

- **Why fifth:** Edge cases (`hasDraft`, `clear`); hub read-only futures.
- **Change:** Repository `hasDraft`, `deleteDraft`, `clearResumeMeta`; hub `hasAnyDraft` / `lastSavedAt` (names per your API).
- **Keep:** Dialog UX for discard; hub navigation intent.
- **Risk reduced:** Discard and “Continue” consistent with multi-draft rules (document **active** vs **any** draft explicitly when fixing hub).

### Phase 6 — `creator_resume_draft.dart` + `creator_route_sync.dart`

- **Why sixth:** Touches every “Continue” path; do after core I/O stable.
- **Change:** Resume reads/writes only through repository.
- **Keep:** URI construction and `creatorDrawerSession` updates.
- **Risk reduced:** No split resume writers bypassing repository.

### Phase 7–8 — Mapper + stabilization

- **Why last:** No user value until remote exists; avoids churn during migration.
- **Change:** Mapper module + optional domain fields for publish linkage / `ownerId` stub.
- **Keep:** `CreatorStoryV1` semantics unless additive fields are agreed.

---

## E. Safe checkpoints

| Stop point | Verify before continuing |
|------------|---------------------------|
| **After repository interface + local impl compile** | App builds; no feature wired yet or feature flag: notifier still works if you wire behind provider override incrementally. |
| **After notifier fully on repository** | Create draft, edit, autosave debounce, `globalSaveDraftNow`, publish Read Only / Full Learn, Processing list refresh — **all** without opening Profile direct-save paths yet (if Profile still old code, test notifier-only flows first). |
| **After Profile / Processing migration** | Rename/delete/resume from Processing; `_loadLocalCreatorDraftIntoProcessing` shows same rows; no crash on empty. |
| **After Add tab migration** | Local drafts list matches expectation; tap continues to correct route. |
| **After basics / hub** | Back/discard from basics; hub “Continue” / “Start new story” / last saved label. |
| **After route / resume** | Deep links with `?draftId=` and panel params; resume lands on correct module. |
| **After DTO hooks** | Build only; mapper unit tests optional. |
| **Final stabilization** | Full regression pass (section F). |

---

## F. Required tests / manual verification (by phase)

### After repository + notifier

- Create new story from Add flow; **first persist** after basics submit.
- Edit sentences — **debounced** save; kill debounce with **Save draft** / navigation flush if implemented.
- **Publish** Read Only and Full Learn — `publishState` in JSON unchanged semantically.
- **`discardDraftFromDiskAndReset`** from hub — understand **active draft only** (documented behavior).

### After Profile migration

- Processing tab lists **all meaningful** drafts; sections **Drafts** / **Ready for Full Learn** / **Full Learn published** unchanged visually.
- **Rename** draft title — title updates and list refreshes; open draft in creator — title matches.
- **Delete** draft — removed from list and disk.
- Sheet flow `_showProcessingDraftSheet` if still used — readiness messages still show.

### After Add tab migration

- Draft cards list only **`publishState == draft`** items; counts sane vs Processing.

### After basics / hub

- Back from basics: persist flush, discard branch, **hasDraft** false path clears shell.
- Hub: **exists** / **last saved** labels match reality; Continue navigates correctly.

### After resume / route

- Resume from Processing → correct **panel** and **sentences** step.
- Route sync: change panel — reopen app or navigate away and back — resume meta still sensible.

### Final pass

- Full **Read Only → Continue Learn → Full Learn** journey.
- Multi-draft: create two drafts, switch between, ensure **active** id behavior understood (see cleanup map).

---

## G. What not to optimize yet

- **Full backend**, sync queue, conflict resolution, ETags — after repository is stable.
- **Mono feed** / `MonoFeedItem` server source.
- **Profile** Published/Saved tabs beyond draft-related code.
- **Large `profile_screen.dart` split** or unrelated UI refactors.
- **Performance tuning** (debounce ms, list virtualization) unless a measured regression appears.
- **Removing** `story_creator_draft_storage.dart` — keep as local adapter.

---

## H. Final recommended order (short list)

1. Create **repository interface** (`story_draft_repository.dart`).
2. Add **local repository implementation** (`local_story_draft_repository.dart`) + Riverpod provider.
3. **Notifier migration** (`story_creator_provider.dart`).
4. **Profile / Processing migration** (`profile_screen.dart`).
5. **Add tab migration** (`story_creator_add_tab_screen.dart`).
6. **Basics + hub cleanup** (`story_creator_basics_screen.dart`, `story_creator_hub_screen.dart`).
7. **Resume + route cleanup** (`creator_resume_draft.dart`, `creator_route_sync.dart`).
8. **DTO mapping hooks** (`story_draft_mapper.dart`, optional domain fields).
9. **Final Add flow verification** + optional **ownerId** dev stub per auth plan.

---

## Top 10 implementation steps I would actually do first

1. Add **`StoryDraftRepository`** abstract API matching `NIMON_ADD_STORY_DRAFT_REPOSITORY_PLAN.md` (minimal methods: load/save/delete/list/resume bundle).
2. Implement **`LocalStoryDraftRepository`** — thin delegation to `StoryCreatorDraftStorage` + `StoryCreatorDraftResumeStorage` (**zero** logic duplication beyond orchestration).
3. Register **`storyDraftRepositoryProvider`** (Riverpod).
4. Migrate **`StoryCreatorDraftNotifier`** to use repository for **every** current static storage call.
5. Add **one** manual QA pass (create, edit, publish, Processing refresh) before touching Profile.
6. Migrate **`profile_screen.dart`** Processing: **load list** first, then **rename/delete** via notifier or repository bundle.
7. Migrate **`story_creator_add_tab_screen.dart`** list load.
8. Migrate **`story_creator_basics_screen.dart`** discard + **`story_creator_hub_screen.dart`** read helpers.
9. Migrate **`creator_resume_draft.dart`** and **`creator_route_sync.dart`** to repository-only resume APIs.
10. Add **`story_draft_mapper.dart`** stub + **checkpoint** full regression (section F); defer real HTTP.

---

*End of report.*
