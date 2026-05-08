# M5 Media Upload And Published Editing Plan

**Status:** Product / engineering plan — **documentation only** (no code or migrations in this file).  
**Inputs:** [M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md](M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md), [CREATOR_LISTENING_ADD_AUDIO_AUDIT.md](CREATOR_LISTENING_ADD_AUDIO_AUDIT.md), [CREATOR_LISTENING_AUDIO_URL_FIX_REPORT.md](CREATOR_LISTENING_AUDIO_URL_FIX_REPORT.md), [DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md](DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md), [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md), [M4_FULL_LEARN_CLOSEOUT_REPORT.md](M4_FULL_LEARN_CLOSEOUT_REPORT.md), current Flutter profile/mono/create modules and Nest story-drafts / published-monos / mono-feed.

---

## 1. Executive Summary

**URL-only audio and cover are not sufficient for release-quality UX.** Creators expect to **pick a file** (gallery / file picker) and have it **reliably appear** after save and for readers after publish. Today:

- **Audio:** Local attach uses paths / `local://` placeholders; **`fromDomainRemoteSafe`** strips non-https `sourceUrl`; post-PUT domain replace often clears **`isValidV1`** until the user pastes a **public http(s) URL** ([CREATOR_LISTENING_ADD_AUDIO_AUDIT.md](CREATOR_LISTENING_ADD_AUDIO_AUDIT.md)).
- **Cover:** Local file never becomes **`coverImageUrl`** on the draft wire payload; Story Basics autosave can pass **`coverImageUrl: null`**; publish copies **`core.coverImageUrl`** only when the draft holds an **https** URL ([M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md](M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md)).

**M5** adds a **small, explicit upload pipeline** (backend + Flutter) so drafts store **stable https URLs**, reusing existing JSON fields where possible. In parallel, **published editing visibility** must align with product: while a creator edits an already-published story, that story should **disappear from public Mono Home** and **Profile Published**, remain **visible in Workspace as Editing**, and **reappear after republish**. That contradicts the current documented/app rule that **backend Published rows stay visible** during editing ([NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md)) and **`profile_screen.dart`** explicitly **never hides** `isBackendPublished` rows when Workspace is “Editing” — so **M5 visibility work is a deliberate policy + implementation change**.

---

## 2. Current Audio Flow

| Stage | Behavior |
|-------|----------|
| **Creator UI** | **`StoryCreatorAudioEditorScreen`** / **`StoryCreatorListeningModuleBody`**: picker → **`setStoryAudioFromPickedFile`** ([CREATOR_LISTENING_ADD_AUDIO_AUDIT.md](CREATOR_LISTENING_ADD_AUDIO_AUDIT.md)). |
| **Local file path** | **`sourceUrl`** set to **`local://…`** or device path; **`localPath`** / metadata populated; **`isValidV1`** true locally. |
| **Public URL** | **`setStoryAudio`** validates **http(s)** ([CREATOR_LISTENING_AUDIO_URL_FIX_REPORT.md](CREATOR_LISTENING_AUDIO_URL_FIX_REPORT.md)); survives **`fromDomainRemoteSafe`**. |
| **Remote save** | **`StoryDraftMapper.fromDomainRemoteSafe`** strips local-only audio fields; only **http(s)** **`sourceUrl`** kept on wire; PUT replaces draft from server echo → local attach often “disappears” until URL is https. |
| **Published snapshot** | **`publishFullLearn`** copies **`draft_audio`** **`content`** into **`published_monos.content.learn.audio.storyAudio`** ([`story-drafts.service.ts`](nimon-backend/src/modules/story-drafts/story-drafts.service.ts)). Without https URL, readers see **unavailable** ([M4_FULL_LEARN_CLOSEOUT_REPORT.md](M4_FULL_LEARN_CLOSEOUT_REPORT.md)). |
| **Reader playback** | **`publishedStoryAudioHttpUrl`** — **http/https** only ([M4B3D_LISTENING_HYDRATION_REPORT.md](M4B3D_LISTENING_HYDRATION_REPORT.md)). |

