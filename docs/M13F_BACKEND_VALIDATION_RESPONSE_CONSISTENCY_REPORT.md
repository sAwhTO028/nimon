# M13F Backend Validation Response Consistency Report

## Problem

Several Nest services threw hand-built `BadRequestException({ message: 'validation_failed', issues })` objects while others duplicated the same shape. Draft story create/update did not reject dangerous title/description content at the API layer. Flutter profile PATCH swallowed `HttpValidationFailedException` inside a broad catch and replaced it with a generic save error.

## Scope

- Backend: central helper for `validation_failed`, refactor auth / creator collections / story drafts publish paths, add draft basics validation on create/update.
- Flutter: ensure profile repository rethrows `HttpValidationFailedException`; extend JSON parser tests; repository tests for validation-first behavior.
- Out of scope: schema, protected-action guard, publish sheet UX logic, DB rules unrelated to alignment, converting query-parameter errors or media upload strings to `validation_failed`.

## Audit Summary

See **`docs/M13F_BACKEND_VALIDATION_RESPONSE_AUDIT.md`** for the module-by-module table (write APIs, query-only bad requests, media audit, mono-social business errors).

## Standard Error Helper

- **`nimon-backend/src/common/validation/validation-exception.ts`**
  - `validationFailedException(issues)` — returns `BadRequestException` with `{ message: 'validation_failed', issues }`.
  - `throwValidationFailed(issues)` — `never`.
  - `assertNoBlockingValidationIssues(result)` — uses `hasBlockingIssues(result)` and throws when blocking issues exist.

## Backend Endpoints Updated

- **Auth**: `register`, `login` (structural validation only), `patchMeProfile` — use `assertNoBlockingValidationIssues` instead of inline constructors.
- **Creator collections**: `create`, `updateMine` — same.
- **Story drafts**: `createDraft`, `updateDraft` — combine `validateStoryTitle` / `validateStoryDescription` with `ValidationMode.Draft` when `title` / `description` keys are present; `publishReadOnly` / `publishFullLearn` — use `assertNoBlockingValidationIssues`.
- **Story validation (Draft mode)**: Backend and Flutter now treat **Draft** as lenient for publish-oriented rules: **blocking only** for unsafe markup and line breaks on title/description (aligned with M13A draft semantics).

## Endpoints Intentionally Not Updated

- **Mono feed / mono-social / user-follow**: invalid cursor, filter combos, `cannot_follow_self`, etc. — remain non–`validation_failed` `400`s or other statuses per audit.
- **Media** (superseded by **M13G**): upload routes now use `validation_failed` for missing/empty/oversize files; MIME rejection stays **415**. See `docs/M13G_MEDIA_UPLOAD_VALIDATION_RESPONSE_REPORT.md`.

## Follow-up: M13G

Structured media upload validation + Flutter `media_upload_error_mapper` + repository parsing. See **`docs/M13G_MEDIA_UPLOAD_VALIDATION_RESPONSE_REPORT.md`** and **`docs/M13G_MEDIA_UPLOAD_VALIDATION_AUDIT.md`**.
- **Story draft list `updatedAfter`**: invalid ISO timestamp remains structured `apiError` 400.

## Flutter Mapping Updates

- **`RemoteMeProfileRepository`**: `patchMyProfile` and `fetchMyProfile` rethrow `HttpValidationFailedException` so structured errors are not replaced by “Could not save/load profile.”

## Field ID Alignment

- No breaking changes: `collection.title` remains the canonical backend field; Flutter continues to treat `collection.name` as an alias in field-error maps (see M13E).

## Tests Added

- **Backend**: `validation-exception.spec.ts`; `story-drafts.basics-validation.spec.ts`; extended `auth.service.spec.ts`, `creator-collections.service.spec.ts`, `validation.spec.ts` (Draft story rules).
- **Flutter**: `validation_issue_from_json_test.dart` (nested `message` object); `auth_repository_test.dart`; `remote_me_profile_repository_test.dart`; `remote_creator_collections_repository_test.dart`.

## Commands Run

- Backend: `jest src/common/validation --runInBand`, `jest src/modules/auth --runInBand`, `jest src/modules/story-drafts --runInBand`, `jest src/modules/creator-collections --runInBand`, full `jest --runInBand`, `nest build`.
- Flutter: `flutter test test/core/validation`, targeted auth/profile/create tests, full `flutter test`.

*(Where `pnpm` / `npx` are unavailable in the environment, equivalent `node ./node_modules/jest/bin/jest.js` and `node ./node_modules/@nestjs/cli/bin/nest.js build` were used.)*

## Manual Verification

Use the checklist from the M13F task brief (register invalid email, login wrong password, profile handle, collection name, draft script title, publish missing title, forbidden action UX).

## Remaining Risks

- **Media / upload**: Clients still see string `400` bodies for some upload failures until a product decision adds `validation_failed` + UI mapping.
- **Login**: Structural `validation_failed` on malformed login payloads is intentional; credential failures remain generic.

## Recommended Next Step

Optionally extend **media upload** responses with `validation_failed` once upload screens have field-level targets; keep **415** for unsupported MIME types if clients branch on status code.
