# M5 Media Upload And Edit Visibility Closeout Report

**Purpose:** Closeout documentation for **M5** — authenticated multipart upload (cover + audio), stable **`https`** URLs on drafts and published snapshots, **Flutter Web** cover display (**CORS** + **MIME** edge cases), and **published-edit visibility** (backend filtering + Flutter refresh / UX).  
**Scope:** Documentation and manual smoke guidance only — **no application code changes** and **no migrations** in this document.

**Inputs:** [M5_MEDIA_UPLOAD_AND_PUBLISHED_EDITING_PLAN.md](M5_MEDIA_UPLOAD_AND_PUBLISHED_EDITING_PLAN.md), [M5B_BACKEND_MEDIA_UPLOAD_REPORT.md](M5B_BACKEND_MEDIA_UPLOAD_REPORT.md), [M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md](M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md), [COVER_UPLOAD_JPG_MIME_FIX_REPORT.md](COVER_UPLOAD_JPG_MIME_FIX_REPORT.md), [UPLOADS_STATIC_CORS_FIX_REPORT.md](UPLOADS_STATIC_CORS_FIX_REPORT.md), [M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md), [M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md).

---

## Completed Milestones

| Milestone | Summary |
|-----------|---------|
| **M5b — Backend media upload** | `POST /v1/media/upload/cover` and `…/audio`; JWT; disk storage under `MEDIA_UPLOAD_DIR`; public URL via `MEDIA_PUBLIC_BASE_URL`; static `/uploads` in `main.ts`. |
| **M5c — Flutter media upload** | `MediaUploadRepository` + provider; Story Basics cover upload; Listening **Upload to server**; `http(s)` URLs on `coverImageUrl` and `storyAudio.sourceUrl`. |
| **Cover JPG MIME fix** | `resolveCoverMime`: `image/jpg` → `image/jpeg`; `application/octet-stream` / empty MIME + safe filename extension for cover only. |
| **`/uploads` static CORS** | Dedicated middleware on `/uploads` (ACAO, CORP, OPTIONS); optional **`CORS_ORIGIN`**; API CORS extended without breaking localhost. |
| **M5d — Backend published visibility** | `PUBLISHED_MONO_CATALOG_VISIBLE`: hide `published_monos` when a linked `StoryDraft` has `hasUnpublishedCoreChanges === true` (feed, public detail, owner list/detail). |
| **M5e — Flutter edit visibility** | `profileProcessingListRefreshProvider` drives Workspace + Published refresh; `MonoScreen` refreshes remote feed; `PublishedMonoHiddenWhileEditingException` + copy for 404 detail fetches. |

**Prisma:** No new columns required for URL storage; visibility uses existing **`hasUnpublishedCoreChanges`**.

---

## Media Upload Data Flow

1. **User** picks a file in Flutter (cover or audio) while **signed in** (Bearer for upload).
2. **Client** `POST` multipart to **`/v1/media/upload/{cover|audio}`**; server validates size/MIME, stores under **`<uploadRoot>/<userId>/{cover|audio}/<timestamp-uuid>.<ext>`**.
3. **Response** returns **`url`** (built from `MEDIA_PUBLIC_BASE_URL` + path under **`/uploads/...`**).
4. **Flutter** writes that URL into **`StoryDraft`**: **`coverImageUrl`** (basics) or **`audio.storyAudio.sourceUrl`** (learn), using **`http(s)`** only for remote wire (`fromDomainRemoteSafe` rules).
5. **Publish** (read-only / full-learn) copies the same URL fields into **`PublishedMono.content`** as in existing publish code paths.
6. **Readers** load cover via **`Image.network`** / feed **`coverUrl`**; listening uses **`publishedStoryAudioHttpUrl`**-style **http(s)** checks.

---

## Cover Upload Result

- **Backend:** Allowlist for cover includes **jpeg / png / webp**; **JPG fix** covers **`image/jpg`**, **octet-stream**, and **empty** MIME with **`.jpg` / `.jpeg` / `.png` / `.webp`** filename inference (see cover MIME report).
- **Flutter Web display:** **`/uploads` CORS** (and **CORP cross-origin**) so cross-origin **GET** of the image does not fail in Chrome / Flutter web.
- **Persistence:** Remote **`coverImageUrl`** is an **`https` (or dev `http`)** URL under the API’s public base — suitable for feed and published core snapshot.

---

## Audio Upload Result

- **Backend:** MIME allowlist for **mpeg / mp3 / mp4 / m4a / wav**; size cap **`MEDIA_AUDIO_MAX_BYTES`** (default 50 MiB).
- **Flutter:** **Upload to server** in the listening flow returns **`sourceUrl`** → **`setStoryAudio`**; local-only attach remains for draft preview, not publish-ready.
- **Persistence:** **`sourceUrl`** on the wire must be **http(s)** for remote save and for reader playback after publish.

---

## Published Edit Visibility Result

- **Backend (M5d):** While **`hasUnpublishedCoreChanges === true`** on a draft linked to a **`PublishedMono`**, that mono is **omitted** from **`GET /v1/mono/feed`**, **`GET /v1/published-monos`**, and **404** on **`GET /v1/mono/:id`** and owner **`GET /v1/published-monos/:id`**.
- **Republish:** **`publishReadOnly`** / **`publishFullLearn`** clear **`hasUnpublishedCoreChanges`**; the row **reappears** in queries without deleting **`PublishedMono`**.
- **Flutter (M5e):** Shared refresh counter refetches **Workspace**, **Profile Published**, and (when Mono Home is used) **remote Mono feed**; user-facing copy when a **404** is the “editing / republish” message on catalog detail fetches.

---

## Manual Smoke Checklist

**Environment**

