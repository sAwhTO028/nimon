# M6c S3/R2 Media Storage Report

## Files Changed

| Path | Change |
|------|--------|
| `nimon-backend/src/modules/media/s3-media.storage.ts` | New `S3MediaStorage` + `assertObjectStorageEnv` using `@aws-sdk/client-s3` (`PutObjectCommand`). |
| `nimon-backend/src/modules/media/media-storage.factory.ts` | `createMediaStorage()` selects disk vs S3/R2; fail-fast env validation for object storage. |
| `nimon-backend/src/modules/media/media.module.ts` | `MEDIA_STORAGE` provided via `useFactory` + `createMediaStorage`. |
| `nimon-backend/src/modules/media/media-storage.factory.spec.ts` | Tests for default disk, `s3`/`r2`, missing env, unknown driver. |
| `nimon-backend/src/modules/media/s3-media.storage.spec.ts` | Mock `S3Client`; asserts `PutObjectCommand` input and public URL encoding. |
| `nimon-backend/package.json` | Dependency `@aws-sdk/client-s3`. |
| `nimon-backend/.env.example` | `MEDIA_STORAGE_DRIVER` and S3/R2-related variables documented. |

Controllers, DTOs, upload routes, and response shapes were not modified.

## Storage Driver Selection

- `MEDIA_STORAGE_DRIVER` defaults to **`disk`** when unset (via `createMediaStorage`).
- **`disk`**: `DiskMediaStorage` — same local filesystem behavior as before M6c.
- **`s3`** or **`r2`**: `S3MediaStorage` — one implementation for AWS S3 and Cloudflare R2 (S3-compatible API).
- Any other value throws at startup with an explicit “unknown driver” error.

## S3/R2 Behavior

- Object **key**: optional `MEDIA_OBJECT_KEY_PREFIX` (slashes normalized, no `..`), then `userId/kind/<timestamp>-<uuid><extension>` — same relative shape as disk after the prefix.
- **PutObject**: `Bucket`, `Key`, `Body` (buffer), `ContentType`, `ContentLength`; **no ACL** set.
- **Client**: `S3Client` with `MEDIA_REGION` (supports `auto` for R2), optional `MEDIA_ENDPOINT`, static credentials, **`forcePathStyle`**: `true` when `MEDIA_ENDPOINT` is set unless `MEDIA_S3_FORCE_PATH_STYLE` overrides (`true`/`false`).

## Environment Variables

| Variable | disk | s3 / r2 |
|----------|------|---------|
| `MEDIA_STORAGE_DRIVER` | `disk` (default) | `s3` or `r2` |
| `MEDIA_PUBLIC_BASE_URL` | Optional (disk has localhost default in code) | **Required** |
| `MEDIA_UPLOAD_DIR` | Used by disk | N/A |
| `MEDIA_BUCKET` | N/A | **Required** |
| `MEDIA_REGION` | N/A | **Required** (e.g. `us-east-1` or `auto` for R2) |
| `MEDIA_ENDPOINT` | N/A | Optional (typical for R2) |
| `MEDIA_ACCESS_KEY_ID` | N/A | **Required** |
| `MEDIA_SECRET_ACCESS_KEY` | N/A | **Required** |
| `MEDIA_OBJECT_KEY_PREFIX` | N/A | Optional |
| `MEDIA_S3_FORCE_PATH_STYLE` | N/A | Optional (`true`/`false`) |

If `s3` or `r2` is selected and any required variable is missing, the app fails during module initialization with a message naming the missing key.

## URL Construction

- Base: `MEDIA_PUBLIC_BASE_URL` with trailing slashes stripped.
- Path: full object key split on `/`, each segment passed through `encodeURIComponent`, joined with `/`.
- Matches the encoding approach used by `DiskMediaStorage` for `userId/kind/filename`.

## Tests Added

- `media-storage.factory.spec.ts`: default `DiskMediaStorage`, `s3` / `r2` → `S3MediaStorage`, missing secret key throws, unknown driver throws.
- `s3-media.storage.spec.ts`: mocked `S3Client.send` — asserts `PutObjectCommand` payload; URL uses base URL + encoded key segments (including optional prefix).

## Backend Test Result

**Not run in this agent environment** (`npm` was not available on `PATH`). After `npm install` in `nimon-backend`, run:

```bash
node ./node_modules/jest/bin/jest.js src/modules/media
```

## Backend Build Result

**Not run here** for the same reason. After installing dependencies:

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

## Remaining Risks

- **Credentials**: Static keys in env; rotation and least-privilege IAM/R2 policies are operational concerns.
- **Public URL vs bucket**: `MEDIA_PUBLIC_BASE_URL` must match how objects are exposed (R2 custom domain, CloudFront, etc.); misconfiguration yields 404s despite successful uploads.
- **Large uploads**: Multipart uploads are not implemented; same limits as today via Multer memory limits.

## Manual Configuration Steps

1. Create bucket (S3 or R2) and note region / endpoint (R2: account endpoint + `MEDIA_REGION=auto`).
2. Set bucket policy or public access rules so `MEDIA_PUBLIC_BASE_URL` can serve uploaded objects (or use signed URLs in a later milestone — not in this change).
3. Set `MEDIA_STORAGE_DRIVER=s3` or `r2` and fill required env vars in deployment secrets.
4. Optionally set `MEDIA_OBJECT_KEY_PREFIX` for environment separation (e.g. `prod` vs `staging`).

## Recommended Next Step

**M6d**: Follow `docs/M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md` — staging smoke tests against real bucket + CDN base URL, monitor errors and latency, and validate Flutter clients against the same public URLs.
