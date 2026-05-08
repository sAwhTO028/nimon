# M6 Production Storage/CDN + Release Hardening Plan

**Status:** Plan / audit only — **no app code changes** and **no migrations** in this document.  
**Context:** M1–M5 are complete per [M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md). Current media upload uses **local disk** under a configurable root, served at **`/uploads`** with **CORS** middleware and **`MEDIA_PUBLIC_BASE_URL`**.

**References:** [M5_MEDIA_UPLOAD_AND_PUBLISHED_EDITING_PLAN.md](M5_MEDIA_UPLOAD_AND_PUBLISHED_EDITING_PLAN.md), [M5B_BACKEND_MEDIA_UPLOAD_REPORT.md](M5B_BACKEND_MEDIA_UPLOAD_REPORT.md), [M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md](M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md), [UPLOADS_STATIC_CORS_FIX_REPORT.md](UPLOADS_STATIC_CORS_FIX_REPORT.md), [COVER_UPLOAD_JPG_MIME_FIX_REPORT.md](COVER_UPLOAD_JPG_MIME_FIX_REPORT.md), `nimon-backend/src/main.ts`, `nimon-backend/.env.example`, `lib/features/create/data/media_upload_repository.dart`, [README.md](../README.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md).

---

## 1. Executive Summary

**Why local `/uploads` is acceptable for dev but not for production**

- **Single-host coupling:** Files live on the API server’s filesystem (`MEDIA_UPLOAD_DIR`). Scaling to multiple API replicas breaks reads unless sticky sessions or shared volumes are added — both are poor substitutes for object storage.
- **Durability & backups:** Disk on the app VM/container is not the same as replicated object storage; backups and restore semantics differ.
- **Bandwidth & CPU:** Serving large audio/image bytes through the Nest process competes with API traffic; CDN edge caching is absent.
- **Security surface:** `express.static` + disk paths increase exposure to misconfiguration and path confusion; production typically wants **bucket IAM**, **private objects**, and optionally **signed GET**.
- **Operational churn:** Deployments and horizontal scaling may orphan files or break URLs unless the disk is externalized.

**Conclusion:** Keep **`disk` + `/uploads`** for **local/dev**. For **staging/production**, move blobs to **object storage + HTTPS CDN/public URLs**, preserve the **same JSON contract** (`POST` returns `{ url, … }`) where possible to minimize Flutter churn.

---

## 2. Current Upload Architecture

**Backend (NestJS)**

- **Endpoints:** `POST /v1/media/upload/cover`, `POST /v1/media/upload/audio` — **`JwtAuthGuard`**, multipart **`file`**, multer memory storage → **`MediaService.persistFile`** writes under **`resolve(uploadRoot)/<userId>/<cover|audio>/<timestamp>-<uuid>.<ext>`**.
- **Validation:** `resolveCoverMime` / audio MIME allowlists; size caps via **`MEDIA_COVER_MAX_BYTES`**, **`MEDIA_AUDIO_MAX_BYTES`** (see `media-file-limits.ts`).
- **Response URL:** **`MEDIA_PUBLIC_BASE_URL`** + encoded path segments (must align with how readers fetch assets).

**Static serving**

- **`main.ts`:** Chain **`applyUploadsStaticCors`** → **`OPTIONS` 204** → **`express.static(uploadAbs)`** at **`/uploads`** where **`uploadAbs`** resolves same as `MediaService` (`MEDIA_UPLOAD_DIR`).
- **CORS:** `applyUploadsStaticCors`; API uses **`enableCors`** with **`CORS_ORIGIN`** / localhost reflection (see [UPLOADS_STATIC_CORS_FIX_REPORT.md](UPLOADS_STATIC_CORS_FIX_REPORT.md)).

**Flutter**

- **`MediaUploadRepository`:** `POST` `{apiBaseUrl}/v1/media/upload/{cover|audio}` with **Bearer** from **`authHeaderBuilderProvider`**; parses **`MediaUploadResponse`** (`url`, `mediaType`, `originalName`, `sizeBytes`, optional **`durationSeconds`**).
- **Consumers:** Story Basics cover path and Listening **Upload to server** — success depends only on **HTTPS JSON shape**, not on disk vs bucket.

---

## 3. Production Storage Options