- [ ] Run backend with **`MEDIA_PUBLIC_BASE_URL`** pointing at the same origin (or CDN) that serves **`/uploads`** (e.g. `http://localhost:3000/uploads` in dev).
- [ ] Set **`CORS_ORIGIN`** appropriately for Flutter web (e.g. dev `*` or your dev web origin; production: real app origin). See [UPLOADS_STATIC_CORS_FIX_REPORT.md](UPLOADS_STATIC_CORS_FIX_REPORT.md).

**Account & story**

- [ ] **Login** (Bearer required for upload and owner published APIs).
- [ ] **Create** a story (remote drafts on if used).

**Cover**

- [ ] **Upload cover** from **JPG / PNG / WebP** (include **web** to exercise MIME/CORS).
- [ ] **Thumbnail** loads in UI (no CORS error in browser devtools for the image **GET**).
- [ ] After save, confirm draft (or server echo) has **`coverImageUrl`** with an **`/uploads/...`** (or full public base) URL.

**Audio**

- [ ] **Upload audio** (**mp3 / m4a / wav** as supported).
- [ ] Confirm **`sourceUrl`** (or equivalent) is stored and **http(s)** on the remote draft.

**Publish & read**

- [ ] **Publish** read-only and/or full-learn.
- [ ] **Mono feed** shows the story and **cover** (summary from API).
- [ ] **Profile → Published** shows the row and **cover**.
- [ ] **Learn → Listening** **plays** uploaded audio (https URL path).

**Edit visibility**

- [ ] **Edit** from **Profile Published** (or **Mono** reader menu) into creator.
- [ ] **Save** an edit (remote save so **`hasUnpublishedCoreChanges`** is set on server).
- [ ] **Mono Home** list **no longer** includes the story (or refresh and confirm).
- [ ] **Profile → Published** list **no longer** includes the story.
- [ ] **Profile → Workspace** shows the draft as **Editing** (or equivalent summary).
- [ ] **Republish** (read-only or full-learn as appropriate).
- [ ] **Mono feed** and **Profile Published** show the story **again**.

---

## Tests Summary

| Area | Evidence (per milestone reports) |
|------|----------------------------------|
| **Backend media** | Jest `src/modules/media` — service + controller specs; **`nest build`** OK. |
| **Backend CORS helper** | Jest `src/common/uploads-static-cors.spec.ts`. |
| **Backend visibility** | Jest `mono-feed`, `published-monos`, `story-drafts.service.spec`; **`nest build`** OK. |
| **Flutter upload / URL rules** | `test/features/create` (media repo, basics remote cover, mapper http preservation); **full `flutter test`** passed at M5e closeout. |
| **Flutter visibility** | New 404 / exception tests; profile + mono + create suites passed. |

*Automated tests do not replace the **manual smoke checklist** above for a real device/browser and env configuration.*

---

## Remaining Risks

| Risk | Notes |
|------|--------|
| **Local disk uploads** | V1 dev-friendly; **production** should use object storage + CDN / signed URLs ([M5 plan §5](M5_MEDIA_UPLOAD_AND_PUBLISHED_EDITING_PLAN.md)). |
| **CORS / prod origin** | **`CORS_ORIGIN`** must match the web app in production for static **`/uploads`**. |
| **404 copy vs truly missing** | Detail endpoints map **any 404** to the “being edited” UX — rare ambiguity if the server returns 404 for other reasons ([M5E report](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md)). |
| **MIME / extension trust** | Octet-stream cover path trusts **sanitized filename** for type; no magic-byte sniff ([COVER_UPLOAD_JPG_MIME_FIX_REPORT.md](COVER_UPLOAD_JPG_MIME_FIX_REPORT.md)). |
| **Upload UX** | No upload progress %; large audio on web uses bytes — see [M5C report](M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md). |
| **Refresh churn** | Frequent list refetch while editing a published remote draft — acceptable; may throttle later ([M5E report](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md)). |

---

## Final Verdict

**M5 implementation is closed at the engineering milestone level:** backend upload + static serving + CORS + MIME hardening + published visibility + Flutter integration and alignment are **delivered and documented**, with **automated tests** reported green in the cited milestone docs.

**Operational “verified”** for a given release still requires executing the **Manual Smoke Checklist** in the target environment (correct **`MEDIA_PUBLIC_BASE_URL`**, **`CORS_ORIGIN`**, auth, and remote-draft flags).

---

## Recommended Next Milestone

1. **M5f / product polish (optional):** “Back to Workspace” on hidden-detail errors; upload progress; analytics on hidden-detail views ([M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md)).
2. **M6 / infrastructure:** Presigned uploads or stream-to-object-storage; retire host-dependent **`/uploads`** URLs for production; tighten CORS and bucket policies.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **M5 implementation closed?** | **Yes** — scope described in milestone reports is implemented; **smoke checklist** remains the gate for environment-specific verification. |
| **Media upload verified?** | **In CI/automation:** yes per tests. **In prod-like env:** use **Manual Smoke Checklist**. |
| **Cover display verified?** | **JPG MIME + CORS** addressed in code; confirm with checklist on **Flutter web**. |
| **Audio upload verified?** | Backend + Flutter paths exist; confirm **`http(s)`** end-to-end via checklist. |
| **Edit visibility verified?** | **M5d + M5e** aligned; confirm hide/show/republish via checklist. |
| **Tests passed?** | **Yes** per milestone reports (backend Jest slices + Flutter full suite at M5e). |
| **Remaining risks** | Local disk for prod, CORS config, 404 messaging ambiguity, upload UX — see **Remaining Risks**. |
| **Next milestone recommendation** | **M5f** polish optional; **M6** storage/CDN and production hardening. |
