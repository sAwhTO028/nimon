# Nimon — DTO mapping & API contract prep (Add flow)

**Backend-prep analysis only.** No backend implementation, refactors, or UI changes in this document.

**Aligns with:** `NIMON_ADD_STORY_DRAFT_MODEL_PLAN.md`, `NIMON_ADD_AUTH_OWNERSHIP_PLAN.md`, `NIMON_ADD_STORY_DRAFT_REPOSITORY_PLAN.md`.

**Code references:** `CreatorStoryV1` / `StoryBasics` / `StorySentenceItem` — `lib/features/create/story_v1_model.dart`; persisted JSON keys — `StoryCreatorDraftStorage._toJson` — `lib/features/create/story_creator_draft_storage.dart`.

---

## A. Current app-domain model vs future API model

### What the app uses today

- **Aggregate:** `CreatorStoryV1` with nested `StoryBasics`, `sentences`, `vocabularyKanji`, `grammar`, `quiz`, `audio`, `publishState`, `moduleWorkflowStatuses`.
- **Identity:** `basics.storyId` (UUID) — app treats as **draft id** via `CreatorStoryV1.id`.
- **Owner:** `basics.creatorOwnerId` (often empty pre-auth).
- **Persistence:** Local JSON mirrors domain closely (`publishState` uses `storageKey` strings: `draft`, `reading_only_published`, `full_learn_published`).

### What the API should receive

- **Same information shape**, with naming normalized for HTTP:
  - **`draftId`** instead of **`storyId`** at the top level (keep `storyId` only as deprecated alias in docs if needed for one release).
  - **`ownerId`** omitted on create/update body when derived from **Authorization**; server rejects mismatch if a client sends `ownerId` ≠ token subject.
  - **Strip** device-only fields before upload (local audio paths, etc.).
- **Concurrency:** Optional **`updatedAt`** or **`revision`** / **`etag`** on updates to detect conflicts.

### What the API should return

- **Full draft snapshot:** `StoryDraftResponse` (same structure as GET body) including:
  - `draftId`, `ownerId`, `schemaVersion`, `createdAt`, `updatedAt`
  - Nested `basics`, `sentences`, learn modules, `publishState`, `moduleWorkflowStatuses`
  - **Publish linkage:** `publishedMonoId`, `readingOnlyPublishedAt`, `fullLearnPublishedAt` (nullable until published)
- **Publish:** `PublishResponse` with updated `publishState`, linkage ids, timestamps.

### Naming differences to resolve (lock in API docs)

| App (today) | API (recommended) |
|-------------|-------------------|
| `basics.storyId` | **`draftId`** (resource id) |
| `creatorOwnerId` | **`ownerId`** (server-authoritative) |
| `publishState` keys (`reading_only_published`) | Same string enum **or** camelCase enum values — pick one style in OpenAPI; align with existing `storageKey` for minimal client mapping |
| `coverImageUrl` | **`coverImage.url`** or flat `coverImageUrl` for V1 simplicity |
| `moduleWorkflowStatuses` keys (`vocabulary_kanji`, …) | Keep **same** `storageKey` strings as `LearnModuleId` / `LearnModuleTaskStatus` for zero surprise |

---

## B. DTO mapping plan

Below: **logical DTO names** and fields. Use **JSON** with **camelCase** keys below unless your backend standardizes on snake_case — either is fine if **one convention** is chosen in OpenAPI.

### 1. `CreateDraftRequest`

```json
{
  "draftId": "optional-client-uuid",
  "schemaVersion": 1
}
```

- Server may ignore client `draftId` and assign one; if accepted, return it in response.
- **No** full payload required for minimal create; optional: seed `basics` empty object.

### 2. `UpdateDraftRequest`