---

## 3. Current Cover Image Flow

| Stage | Behavior |
|-------|----------|
| **Story Basics UI** | **`CreateStoryBasicsForm`**: **`ImagePicker`**, **`_coverLocalPath`** / web bytes / optional network URL ([M4 audit §5](docs/M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md)). |
| **Local preview** | **`Image.file` / `Image.memory`**. |
| **`coverImageUrl` on draft** | **`_coverImageUrlForDraft()`** returns **null** for normal device paths; only **http(s)** path or **`_coverNetworkUrl`**. |
| **Autosave** | **`StoryCreatorBasicsScreen._handleAutosaveDraftFields`** passes **`coverImageUrl: null`** (“not persisted as local path in V1”). |
| **Remote save** | Mapper does **not** strip cover like audio; if **`coverImageUrl`** is null on PUT payload, server stores null. |
| **Publish** | **`publishReadOnly`** writes **`content.core.coverImageUrl`** from **`draft.coverImageUrl`** ([`published-mono-common.ts`](nimon-backend/src/modules/published-monos/published-mono-common.ts) derives list **`coverImageUrl`** from **`core`**). |
| **Mono feed / Profile** | **`coverUrl`** / **`coverImageUrl`** from **`content.core.coverImageUrl`** — empty if draft never held an **https** URL. |

---

## 4. Desired Media Upload Product Behavior

1. User picks **audio** or **cover** file (within **size / mime** policy).
2. App **uploads** bytes to **trusted backend or signed storage**.
3. Backend returns a **stable, publicly readable https URL** (time-limited signed URLs acceptable only if the app re-uploads or refreshes before publish — **prefer durable public or CDN path for V1 reader simplicity**).
4. Client writes URL into **`StoryDraft`** fields already used today: **`coverImageUrl`** (basics), **`audio.storyAudio.sourceUrl`** (learn wire).
5. **Publish** flows unchanged in shape: snapshot copies **URLs** into **`PublishedMono.content`** as today.
6. **Mono feed, Profile lists, Listening** consume the same **https** strings — no local path in production paths.

---

## 5. Backend Upload Design Options

| Option | Pros | Cons |
|--------|------|------|
| **A. Local filesystem + static serving (dev)** | Fast to ship; no cloud account | Not viable for production scale/security; host-dependent URLs |
| **B. S3 / R2 / Supabase Storage (presigned PUT or POST)** | Production-grade; CDN-friendly; scales | Bucket setup, CORS, IAM; client must handle presign + PUT |
| **C. Multipart POST to Nest → stream to object storage** | Single auth model (JWT); easier Flutter client | Server memory/limit discipline; still need storage backend |

**Recommendation**

- **Dev / local:** **A** acceptable for **developer testing only** (e.g. `uploads/` + `/static` or Nest `ServeStaticModule`) with **clear env flag** so staging/prod never rely on it.
- **Release:** **B or C** with **object storage** (R2/S3/Supabase). **Practical V1:** **Presigned upload (B)** keeps heavy files off the API server; **C** is acceptable if max body size is strict and files stream to the same bucket.

---

## 6. Database / Prisma Impact

**Existing fields are enough to store resulting URLs** (no new column strictly required for “URL pointer”):

| Field | Role |
|-------|------|
| **`StoryDraft.coverImageUrl`** | Basics cover URL after upload |
| **`draft_audio.content`** (JSON) **`sourceUrl`** | Story audio URL after upload |
| **`PublishedMono.content.core.coverImageUrl`** | Read-only / merged core on publish |
| **`PublishedMono.content.learn.audio.storyAudio`** | Full-learn learn snapshot |

**Optional future:** **`MediaAsset`** table (ownerId, draftId, kind, storageKey, url, createdAt) for **audit, dedup, delete-on-unpublish** — **not required for V1** if product accepts “orphan objects in bucket” or periodic GC.

