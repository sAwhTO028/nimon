# Published Mono Edit Runtime Diagnosis Report

## Runtime Symptom

Profile → Published → mono reader → dock **Published Mono** panel → **Edit** appeared to do nothing: Creator did not open. Automated tests passed because they mocked IDs or did not exercise raw HTTP JSON shapes end-to-end.

## Debug Trace Points

Under **`kDebugMode` only** (no logs in release):

| Location | What is logged |
|----------|----------------|
| `mono_story_options_sheet.dart` | Edit tap: `item.id`, `sourceDraftId`, `catalogMonoId`, `hostMounted` |
| `creator_resume_draft.dart` → `tryResumeFromPublishedSurface` / `resume` | Entry: mono id, `sourceDraftId`, `useRemoteDrafts`; candidate list; each `loadDraft(candidate)` result or exception; refresh GET detail result; resolved draft id; **`resume` navigate `target=` URI**; `resume()` finished |

Use a debug build and watch the console while reproducing.

## Actual IDs Observed

Expected shapes:

- **`item.id`**: often `profile-<publishedMonoUuid>` in Profile reader.
- **`sourceDraftId`**: must be the **story draft UUID** (`GET /v1/story-drafts/:draftId`). **`loadDraft` never accepts a published mono id** for remote repository (HTTP path is `/v1/story-drafts/:id`).
- Backend stores the draft link in published **`content.sourceDraftId`** (see `nimon-backend` `published-mono-common.ts`); the API response may expose `sourceDraftId` at the **root** and/or **only inside `content`**.

## Root Cause

1. **JSON parsing gap:** Flutter read `sourceDraftId` only from the **top-level** JSON field. If the wire payload omitted the duplicate root field but still had `content.sourceDraftId`, **`MonoFeedItem.sourceDraftId` stayed null** at runtime even though the draft link existed.
2. **Candidate order:** `publishedEditResumeDraftLookupIds` tried the **stripped published mono id first**. Remote `loadDraft` uses `GET /v1/story-drafts/:id`, so that candidate **cannot** succeed for a mono UUID—only the real draft id can (second candidate previously came too late when the first failure path masked UX).
3. **Silent / invisible failure:** Using `context` after async gaps without capturing **`ScaffoldMessenger.maybeOf` early** could skip the snackbar in edge cases. Failure UX now uses a messenger reference captured when the route is still mounted.

## Fix Applied

1. **`readPublishedMonoSourceDraftIdFromJson`** (`published_mono_dto.dart`): resolve linked draft id from **top-level `sourceDraftId` OR `content.sourceDraftId`**.
2. **`RemotePublishedMonoRepository`** list + detail and **`RemoteMonoFeedRepository.fetchMonoDetail`**: use that helper when building DTOs.
3. **`publishedEditResumeDraftLookupIds`:** order candidates **`[sourceDraftId, stripped surface id]`** so the draft UUID is tried first.
4. **`tryResumeFromPublishedSurface`:** if `sourceDraftId` is still empty, **`GET /v1/published-monos/:id`** refresh via `remotePublishedMonoRepositoryForProfileProvider` (when `NIMON_USE_REMOTE_DRAFTS` is true) to recover `sourceDraftId`.
5. **Instrumentation:** `debugPrint` trace (debug only) through edit + load + resume; **exception** logging per `loadDraft` candidate.
6. **SnackBar:** `ScaffoldMessenger.maybeOf(context)` captured up front; failure message remains **“Could not open this story for editing.”**
7. **`context.mounted`** check before `resume()`; async-gap lint addressed.

## Tests Added

- `test/features/profile/published_mono_source_draft_id_parse_test.dart` — top-level vs `content.sourceDraftId`, absent case.
- Updated `test/features/create/creator_resume_published_edit_lookup_test.dart` — candidate order (**draft id before mono id**).

## Flutter Analyze Result

Command: `flutter analyze` on touched paths.

- `creator_resume_draft.dart`: resolved **`use_build_context_synchronously`** by checking `context.mounted` before `resume()` and capturing `ScaffoldMessenger` early.
- `published_mono_dto.dart`: file-level `///` doc adjusted to avoid **`dangling_library_doc_comments`** (no named `library` directive).

Remaining infos in `mono_story_options_sheet.dart` (e.g. `withOpacity` deprecations) are pre-existing in that file.

## Flutter Test Result

- `flutter test test/features/profile test/features/create test/features/mono` — passed during verification.
- `flutter test` (full suite) — **251 tests, all passed** (includes +3 new/updated tests).

## Manual Verification Steps

1. Debug build, remote drafts ON (`NIMON_USE_REMOTE_DRAFTS=true`), valid API.
2. Profile → Published → open story → **⋯** → **Edit**.
3. Confirm console `[PublishedEdit]` lines show a **draft** candidate first and `loadDraft` → `found`.
4. Confirm Creator opens; if not, confirm snackbar and logs show **useRemoteDrafts false** or **401**/network.

## Remaining Risks

- **`NIMON_USE_REMOTE_DRAFTS=false`:** `RemoteStoryDraftRepository` is not used; **`loadDraft` is local storage only**. Unless a full draft file exists under the draft UUID locally, Edit cannot succeed (logs will state `useRemoteDrafts=false`).
- **Auth:** `GET` published mono / story draft requires a valid session; 401 falls through to failure snackbar.
- **Duplicate GET:** When `sourceDraftId` is missing from the in-memory item, the resume path may **refetch** published detail (extra network call).