Full replacement or PATCH-style — **V1 recommendation:** **PUT** full `StoryDraftPayload` (same shape as `StoryDraftResponse` body without server-only read-only fields if any) for simplicity and to match current local “save whole JSON” behavior.

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-04-21T12:00:00.000Z",
  "basics": { },
  "sentences": [ ],
  "vocabularyKanji": { "entries": [ ] },
  "grammar": { "entries": [ ] },
  "quiz": { "entries": [ ] },
  "audio": { "storyAudio": null },
  "publishState": "draft",
  "moduleWorkflowStatuses": {
    "vocabulary_kanji": "not_started",
    "grammar": "not_started",
    "quiz": "not_started",
    "audio": "not_started"
  }
}
```

- **`If-Match` / `updatedAt`:** Client sends last known `updatedAt`; server returns **409** on conflict.

### 3. `StoryDraftResponse`

`UpdateDraftRequest` payload **plus** server fields:

| Field | Notes |
|-------|--------|
| `draftId` | |
| `ownerId` | From token |
| `createdAt` | |
| `updatedAt` | |
| `schemaVersion` | |
| `publishedMonoId` | nullable |
| `readingOnlyPublishedAt` | nullable |
| `fullLearnPublishedAt` | nullable |
| `basics`, `sentences`, … | Same nested shapes as domain |
| `etag` | Optional HTTP header mirror |

### 4. `PublishReadOnlyRequest`

**V1 minimal:** empty JSON `{}` — all context in URL **`/drafts/{draftId}/publish/read-only`**.  
Optional body for future:

```json
{
  "clientUpdatedAt": "2026-04-21T12:00:00.000Z"
}
```

### 5. `PublishFullLearnRequest`

Same as read-only: **`/drafts/{draftId}/publish/full-learn`** with optional `clientUpdatedAt`.

### 6. `PublishResponse`

```json
{
  "draftId": "...",
  "publishState": "reading_only_published",
  "publishedMonoId": "mono_...",
  "readingOnlyPublishedAt": "...",
  "fullLearnPublishedAt": null,
  "updatedAt": "..."
}
```

- After full learn, `publishState` is `full_learn_published` and both timestamps set as appropriate.

### 7. `ProcessingListItemResponse` (list view / tab)

Lightweight row for “my drafts / processing” — **avoid** shipping full learn payloads.

| Field | Purpose |
|-------|---------|
| `draftId` | |
| `title` | From basics (or “Untitled”) |
| `updatedAt` | |
| `publishState` | Same enum as domain |
| `readinessSummary` | **Server-computed** short string **or** enum: `draft_incomplete` \| `ready_read_only` \| `read_only_published` \| `ready_full_learn` \| `full_learn_published` — **or** omit and let client derive from full draft when opened |
| `primaryActionHint` | Optional: `continue` \| `continue_learn` \| `edit` — mirrors `CreatorProcessingCopy.primaryButton` intent |

**Alternative V1:** Return **`StoryDraftResponse[]`** with **truncated** nested arrays (max counts only) — heavier; prefer `ProcessingListItemResponse` for list endpoint.

### 8. Resume meta sync DTO — **only if needed**

**Default:** **Do not** sync resume meta in V1 API. Keep **`CreatorDraftResumeMeta` device-local.**

If product requires cross-device resume later:

```json
{
  "draftId": "...",
  "lastActiveModule": "story_basics",
  "lastActiveSubPage": "optional",
  "lastEditedAtUtc": "..."
}
```

**Endpoint:** `PUT /drafts/{draftId}/client-meta` — clearly non-authoritative for content.

---

## C. Domain → DTO mapping

### Basics

| `StoryBasics` | DTO `basics` |
|---------------|--------------|
| `storyId` | → **`draftId`** at root; omit duplicate inside `basics` or set `basics.draftId` same value |
| `creatorOwnerId` | → **`ownerId`** on response; omit or ignore on write (token) |
| `title`, `description`, `category`, `level`, `promptSourceNote`, `targetDurationBandKey` | 1:1 |
| `coverImageUrl` | → `coverImageUrl` or `coverImage.url` |
| `createdAt`, `updatedAt` | ISO-8601 strings |

### Sentences

| `StorySentenceItem` | DTO |
|---------------------|-----|
| `id` | `sentenceId` or keep `id` — **pick one**; recommend **`id`** for minimal diff from current JSON |
| `storyId` | Omit in DTO (redundant if nested under draft) or echo `draftId` |
| `orderIndex`, `japaneseText`, `reading`, `furiganaSpans`, `meanings`, `audioStartMs`, `audioEndMs`, `provenance` | 1:1 with snake/camel policy |

### Learn modules

- **`vocabularyKanji`:** `entries[]` — map `examplePairs` as `{ source, english }` per current `_toJson` or normalize to `sourceExample` / `englishExample` in API doc.
- **`grammar` / `quiz`:** same structure as storage JSON.
- **`audio.storyAudio`:** map **remote-safe** fields only; strip locals (below).

### `publishState`

- Enum strings identical to **`StoryPublishState.storageKey`**: `draft`, `reading_only_published`, `full_learn_published`.

### Workflow statuses

- Map `moduleWorkflowStatuses` with keys **`LearnModuleId.storageKey`**, values **`LearnModuleTaskStatus.storageKey`**: `not_started`, `in_progress`, `completed`.

### Owner & timestamps

- **`ownerId`:** Server fills from auth on create; client displays from response.
- **`updatedAt`:** Bump on every successful save server-side; client merges into `StoryBasics.updatedAt` when applying response.

### Publish linkage

- Not in current `CreatorStoryV1` — add to **`StoryDraftResponse`** only; local app merges into repository/cache when remote is wired.

---

## D. Fields that must not go to backend yet (or must be stripped)

| Field / state | Reason |
|---------------|--------|
| `StoryAudioAsset.localPath`, `localFileName`, `localSizeBytes`, `localExtension` | Device paths; replace with **`assetId`** + **`sourceUrl`** after upload pipeline |
| `dirty`, `saveStatus`, `lastSavedAt`, `lastSaveError` | `StoryCreatorDraftState` — client only |
| Scroll position, focused field, transient form state | UI only |
| **`CreatorDraftResumeMeta`** | Local-only until `client-meta` endpoint exists |
| **Derived readiness** (`computeReadOnlyReady` results) | Do not store as authoritative; server may echo **`readinessSummary`** for list UX |

**Provenance** (`ContentProvenance`): Can ship for analytics/AI future; strip internal-only flags if any appear later.

---

## E. API endpoint prep (practical V1)

Base path example: **`/v1/story-drafts`** (name TBD).

| Method | Path | Body | Notes |
|--------|------|------|--------|
| `POST` | `/v1/story-drafts` | `CreateDraftRequest` | Returns `StoryDraftResponse` |
| `GET` | `/v1/story-drafts/{draftId}` | — | Returns `StoryDraftResponse` |
| `PUT` | `/v1/story-drafts/{draftId}` | `UpdateDraftRequest` | Concurrency via `If-Match` / `updatedAt` |
| `GET` | `/v1/story-drafts` | — query: `processing=true` optional | Returns `{ items: ProcessingListItemResponse[] }` or full list |
| `POST` | `/v1/story-drafts/{draftId}/publish/read-only` | `PublishReadOnlyRequest` | Returns `PublishResponse` |
| `POST` | `/v1/story-drafts/{draftId}/publish/full-learn` | `PublishFullLearnRequest` | Returns `PublishResponse` |
| `DELETE` | `/v1/story-drafts/{draftId}` | — | Soft-delete optional later |

**Auth:** `Authorization: Bearer` required for all; **`ownerId`** from token.

---

## F. Processing response contract

**Goal:** Feed Profile **Processing** tab without loading every full draft.

**Option A (simplest):** `GET /v1/story-drafts` returns **`ProcessingListItemResponse[]`** with:

- `draftId`, `title`, `updatedAt`, `publishState`
- **`readinessSummary`:** one of a **small enum** or short string (server may duplicate client rules for consistency)
- **`primaryActionHint`:** optional — reduces duplication of `CreatorProcessingCopy` logic on client **if** server and client rules stay in sync

**Option B:** Client calls list endpoint + **lazy GET** full draft on tap — fewer fields in list DTO, more round trips.

**Recommendation:** **Option A** with **minimal** `readinessSummary` enum; client keeps **`CreatorProcessingCopy`** as fallback if field missing (offline).

**Derived fields** (`computeFullLearnReady` for secondary line): Either recompute client-side after fetch, or add **`secondaryLineHint`** later — **not** required for V1 list.

---

## G. Error contract basics

Minimal JSON body for errors (align with RFC 7807 **Problem Details** if desired):

```json
{
  "type": "https://api.nimon.example/errors/validation",
  "title": "Validation failed",
  "status": 400,
  "detail": "Human-readable summary",
  "instance": "/v1/story-drafts/123",
  "errors": [
    { "field": "sentences[0].japaneseText", "message": "Required" }
  ]
}
```

| HTTP | Meaning | Typical `type` / code |
|------|---------|------------------------|
| **400** | Validation | `validation` — include `errors[]` |
| **401** | Missing/invalid token | `unauthorized` |
| **403** | Not owner of draft | `forbidden` |
| **404** | Unknown `draftId` | `not_found` |
| **409** | Conflict (`updatedAt` / etag) | `conflict` — include server’s latest `StoryDraftResponse` in extension if useful |
| **413 / 415** | Payload too large / bad media | Rare for JSON; use for future uploads |
| **422** | Business rule (e.g. publish while not ready) | `unprocessable_entity` — e.g. “Read-only readiness not met” |

**Upload/media failure** (future): **502** / **424** with `detail` and optional `assetId` — out of scope for pure draft JSON V1.

---

## H. Migration notes (repository + local-first)

1. **Introduce DTOs as Dart classes or `typedef`** mapping **to/from** `CreatorStoryV1` in one **`StoryDraftMapper`** module — **not** inside widgets.
2. **`LocalStoryDraftRepository`** continues to read/write **`CreatorStoryV1`** with no DTO until backend exists.
3. **`RemoteStoryDraftRepository`** implements same repository interface: **HTTP** ⇄ DTO ⇄ **mapper** ⇄ **`CreatorStoryV1`** for the rest of the app.
4. **Strip locals** in mapper on **outbound**; **merge** `publishedMonoId` + timestamps on **inbound** response.
5. **Minimal churn:** Keep internal model **`CreatorStoryV1`** until a rename pass; API uses **`draftId`** at HTTP boundary only.

---

## Top 10 DTO/API decisions to lock now

1. **API primary key name:** **`draftId`** everywhere HTTP-facing; `storyId` deprecated in docs.
2. **`ownerId` from auth** on server — ignore or validate client-supplied owner field.
3. **`publishState` enum strings** match existing **`StoryPublishState.storageKey`** values for trivial mapping.
4. **`moduleWorkflowStatuses` keys** match **`LearnModuleId.storageKey`** / **`LearnModuleTaskStatus.storageKey`**.
5. **PUT full draft** for V1 update — avoids PATCH complexity until needed.
6. **Concurrency:** require **`updatedAt`** or **`If-Match`** on PUT and publish.
7. **Strip** audio **local** fields on outbound; **`sourceUrl` / `assetId`** only when uploaded.
8. **`StoryDraftResponse`** includes **publish linkage** fields absent from current domain — **additive** merge on client.
9. **Processing list** uses **`ProcessingListItemResponse`** — not full aggregate — for performance.
10. **Resume meta:** **out of V1 API** unless product mandates cross-device resume — keep local-only.

---

*End of report.*
