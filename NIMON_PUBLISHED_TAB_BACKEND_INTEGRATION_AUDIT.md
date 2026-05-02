# Nimon Published Tab — Backend Integration Audit (Report Only)

**Audit date:** 2026-04-25  
**Scope:** Published tab support for **Read Only** + **Full Learn** publishes, with Docker + Nest backend + Flutter Chrome “remote strict mode”.  
**Constraints honored:** no fixes implemented in this pass; no UI redesign; backend read-only inspection only.

---

## Executive summary (what’s missing)

Even though the backend **does** create/update a `PublishedMono` row on **Read Only publish**, the Flutter **Published tab is not currently backed by any backend “PublishedMono list” API**. The Published tab is driven by **mock/static “uploaded” data**, not by the draft/publish endpoints.

So, after Read Only publish succeeds, **the correct database rows can exist**, but **Flutter never fetches them into Published**.

---

## A. Current backend published support

### A1. Data model (Prisma)

In `nimon-backend/prisma/schema.prisma`:

- **`StoryDraft`** has:
  - `publishState: PublishState` (`draft | reading_only_published | full_learn_published`)
  - `publishedMonoId: String?`
  - `readingOnlyPublishedAt: DateTime?`
  - `fullLearnPublishedAt: DateTime?`
- **`PublishedMono`** has:
  - basic metadata (`title`, `category`, `level`, `description`)
  - `content: Json` (opaque payload; V1 fields are embedded here)
  - relation back to drafts (`drafts StoryDraft[]`)

### A2. Backend endpoints (Nest)

In `nimon-backend/src/modules/story-drafts/story-drafts.controller.ts`:

- `GET /v1/story-drafts` (lists drafts for Processing/Workspace-like list)
- `GET /v1/story-drafts/:draftId` (full draft)
- `PUT /v1/story-drafts/:draftId` (update draft content)
- `POST /v1/story-drafts/:draftId/publish/read-only`
- `POST /v1/story-drafts/:draftId/publish/full-learn`

**There is no `PublishedMono` controller/module** exposed under `/v1` in the code inspected (no `@Controller('v1/published-*')`, no `published-monos` routes).

### A3. Does backend create/update `PublishedMono` on Read Only publish?

**Yes.**

In `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` → `publishReadOnly`:

- If `draft.publishedMonoId` is null, it **creates** a `PublishedMono`.
- It then **updates the same PublishedMono** on subsequent Read Only publishes (“Update Read Only” safe path).
- It updates the `StoryDraft` row:
  - `publishState = reading_only_published`
  - `publishedMonoId = <id>`
  - `readingOnlyPublishedAt = now (first publish only)`
  - `version++`

The `PublishedMono.content` JSON is updated with:
- `publishKind: 'read_only_v1'`
- `core` containing basics + ordered sentences payload

### A4. Does backend update `PublishedMono` on Full Learn publish?

**No (not in current code).**

In `publishFullLearn`, the backend:
- Requires `draft.publishedMonoId` already exists.
- Updates the **draft** row only:
  - `publishState = full_learn_published`
  - `fullLearnPublishedAt = now (first publish only)`
  - `version++`

It does **not** write additional “full learn” content into `PublishedMono.content` (no learn layers mapped to a published read model here yet).

---

## B. Current Flutter Published tab data source

### B1. What Published tab displays today

In `lib/features/profile/profile_screen.dart`, the Published tab (`idx: 0`, icon `cloud_done_outlined`, label `"Published"`) renders `_FolderGroupList` using:

- `_uploadedFolders` seeded from **`_uploadedFoldersMock`**
- `_uploadedLooseItems` seeded from **`_uploadedLooseMock`**

There is **no backend fetch** for published items in Published tab rendering—no repository call to list published content.

### B2. What Flutter fetches remotely today (creator)

`lib/features/create/data/remote_story_draft_repository.dart` talks to the backend **only** for **draft** lifecycle:

- `GET /v1/story-drafts` → list draft IDs
- `GET /v1/story-drafts/:id` → load draft (and caches locally)
- `PUT /v1/story-drafts/:id` → update content
- `POST /v1/story-drafts/:id/publish/read-only`
- `POST /v1/story-drafts/:id/publish/full-learn`

There is **no** repository method for:
- listing `PublishedMono` rows
- loading a published feed item for Published tab
- mapping `PublishedMono` DTOs to UI models

---

## C. Exact missing endpoints/methods

### Backend missing

- **A `/v1/published-monos` (or equivalent) endpoint** to support Published tab:
  - list by owner (dev owner id currently)
  - sorting/paging by `updatedAt` / `createdAt`
  - fields needed by Published tab list rows (title/desc/level/category/thumbnail-ish if any)

Optional but likely required soon:
- **`GET /v1/published-monos/:id`** (detail view for reader)

### Flutter missing

At minimum:
- A client/repository method to call the published list endpoint:
  - e.g. `PublishedMonoRepository.listPublished(...)`
- DTO(s) + mapper(s) for published list rows
- Profile Published tab wiring to use backend data instead of mocks

---

