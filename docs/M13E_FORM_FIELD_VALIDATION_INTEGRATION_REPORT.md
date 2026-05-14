# M13E Form Field Validation Integration Report

## Problem

High-value forms still mixed local string checks with the centralized validator suite from M13A, and HTTP `validation_failed` bodies were not consistently surfaced as field-level feedback.

## Scope

- **Flutter only** — no backend API or rule changes.
- **Does not** alter protected-action flow (M13C), live connectivity (M13D), or publish validation sheet ordering (M13B).
- **Does not** alter protected-action or publish flows; **M13F** aligned **Draft** title/description validators (server + Flutter) so draft saves block only dangerous patterns (unsafe markup, line breaks), not publish-length rules.

## Follow-up: M13F

`RemoteMeProfileRepository` must rethrow `HttpValidationFailedException` (non-strict mode no longer turns it into a generic `StateError`). Server uses shared `validation-exception` helper; see `docs/M13F_BACKEND_VALIDATION_RESPONSE_CONSISTENCY_REPORT.md`.

## Field Validation Adapter

- **`lib/core/validation/form_validation_adapter.dart`**
  - `firstBlockingMessageForField` — blocking issues only; warnings excluded from “hard” field errors.
  - `validateFieldForTextForm` — thin wrapper for text fields.
  - `fieldErrorsFromIssues` / `firstUnhandledBlockingMessage` — map backend issues to fields + optional central fallback.

- **`lib/core/validation/http_validation_failed_exception.dart`** — typed carrier for `validation_failed` issue lists (shared by auth and profile/collections repositories).

## Auth Forms

- **Register** (`register_screen.dart`): `validateRegisterFormFields` (email + password + confirm match); `normalizeEmailInput` on submit; backend `validation_failed` maps via `HttpValidationFailedException`.
- **Login** (`login_screen.dart`): `validateLoginFields` for inline empty/format; generic **`auth.login.failed`** when credentials fail (no account enumeration).
- **`auth_repository.dart`**: parses `validation_failed` before generic `AuthRepositoryException`.

## Edit Profile

- **Local**: `validateDisplayName` / `validateHandle` / `validateBio` before PATCH.
- **State**: `EditProfileState.profileFieldErrors` keyed by validator `field` ids (`displayName`, `handle`, `bio`).
- **Remote**: `RemoteMeProfileRepository` throws `HttpValidationFailedException` when the response body is `validation_failed`.
- **UI**: inline `errorText` on the three fields; helper text for handle updated to **3–24** chars to match validators.

## Collections

- **Add to collection sheet**: `validateCollectionName` before create; inline `errorText`; HTTP validation maps `collection.title` / `collection.name` keys.
- **`_CollectionNameSheet`** (profile rename/new folder): same client validation before `Navigator.pop`.
- **Owner collections rename dialog** (`profile_screen.dart`): client validation + `HttpValidationFailedException` snack messaging instead of raw exception strings.
- **`RemoteCreatorCollectionsRepository`**: `validation_failed` → `HttpValidationFailedException`.

## Story Basics

- **`create_story_basics_form.dart`**: `validateStoryTitle` / `validateStoryDescription` with **`ValidationMode.draft`**.
  - Blocking issues (unsafe input, length, etc.) show as `errorText`.
  - Empty title in draft stays a **warning** (`story.title.recommended`) via `helperText`, not a blocking error — autosave remains lenient.
- Title `maxLength` aligned to **80** (validator max).

## Backend validation_failed Mapping

- Reuses **`tryParseValidationIssuesFromHttpBody`** / **`validation_issue_from_json`** (M13A).
- Repositories throw **`HttpValidationFailedException`** before legacy string/code paths when issues are present.

## Fallback Messages

- Added **`auth.confirmPassword.mismatch`**, **`auth.login.failed`**, and **`collection.name.*`** aliases mirroring `collection.title.*` copy for docs/product keys.

## Tests Added

| File | Role |
|------|------|
| `test/core/validation/form_validation_adapter_test.dart` | Adapter + draft title warning vs blocking behavior |

## Commands Run

```text
dart format (touched files)
dart analyze lib/core/validation lib/features/auth lib/features/profile lib/features/create/create_story_basics_form.dart
flutter test test/core/validation
flutter test test/auth
flutter test test/widget_test.dart
flutter test
```

Last full run: **505** tests passed.

## Manual Verification

1. Register with invalid email / weak password / mismatch — inline errors; success still reaches `/mono` when valid.
2. Login with empty fields — field errors; wrong password — generic login failed copy only.
3. Edit profile — invalid handle/bio lines; save with valid data; handle conflict still shows friendly taken message.
4. Collection create/rename — reject URL/script-only names inline; server `validation_failed` maps when backend sends it.
5. Story basics — dangerous title shows error; empty title shows recommendation helper, not a blocking error.

## Remaining Risks

- Backend field ids for `validation_failed` must align with **`ValidationIssue.field`** names for perfect mapping; unmapped issues fall back to snack copy.
- **`register_validation.dart`** remains for legacy unit tests; UI uses **`auth_validators`** only.

## Recommended Next Step

Wire **`validation_failed`** on remaining write APIs (draft PATCH beyond publish) using the same **`HttpValidationFailedException`** pattern where product needs field UX.

## Follow-up: M13H

UI layers display validator / HTTP issues via **`validationIssueDisplayMessageLocalized`**; pure **`form_validation_adapter`** helpers still return English fallback strings for non-UI consumers. See **`docs/M13H_VALIDATION_LOCALIZATION_REPORT.md`**.
