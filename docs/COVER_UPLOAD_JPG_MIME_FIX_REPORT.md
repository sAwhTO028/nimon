# Cover Upload JPG MIME Fix Report

## Root Cause

Cover uploads were validated with a strict MIME allowlist (`image/jpeg`, `image/png`, `image/webp`). Browsers and Flutter web often send **`image/jpg`** (non-standard but widespread), **`application/octet-stream`**, or an **empty** `mimetype` from Multer. Those cases failed validation even when the file was a valid JPEG and the original filename had a `.jpg` / `.jpeg` extension.

## Files Changed

| File | Change |
|------|--------|
| `nimon-backend/src/modules/media/media.validation.ts` | Added `resolveCoverMime()` to normalize `image/jpg` → `image/jpeg`, and for empty / `application/octet-stream` MIME to infer allowed types from the **sanitized** original filename extension (`.jpg`, `.jpeg`, `.png`, `.webp` only). Exported `sanitizeOriginalFilename()` shared with the service. |
| `nimon-backend/src/modules/media/media.service.ts` | `saveCover` uses `resolveCoverMime` instead of `assertMimeAllowed('cover', …)`. Imports sanitization from validation (single implementation). |
| `nimon-backend/src/modules/media/media.service.spec.ts` | Tests for `image/jpg`, octet-stream + `.jpg`, empty MIME + `.jpeg`, octet-stream + `.pdf` rejection. |
| `nimon-backend/src/modules/media/media.controller.spec.ts` | Integration tests for `image/jpg`, octet-stream + JPG filename, octet-stream + PDF rejection. |

## MIME / Extension Policy

- **Direct MIME (no fallback):** `image/jpeg`, `image/jpg` (normalized to **`image/jpeg`** in responses), `image/png`, `image/webp`. Any other declared MIME (e.g. `image/gif`, `application/pdf`) is rejected unless the rules below apply.
- **Fallback (cover only):** If MIME is **empty** or **`application/octet-stream`**, the server derives the type from the **sanitized basename** extension: **`.jpg`**, **`.jpeg`** → `image/jpeg`; **`.png`** → `image/png`; **`.webp`** → `image/webp`. Extensions such as **`.gif`**, **`.bmp`**, **`.pdf`** are rejected.
- **Storage:** Filenames remain **server-generated** (`timestamp` + UUID + extension). **`image/jpeg`** is always stored with extension **`.jpg`** (consistent JPEG on disk). Paths never use raw client paths.

## Tests Added

- **MediaService:** `image/jpg` → response `mediaType` `image/jpeg` and written path ends with `.jpg`; `application/octet-stream` + `photo.jpg`; empty `mimetype` + `photo.jpeg`; `application/octet-stream` + `photo.pdf` → 415.
- **MediaController:** Same scenarios at HTTP layer (`image/jpg`, octet-stream + JPG, octet-stream + PDF).

Audio upload tests and `saveAudio` validation were not changed.

## Backend Test Result

Command:

```bash
node ./node_modules/jest/bin/jest.js src/modules/media
```

**Result:** All tests passed (`2` suites, `17` tests).

## Backend Build Result

Command:

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** Build succeeded (exit code `0`).

## Remaining Risks

- **Extension-only inference** for octet-stream / empty MIME trusts the client-provided filename for type hints only (after sanitization). Content is not sniffed; malicious uploads renamed with an image extension could still be stored (same class of risk as before for untrusted clients).
- Clients sending wrong MIME **and** wrong extension (e.g. PNG bytes labeled `.jpg`) may still pass extension/MIME checks until optional magic-byte validation exists.

## Manual Verification Steps

1. Obtain a valid JPEG file (or minimal JPEG bytes).
2. **POST** `multipart/form-data` to `/v1/media/upload/cover` with field `file`, valid Bearer JWT.
3. Verify accepts when `Content-Type` for the part is `image/jpg` and response `mediaType` is `image/jpeg`.
4. Verify accepts when the part is `application/octet-stream` and filename ends with `.jpg`.
5. Verify **415** when type is `application/octet-stream` and filename ends with `.pdf`.
6. Confirm returned `url` uses a new server-generated name ending in `.jpg` for JPEG covers.

---

## Output Summary

| Check | Result |
|-------|--------|
| `image/jpg` accepted? | Yes (canonicalized to `image/jpeg`) |
| `application/octet-stream` + `.jpg` accepted? | Yes |
| Unsupported types still rejected? | Yes (e.g. declared `application/pdf`, octet-stream + `.pdf`) |
| Tests passed? | Yes (`jest src/modules/media`) |
| Backend build passed? | Yes (`nest build`) |
