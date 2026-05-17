# M20F — Publish stale draft conflict (HTTP 409)

## Root cause

Publish runs `PUT /v1/story-drafts/:id` then `POST …/publish/read-only` or `POST …/publish/full-learn` with an `If-Match` etag. Autosave, debounced saves, or another client can advance the server version first. Publish then sends a stale etag and Nest returns:

- HTTP **409**
- `error.code`: `conflict`
- `error.message`: `Draft was modified; refresh and retry`
- `error.details.currentEtag`: e.g. `v341`

The app previously surfaced a generic “Could not publish” (sometimes with raw HTTP text) and could leave optimistic publish UI state without a successful server publish.

## 409 behavior (backend unchanged)

Backend draft version checks are unchanged. Flutter now:

1. Detects 409 + `conflict` + `currentEtag` (and message containing “Draft was modified” when present).
2. Performs one HTTP retry with the server `currentEtag` on PUT/POST (existing `_retryOnceOn409Conflict`).
3. If 409 persists on a **publish** path: `GET /v1/story-drafts/:id`, updates local etag/cache, throws `StoryDraftPublishConflictException`.

Debug logs (no tokens):

- `[M20F publish-conflict] draftId=… currentEtag=…`
- `[M20F publish-refresh] draftId=… refreshedEtag=…`
- `[M20F publish-retry] attempted=true/false`

## UX behavior

On publish conflict:

- User stays on the editor (no Published tab navigation).
- Snackbar: **“Draft changed. Please review and publish again.”**
- `lastSaveError` uses the same friendly string (not prefixed with “Could not publish:”).
- Publish is **not** marked successful; catalog refresh / Published move only after server publish succeeds.
- Local draft is replaced with the reloaded server DTO when reload succeeds.
- Optimistic `publishState` from the failed attempt is reverted.

## Retry policy

| Layer | Policy |
|--------|--------|
| HTTP (repository) | One retry per failing PUT/POST using `details.currentEtag` |
| After persistent 409 on publish | Reload draft via GET, throw conflict exception |
| Notifier | One extra publish attempt **only if** reload left `dirty == false` (no pending local edits) |
| Never | Infinite loops |

## Pre-publish save

Before publish:

1. Cancel debounced autosave timer.
2. Await any in-flight `persistLocalNow`.
3. If still `dirty`, flush with `pre_publish_flush` (PUT only, no publish POST).

Publish then uses the etag from the latest save response.

## Code touchpoints

- `lib/features/create/data/story_draft_remote_publish_errors.dart` — conflict exception + parsers
- `lib/features/create/data/remote_story_draft_repository.dart` — reload on publish 409, M20F logs
- `lib/features/create/story_creator_provider.dart` — pre-publish flush, conflict retry, friendly error
- `lib/features/create/creator_drawer_publish.dart` — friendly snackbar text

## Tests

Flutter (`test/features/create/m20f_publish_stale_conflict_test.dart`):

- Persistent publish 409 → reload GET + `StoryDraftPublishConflictException`
- Conflict body parsing helpers
- Notifier: conflict → friendly `lastSaveError`, `publishReadingOnlyToDisk` false, publish state reverted
- Notifier: at most one retry when second publish succeeds
- Notifier: debounced dirty save flushed (`none` intent) before publish intent

Run:

```bash
flutter test test/features/create/m20f_publish_stale_conflict_test.dart
```

## Phone acceptance checklist

- [ ] `NIMON_USE_REMOTE_DRAFTS=true` and correct `NIMON_API_BASE_URL` on device
- [ ] Edit draft, trigger autosave, tap Publish quickly → friendly conflict message (not raw 409 JSON)
- [ ] Remain on creator/editor; Published tab not opened on conflict
- [ ] After conflict, draft content matches server (reload visible if server changed)
- [ ] Tap Publish again after review → succeeds when etag aligned
- [ ] No false “published” toast when 409 occurs
- [ ] Debug console shows `[M20F publish-conflict]` / `[M20F publish-refresh]` / `[M20F publish-retry]` without tokens