| Option | Pros | Cons |
|--------|------|------|
| **AWS S3** | Industry standard, IAM, lifecycle, CloudFront; mature SDKs | Cost/complexity; region/account hygiene |
| **Cloudflare R2** | S3-compatible API, egress-friendly with Cloudflare | Newer; IAM model differs from AWS |
| **Supabase Storage** | Simple if already on Supabase; JWT-friendly docs | Coupled to Supabase product surface |
| **Firebase Storage** | Good mobile DX; rules language | Less natural for Nest-centric JWT API unless bridged |
| **Backend stream-to-bucket** | Reuses current multipart endpoints; server validates then **`PutObject`** | Large files use API memory/CPU unless streaming carefully |
| **Presigned direct upload** | Client uploads to bucket/cdn **without** bytes through API | Requires **`POST /presign`** + **`complete`** or equivalent; more moving parts |

---

## 4. Recommended Storage Strategy

**Practical V1 (staging + production)**

1. **Object storage** with **S3-compatible API** (**AWS S3** or **Cloudflare R2**) — pick one per environment; abstract behind a **driver** (see §12).
2. **`MEDIA_PUBLIC_BASE_URL`** = canonical **public HTTPS base** for reader-facing URLs (either **R2/S3 public bucket URL**, **custom domain**, or **CloudFront**/`*.r2.dev` style URL). Must match what **`MediaUploadRepository`** and **`Image.network`** can load cross-origin (CORS on bucket + Flutter web).
3. **Dev/local:** Keep **`MEDIA_STORAGE_DRIVER=disk`** (or unset default disk) + existing **`/uploads`** + localhost **`MEDIA_PUBLIC_BASE_URL`**.
4. **Staging:** Same driver as prod with **separate bucket/credentials**; run full smoke (§9).
5. **Production:** **No** reliance on API disk for user media; API may optionally stop mounting **`/uploads`** or mount only for legacy/dev.

**Why R2 is often chosen for small teams:** S3-compatible (`@aws-sdk/client-s3`), lower egress friction when paired with Cloudflare, single dashboard for DNS/CDN. **S3 + CloudFront** remains the default enterprise pattern.

---

## 5. API Design For Production Upload

**Recommendation**

- **Phase 1 (minimal Flutter change):** Keep **`POST /v1/media/upload/cover`** and **`POST /v1/media/upload/audio`**. Implement **`MediaService`** persistence via **`PutObject`** (stream buffer from multer) instead of **`writeFile`**. Return **`url`** = **`MEDIA_PUBLIC_BASE_URL`** + stable **object key** (same shape as today).
- **Phase 2 (scale):** Add **`POST /v1/media/presign`** returning **`uploadUrl`**, **`headers`**, **`objectKey`**, **`expiresAt`**; optional **`POST /v1/media/complete`** to verify ownership and return final **`url`**. Flutter then switches upload transport only — **response JSON** can stay **`MediaUploadResponse`-compatible**.

**Migration path for Flutter**

- **Zero schema change** to Prisma for URLs (still strings in draft/published JSON).
- **Minimal change:** Ensure **`MediaUploadResponse.url`** remains absolute **https**; if CDN domain differs from API, set **`MEDIA_PUBLIC_BASE_URL`** accordingly — **no Dart change** if env is correct.
- **Larger change only if** switching to presigned: extend **`MediaUploadRepository`** with **`uploadViaPresign`** or dual path behind feature flag.

---

## 6. Environment Variables

**Proposed (additive; names may be refined at implementation)**

| Variable | Purpose |
|----------|---------|
| **`MEDIA_STORAGE_DRIVER`** | `disk` \| `s3` \| `r2` (alias of s3 SDK) \| future — selects implementation. |
| **`MEDIA_PUBLIC_BASE_URL`** | Public **base URL** for returned **`url`** (no trailing slash); must match reader fetch origin/CORS (CDN or bucket website/public URL). |
| **`MEDIA_UPLOAD_DIR`** | Local disk root when **`driver=disk`**; aligns with static **`/uploads`** today. |
| **`MEDIA_BUCKET`** | Bucket name (S3/R2). |
| **`MEDIA_REGION`** | AWS region or **`auto`** for R2 as required by SDK. |
| **`MEDIA_ENDPOINT`** | Optional custom endpoint (R2: account-specific **S3 API** endpoint). |
| **`MEDIA_ACCESS_KEY_ID`** | Access key id (store as secret in prod). |
| **`MEDIA_SECRET_ACCESS_KEY`** | Secret key (secret). |
| **`MEDIA_OBJECT_KEY_PREFIX`** | Optional env-specific prefix e.g. `prod/` or `staging/` inside bucket. |
| **`CORS_ORIGIN`** | Web app origin(s) for API + coordinate bucket CORS for direct GET/presign. |
| **`MEDIA_COVER_MAX_BYTES`** | Cover max size (default 10 MiB in code). |
| **`MEDIA_AUDIO_MAX_BYTES`** | Audio max size (default 50 MiB in code). |

