# Nimon Add flow — HTTP API contract **V1**

**Status:** Source of truth for first backend + app integration.  
**JSON:** Field names use **camelCase** unless noted.  
**Auth:** All endpoints require a valid **Bearer** session unless marked; **`ownerId` is always derived from the token subject** — never trusted from client body alone.

---

## 1. Overview

### Add flow backend scope

These APIs support the **creator “Add flow”**: creating and editing a **story draft** locally represented in-app as `CreatorStoryV1`, persisting it remotely, listing it for **Processing**, and **publishing** to Reading Only or Full Learn (with linkage to a published mono resource).

### What this contract covers

- CRUD-style operations for **story drafts** under authenticated users.
- **List** endpoint optimized for Processing / “my drafts”.
- **Publish** transitions (read-only, full learn).
- **Concurrency** for updates.
- **Validation** expectations aligned with current app readiness rules (V1).

### What this contract does **not** cover yet

- Resume / navigation meta (`CreatorDraftResumeMeta`) — **device-local only** in V1; no endpoint.
- Upload of binary media (audio files, images) — assume **URLs** or **future upload tickets**; not specified here.
- Search, admin, or cross-user draft access.
- Webhooks, batch operations, or draft sharing.

---

## 2. Naming rules (locked)

| Name | Meaning |
|------|---------|
| **draftId** | Canonical UUID for the draft resource (equals `basics.storyId` in the app model). |
| **ownerId** | Authenticated user id owning the draft; **server-authoritative** from auth. |
| **publishState** | String enum — see §3 (matches app `StoryPublishState.storageKey`). |
| **publishedMonoId** | Server id of the published mono story after publish (nullable until published). |
| **createdAt** | ISO-8601 UTC timestamp when the draft record was created. |
| **updatedAt** | ISO-8601 UTC timestamp of last successful content or publish mutation. |
| **moduleWorkflowStatuses** | Map: **learn module id** → **task status** (see §3). Keys use app `LearnModuleId.storageKey` strings. |
| **vocabularyKanji** | Object with **`entries`** array (vocab/kanji layer). |
| **grammar** | Object with **`entries`** array. |
| **quiz** | Object with **`entries`** array. |
| **audio** | Object with optional **`storyAudio`** (single track metadata). |

**Nested `basics`:** includes **`storyId`** (must equal **draftId**), plus title, category, level, description, etc. **`ownerId` inside `basics`** must match the authenticated owner when present; server may omit on responses in favor of top-level **ownerId**.

---

## 3. Enums (exact allowed values)

### publishState

| Value | Meaning |
|-------|---------|
| `draft` | Editable draft; not reading/full published. |
| `reading_only_published` | Reading-only publish completed. |
| `full_learn_published` | Full Learn publish completed. |

### Learn module ids (`moduleWorkflowStatuses` keys)

| Key |
|-----|
| `vocabulary_kanji` |
| `grammar` |
| `quiz` |
| `audio` |

### Learn module task statuses (values)

| Value |
|-------|
| `not_started` |
| `in_progress` |
| `completed` |

### Processing list: readinessSummary (optional server-computed)

| Value | Typical meaning |
|-------|-----------------|
| `draft_incomplete` | Core story / basics incomplete. |
| `ready_read_only` | Meets read-only readiness; not yet published RO. |
| `read_only_published` | RO published; Full Learn not done. |
| `ready_full_learn` | Meets full-learn readiness. |
| `full_learn_published` | Full Learn published. |

### Processing list: primaryActionHint (optional)

| Value |
|-------|
| `continue` |
| `continue_learn` |
| `edit` |

### Visibility

**Not used in V1** list/detail contract — omit unless product adds a visibility field later.

---

## 4. Endpoints

Base path: **`/v1/story-drafts`**

All paths below are relative to the API host.  
**Content-Type:** `application/json` for bodies.

---

### A. `POST /v1/story-drafts`

**Purpose:** Create a new empty (or client-seeded) draft.

**Auth:** Required.

#### Request body

| Field | Required | Description |
|-------|----------|-------------|
| `schemaVersion` | Yes | Must be `1` for V1. |
| `draftId` | No | Client-proposed UUID; server may accept or assign its own. |
| `basics` | No | If omitted, server initializes empty basics with generated `storyId` = `draftId`. |

#### Example request

