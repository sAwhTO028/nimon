# Nimon — Backend-ready Story Draft data model (Add flow)

**Analysis + schema planning only.** No backend, UI changes, or refactors in this document.

**Primary code references:**

- Aggregate model: `CreatorStoryV1`, `StoryBasics`, `StorySentenceItem`, learn layers, `StoryPublishState`, `LearnModuleId` / `LearnModuleTaskStatus` — `lib/features/create/story_v1_model.dart`
- JSON persistence shape: `StoryCreatorDraftStorage._toJson` / `_fromJson*` — `lib/features/create/story_creator_draft_storage.dart`
- Resume (separate store): `CreatorDraftResumeMeta`, `CreatorLastActiveModule` — same file, bottom section
- Readiness / processing label (mostly **derived**): `computeReadOnlyReady`, `computeFullLearnReady`, `computeProcessingState`, `CreatorProcessingState` — `lib/features/create/creator_readiness.dart`
- In-memory save state (not in draft JSON): `StoryCreatorDraftState` — `lib/features/create/story_creator_provider.dart`

---

## A. Current draft model summary

### What `CreatorStoryV1` contains today

| Area | Types / fields | Notes |
|------|----------------|--------|
| **Identity + basics** | `StoryBasics` | `storyId` (UUID), `title`, `category`, `level`, `description`, `promptSourceNote`, `targetDurationBandKey` (duration band), `coverImageUrl`, `creatorOwnerId`, `createdAt`, `updatedAt` |
| **Sentences** | `List<StorySentenceItem>` | `id`, `storyId`, `orderIndex`, `japaneseText`, legacy `reading`, `furiganaSpans`, `meanings` (`LocalizedMeanings`), `audioStartMs` / `audioEndMs`, `ContentProvenance` |
| **Vocabulary / Kanji** | `VocabularyKanjiLayer` → `VocabularyKanjiEntry[]` | term, type, readings, glosses, `examplePairs` (+ legacy `exampleSentence` / `exampleMeanings` mirrors), provenance |
| **Grammar** | `GrammarLayer` → `GrammarEntry[]` | headline, form, meanings, usage, examples, mistake pairs, related notes, provenance |
| **Quiz** | `QuizLayer` → `QuizEntry[]` | category, prompt, 4 options, correct index, explanations, source note, provenance |
| **Listening / audio** | `AudioLayer` | single `StoryAudioAsset?` (`sourceUrl`, local file metadata, duration, provenance) |
| **Publish** | `StoryPublishState` | `draft` \| `readingOnlyPublished` \| `fullLearnPublished` (JSON: `draft` / `reading_only_published` / `full_learn_published`) |
| **Module workflow** | `moduleWorkflowStatuses` | Per `LearnModuleId`: `notStarted` \| `inProgress` \| `completed` — creator “done” flags, separate from raw content validity |

**Convenience:** `CreatorStoryV1.id` aliases `basics.storyId`.

### Fields that already exist and map well to a backend draft

- **Draft id:** `basics.storyId` (stable UUID).
- **Owner:** `basics.creatorOwnerId` (string; often empty until auth stub — see ownership plan).
- **Timestamps:** `createdAt`, `updatedAt` on basics.
- **Story basics** as above; **sentences** and **learn modules** are structured and JSON-serialized today.
- **Publish state** is first-class on the aggregate.

### Overloaded / unclear / missing

| Issue | Detail |
|-------|--------|
| **`storyId` vs “draft id”** | `StoryBasics.storyId` is both the draft primary key and the parent id for sentences (`StorySentenceItem.storyId`). Naming suggests “published story,” but in practice it is the **draft id**. Backend should treat **`draftId`** as the canonical name; keep `storyId` only as legacy alias or drop in API. |
| **`creatorOwnerId` empty** | Ownership field exists but is not always populated — server must enforce `ownerId` from auth, not trust client-only. |
| **No server linkage** | No `publishedMonoId`, `serverRevision`, or `etag` on the model — required for sync and publish mapping. |
| **`publishState` vs “readiness”** | `StoryPublishState` is persisted; “Processing” UI also uses **`computeProcessingState`** (`CreatorProcessingState`) derived from **content + thresholds** — partially overlaps conceptually with publish state (e.g. “ready for read-only” vs already `readingOnlyPublished`). |
| **`moduleWorkflowStatuses` vs completion rules** | Workflow flags can diverge from `computeFullLearnReady` / `syncModuleWorkflowWithContent` — two sources of “done.” |
| **`CreatorProcessingState` upload enums** | `uploadQueued` / `uploading` / `uploaded` / `uploadFailed` exist in `creator_readiness.dart` but **`computeProcessingState` only returns local states** today — upload lifecycle is **not** persisted on the draft payload. |
| **Resume metadata** | `CreatorDraftResumeMeta` is **stored separately** from draft JSON (good separation); backend may want optional `lastActiveModule` as sync metadata, not as domain truth. |
| **Riverpod-only state** | `dirty`, `saveStatus`, `lastSavedAt`, `lastSaveError` live in `StoryCreatorDraftState` — must not be the canonical draft record. |