**Existing auth/database vars** remain (`JWT_SECRET`, `DATABASE_URL`, `PORT`, `NODE_ENV`, …).

---

## 7. Security Rules

| Area | Rule |
|------|------|
| **Auth** | Upload routes remain **JWT-only** (no dev-owner fallback on upload). |
| **MIME** | Keep server-side allowlists (cover + audio); preserve **`resolveCoverMime`** behavior for web clients. |
| **Max size** | Enforce at multer + service (already shared limits). |
| **Object keys** | **`{prefix}/{userId}/{kind}/{storedFileName}`** — **`userId`** from JWT only; **never** from client path; **`storedFileName`** server-generated (already). |
| **Path traversal** | Continue rejecting **`..`** in **`userId`** / storage name checks (`MediaService`). |
| **Public vs signed** | **V1:** public-read objects + HTTPS URL is simplest. **Hardening:** private bucket + **short-lived signed GET** for readers (requires Flutter reader changes or CDN signed URLs). |
| **Deletion / orphans** | Policy: on draft delete / unpublish / account deletion — optional GC job or lifecycle rule (versioned deletes); document **no guarantee** in V1 if not implemented. |
| **CORS** | Bucket CORS allows **`GET`** from app origins; **`PUT`** only if presigned uploads use browser directly; API **`CORS_ORIGIN`** for **`POST`**.

---

## 8. Flutter Impact

| Topic | Impact |
|-------|--------|
| **Minimal path** | If API still returns **`{ url }`** after server-side **`PutObject`**, **no Dart changes** beyond QA and **`NIMON_API_BASE_URL` / CDN URL** alignment. |
| **Presigned path** | **`MediaUploadRepository`** gains presign + **`PUT`** binary to bucket; error mapping preserved. |
| **Progress** | Today **no upload progress %** ([M5C](M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md)); optional **`StreamedRequest`** / XMLHttpRequest progress — separate small milestone. |
| **Retry** | Idempotent keys or client retry on **5xx** recommended for production UX. |
| **Web large files** | Audio upload uses bytes on web — memory pressure; presigned **direct upload** reduces API RAM. |
| **User messages** | Keep **`MediaUploadException.userMessage`**; map bucket/S3 errors to friendly strings server-side when possible. |

---

## 9. Release Smoke Checklist

**Functional (same as M5 closeout, against staging/prod URLs)**

- [ ] **Upload cover** (JPG/PNG/WebP + web MIME edge cases if applicable).
- [ ] **Upload audio** (mp3/m4a/wav).
- [ ] **Publish** read-only and/or full-learn.
- [ ] **Mono feed** — story + cover visible.
- [ ] **Profile Published** — row + cover.
- [ ] **Learn Listening** — playback from returned **https** URL.
- [ ] **Edit from Published** → **save** → **Mono + Published hide**; **Workspace** shows **Editing**.
- [ ] **Republish** → row **reappears**.
- [ ] **Hard refresh / cache** — force reload; confirm assets still load (CDN/cache headers).
- [ ] **Different account** — non-owner cannot upload to another user’s prefix; published/read-only reads behave as designed.

**Infrastructure**

- [ ] **`MEDIA_PUBLIC_BASE_URL`** matches actual asset host (no mixed-content **`http`** on prod web).
- [ ] Bucket/object **CORS** allows Flutter web origin if loading cross-origin.
- [ ] **TLS** valid on API and asset domain.

---

## 10. CI / Deployment Checklist

- [ ] **`prisma migrate status`** / migrate deploy (schema changes only if M6 adds tracking tables later — **none required for URL-only V1**).
- [ ] **`nest build`** / Docker image build.
- [ ] **Backend tests:** `jest` media module + integration smoke if added.
- [ ] **`flutter test`** (full suite before release tag).
- [ ] **Env validation** on boot: fail fast if **`MEDIA_STORAGE_DRIVER=s3`** but credentials missing.
- [ ] **Bucket CORS** JSON reviewed for prod origins.
- [ ] **Public URL test:** `curl -I` on a sample **`{MEDIA_PUBLIC_BASE_URL}/...`** object returns **200** and correct **`content-type`** (and CORS headers if browser fetch).