**Migrations:** Upload feature can ship **without** Prisma migration if only URLs are persisted in existing JSON/string fields. **Published visibility** (below) may introduce **one boolean or enum** — see §10.

---

## 7. API Design (Proposal)

Unified pattern (adjust paths to Nest module layout):

**Authenticated** (`Authorization: Bearer`):

| Endpoint | Purpose |
|----------|---------|
| **`POST /v1/media/upload/cover`** | `multipart/form-data`: **`file`**; response **`{ url, mediaType, originalName, sizeBytes }`** |
| **`POST /v1/media/upload/audio`** | Same; optional server-side **durationSeconds** via probe |

**Or presigned:**

| Endpoint | Purpose |
|----------|---------|
| **`POST /v1/media/presign`** | Body `{ kind: 'cover' \| 'audio', contentType, sizeBytes }` → **`{ uploadUrl, headers?, objectKey, expiresAt }`** |
| Client **`PUT`** binary to **`uploadUrl`**, then **`GET`** final public **`url`** from **`POST /v1/media/complete`** with **`objectKey`** — only if using temporary uploads |

**Constraints (document in OpenAPI):**

- **Max size** (e.g. cover 5–10 MB, audio 20–50 MB — product decision).
- **Mime allowlist** (e.g. cover: `image/jpeg`, `image/png`, `image/webp`; audio: `audio/mpeg`, `audio/mp4`, `audio/wav`).
- **Auth:** owner-only; optional **draftId** query for future ACL.

**Response shape (success):**

```json
{
  "url": "https://cdn.example/…",
  "mediaType": "audio/mpeg",
  "originalName": "lesson.mp3",
  "sizeBytes": 1234567,
  "durationSeconds": null
}
```

---

## 8. Flutter Upload Plan

- **Pick file:** existing pickers; after pick, **upload** before treating as “saved”.
- **Progress:** `Stream<double>` or chunked **`dio/http`** with **`CircularProgressIndicator`** on Basics / Audio sheets.
- **Errors:** network, 413, 415, 401 → **SnackBar** + **retry**; do not write broken **`sourceUrl`**.
- **On success:** call **`setStoryAudio`** / **`applyBasics`** with returned **`url`**; then **`persistLocalNow`** / debounced save so remote draft holds https.
- **Preview:** cover **`Image.network`**; audio **short preview** via **`just_audio`** with returned URL (optional).
- **Remove:** clear URL and optionally **delete remote object** if API supports (P2).

---

## 9. Published Editing Visibility Policy (Desired)

When user taps **Edit** on an **already published** mono (reader or Profile):

| Surface | Desired |
|---------|---------|
| **Mono Home feed** | **Hidden** for that PublishedMono until next successful publish |
| **Profile → Published tab** | **Hidden** (same row) while **Editing** |
| **Profile → Workspace** | **Shown** as **Editing** (already driven by **`workspaceState` / dirty** for drafts) |
| **After republish** | **Visible** again in feed + Published |

**Clarifications**

- **Do not delete** **`PublishedMono`** on “Edit” — keep row for **id stability**, **Learn URLs**, **analytics**; **visibility** is a **query/filter** concern (or a flag).
- **Mono feed** must **filter** rows that are “under active unpublished edit” — not only owner’s client hiding.
- **Profile Published** list should **hide** the backend row matching **`sourceDraftId`** when that draft is **`editing`** (today code **explicitly does not hide** backend rows — see §11).

---

## 10. Backend State Model For Published Editing

**Existing ([DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md](DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md))**

- **`StoryDraft.publishState`**: `draft` | `reading_only_published` | `full_learn_published`
- **`StoryDraft.hasUnpublishedCoreChanges`**: `true` after **`updateDraft`** when published, until publish clears it
- **`PublishedMono`**: no dedicated **visibility** column in [schema](nimon-backend/prisma/schema.prisma); **`content`** JSON only