### One Short vs Story Creator overlap

- **Story Add flow** uses `CreatorStoryV1` end-to-end (basics → sentences → learn → review/publish).
- **`MonoDraftV1`** (`lib/create_mono/mono_draft_v1.dart`) is a **separate, lighter** line-based mono draft — different aggregate, different persistence path. Any unified “Nimon draft” API should either **explicitly exclude** mono-only drafts or version them as **`contentKind: story | mono`** with different payloads. Do not assume one table fits both without a discriminator.

---

## B. Proposed V1 draft model (backend-ready)

Single logical resource: **`StoryDraft`** (working title). Prefer **normalized DB** + **optional composite JSON** for bulk sync.

### 1) Draft identity & lifecycle

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `draftId` | string (UUID) | yes | Maps to current `basics.storyId`. |
| `ownerId` | string | yes | Maps to `creatorOwnerId`; must match auth subject server-side. |
| `createdAt` | datetime (ISO-8601) | yes | Align with `StoryBasics.createdAt`. |
| `updatedAt` | datetime | yes | Align with `StoryBasics.updatedAt`; bump on any content or workflow change. |
| `schemaVersion` | int | yes | For API evolution (start at `1`). |
| `publishState` | enum | yes | Same semantics as `StoryPublishState`: `draft` \| `reading_only_published` \| `full_learn_published`. |
| `visibility` | enum | optional on draft | For V1, drafts are **private**; can default `private` and omit from client until “preview link” exists. Published mono carries its own visibility. |

### 2) Story basics

| Field | Type | Maps from |
|-------|------|-----------|
| `title` | string | `StoryBasics.title` |
| `description` | string | `StoryBasics.description` |
| `category` | string | `StoryBasics.category` |
| `level` | string (JLPT label) | `StoryBasics.level` |
| `targetDurationBandKey` | string? | `StoryBasics.targetDurationBandKey` (e.g. `3_5`, `5_7`, `7_9`) |
| `promptSourceNote` | string | `StoryBasics.promptSourceNote` |
| `coverImage` | object? | See below |

**Cover representation (backend-friendly):**

```json
{
  "coverImage": {
    "remoteUrl": "https://...",
    "assetId": null,
    "uploadStatus": "pending_upload"
  }
}
```

- Today: `coverImageUrl` string only — sufficient for V1 API; add `assetId` when uploads exist.

### 3) Story sentences

Per row (`draft_sentences`):

| Field | Type | Maps from |
|-------|------|-----------|
| `sentenceId` | string (UUID) | `StorySentenceItem.id` |
| `draftId` | string | FK |
| `orderIndex` | int | `orderIndex` |
| `japaneseText` | string | `japaneseText` |
| `readingLegacy` | string? | `reading` (legacy line; keep for backward compatibility) |
| `furiganaSpans` | array | `{ start, end, reading }` (UTF-16 indices — document in API) |
| `meanings` | object? | `LocalizedMeanings` → `{ en, my, byLanguage }` |
| `audioStartMs` / `audioEndMs` | int? | Optional sentence-level timing |
| `provenance` | object? | `ContentProvenance` |

### 4) Learn modules

Align with `LearnModuleId`: **vocabulary_kanji**, **grammar**, **quiz**, **audio** (listening).

- **Vocabulary / Kanji:** array of entries (current `VocabularyKanjiEntry`); prefer **`examplePairs`** as canonical; keep legacy fields as read-compat only.
- **Grammar:** array of `GrammarEntry`.
- **Quiz:** array of `QuizEntry` (4 options enforced in app — enforce in API validation too).
- **Listening:** single story-level asset (`AudioLayer.storyAudio`) — table `draft_audio` or embedded JSON; local path fields are **device-only** until upload.

### 5) Workflow metadata

