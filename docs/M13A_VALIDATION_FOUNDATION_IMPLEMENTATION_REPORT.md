# M13A Validation Foundation Implementation Report

## Problem

Validation rules and UX handling for guests, offline mode, auth failures, and rich text fields were not centralized. Risk of duplicated logic, inconsistent messages, and hard-to-test scattered checks across Flutter screens and Nest modules.

## Architecture

- **Specification**: `docs/M13_NIMON_VALIDATION_AND_LIMITATION_STANDARD.md` defines modes, severities, issue shape, UX policy, and product rules.
- **Backend**: Pure validators under `nimon-backend/src/common/validation/` with `ValidationIssue` / `ValidationResult`, `combine`, `hasBlockingIssues`, and `messageKey` for client mapping.
- **Flutter**: Mirrored helpers under `lib/core/validation/` with the same codes/keys, plus `validation_fallback_messages.dart` (English) for `messageKey` → copy.
- **Protected actions**: `lib/core/validation/protected_action.dart` + `nimonNetworkOnlineProvider` (defaults to online until connectivity is integrated).
- **Error mapping (N)**: API returns `400` with `{ message: 'validation_failed', issues: ValidationIssue[] }` where present; Flutter maps `messageKey` via `validation_fallback_messages.dart`.

## Validation Modes

Aligned with the standard document: `Draft`, `ReadOnlyPublish`, `FullLearnPublish`, `ProfileUpdate`, `Auth`, `ProtectedAction`.

## Validation Issue Shape

`ValidationIssue`: `code`, `field`, `messageKey`, `severity`, optional `params`, optional `source`.

## Backend Foundation

Files include `validation-issue.ts`, `validation-result.ts`, `validation-mode.ts`, `validation-severity.ts`, `text-normalization.ts`, `text-safety.ts`, `reserved-words.ts`, `profile-validation.ts`, `story-validation.ts`, `learn-validation.ts`, `auth-validation.ts`, `collection-validation.ts`, barrel `index.ts`.

## Flutter Foundation

Exported barrel `lib/core/validation/validation.dart`; normalization + validators + fallback messages + protected-action UX.

## Profile Rules

Implemented: display name (1–30, trim/collapse, no HTML/script), handle (3–24, `a-z`/`0-9`/`_`/`.` rules, reserved list, no emoji), bio (≤150 chars, ≤3 lines, no HTML/script).

## Story Rules

Implemented: title/description validators by mode; **sentence limit matrices** in `story-validation.ts` / `story_validators.dart`; draft basics normalization via `normalizeStoryDraftTextFields` on story draft create/update (trim/collapse, single-line awareness).

## Learn Limits

Vocabulary, grammar, and quiz band tables plus global quiz ceiling (`QUIZ_GLOBAL_HARD_MAX = 24`). First-pass validators: vocabulary meaning, furigana reading, grammar title, quiz item.

## Auth Rules

Structural validation for register/login payloads; weak-password blocklist; generic login failure message: `Email or password is incorrect.` Password length aligned to **8–64** in DTOs and validators.

## Protected Action UX

`ProtectedActionType`, `ProtectedActionDecision`, `checkProtectedAction`, `showProtectedActionPrompt` (Sign in / Not now → `/login`). **Mono react** uses this flow instead of an inline snackbar for guests.

## Integrated Paths

| Area | Integration |
|------|-------------|
| Auth register/login | `validateRegisterPayload` / `validateLoginPayload`; generic unauthorized login message |
| Profile PATCH | `patchMeProfile` combines profile validators; rejects blocking issues with `400` + `issues` |
| Collections create/update | `validateCollectionName` before persistence |
| Story drafts | Title/description normalization on create/update draft |

Publish pipeline deep validation (read-only vs full learn) is **not** fully wired yet to avoid blocking legacy content; constants and pure validators are ready for gated use.

## Tests Added

