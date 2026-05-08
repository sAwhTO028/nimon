# M6b Media Storage Driver Abstraction Report

## Files Changed

| Path | Change |
|------|--------|
| `nimon-backend/src/modules/media/media-storage.ts` | **New** — `MEDIA_STORAGE` injection token, `MediaStorage` interface, `MediaStorageSaveParams`, `MediaStorageSaveResult`. |
| `nimon-backend/src/modules/media/disk-media.storage.ts` | **New** — `DiskMediaStorage` implements `MediaStorage`: same disk layout, path safety, and public URL building as pre-M6b `MediaService`. |
| `nimon-backend/src/modules/media/media.service.ts` | Validation + `extensionForMime` unchanged; persistence delegated to `MediaStorage.save()`; `ConfigService` removed (no longer needed on service). |
| `nimon-backend/src/modules/media/media.module.ts` | Registers `DiskMediaStorage` and `{ provide: MEDIA_STORAGE, useExisting: DiskMediaStorage }` + `MediaService`. |
| `nimon-backend/src/modules/media/media.service.spec.ts` | Mocks `MediaStorage`; asserts `save` args and response mapping; no `fs` mocks. |
| `nimon-backend/src/modules/media/disk-media.storage.spec.ts` | **New** — `DiskMediaStorage` + mocked `fs/promises` for path/URL shape. |
| `nimon-backend/src/modules/media/media.controller.spec.ts` | Test module providers include `DiskMediaStorage` + `MEDIA_STORAGE` + `MediaService`. |

**Not changed:** `media.controller.ts`, `media.validation.ts`, `media-file-limits.ts`, DTOs, HTTP routes, Prisma.

## Storage Interface

- **`MediaStorageSaveParams`:** `userId`, `kind` (`cover` | `audio`), `buffer`, `extension` (leading dot, e.g. `.jpg`), `mediaType` (canonical lowercase MIME for future S3 `Content-Type`).
- **`MediaStorageSaveResult`:** `key` (relative path `userId/kind/<timestamp>-<uuid><ext>`), `url` (full public URL with encoded path segments).
- **`MediaStorage.save(params)`** — single write entry point for M6c (S3/R2).

## Disk Storage Behavior

- **Root:** `MEDIA_UPLOAD_DIR` resolution unchanged (relative to `cwd` or absolute; `..` rejected in segment).
- **Files:** `<uploadRoot>/<userId>/<kind>/<Date.now()>-<uuid><extension>`.
- **URL:** `MEDIA_PUBLIC_BASE_URL` (no trailing slash) + `encodeURIComponent` per segment — same as before.
- **Safety:** User id and path traversal checks; `writeFile` only after `relative()` containment check.

## MediaService Refactor

- `saveCover` / `saveAudio` still: size limits → MIME validation (`resolveCoverMime` / `assertMimeAllowed`) → `persistFile`.
- `persistFile` validates `userId`, derives `extension` via `extensionForMime(normalizedMime)`, calls `storage.save({ userId, kind, buffer, extension, mediaType })`, builds `MediaUploadResponseDto` with `sanitizeOriginalFilename` for `originalName`.

## DI / Provider Setup

```typescript
providers: [
  DiskMediaStorage,
  { provide: MEDIA_STORAGE, useExisting: DiskMediaStorage },
  MediaService,
],
```

Future **M6c:** register an `S3MediaStorage` (or factory on `MEDIA_STORAGE_DRIVER`) without changing `MediaService` or controllers.

## Tests Added

| Suite | Role |
|-------|------|
| `media.service.spec.ts` | Mock `MediaStorage`; cover/audio MIME matrix; invalid MIME skips `save`. |
| `disk-media.storage.spec.ts` | Mocked `mkdir`/`writeFile`; URL and key pattern; `.jpg` path. |
| `media.controller.spec.ts` | E2E-style supertest unchanged at HTTP level. |

## Backend Test Result

```bash
node ./node_modules/jest/bin/jest.js src/modules/media
```

**Result:** **3** suites, **19** tests passed.

## Backend Build Result

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** Succeeded (exit code **0**).

## Remaining Risks

- **`mediaType` on disk path** is passed through for interface parity; `DiskMediaStorage` does not yet set HTTP headers (not needed for disk).
- **Duplicate `userId` validation** in `MediaService` and `DiskMediaStorage` — intentional defense-in-depth; could be deduplicated later.

## Recommended Next Step

**M6c** — Implement `S3`/`R2` (or `S3Client` + `PutObject`) behind `MediaStorage`, env-driven selection, and integration tests with mocked AWS SDK or LocalStack.

---

## Output Summary

| Check | Result |
|-------|--------|
| Storage interface added? | **Yes** — `media-storage.ts` |
| Disk storage preserves behavior? | **Yes** — same paths and URLs |
| Endpoints / DTOs unchanged? | **Yes** |
| Tests passed? | **Yes** — **19** tests |
| Backend build passed? | **Yes** |
| Next step? | **M6c** — S3/R2 driver |
