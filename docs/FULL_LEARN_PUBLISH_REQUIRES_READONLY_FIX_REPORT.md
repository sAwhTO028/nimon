# Full Learn Publish Requires Readonly Fix Report

## Root Cause

`publishFullLearn` on the Nest `StoryDraftsService` updates an existing `PublishedMono` row and requires `draft.publishedMonoId` to already exist. A draft that has never completed read-only publish has `publishedMonoId == null`, so the backend returns **HTTP 422** with `details.unmet` containing `published_mono_missing` and a technical message.

The Flutter remote save path sent **PUT** draft content then **POST** `/publish/full-learn` only. It did not insert **POST** `/publish/read-only` when the server draft had no `publishedMonoId`, so first-time Full Learn publish failed even when read-only requirements were satisfied.

## Files Changed

| Area | File |
|------|------|
| Remote publish sequence + HTTP errors | `lib/features/create/data/remote_story_draft_repository.dart` |
| 422 `published_mono_missing` mapping + `StoryDraftHttpResponseException` | `lib/features/create/data/story_draft_remote_publish_errors.dart` |
| Progress hook wiring | `lib/features/create/data/story_draft_repository_provider.dart` |
| Publish phase state | `lib/features/create/creator_publish_status_provider.dart` |
| Clear phase on finish / back reset | `lib/features/create/creator_drawer_publish.dart`, `lib/features/create/creator_back_policy.dart` |
| Drawer progress line under Publish | `lib/features/create/creator_progress_drawer.dart` |
| Tests | `test/features/create/remote_story_draft_full_learn_publish_sequence_test.dart`, `test/features/create/story_draft_remote_publish_errors_test.dart` |

## Publish Sequence

On `saveDraft` when the in-memory draft requests `full_learn_published`:

1. **PUT** `/v1/story-drafts/:id` with content and `publishState: draft` (unchanged).
2. If the **PUT response DTO** has no `publishedMonoId` (null/empty):
   - Fire progress: `Publishing story…`
   - **POST** `/v1/story-drafts/:id/publish/read-only` with `If-Match` from the PUT (then 409 retry path unchanged).
   - Refresh stored etag from the read-only response.
3. Fire progress: `Publishing learn modules…`
4. **POST** `/v1/story-drafts/:id/publish/full-learn` with `If-Match` from the latest successful step.
5. Clear progress callback to `null` on success; also cleared on error and in `performCreatorDrawerPublish` `finally`.

If read-only POST throws, full-learn is **not** called. If `publishedMonoId` is already present on the PUT DTO, the read-only step is **skipped** (existing republish path).

## Error Message Handling

- **422 + `published_mono_missing`:** Mapped to:  
  `We need to publish the reading version first, then publish Full Learn.`  
  Thrown as `StoryDraftHttpResponseException` so `Exception.toString()` is clean (no `Bad state:` from `StateError`).
- **Other HTTP errors:** Still thrown as `StoryDraftHttpResponseException` with `HTTP <code>: <body>` so failures are not hidden—only the known validation case is rewritten.

## Tests Added

- `test/features/create/remote_story_draft_full_learn_publish_sequence_test.dart`
  - Full learn with missing `publishedMonoId`: **GET → PUT → POST read-only → POST full-learn** in order.
  - Read-only POST fails (422): **no** full-learn POST; non-strict mode falls back to local persistence (no silent “success” on wire).
  - PUT already includes `publishedMonoId`: **no** read-only POST; full-learn only.
- `test/features/create/story_draft_remote_publish_errors_test.dart`
  - Parser maps `published_mono_missing`; other `unmet` codes return null.

## Flutter Analyze Result

- **Scoped (changed app libraries):** `flutter analyze` on the touched `lib/features/create/...` paths: **No issues found.**
- **Full repo:** `flutter analyze` reports many pre-existing infos/warnings across the project (225 analyzer entries in this environment); none were introduced specifically for this fix.

## Flutter Test Result

- `flutter test` (full suite): **All tests passed** (195 tests in the run used for this report).

## Remaining Risks

- If the backend **omits** `publishedMonoId` from GET/PUT JSON even when the row exists, the client might run an extra read-only publish (should be idempotent server-side for V1).
- `RemoteBackendConfig.strictRemoteDrafts` still controls whether remote failures fall back to local-only success; creators using strict mode will see the exception instead of fallback.

## Recommended Next Step

- Optional backend improvement: accept Full Learn publish without a prior client-driven read-only call by creating `PublishedMono` inside `publishFullLearn` when missing (would remove the need for the client chain, but was out of scope here).

---

## Output summary (task checklist)

| Question | Answer |
|----------|--------|
| Auto read-only before full-learn added? | **Yes** — in `RemoteStoryDraftRepository.saveDraft` when PUT DTO has no `publishedMonoId`. |
| Raw 422 hidden? | **`published_mono_missing` only** — replaced with friendly copy; other errors keep HTTP + body. |
| New tests passed? | **Yes** — sequence + parser tests. |
| Full `flutter test` passed? | **Yes** — 195 tests. |
| Manual flow to verify | Enable remote drafts, open a draft that never had Read Only published, complete Full Learn readiness, tap **Publish Full Learn**: expect brief “Publishing story…” then “Publishing learn modules…”, then success; Profile **Published** should show the story. Force a stale backend-only edge (if available) to confirm the friendly sentence if `published_mono_missing` still appears. |
