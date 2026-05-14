# M13B Publish Validation Gate Report

## Problem

Publish (Read-only and Full Learn) needed the same validation rules as the M13A foundation, applied at the right time: before creating/updating `PublishedMono` on the server, and with a clear client-side preflight so authors see blocking and recommended items instead of raw HTTP errors.

## Scope

- **Backend**: Central `validateStoryPublishInput` (already in M13A follow-up) throws `400` with `{ message: 'validation_failed', issues }` when blocking issues exist.
- **Flutter**: Local `validateStoryPublishData` with the same modes, preflight in `performCreatorDrawerPublish`, shared bottom sheet, and `400` body parsing in `RemoteStoryDraftRepository` as `StoryDraftValidationFailedException`.
- **Out of scope**: Authoring flow rewrite, schema changes, new AI or media work, and full semantic/AI rules.

## Backend Publish Gate

- **Entry point**: `nimon-backend/src/common/validation/publish-validation.ts` — `validateStoryPublishInput(input, mode)`.
- **Integration**: `StoryDraftsService.publishReadOnly` / `publishFullLearn` run validation before writing; on blocking issues, `assertNoBlockingValidationIssues` (same `{ message: 'validation_failed', issues }` response as before — **M13F** centralizes the throw).
- **Authoritative**: Client preflight is UX only; the server re-validates every publish.

## Read-only Publish Rules

Blocking: title (required and full title rules), at least one sentence with Japanese text, story body length and sentence count when JLPT and duration **band** both resolve, dangerous input on title, no line breaks in title, title not only numbers/symbols, etc. (per M13A story validators).

Warnings: empty description, missing JLPT, missing duration band (limits skipped for that publish).

**Learn content** (vocab, grammar, quiz, listening) is **not** required for Read-only.

## Full Learn Publish Rules

All Read-only blocking rules, plus: learn module workflow keys `vocabulary_kanji`, `grammar`, `quiz`, `audio` must be `completed`; counts for vocab, grammar, and quiz within JLPT×band tables and quiz global cap; per-item learn validators (meanings, furigana, grammar title, quiz row shape and correct answer), as implemented in M13A and mirrored in Flutter `publish_validation.dart`.

## Duration Band Handling

- **Backend / Flutter shared logic**: `resolveStoryDurationBand` in `story-duration-band.ts` and `lib/core/validation/story_duration_band.dart`.
- **Precedence**: Explicit `targetDurationBandKey` (`3_5` / `5_7` / `7_9`) if set; else infer from `durationSeconds` when present (minutes 3–5 → `3_5`, 5–7 → `5_7`, 7–9 → `7_9`); else `null`.
- **Creator V1 note**: `StoryPublishData` / `storyPublishDataFromCreator` pass `durationSeconds: null` because the V1 story aggregate does not store a story-level duration in seconds (only audio track duration exists, which is not used as a proxy for the reading length band to avoid wrong limits).
- **When band is null**: JLPT×band min/max for sentences and learn counts are **not** applied as blocking; warnings `story.limits.skippedNoBand` (and `story.limits.skippedNoJlpt` when level does not map to N1–N5) are emitted. This matches the “do not break old flow when duration was never collected” product constraint.

## Flutter Preflight

- **Mapper**: `lib/features/create/creator_publish_preflight.dart` — `storyPublishDataFromCreator(CreatorStoryV1)` builds the portable snapshot (sentences, learn rows, module workflow map).
- **Run**: `performCreatorDrawerPublish` calls `validateStoryPublishData` with `readOnlyPublish` or `fullLearnPublish` before `publishReadingOnlyToDisk` / `publishFullLearnToDisk`.
- **Behavior**: Blocking issues open the sheet and **do not** call the remote publish path. Warnings open the sheet with **Publish anyway**; choosing it continues to the existing save/publish flow.

## Publish Validation UI

