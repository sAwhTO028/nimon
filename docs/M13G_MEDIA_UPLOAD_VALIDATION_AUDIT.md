# M13G Media Upload Validation Audit

Upload surfaces share **`POST /v1/media/upload/cover`** (story cover, profile avatar, profile cover) and **`POST /v1/media/upload/audio`** (listening / story audio). There are no separate avatar/cover backend routes.

## Audit table

| Upload surface | Backend route / service | Current invalid-input behavior (after M13G) | Status code | Current Flutter behavior | Desired behavior | Change status |
|----------------|---------------------------|-----------------------------------------------|-------------|-------------------------|------------------|---------------|
| Story cover | `POST /v1/media/upload/cover` → `MediaController.uploadCover` → `MediaService.saveCover` | Missing/empty file → `validation_failed` (`media.file.*`). Oversize (multer + app check) → `validation_failed` (`coverImage` / `media.image.tooLarge`). Invalid MIME → **`UnsupportedMediaTypeException`** (415) unchanged | 400 / 415 | `MediaUploadRepository` parses `validation_failed` → `HttpValidationFailedException`; else friendly `MediaUploadException`. UI uses `mediaUploadUserMessage` | Same + no raw strings | **Done** |
| Profile avatar | Same as story cover (`upload/cover`) | Same as row above | 400 / 415 | Same repository path; `MediaUploadSurface.profileAvatar` for generic fallback | Surface-specific generic copy | **Done** |
| Profile cover | Same as story cover | Same | 400 / 415 | `MediaUploadSurface.profileCover` | Same | **Done** |
| Listening / story audio | `POST /v1/media/upload/audio` → `saveAudio` | Missing/empty → `validation_failed`. Oversize → `validation_failed` (`audioFile`). Invalid MIME → **415** | 400 / 415 | Same repo + `listeningAudio` surface | Same | **Done** |
| Multer `LIMIT_FILE_SIZE` | Filter before controller | **`validation_failed`** with `coverImage` vs `audioFile` by URL | **400** (was 413) | Parsed as structured validation when body matches parser | Friendly issue copy via fallback keys | **Done** |
| Unauthenticated | `JwtAuthGuard` | **401** Unauthorized | 401 | `notifyIfStrictUnauthorized401` / existing session copy | Not `validation_failed` | **Unchanged** |
| Storage write (`DiskMediaStorage` / S3) | `MediaService.persistFile` → `storage.save` | Propagate provider error (not wrapped as validation) | 5xx / thrown Error | `MediaUploadException` generic / mapper fallback | Generic “try again”, not field validation | **Unchanged** |
| Invalid user id (pathological JWT sub) | `persistFile` | `BadRequestException` string | 400 | Friendly generic via `_friendlyHttpError` | Rare; not `validation_failed` | **Unchanged** |

## Status code policy

| Situation | Code | Body shape |
|-----------|------|------------|
| Missing multipart `file`, empty buffer, app-level oversize, multer oversize | **400** | `{ message: 'validation_failed', issues: [...] }` |
| Declared MIME / extension not allowed (`resolveCoverMime` / `resolveAudioMime`) | **415** | Nest default unsupported media payload (Flutter maps with friendly copy, no structured issues) |
| Not authenticated | **401** | Standard Nest unauthorized |
| Storage failure | **500** or thrown | Not validation |

## Notes

- **415 retained** for MIME rejection so existing tests and any client branching on **415** remain valid.
- **Multer limit** moved from **413** to **400 + validation_failed** for consistent structured UX (Flutter parses issues when present).