- Backend: `src/common/validation/validation.spec.ts`.
- Flutter: `test/core/validation/validation_foundation_test.dart`.

## Commands Run

- Backend: `jest --runInBand` (full suite: **20** suites, **203** tests passed).
- Backend build: `nest build` (exit **0**).
- Flutter: `dart format` on touched Dart paths.
- Flutter: `flutter analyze lib/core/validation lib/features/mono/mono_screen.dart` (no issues).
- Flutter: `flutter test test/core/validation/validation_foundation_test.dart` and **full** `flutter test` (exit **0**).

## Manual Verification

Not run in this session (API + device). Recommend: profile PATCH with invalid handle; collection create with invalid title; register with weak password; guest Mono react shows bottom sheet with Sign in / Not now.

## Remaining Risks

- **Connectivity**: `nimonNetworkOnlineProvider` defaults to `true`; offline UX relies on overriding this when a real connectivity source exists.
- **Emoji / unicode**: Dart uses `characters` + `\p{Extended_Pictographic}` where supported; edge-case emoji sequences may differ slightly from backend counts.
- **Publish guards**: Full integration with published-mono publish workflow deferred to avoid rejecting existing edge-case content until explicitly gated by publish mode.

## Recommended Next Step

Wire **publish** and **full learn publish** flows to call story/learn validators with the correct `ValidationMode`, add localized strings for all `messageKey` values, and replace `nimonNetworkOnlineProvider` with a real connectivity signal.

---

## Part Q — Delivery checklist

| Item | Status |
|------|--------|
| Validation standard doc (`M13_NIMON_VALIDATION_AND_LIMITATION_STANDARD.md`) | Yes (pre-existing / referenced) |
| Backend validation foundation | Yes (`src/common/validation/`) |
| Flutter validation foundation | Yes (`lib/core/validation/`) |
| Profile rules implemented | Yes (backend + Flutter) |
| Story title/description rules implemented | Yes |
| Learn limit constants implemented | Yes |
| Auth rules implemented | Yes |
| Protected action foundation created | Yes |
| Guest react → login-required decision works | Yes (tests + Mono wiring) |
| Offline network decision works | Yes (tests + provider override) |
| Tests passed | Yes |
| Build passed | Yes (`nest build`) |

## Follow-up: M13B

Publish Read-only and Full Learn flows now call the shared publish validator on the server and use matching Flutter preflight + `showPublishValidationSheet` before/after remote publish. See `docs/M13B_PUBLISH_VALIDATION_GATE_REPORT.md`.

## Follow-up: M13C

Protected actions (react, follow, save, create/publish story, collections, media upload, edit profile) use `ensureProtectedActionAllowed`, centralized fallback keys (`protected.*.login`), optional offline snack via `nimonNetworkOnlineProvider`, and transport-level offline mapping. See `docs/M13C_PROTECTED_ACTION_CONNECTIVITY_REPORT.md` and `docs/M13C_PROTECTED_ACTION_CONNECTIVITY_AUDIT.md`.

## Follow-up: M13E

High-traffic forms now call shared validators + `form_validation_adapter`; HTTP `validation_failed` maps via `HttpValidationFailedException` where wired. See `docs/M13E_FORM_FIELD_VALIDATION_INTEGRATION_REPORT.md`.

## Follow-up: M13F

Central `assertNoBlockingValidationIssues` / `validationFailedException` in `nimon-backend/src/common/validation/validation-exception.ts`; draft story create/update wired to Draft-mode title/description checks; audit table in `docs/M13F_BACKEND_VALIDATION_RESPONSE_AUDIT.md`. See `docs/M13F_BACKEND_VALIDATION_RESPONSE_CONSISTENCY_REPORT.md`.

## Follow-up: M13H

`messageKey` display is wired through **AppLocalizations** first with English fallback safety (`localized_validation_messages.dart`, expanded ARB). See `docs/M13H_VALIDATION_LOCALIZATION_REPORT.md`.