**Gap:** **`MonoFeedService`** lists **all** `published_monos` matching level/category/cursor — **no join** to **`story_drafts`** ([`mono-feed.service.ts`](nimon-backend/src/modules/mono-feed/mono-feed.service.ts)).

**Recommended minimal approach (safest for public catalog)**

1. **Derive “hidden from public catalog”** from linked draft:  
   **`EXISTS story_drafts WHERE publishedMonoId = published_monos.id AND hasUnpublishedCoreChanges = true`**  
   → **exclude** from **`GET /v1/mono/feed`** (and any public list).  
   - **Republish** sets **`hasUnpublishedCoreChanges = false`** → row **reappears**.  
   - **No second source of truth** if you trust dirty flag semantics.

2. **Alternative:** **`PublishedMono.content.catalogListingHidden: boolean`** set by server on first post-publish edit and cleared on publish — duplicates dirty semantics; **avoid unless** dirty flag cannot represent “edit published” reliably.

3. **Do not** rely on Flutter-only hiding for Mono Home — **other users** would still see stale rows.

**Owner Profile `GET /v1/published-monos`:** Apply **same filter** for consistency, **or** owner sees “draft editing” only in Workspace — product choice: **hide from Published tab** for owner too (matches §9).

---

## 11. Flutter Published Edit Flow (Audit)

- **Edit** from reader: **`mono_story_options_sheet`** → **`CreatorDraftResumeFlow.tryResumeFromPublishedSurface`** ([`creator_resume_draft.dart`](lib/features/create/creator_resume_draft.dart)) opens **`/create/...`** with **`draftId`** aligned to **`sourceDraftId`**.
- **Profile Published loose card Edit:** same resume helper ([`profile_screen.dart`](lib/features/profile/profile_screen.dart)).
- **Workspace state:** From **`GET /v1/story-drafts`** summaries — **`workspaceState: editing`** when published + **`hasUnpublishedCoreChanges`** ([DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md](DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md)).
- **Profile Published hide:** **`_hidePublishedItemForWorkspaceEditing`** returns **`false` whenever `it.isBackendPublished`** — i.e. **real API Published rows are never hidden** when Workspace shows Editing ([`profile_screen.dart` ~468–477](lib/features/profile/profile_screen.dart)). **This must change for M5e** if §9 is accepted.
- **Refresh:** Pagers **`profilePublishedMonoPagerProvider`**, **`monoFeedPagerProvider`** — need **invalidate on resume/edit** if filtering stays client-side for Profile only (prefer **server filter** for feed).

---

## 12. Tests Needed

**Backend**