| Field | Source | Store in DB? |
|-------|--------|----------------|
| `lastActiveModule` | `CreatorDraftResumeMeta.lastActiveModule` | Optional **client sync metadata** table or column — not required for publish correctness. |
| `lastActiveSubPage` | resume meta | Same — UI convenience. |
| `moduleWorkflowStatuses` | `CreatorStoryV1.moduleWorkflowStatuses` | **Yes** — creator explicit progress; small JSON map or columns per module. |
| `localDraftStatus` | N/A as single field | Prefer **`syncState`** server-side: `clean` \| `dirty` \| `conflict` (client); local-only `saveStatus` stays out of domain. |
| `readinessState` | `computeProcessingState` / readiness results | **Derived** — do not store as source of truth; optionally cache for list views with `readinessVersion` if needed. |
| `moduleCompletionSnapshot` | Could mirror workflow | Prefer **derive from content + thresholds** for audit; if stored, treat as denormalized cache with `updatedAt`. |

### 6) Publish linkage

| Field | Type | Notes |
|-------|------|--------|
| `publishedMonoId` | string? | Set when backend creates reader-visible mono; nullable while draft-only. |
| `readingOnlyPublishedAt` | datetime? | When `publishState` first became `reading_only_published`. |
| `fullLearnPublishedAt` | datetime? | When `publishState` first became `full_learn_published`. |
| `lastPublishError` | string? | Optional; for failed publish retries (server or client). |

**Rule:** `publishState` + timestamps must stay consistent (e.g. if `fullLearnPublishedAt` set, `readingOnlyPublishedAt` should exist and `publishState` ≥ read-only).

---

## C. Separate data vs UI state

### True draft data (canonical — belongs in `StoryDraft` / DB)

- Identity: `draftId`, `ownerId`, `schemaVersion`, timestamps.
- All story basics fields.
- Sentences + learn module content + audio **metadata** (URLs, durations, provenance).
- `publishState` + publish linkage fields (`publishedMonoId`, publish timestamps).
- `moduleWorkflowStatuses` (creator completion flags).

### Local / UI-only (should **not** be the main draft payload on the server)

| State | Where today | Recommendation |
|-------|-------------|----------------|
| `dirty`, `saveStatus`, `lastSaveError` | `StoryCreatorDraftState` | Client-only; server uses `updatedAt` + optimistic locking. |
| `lastSavedAt` (local) | provider | Same. |
| `CreatorDraftResumeMeta` (navigation resume) | separate prefs keys | Optional sync as **`draft_client_meta`**; not authoritative for content. |
| Scroll position, focused field, transient dialog | widgets | Never persist in draft table. |
| In-memory “highlight draft id” for Processing tab | navigation | Not domain. |

### Temporary editing state

- Unsaved form fields before debounced save — client buffer only.
- Plaintext sentence editor buffer before merge — client only until persisted to `StorySentenceItem` list.

### Derived / computed (do **not** store as sole truth)

- `computeReadOnlyReady`, `computeFullLearnReady`, `computeProcessingState` — recomputable from draft + rules in `creator_completion_rules.dart` / `creator_readiness.dart`.
- Display labels (`CreatorLabels`, `CreatorProcessingCopy`) — UI.

**Exception:** Optional **cached** readiness flags on list endpoints for performance — must be invalidated when draft content or rules version changes.

---

## D. Required model cleanup (when you implement — not now)

| Item | Action |
|------|--------|
| `basics.storyId` | **Rename** in API to `draftId` (keep internal alias during migration). |
| `creatorOwnerId` | **Rename** to `ownerId` in DTOs; always set from auth when logged in. |
| `publishState` string keys | Already stable (`storageKey`); keep aligned with server enum. |
| `moduleWorkflowStatuses` | **Keep**; document relationship to `syncModuleWorkflowWithContent`. |
| Legacy vocab `exampleSentence` / `exampleMeanings` | **Keep read path**; **write** prefers `examplePairs` only in new APIs. |
| `StoryAudioAsset.localPath` / local file fields | **Strip or redact** in server payloads; replace with `assetId` + `uploadUrl` after upload. |
| `CreatorProcessingState` upload values | **Move** to a separate **`DraftSyncStatus`** / outbox model when backend exists — not inside canonical draft content. |
| `ContentProvenance` | **Keep** for future AI workflows; optional column or JSON. |

---

## E. Backend-friendly JSON / API shape (illustrative)

### Create draft

`POST /v1/story-drafts`

```json
{
  "draftId": "optional-client-uuid",
  "basics": {
    "title": "",
    "description": "",
    "category": "",
    "level": "",
    "targetDurationBandKey": null,
    "promptSourceNote": "",
    "coverImageUrl": null
  }
}
```

Response: `{ "draftId", "ownerId", "updatedAt", "schemaVersion" }` (server may assign `draftId` if omitted).

### Update draft (full-document sync — matches current local JSON style)

`PUT /v1/story-drafts/{draftId}`