- **API**: `lib/features/create/publish_validation_sheet.dart` — `showPublishValidationSheet(context, issues: …, showPublishAnyway: …)`.
- **Copy**: Title **Before publishing**; sections **Blocking** and **Recommended**; messages from `validation_fallback_messages.dart` (`validationIssueDisplayMessage` / `validationFieldLabelForPublish`).
- **Actions**: Primary **Fix issues** (dismiss). Optional **Publish anyway** when there are only warnings.

## Error Mapping

- **HTTP**: On `400`, `RemoteStoryDraftRepository._throwIfNotOk` parses bodies matching `validation_failed` via `tryParseValidationIssuesFromHttpBody` and throws `StoryDraftValidationFailedException(issues)`.
- **Provider**: `persistLocalNow` rethrows `StoryDraftValidationFailedException` after marking save failed; `publishReadingOnlyToDisk` / `publishFullLearnToDisk` roll back the optimistic publish state transition and rethrow.
- **UI**: `performCreatorDrawerPublish` catches the exception and opens `showPublishValidationSheet` with server issues (no generic snackbar-only path for validation failures).

## Tests Added

| Area | File |
|------|------|
| Publish gate (Flutter) | `test/core/validation/publish_validation_gate_test.dart` |
| JSON → issues | `test/core/validation/validation_issue_from_json_test.dart` |
| Sheet smoke | `test/features/create/publish_validation_sheet_test.dart` |

Backend tests from Part L were **not** executed in this environment (`pnpm` / `npx` / system Node were unavailable on PATH). The repo already contains `nimon-backend/src/common/validation/publish-validation.spec.ts` and updated story-drafts specs from the earlier M13B backend pass.

## Commands Run

**Flutter (executed)**

- `dart format` on touched Dart files
- `dart analyze` on touched validation/create paths (clean after cast fixes)
- `flutter test test/core/validation/publish_validation_gate_test.dart test/core/validation/validation_issue_from_json_test.dart test/features/create/publish_validation_sheet_test.dart`
- `flutter test test/features/create/creator_drawer_publish_labels_test.dart test/features/create/story_draft_remote_publish_errors_test.dart`
- `flutter test` (full suite, exit code 0)

**Backend (not executed here)**

- `pnpm jest src/common/validation --runInBand`
- `pnpm jest src/modules/story-drafts --runInBand`
- `pnpm jest src/modules/published-monos --runInBand`
- `pnpm jest --runInBand`
- `pnpm nest build`

Re-run these locally where Node/pnpm are installed.

## Manual Verification

1. Open creator workspace with a draft missing title → tap Read-only publish → sheet lists blocking title issue; network publish not sent until fixed (preflight).
2. Turn **remote drafts** on (if applicable), publish with invalid server-side payload → expect sheet from `StoryDraftValidationFailedException`, not only a snackbar.
3. Full Learn with incomplete module → blocking sheet from preflight.

## Remaining Risks

- **Nest JSON shape**: If the global exception filter changes how `BadRequestException` is serialized, `tryParseValidationIssuesFromHttpBody` may need a small adjustment (multiple shapes are partially tolerated).
- **Duration**: Until story-level duration is stored explicitly, band limits depend on `targetDurationBandKey`; authors without a band skip band-based blocking.

## Recommended Next Step

Wire structured validation responses for other user-facing commands that already use `validation_failed`, and add connectivity-aware messaging when publish fails for non-validation reasons.

## Follow-up: M13C

Publish from the creator drawer now runs **`ensureProtectedActionAllowed(ProtectedActionType.publishStory)`** before M13B preflight so guests see the standard sign-in sheet instead of hitting validation first. See `docs/M13C_PROTECTED_ACTION_CONNECTIVITY_REPORT.md`.

## Follow-up: M13E

Story basics uses **`ValidationMode.draft`** inline checks without changing publish gate ordering; auth/profile/collections forms share **`form_validation_adapter`** + **`HttpValidationFailedException`**. See `docs/M13E_FORM_FIELD_VALIDATION_INTEGRATION_REPORT.md`.

## Follow-up: M13H

Publish validation sheet titles, sections, buttons, and issue copy use **localized** strings while preserving the same gate behavior. See `docs/M13H_VALIDATION_LOCALIZATION_REPORT.md`.
