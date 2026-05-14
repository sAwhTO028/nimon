# M13G Media Upload Validation Response Report

## Problem

Media uploads returned ad-hoc `BadRequestException` strings, **413** for multer oversize, and **415** for MIME rejection without a consistent structured validation envelope where field-level UX helps.

## Scope

- **Backend**: `media.validation.ts` assert file presence; `MediaService` size checks; `MulterExceptionFilter` for `LIMIT_FILE_SIZE`; reuse `assertNoBlockingValidationIssues` pattern via `throwValidationFailed` / `validationFailedException`. **No** changes to storage drivers, URL canonicalization, or successful response DTOs.
- **Flutter**: `MediaUploadRepository` parses `validation_failed`; `media_upload_error_mapper.dart`; fallback keys; upload UI catch blocks (story cover, audio, profile avatar/cover).

## Audit Summary

See **`docs/M13G_MEDIA_UPLOAD_VALIDATION_AUDIT.md`**.

## Backend Media Validation

- **`nimon-backend/src/common/validation/media-validation.ts`** — stable `ValidationIssue` builders (`media.file.*`, `coverImage` / `audioFile` for typed too-large).
- **`media.validation.ts`** — `assertFilePresent` throws `validation_failed` for missing vs empty buffer.
- **`media.service.ts`** — image/audio oversize uses `issueMediaImageTooLarge` / `issueMediaAudioTooLarge`.
- **`multer-exception.filter.ts`** — `LIMIT_FILE_SIZE` → **400** `validation_failed` (field by `/upload/cover` vs `/upload/audio`).

## Status Code Policy

- **400 + validation_failed**: missing file, empty file, oversize (multer + service).
- **415**: unsupported MIME from `resolveCoverMime` / `resolveAudioMime` (unchanged).
- **401**: auth (not converted).

## Flutter Error Mapping

- **`lib/core/media/media_upload_error_mapper.dart`** — `MediaUploadSurface`, `mediaUploadUserMessage`, `isMediaValidationError`.
- **`MediaUploadRepository._throwIfNotOk`** — `HttpValidationFailedException` when body parses as `validation_failed`.

## Upload Surfaces Updated

- Story cover / Create / Story basics: snackbar + inline hint via mapper.
- Listening audio: bottom sheet upload path.
- Profile avatar & cover: `EditProfileNotifier` error message.

## Fallback Messages

Added keys under **`validation_fallback_messages.dart`** for `media.file.*`, `media.image.*`, `media.audio.*` (English).

## Tests Added

- **Backend**: `media-validation.spec.ts`, `multer-exception.filter.spec.ts`; extended `media.controller.spec.ts`, `media.service.spec.ts`.
- **Flutter**: `test/core/media/media_upload_error_mapper_test.dart`, `test/features/create/media_upload_repository_validation_test.dart`; updated cover outcome tests.

## Commands Run

- Backend: `jest src/common/validation --runInBand`, `jest src/modules/media --runInBand`, full `jest --runInBand`, `nest build`.
- Flutter: `flutter test test/core/validation`, `flutter test test/core/media`, `flutter test test/features/create`, `flutter test test/features/profile`, full `flutter test`.

## Manual Verification

Use Part L checklist from the M13G task (invalid types, offline, valid retry).

## Remaining Risks

- **415** bodies remain Nest default strings in some environments; Flutter maps by **status code** + friendly template, not parsed issues.
- Changing multer oversize from **413** to **400** could affect any external client that keyed only on **413**; in-repo Flutter accepts both patterns.

## Recommended Next Step

If product wants **415** to carry structured issues too, add optional parallel `validation_failed` payload in a custom exception filter without removing **415** status.

## Follow-up: M13H

UI code paths use **`mediaUploadUserMessageLocalized`**; **`mediaUploadUserMessage`** remains for tests and non-widget layers. See **`docs/M13H_VALIDATION_LOCALIZATION_REPORT.md`**.