## D. Expected data flow after Read Only publish (what *should* happen)

### Backend writes (expected rows)

After `POST /v1/story-drafts/:draftId/publish/read-only` succeeds, the DB should contain:

1. **`story_drafts`** row:
   - `publishState = reading_only_published`
   - `publishedMonoId = <uuid>`
   - `readingOnlyPublishedAt != null`
   - `version` incremented
2. **`published_monos`** row (id = `publishedMonoId`):
   - updated title/category/level/description
   - `content.publishKind = read_only_v1`
   - `content.core.sentences[]` etc.

### Frontend reads (what’s missing today)

To show in Published tab, Flutter must:

- fetch published list (currently **no endpoint + no client**)
- map to the Published tab UI model (currently **mock data only**)

---

## E. Expected data flow after Full Learn publish (what *should* happen)

### Backend writes (current behavior)

After `POST /v1/story-drafts/:draftId/publish/full-learn` succeeds today, the DB should contain:

1. `story_drafts` row:
   - `publishState = full_learn_published`
   - `fullLearnPublishedAt != null`
   - `publishedMonoId` must already exist (enforced)

**But**: no full-learn published read model is written anywhere (no `PublishedMono` update for learn content).

### Backend reads needed for Published tab

To show “Full Learn published” content correctly, backend needs either:

- `PublishedMono.content` to include full learn payload (vocab/grammar/quiz/audio) **or**
- a separate table/read model for full learn published content, with list endpoints

---

## F. Recommended implementation steps (correct order)

1. **Backend: add a list endpoint for published content**
   - `GET /v1/published-monos?limit=&cursor=` (or similar)
   - Return minimal list row DTO: `id`, `title`, `description`, `level`, `category`, `updatedAt`, and a `publishKind/state` for badges.

2. **Flutter: add repository + DTO + mapper for that endpoint**
   - Keep it isolated from creator draft repository (separate concern).

3. **Flutter: wire Published tab to fetched published list**
   - Replace `_uploaded*Mock` usage (or gate mocks behind dev flag).
   - Keep layout unchanged; only swap data source.

4. **Full Learn parity (backend)**
   - Decide read model: extend `PublishedMono.content` to include learn layers or create a parallel full-learn published structure.
   - Update `publishFullLearn` to update the published read model.

5. **Badges / state mapping**
   - Use the published endpoint’s returned state to show Read Only vs Full Learn badges (neutral/green vs green-check).

---

## G. Files likely to change (when implementing)

### Backend
- `nimon-backend/prisma/schema.prisma` (only if adding new tables/fields for Full Learn)
- `nimon-backend/src/modules/*` (new `published-monos` module/controller/service)
- `nimon-backend/src/common/api-error.ts` (if adding new error codes)

### Flutter
- `lib/features/profile/profile_screen.dart` (Published tab data source swap)
- `lib/data/*` or `lib/features/*/data/*` (new published repository + DTO + mapper)
- Possibly `lib/main.dart` routing if adding new deep-links for published items

---

## H. What should NOT be changed (per your constraints / stability)

- Do **not** redesign the profile tab UI layout or navigation structure.
- Do **not** change creator publish flows (`performCreatorDrawerPublish`, `RemoteStoryDraftRepository.saveDraft` publish routing) in the first step.
- Do **not** change back policy as part of “published tab appears” work (separate concern).
- Do **not** conflate “draft list (Workspace)” endpoints with “published feed” endpoints—keep separate for clarity.

---

## Answers to your numbered questions

1. **Does backend currently create/update PublishedMono on Read Only publish?**  
   **Yes** (`StoryDraftsService.publishReadOnly` creates/updates `published_monos` and sets `publishedMonoId`).

2. **Does backend expose an API endpoint to list PublishedMono content for Published tab?**  
   **No** (only `/v1/story-drafts/*` endpoints are present; no `/v1/published-monos` list).

3. **Does Flutter Published tab call a backend PublishedMono endpoint, or only local/mock/profile data?**  
   **Only mock/profile data** (`_uploadedFoldersMock`, `_uploadedLooseMock`).

4. **Is Published tab reading StoryDraft rows, PublishedMono rows, or local storage?**  
   **Neither drafts nor PublishedMono**; it is reading **mock in-memory lists**.

5. **After Read Only publish, what exact database rows should exist?**  
   `story_drafts`: `publishState=reading_only_published`, `publishedMonoId` set, `readingOnlyPublishedAt` set;  
   `published_monos`: row exists/updated with `content.publishKind=read_only_v1` and `content.core` payload.

6. **What is missing for Published tab to show Read Only published content?**  
   Backend list endpoint for published content + Flutter repository/mapping + Published tab wiring to that data.

7. **What is missing for Full Learn published content?**  
   Backend does not write a Full Learn published read model (it only flips draft state). Needs published content representation + list endpoint fields.

8. **Is the issue backend endpoint missing, frontend repository missing, mapper missing, or filtering mismatch?**  
   **Primary:** backend **published list endpoint missing** + frontend **Published tab not wired** (mock-only).  
   **Secondary:** Full Learn lacks a published read model update.