---

## 11. Remaining Product Risks

| Risk | Source |
|------|--------|
| **No upload progress %** | [M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md](M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md) |
| **Audio `durationSeconds` often null** | Server probe not guaranteed; [M5B](M5B_BACKEND_MEDIA_UPLOAD_REPORT.md) |
| **No transcript model** | Out of M6 storage scope; note for future features |
| **Dev disk vs prod bucket mismatch** | Teams forget **`MEDIA_PUBLIC_BASE_URL`** — enforce checklist §9–10 |
| **404 “editing” copy ambiguity** | [M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md) |

---

## 12. Recommended Implementation Split

| Phase | Deliverable |
|-------|-------------|
| **M6a** | Finalize provider (S3 vs R2), bucket layout, env matrix, runbook — **this document** + decision log. |
| **M6b** | **Storage driver abstraction** in Nest (`MediaStorage` interface: `put`, `publicUrl`); **`disk`** implementation = current behavior. |
| **M6c** | **S3/R2 driver** (`PutObject`), wire **`MediaService`** to driver when **`MEDIA_STORAGE_DRIVER`** set; integration tests with **LocalStack** or mocked SDK. |
| **M6d** | **Staging smoke:** deploy API + bucket; run §9 smoke; fix CORS/TLS. |
| **M6e** | **Release checklist** frozen; tag; optional presign **M6f** if API CPU/memory requires offloading uploads. |

---

## 13. Exact Cursor Prompt For M6b

Use when starting implementation — **storage driver abstraction only** (no R2/S3 credentials wiring yet unless trivial mock).

```text
You are a senior NestJS engineer working on nimon-backend.

Task: Implement M6b — storage driver abstraction for the media module only.

Constraints:
- Do NOT add S3/R2 credentials or production bucket wiring yet (that is M6c).
- Do NOT change Prisma schema or run migrations.
- Do NOT change HTTP routes or DTO shapes for POST /v1/media/upload/cover|audio.
- Keep existing MIME/size validation and resolveCoverMime behavior.

Goals:
1. Introduce an abstraction, e.g. MediaStorage interface with:
   - save(params: { userId, kind: 'cover'|'audio', buffer, extension, mediaType }): Promise<{ relativePathOrKey: string }>
   - getPublicUrl(relativePathOrKey: string): string  // uses MEDIA_PUBLIC_BASE_URL
2. Implement DiskMediaStorage that preserves current MediaService behavior:
   - Same directory layout: <uploadRoot>/<userId>/<kind>/<timestamp>-<uuid><ext>
   - Same path safety checks (no .. in userId, safe stored filename).
3. Refactor MediaService.persistFile to use the injected MediaStorage implementation (default DiskMediaStorage).
4. Register the provider in MediaModule using Nest DI; read upload root from existing env resolution.
5. Unit tests: MediaService saves via mocked MediaStorage; DiskMediaStorage writes to temp dir in test optional.

Files likely touched:
- nimon-backend/src/modules/media/media.service.ts
- nimon-backend/src/modules/media/media.module.ts
- new: media-storage.interface.ts, disk-media.storage.ts

Commands to run after changes:
- node ./node_modules/jest/bin/jest.js src/modules/media
- node ./node_modules/@nestjs/cli/bin/nest.js build

Deliver: minimal diff, same external behavior for disk mode.
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Is local `/uploads` acceptable for production?** | **No** — use object storage + HTTPS CDN/public URLs for production workloads. |
| **Recommended storage provider** | **S3-compatible** bucket (**AWS S3** or **Cloudflare R2**) with **`MEDIA_PUBLIC_BASE_URL`** pointing at the public asset host; pick one per environment in **M6a**. |
| **Can current endpoints stay?** | **Yes for V1** — server-side **`PutObject`** after multipart preserves **`MediaUploadResponse`**; **presign** is optional scale-up. |
| **Flutter changes needed?** | **Minimal** if URL shape stays **`https`** absolute; **more** if switching to presigned client **`PUT`**. |
| **Biggest risk** | **Misconfigured `MEDIA_PUBLIC_BASE_URL` / bucket CORS / TLS** causing broken images/audio in prod despite successful upload. |
| **First implementation step** | **M6b:** Introduce **`MediaStorage`** interface + **`DiskMediaStorage`** refactor (**§13 prompt**) so **M6c** swaps in S3 without touching controllers. |
