# P3 Backend Published Mono Permanent Delete Report

## Files Changed

- `nimon-backend/src/modules/published-monos/published-monos.controller.ts`
- `nimon-backend/src/modules/published-monos/published-monos.service.ts`
- `nimon-backend/src/modules/published-monos/published-monos.dto.ts`
- `nimon-backend/src/modules/published-monos/published-monos.service.spec.ts`

## Endpoint

- **DELETE** `/v1/published-monos/:id/permanent`
- **Auth:** `JwtOrDevOwnerFallbackGuard` (owner-scoped; matches Trash/Restore).
- **HTTP:** `204 No Content` on success.

## Preconditions

- PublishedMono must exist for the owner, otherwise **404** `published_mono_not_found`.
- PublishedMono must be trashed (`trashedAt != null`), otherwise **400** `published_mono_must_be_trashed_first`.
- Body must include: `{ "confirm": "DELETE" }`, otherwise **400** `missing_delete_confirm`.

## Delete Transaction

Implemented in a single `prisma.$transaction()`:

1. `findFirst` published mono by `{ id, ownerId }` (select `id`, `trashedAt`).
2. Verify `trashedAt != null`.
3. `deleteMany` StoryDraft rows where `{ ownerId, publishedMonoId: id }` (cascades draft dependents).
4. `deleteMany` PublishedMono row where `{ ownerId, id }`.

## Draft Cascade Behavior

Schema uses `onDelete: Cascade` for draft dependents:

- `draft_sentences`
- `draft_vocab_entries`
- `draft_grammar_entries`
- `draft_quiz_entries`
- `draft_audio`

Deleting `StoryDraft` rows therefore removes these rows automatically.

## Media Cleanup Policy

- **Deferred / best-effort only.** This P3.0 endpoint does **not** attempt object storage deletion.
- Rationale: do not block DB deletion on media cleanup; media key tracking is not yet first-class.

## Tests Added

Added unit tests to `published-monos.service.spec.ts`:

- confirm body required (`missing_delete_confirm`)
- 404 when missing/not owner (`published_mono_not_found`)
- 400 when not trashed (`published_mono_must_be_trashed_first`)
- successful path deletes linked drafts then deletes PublishedMono

## Backend Test Result

Run:

- `node ./node_modules/jest/bin/jest.js src/modules/published-monos`
- `node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.owner-scope.spec.ts`

Result: **pass**.

## Backend Build Result

Run:

- `node ./node_modules/@nestjs/cli/bin/nest.js build`

Result: **pass**.

## Remaining Risks

- **Idempotency:** retries after success return **404** (acceptable V1; document for clients).
- **Media orphaning:** object storage keys referenced from `coverImageUrl` / `DraftAudio.content` are not cleaned up yet.
- **Future social surfaces:** bookmarks/shares may want a tombstone instead of generic 404.

## Recommended Next Step

- **P3.1 Flutter UI:** add “Permanently delete” button on Trash rows with double confirmation, wire to this endpoint, and refresh surfaces.