- Upload endpoint: auth, size, mime, happy path URL returned.
- **Mono feed exclusion:** seed **`published_monos` + story_drafts`** with **`hasUnpublishedCoreChanges true`** → row **absent** from feed; after **publish** mock → **present**.
- **Owner list** (if filtered): same.

**Flutter**

- Upload success → draft model contains https → remote save round-trip keeps **`hasUploadedSourceUrl`** / cover display.
- Widget/integration: **Published row hides** when summary **`editing`** (after policy change + API).
- **Workspace** shows **Editing** chip (existing DTO tests extended).
- **Republish** clears dirty → row visible again (mock server).

---

## 13. Recommended Implementation Split

| Milestone | Scope |
|-----------|--------|
| **M5a** | This plan + API sketch sign-off (done). |
| **M5b** | Nest: storage config, upload or presign routes, validation, **optional** static dev fallback. |
| **M5c** | Flutter: wire upload from Basics + Audio editors, progress/error, write URLs to draft. |
| **M5d** | Nest: **mono-feed** (+ optional **published-monos list**) **exclude** “dirty linked draft”; contract tests. |
| **M5e** | Flutter: Profile Published hide **backend** rows when editing; refresh/invalidate; align with **NIMON_V1** doc update. |
| **M5f** | Smoke: pick file → upload → publish → reader sees cover/audio; edit → gone from feed → republish → back. |

---

## 14. Exact Cursor Prompt For M5b

> Implement **M5b — backend media upload** for Nimon NestJS.  
> **Goals:** Authenticated creators upload **cover** and **story audio** files; receive **stable https URLs** suitable for storing in existing **`StoryDraft.coverImageUrl`** and **`draft_audio.content.sourceUrl`**.  
> **Constraints:** Follow existing **`Jwt`** / owner patterns used in **`story-drafts`** module. Add env-driven storage: **dev** may use local disk + static URL prefix; **prod** uses **S3-compatible** (env: bucket, region, endpoint, credentials) with **public-read objects** or **CloudFront-style base URL** documented in **README**.  
> **Endpoints:** `POST /v1/media/upload/cover` and `POST /v1/media/upload/audio` with **`multipart/form-data`**, fields **`file`**, max size + mime validation, response **`{ url, mediaType, originalName, sizeBytes, durationSeconds? }`**. Log upload failures; never persist file paths in DB.  
> **Tests:** Supertest or Nest e2e — rejects unauthenticated, rejects bad mime, returns 200 with JSON containing **https** **`url`** (mock S3 with **msw** or local fs in dev).  
> **Do not** change **`publishReadOnly` / `publishFullLearn`** snapshot shapes beyond existing URL fields.

---

## 15. Exact Cursor Prompt For M5d

> Implement **M5d — hide publicly listed PublishedMono rows while linked draft has unpublished edits.**  
> **Context:** **`StoryDraft.hasUnpublishedCoreChanges`** is **`true`** after **`updateDraft`** when **`publishState !== draft`** until publish clears it ([DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT](docs/DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md)). **`MonoFeedService`** currently lists **all** matching **`published_monos`**.  
> **Requirements:**  
> (1) **`MonoFeedService.listFeed`** (public catalog): **`WHERE NOT EXISTS`** **`story_drafts`** with **`publishedMonoId = published_monos.id`** **`AND`** **`hasUnpublishedCoreChanges = true`**. Use efficient Prisma (`relation`, `none`, or raw).  
> (2) **`getPublicMonoById`:** Return **404** **`published_mono_not_found`** when that exclusion applies **OR** document **403 hidden** — pick one consistently (prefer **404** for “not in catalog”).  
> (3) Owner **`GET /v1/published-monos`** list: **same exclusion** so Profile Published stays aligned with §9 (confirm with product).  
> (4) **Tests:** Seed prisma **`publishedMono` + `storyDraft`** linked; dirty true → feed empty detail 404; publish clears dirty → appears.  
> **Do not** delete **`PublishedMono`** on edit. **No** Flutter in this task.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **URL-only audio acceptable for release?** | **No** — creators expect file attach; URL-only is **stopgap** ([CREATOR_LISTENING_ADD_AUDIO_AUDIT.md](CREATOR_LISTENING_ADD_AUDIO_AUDIT.md)). |
| **Cover needs upload?** | **Yes** for gallery-driven UX; **or** mandatory **https URL paste** if product refuses upload scope ([M4 audit](docs/M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md)). |
| **Audio needs upload?** | **Yes** for parity with cover and reader **https** policy. |
| **Existing DB fields enough?** | **Yes** for storing **URLs**; **visibility** can use **dirty + join** without new column, or add **optional** flag if join is too heavy. |
| **Published edit hide policy recommendation** | **Exclude from public mono feed** (and owner published list if desired) when **`hasUnpublishedCoreChanges`** on linked **`story_drafts`**; **republish** clears flag → visible. Update Flutter Profile hide rule for **backend** rows. |
| **First implementation step** | **M5b** storage + one upload path **or** **M5d** feed filter if product prioritizes **misleading catalog** over media — **recommended order: M5b → M5c → M5d → M5e** so readers always receive **https** assets before hiding stale listings. |
