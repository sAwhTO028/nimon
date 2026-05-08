# M5b Backend Media Upload Report

## Files Changed

| Area | Path |
|------|------|
| Media module | `nimon-backend/src/modules/media/media-upload-response.dto.ts` |
| | `nimon-backend/src/modules/media/media-upload.types.ts` |
| | `nimon-backend/src/modules/media/media-file-limits.ts` |
| | `nimon-backend/src/modules/media/media.validation.ts` |
| | `nimon-backend/src/modules/media/media.service.ts` |
| | `nimon-backend/src/modules/media/media.controller.ts` |
| | `nimon-backend/src/modules/media/media.module.ts` |
| | `nimon-backend/src/modules/media/multer-memory.storage.ts` |
| | `nimon-backend/src/modules/media/multer-exception.filter.ts` |
| Tests | `nimon-backend/src/modules/media/media.service.spec.ts` |
| | `nimon-backend/src/modules/media/media.controller.spec.ts` |
| App bootstrap | `nimon-backend/src/app.module.ts` |
| | `nimon-backend/src/main.ts` |
| Config example | `nimon-backend/.env.example` |

Prisma schema was not modified.

## Endpoints Added

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/v1/media/upload/cover` | Cover image upload (`multipart/form-data`, field `file`) |
| `POST` | `/v1/media/upload/audio` | Story audio upload (`multipart/form-data`, field `file`) |

## Auth Behavior

- Both routes use **`JwtAuthGuard`** (Bearer JWT only).
- **`JwtOrDevOwnerFallbackGuard` is not used** — uploads never fall back to `DEV_OWNER_ID` / dev-owner behavior.
- **`CurrentUser`** supplies `userId` from the validated JWT payload (same pattern as other authenticated modules).

## Storage Behavior

- Files are written under **`<cwd>/<MEDIA_UPLOAD_DIR>/<userId>/<kind>/`** where `<kind>` is `cover` or `audio`.
- **`MEDIA_UPLOAD_DIR`** may be relative to the process cwd or an absolute filesystem path (resolved consistently in `MediaService` and static hosting).
- Stored filenames are **`Date.now()` + UUID + extension derived from validated MIME** (not the client extension alone).
- **`MEDIA_PUBLIC_BASE_URL`** (default **`http://localhost:3000/uploads`** if unset) is normalized (no trailing slash) and used to build the returned URL:  
  `{base}/{encodeURIComponent(userId)}/{encodeURIComponent(kind)}/{encodeURIComponent(storedFileName)}`.
- **Production** should move to object storage (S3-compatible, GCS, etc.) and set `MEDIA_PUBLIC_BASE_URL` to the public or signed CDN/base URL; local disk is **V1 dev/local only**.

## Validation Rules

**Cover**

- MIME (from multer / file metadata, lowercased): `image/jpeg`, `image/png`, `image/webp`
- Max size: **`MEDIA_COVER_MAX_BYTES`** (default **10 MiB**)

**Audio**

- MIME: `audio/mpeg`, `audio/mp3`, `audio/mp4`, `audio/x-m4a`, `audio/wav`, `audio/wave`
- Max size: **`MEDIA_AUDIO_MAX_BYTES`** (default **50 MiB**)

**HTTP errors**

- Missing or empty `file` → **400** (`BadRequestException`)
- MIME not allowed → **415** (`UnsupportedMediaTypeException`)
- Over limit (multer or service) → **413** (`PayloadTooLargeException`)
- Unauthenticated → **401**

Original filenames are sanitized for the JSON response (path segments stripped, unsafe characters replaced); storage names are server-generated.

## Response Shape

Successful JSON body:

```json
{
  "url": "http://localhost:3000/uploads/<userId>/cover/<filename>.png",
  "mediaType": "image/png",
  "originalName": "cover.png",
  "sizeBytes": 12345,
  "durationSeconds": null
}
```

## Static Serving

- **`main.ts`** mounts **`express.static`** at **`/uploads`** to the resolved upload root directory (same resolution rules as `MediaService`).
- URLs returned by the API match paths under **`/uploads/...`** when the server is reachable at the host implied by `MEDIA_PUBLIC_BASE_URL`.

## Tests Added

- **`media.service.spec.ts`**: mocked `fs/promises`; valid cover/audio responses; invalid MIME; sanitized `originalName`.
- **`media.controller.spec.ts`**: in-memory Nest app with **`JwtAuthGuard` overridden** by a test guard that requires `Bearer` and sets a fake `user`; asserts **401** without token, **400** without file, **415** for PDF cover, **201** for valid cover/audio and response shape.

## Prisma Generate Result

Command: `node ./node_modules/prisma/build/index.js generate`

Result: **Success** — Prisma Client v7.7.0 generated (schema loaded from `prisma/schema.prisma`). Optional CLI notice: newer Prisma 7.8.0 available (informational only).

## Backend Test Result

Command: `node ./node_modules/jest/bin/jest.js src/modules/media`

Result: **All tests passed** — 2 suites, 10 tests.

## Backend Build Result

Command: `node ./node_modules/@nestjs/cli/bin/nest.js build`

Result: **Success** (exit code 0).

## Remaining Risks

- **Disk growth / ops**: no lifecycle cleanup or quotas on `uploads/`.
- **Durability**: local filesystem is unsuitable for multi-instance production without shared storage.
- **Security**: uploads are **world-readable** under `/uploads` once URL is known; no signed URLs or auth gate on static files in V1.
- **Audio**: `durationSeconds` is always **`null`** (no metadata probe in M5b).

## Recommended Next Step

**M5c**: Wire the Flutter/client flow to call these endpoints, persist returned URLs into draft fields (`StoryDraft.coverImageUrl`, draft audio `sourceUrl`), and move production storage to object storage with CDN and optional auth-gated or signed URLs.

---

### Checklist (execution summary)

| Question | Answer |
|----------|--------|
| Cover upload endpoint added? | **Yes** — `POST /v1/media/upload/cover` |
| Audio upload endpoint added? | **Yes** — `POST /v1/media/upload/audio` |
| Auth required? | **Yes** — `JwtAuthGuard` (no dev-owner fallback) |
| Static `/uploads` serving added? | **Yes** — `express.static` in `main.ts` |
| URL response stable? | **Yes** — derived from `MEDIA_PUBLIC_BASE_URL` + deterministic path segments |
| Tests passed? | **Yes** — `jest src/modules/media` |
| Backend build passed? | **Yes** — `nest build` |
| Next step M5c? | **Yes** — client integration + production object storage |