Body: mirror `StoryCreatorDraftStorage` composite shape + `ownerId` omitted (from token) + `schemaVersion` + optional `ifMatch` / `updatedAt` for concurrency.

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-04-21T12:00:00.000Z",
  "basics": { },
  "sentences": [ ],
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

### Publish draft

`POST /v1/story-drafts/{draftId}/publish`

```json
{
  "mode": "reading_only"
}
```

or `{ "mode": "full_learn" }`.

Response:

```json
{
  "draftId": "...",
  "publishState": "reading_only_published",
  "publishedMonoId": "mono_...",
  "readingOnlyPublishedAt": "...",
  "fullLearnPublishedAt": null
}
```

(Adjust enum names to match product naming.)

---

## F. Database mapping suggestion

Practical normalized layout (add columns only where you need querying).

| Table | Purpose |
|-------|---------|
| **`story_drafts`** | `draft_id` (PK), `owner_id`, `schema_version`, `created_at`, `updated_at`, `publish_state`, basics fields (or JSON `basics_json`), `published_mono_id`, `reading_only_published_at`, `full_learn_published_at`, optional `module_workflow_json` |
| **`draft_sentences`** | FK `draft_id`, `sentence_id`, `order_index`, text fields, `meanings_json`, `furigana_json`, `audio_start_ms`, `audio_end_ms`, `provenance_json` |
| **`draft_vocab_entries`** | FK `draft_id`, entry payload JSON or normalized columns |
| **`draft_grammar_entries`** | Same |
| **`draft_quiz_entries`** | Same |
| **`draft_audio`** | FK `draft_id` (0–1 row), URL + metadata; no local path on server |
| **`published_monos`** | `mono_id` (PK), `owner_id`, `source_draft_id` (FK), `visibility`, `tier` (read-only vs full learn), content snapshot or references |

**Optional:** `draft_client_meta` for `last_active_module` + subpage (non-authoritative).

---

## G. Risks in current model

1. **Single-device truth:** SharedPreferences JSON has no multi-device merge — `updatedAt` conflict handling needed for API.
2. **Mixed semantics:** `storyId` naming vs draft-only use confuses API design.
3. **Dual “completion” signals:** `moduleWorkflowStatuses` vs derived readiness — can disagree; backend should define which gates **publish**.
4. **Publish state without server mono id:** Today publish only flips enum locally — no idempotent server publish or rollback.
5. **Sensitive paths in JSON:** `localPath` in audio should never leave device unredacted.
6. **`CreatorProcessingState` upload states** are unused in persistence — risk of fake “synced” UI if not modeled separately later.
7. **One Short / Mono** parallel models risk duplicate product concepts — keep discriminators if you unify “my creations” lists.

---

## H. Recommended next cleanup order (after this plan)

1. **Model cleanup** — Freeze naming: `draftId`, `ownerId`; document `storyId` deprecation; add placeholder DTO fields for `publishedMonoId` + publish timestamps (even if null locally).
2. **Local storage adapter cleanup** — Isolate `StoryCreatorDraftStorage` behind a `StoryDraftRepository` interface; same JSON shape as future API body to reduce mapping.
3. **Repository boundary** — `StoryDraftRepository`: `load`, `save`, `publish` (local now, remote later); readiness stays computed outside.
4. **DTO mapping** — `CreatorStoryV1` ↔ `StoryDraftDto` with explicit strips for local-only audio paths on “export.”
5. **API prep** — OpenAPI sketch for create/update/publish; concurrency via `updatedAt` or ETag.

---

## Top 10 model decisions to lock now

1. **`draftId` is the primary key** — same value as today’s `basics.storyId`; rename in API docs, not necessarily in Dart on day one.
2. **`ownerId` is required** on every server record — populated from auth; client `creatorOwnerId` is the migration field.
3. **`publishState` remains the persisted lifecycle enum** — do not replace with derived readiness alone.
4. **Derived readiness is not stored** as source of truth — only cache optionally for lists.
5. **`publishedMonoId` + publish timestamps** are first-class when backend exists — nullable until first successful publish.
6. **Learn modules stay four buckets** matching `LearnModuleId` — vocabulary/kanji combined layer stays one module until product splits DB.
7. **Resume metadata (`CreatorDraftResumeMeta`) stays out of canonical draft** — optional `client_meta` sync later.
8. **Riverpod save state never becomes the server model** — `dirty` / `saveStatus` remain client-only.
9. **Audio: server stores URLs/asset ids only** — local paths are device-only and stripped for sync.
10. **Mono `MonoDraftV1` is out of scope** for this story-draft schema unless you add explicit `contentKind` and separate tables — avoid silent merging.

---

*End of report.*