```json
{
  "schemaVersion": 1,
  "draftId": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Response `201 Created`

Body: **StoryDraftResponse** (§7).  
Headers: **`ETag`** (see §11).

#### Example response

```json
{
  "draftId": "550e8400-e29b-41d4-a716-446655440000",
  "ownerId": "user_abc123",
  "schemaVersion": 1,
  "etag": "\"a1b2c3d4\"",
  "createdAt": "2026-04-21T12:00:00.000Z",
  "updatedAt": "2026-04-21T12:00:00.000Z",
  "basics": {
    "storyId": "550e8400-e29b-41d4-a716-446655440000",
    "ownerId": "user_abc123",
    "title": "",
    "category": "",
    "level": "",
    "description": "",
    "promptSourceNote": "",
    "targetDurationBandKey": null,
    "coverImageUrl": null,
    "createdAt": "2026-04-21T12:00:00.000Z",
    "updatedAt": "2026-04-21T12:00:00.000Z"
  },
  "sentences": [],
  "vocabularyKanji": { "entries": [] },
  "grammar": { "entries": [] },
  "quiz": { "entries": [] },
  "audio": { "storyAudio": null },
  "publishState": "draft",
  "moduleWorkflowStatuses": {
    "vocabulary_kanji": "not_started",
    "grammar": "not_started",
    "quiz": "not_started",
    "audio": "not_started"
  },
  "publishedMonoId": null,
  "readingOnlyPublishedAt": null,
  "fullLearnPublishedAt": null
}
```

---

### B. `GET /v1/story-drafts/:draftId`

**Purpose:** Load one full draft.

**Auth:** Required. **404** if draft missing or not owned by caller.

#### Request body

None.

#### Response `200 OK`

Body: **StoryDraftResponse** (§7).  
Headers: **`ETag`**.

#### Example response

Same shape as §7 example; content reflects stored draft.

---

### C. `PUT /v1/story-drafts/:draftId`

**Purpose:** Replace full draft content (same shape as app “save whole JSON”).

**Auth:** Required.

#### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `If-Match` | Yes | **ETag** from last `GET`/`POST`/`PUT` response (§11). |

#### Request body

Full **StoryDraftWrite** payload (content fields + `schemaVersion`; see below).  
**Must not** set **`ownerId`** to a value different from the authenticated user — server rejects (**403**).

**StoryDraftWrite** (PUT body — server fields omitted)

| Field | Required | Description |
|-------|----------|-------------|
| `schemaVersion` | Yes | `1` |
| `basics` | Yes | Includes `storyId` = path `draftId`. |
| `sentences` | Yes | Array (may be empty). |
| `vocabularyKanji` | Yes | `{ "entries": [ ... ] }` |
| `grammar` | Yes | `{ "entries": [ ... ] }` |
| `quiz` | Yes | `{ "entries": [ ... ] }` |
| `audio` | Yes | `{ "storyAudio": null | { ... } }` |
| `publishState` | Yes | Enum string. |
| `moduleWorkflowStatuses` | Yes | Map with all four keys. |

**Strip before send (client):** local-only audio paths, device-only fields per app mapper (`StoryDraftMapper.fromDomainRemoteSafe` policy).

#### Example request

```json
{
  "schemaVersion": 1,
  "basics": {
    "storyId": "550e8400-e29b-41d4-a716-446655440000",
    "ownerId": "user_abc123",
    "title": "雨上がり",
    "category": "fiction",
    "level": "N4",
    "description": "…",
    "promptSourceNote": "",
    "targetDurationBandKey": "5_7",
    "coverImageUrl": null,
    "createdAt": "2026-04-21T12:00:00.000Z",
    "updatedAt": "2026-04-21T14:30:00.000Z"
  },
  "sentences": [],
  "vocabularyKanji": { "entries": [] },
  "grammar": { "entries": [] },
  "quiz": { "entries": [] },
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

#### Response `200 OK`

Body: **StoryDraftResponse** including new **`updatedAt`** and **`etag`**.

---

### D. `GET /v1/story-drafts`

**Purpose:** List current user’s drafts for **Processing** (lightweight rows).

**Auth:** Required.

#### Query parameters (optional V1)

| Param | Description |
|-------|-------------|
| `limit` | Max items (default e.g. 50, max 100). |
| `cursor` | Opaque pagination cursor (optional). |

#### Response `200 OK`

Body:

```json
{
  "items": [ /* ProcessingListItemResponse, §8 */ ],
  "nextCursor": null
}
```

---

### E. `POST /v1/story-drafts/:draftId/publish/read-only`

**Purpose:** Transition draft to **Reading Only** published (server validates readiness).

**Auth:** Required.

#### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `If-Match` | Yes | Current draft **ETag**. |

#### Request body

Optional empty object, or optional concurrency hint:

```json
{}
```

Optional:

```json
{
  "clientUpdatedAt": "2026-04-21T14:30:00.000Z"
}
```

(`clientUpdatedAt` is **not** a substitute for `If-Match` in V1.)

#### Response `200 OK`

**PublishResponse** shape:

```json
{
  "draftId": "550e8400-e29b-41d4-a716-446655440000",
  "publishState": "reading_only_published",
  "publishedMonoId": "mono_xyz789",
  "readingOnlyPublishedAt": "2026-04-21T15:00:00.000Z",
  "fullLearnPublishedAt": null,
  "updatedAt": "2026-04-21T15:00:00.000Z",
  "etag": "\"e5f6g7h8\""
}
```

---

### F. `POST /v1/story-drafts/:draftId/publish/full-learn`

**Purpose:** Transition to **Full Learn** published (server validates full-learn readiness).

**Auth:** Required.

#### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `If-Match` | Yes | Current draft **ETag**. |

#### Request body

Same as read-only (optional `{}`).

#### Response `200 OK`

```json
{
  "draftId": "550e8400-e29b-41d4-a716-446655440000",
  "publishState": "full_learn_published",
  "publishedMonoId": "mono_xyz789",
  "readingOnlyPublishedAt": "2026-04-21T15:00:00.000Z",
  "fullLearnPublishedAt": "2026-04-21T16:00:00.000Z",
  "updatedAt": "2026-04-21T16:00:00.000Z",
  "etag": "\"i9j0k1l2\""
}
```

---

## 7. StoryDraftResponse (canonical full draft)

Top-level object returned by `GET`, `POST` create, and `PUT` success.

| Field | Type | Notes |
|-------|------|--------|
| `draftId` | string | UUID |
| `ownerId` | string | From auth |
| `schemaVersion` | number | `1` |
| `etag` | string | Opaque, for `If-Match` |
| `createdAt` | string | ISO-8601 UTC |
| `updatedAt` | string | ISO-8601 UTC |
| `basics` | object | See nested basics schema (storyId, title, …) |
| `sentences` | array | Ordered by `orderIndex` |
| `vocabularyKanji` | object | `{ "entries": [ ... ] }` |
| `grammar` | object | `{ "entries": [ ... ] }` |
| `quiz` | object | `{ "entries": [ ... ] }` |
| `audio` | object | `{ "storyAudio": ... }` |
| `publishState` | string | §3 |
| `moduleWorkflowStatuses` | object | §3 |
| `publishedMonoId` | string \| null | After publish |
| `readingOnlyPublishedAt` | string \| null | ISO-8601 UTC |
| `fullLearnPublishedAt` | string \| null | ISO-8601 UTC |

Nested shapes **match** the app’s persisted JSON (see `StoryCreatorDraftStorage` / `StoryDraftMapper` in the codebase). V1 does not redefine every nested field here — **parity with `StoryDraftDto` / local JSON** is the contract.

**Example:** see §4.A response.

---

## 8. ProcessingListItemResponse (lightweight list item)

Used inside `GET /v1/story-drafts` → `items[]`.

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `draftId` | string | Yes | |
| `title` | string | Yes | Display title; `"Untitled draft"` if empty server-side |
| `updatedAt` | string | Yes | ISO-8601 UTC |
| `publishState` | string | Yes | §3 |
| `readinessSummary` | string | No | §3 enum |
| `primaryActionHint` | string | No | §3 enum |

#### Example item

```json
{
  "draftId": "550e8400-e29b-41d4-a716-446655440000",
  "title": "雨上がり",
  "updatedAt": "2026-04-21T14:30:00.000Z",
  "publishState": "draft",
  "readinessSummary": "ready_read_only",
  "primaryActionHint": "continue"
}
```

---

## 9. Validation rules (V1)

| Rule | Detail |
|------|--------|
| **Read-only publish** | **Basics** complete: non-empty title, category, level, description; **targetDurationBandKey** set per product rule. **At least one** sentence valid (non-empty Japanese text). Aligns with app “read only ready”. |
| **Full-learn publish** | **All** `moduleWorkflowStatuses` values are `completed`. Aligns with app “all learn modules marked completed” + data readiness (server may re-validate module content). |
| **Quiz entries** | Each MCQ has **exactly 4** `options`; `correctIndex` in `0..3`; non-empty trimmed options. |
| **ownerId** | Taken from **auth**; if request body includes `ownerId` / `basics.ownerId`, must **equal** token subject or **403**. |
| **draftId / storyId** | `basics.storyId` must equal path `draftId`. |

---

## 10. Error contract

All errors use a **single JSON envelope**:

```json
{
  "error": {
    "code": "string_machine_code",
    "message": "Human-readable message",
    "details": {}
  }
}
```

`details` is optional object (field errors, current etag, etc.).

### HTTP status mapping

| Status | Meaning | Example `code` |
|--------|-----------|----------------|
| **400** | Malformed JSON / bad type | `validation_error` |
| **401** | Missing or invalid token | `unauthorized` |
| **403** | Authenticated but cannot access or owner mismatch | `forbidden` |
| **404** | Draft not found | `not_found` |
| **409** | Conflict (concurrency) | `conflict` |
| **422** | Semantic validation failed (readiness, quiz shape) | `unprocessable_entity` |

### Example: validation (400)

```json
{
  "error": {
    "code": "validation_error",
    "message": "quiz.entries[0].options must have length 4",
    "details": { "field": "quiz.entries[0].options" }
  }
}
```

### Example: unauthorized (401)

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

### Example: forbidden (403)

```json
{
  "error": {
    "code": "forbidden",
    "message": "ownerId does not match authenticated user"
  }
}
```

### Example: not found (404)

```json
{
  "error": {
    "code": "not_found",
    "message": "Draft not found"
  }
}
```

### Example: conflict (409)

```json
{
  "error": {
    "code": "conflict",
    "message": "Draft was modified; refresh and retry",
    "details": { "currentEtag": "\"x7y8z9\"" }
  }
}
```

### Example: unprocessable (422)

```json
{
  "error": {
    "code": "unprocessable_entity",
    "message": "Read-only publish requirements not met",
    "details": { "unmet": ["description_empty"] }
  }
}
```

---

## 11. Concurrency rule (V1)

**Strategy: `ETag` + `If-Match` (opaque)**

1. Every **`GET` / `POST` / `PUT` / publish** success returns a strong **`ETag`** header (and duplicates **`etag`** in JSON body for mobile convenience).
2. **`PUT`** and **`POST .../publish/...`** require header:  
   `If-Match: <etag>`  
   where `<etag>` is the **exact** value from the last successful read of that draft (quotes included if server uses quoted etags).
3. If the resource changed since that ETag: respond **`409 Conflict`** with **`error.code`: `conflict`** and optional `currentEtag` in `details`.

**Rationale:** Clear HTTP semantics; avoids clock skew on `updatedAt` alone; client already tracks full draft snapshots.

---

## 12. Notes for frontend mapping

- **`CreatorStoryV1`** maps to **StoryDraftResponse** / write payloads via **`StoryDraftMapper`** (`fromDomain` / `toDomain`); use **`fromDomainRemoteSafe`** (or equivalent) before upload to **omit local-only audio paths** and non-HTTP `sourceUrl` values.
- **Resume meta** (`CreatorDraftResumeMeta`) **does not** appear in this API in V1.
- **Riverpod** continues to own in-memory state; a future **`RemoteStoryDraftRepository`** will call these endpoints and merge results into the same domain model.

---

## A. Top 10 contract decisions locked now

1. **Base path:** `/v1/story-drafts`.
2. **JSON naming:** camelCase keys throughout.
3. **IDs:** **`draftId`** is the resource id; **`basics.storyId` must match `draftId`**.
4. **Owner:** **`ownerId` from auth**; client values are not authoritative.
5. **Publish states:** exactly three strings (`draft`, `reading_only_published`, `full_learn_published`).
6. **Module keys:** `vocabulary_kanji`, `grammar`, `quiz`, `audio` only.
7. **Module statuses:** `not_started`, `in_progress`, `completed`.
8. **Full draft list vs detail:** list uses **ProcessingListItemResponse**; detail uses **StoryDraftResponse**.
9. **Concurrency:** **ETag + If-Match**; **409** on mismatch.
10. **Errors:** unified **`error.code` / `message` / `details`** envelope.

---

## B. Open questions still not decided

- **Pagination:** cursor format and default `limit` (suggested defaults only; server may tune).
- **Media upload:** how `coverImageUrl` / `storyAudio.sourceUrl` get populated (direct upload vs signed URL).
- **Mono linkage:** full schema of **`publishedMonoId`** and reader URLs.
- **Rate limits / quotas** per user.
- **Soft delete** vs hard delete for drafts (not in V1 endpoints above).
- **Partial update (PATCH):** intentionally omitted in V1; may be added later.

---

*End of Nimon Add API contract V1.*
