# Audio Upload 415 And CTA Fix Report

**Report date:** 2026-05-05  
**Scope:** NestJS media validation for audio (MIME tolerance + extension inference) and Flutter creator sheet CTA copy. Prisma schema and migrations untouched. `MediaUploadRepository` client contract unchanged (same multipart upload and response parsing).

## Root Cause

**HTTP 415** on `POST /v1/media/upload/audio` came from **strict audio MIME checks**: only a small fixed set of exact `file.mimetype` strings was allowed. Browsers and **Flutter web** often send `application/octet-stream`, an **empty** `Content-Type`, or **non-canonical** audio aliases (`audio/x-wav`, `audio/vnd.wave`, `audio/m4a`, etc.), which the previous `assertMimeAllowed('audio', …)` rejected even when the file was a valid `.mp3` / `.m4a` / `.wav`.

## Backend Audio MIME Policy

- Added **`resolveAudioMime(mimetype, originalname)`** (parallel to `resolveCoverMime`):
  - **Declared types** are mapped to **canonical** values returned in `mediaType` and used for storage extension:
    - `audio/mpeg` and `audio/mp3` → **`audio/mpeg`**
    - `audio/mp4`, `audio/x-m4a`, `audio/m4a` → **`audio/mp4`**
    - `audio/wav`, `audio/x-wav`, `audio/wave`, `audio/vnd.wave` → **`audio/wav`**
  - If the type is **empty** or **`application/octet-stream`**, MIME is **inferred** from the **sanitized** `originalname` extension:
    - `.mp3` → `audio/mpeg`
    - `.m4a` → `audio/mp4`
    - `.wav` → `audio/wav`
  - **Blocked extensions** on inference path include `.pdf`, `.txt`, `.exe`, `.aac`, and common image extensions (prevents disguised uploads).
  - Unknown declared types still yield **415**.
- **`MediaService.saveAudio`** now uses **`resolveAudioMime`** instead of strict allow-list equality.
- **Storage file extension** mapping: canonical MIME → `.mp3` / `.m4a` / `.wav` (unchanged size limits).

## Flutter CTA Copy

| Location | Copy |
|----------|------|
| Empty helper | *Choose a file first. After upload, add it to your story.* |
| Success hint | *Tap Add audio to story to attach this file to your draft.* |
| Primary CTA | **Add audio to story** (`Icons.library_music_rounded`) |
| Secondary | **Replace audio**, **Remove audio** (unchanged) |

Release UI still hides Public URL / Attach without uploading unless advanced flag is enabled.

## Tests Added

**Backend (`media.service.spec.ts`):**

- `audio/mp3` → canonical `audio/mpeg`
- `application/octet-stream` + `song.mp3` / `song.m4a` / `song.wav`
- `audio/x-wav` and `audio/vnd.wave` → `audio/wav`
- `application/octet-stream` + `file.pdf` → 415

**Backend (`media.controller.spec.ts`):**

- Integration: octet-stream + `.mp3` / `.m4a`; octet-stream + `.pdf` → 415

**Flutter (`creator_audio_upload_sheet_test.dart`):**

- Helper line; success **Add audio to story** + hint text; release sheet still hides advanced controls.

Existing cover tests remain in suite.

## Backend Test Result

```bash
cd nimon-backend && node ./node_modules/jest/bin/jest.js src/modules/media --no-cache
```

**Result:** **36** tests passed (5 suites).

## Backend Build Result

```bash
cd nimon-backend && node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** Succeeded (exit code 0).

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/creator_audio_upload_sheet.dart \
  lib/features/create/story_creator_sentences_screen.dart \
  test/features/create/creator_audio_upload_sheet_test.dart
```

**Result:** No issues found.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/create` | **70** passed |
| `flutter test` | **231** passed |

## Manual Verification Steps

1. Sign in; open **Listening / Audio** → **Choose audio file**; pick `.mp3` (especially **web** where type may be octet-stream).
2. Confirm upload completes (**Upload complete**) without 415; tap **Add audio to story** and verify draft shows uploaded audio.
3. Repeat with `.m4a` / `.wav` if available.
4. Optional: attempt `.pdf` renamed — expect rejection / no successful audio attach.

## Remaining Risks

- **Declared MIME mismatch + misleading extension** (e.g. MP3 bytes labeled as something exotic not in the map) may still 415; inference path requires octet-stream or empty type.
- **AAC** is not accepted by policy (extension `.aac` blocked on inference).
- Flutter client still does not receive byte-level upload progress from API.

## Output Summary

| Question | Answer |
|----------|--------|
| Audio 415 fixed for typical clients? | **Yes** — octet-stream / aliases / wav variants normalized |
| octet-stream `.mp3` / `.m4a` / `.wav` accepted? | **Yes** (tests + controller integration) |
| Unsupported files still rejected? | **Yes** — e.g. `.pdf` with octet-stream |
| Success CTA updated? | **Yes** — **Add audio to story** + clearer hint |
| Backend tests passed? | **Yes** (36 in `src/modules/media`) |
| Backend build passed? | **Yes** |
| Flutter tests passed? | **Yes** (70 create / 231 full) |
