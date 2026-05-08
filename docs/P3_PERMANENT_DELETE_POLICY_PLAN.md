# P3 Permanent Delete Policy Plan

## 1. Executive Summary

P1 introduced **Trash** for `PublishedMono` via `trashedAt` and owner-scoped APIs (`POST .../trash`, `POST .../restore`, `GET ...?trashed=true`). P2 added Flutter Trash UX and explicitly **deferred permanent delete**.

**P3 goal:** add a safe, irreversible **Permanent delete** policy and backend endpoint that permanently removes a trashed story’s data **without reintroducing orphan/zombie states** and with a UX that avoids accidental loss.

**High-level recommendation (V1):**

- Permanent delete should be **allowed only when `PublishedMono.trashedAt != null`**.
- The endpoint should **delete the PublishedMono row and all linked draft data** (sentences + learn modules + audio rows) and attempt media cleanup where possible.
- UX should be **double-confirmed** with clear “no undo” copy.
- Start with synchronous DB cleanup; add **async media/orphan cleanup job** as a follow-on (P3.1/P4).

## 2. Current Trash Behavior

From P1/P2 implementation:

- **Soft delete:** `PublishedMono.trashedAt` set to ISO timestamp.
- **Visibility:**
  - Catalog/feed/detail/default owner published list require `trashedAt == null` (plus M5 dirty-draft hiding).
  - Trash list is `GET /v1/published-monos?trashed=true` → `{ ownerId, trashedAt: { not: null } }` (does not apply dirty-draft predicate).
- **Restore:** clears `trashedAt`; may remain hidden if linked draft has `hasUnpublishedCoreChanges === true` (M5 rule).
- **Draft delete orphan prevention:** `DELETE /v1/story-drafts/:draftId` rejects with `409 published_draft_must_be_trashed_first` when draft links to a PublishedMono with `trashedAt == null`.

Key state today (Prisma):

- `StoryDraft.publishedMonoId` is a nullable FK with `onDelete: SetNull`.
- Draft dependents `DraftSentence`, `DraftVocabEntry`, `DraftGrammarEntry`, `DraftQuizEntry`, `DraftAudio` all have `onDelete: Cascade` from `StoryDraft`.
- `PublishedMono` has `drafts StoryDraft[]` relation (inverse of `publishedMonoId`).

## 3. What Permanent Delete Must Remove

Permanent delete should remove *the user’s story footprint* across:

- **PublishedMono**
  - Row in `published_monos` (includes `title/category/level/description/content/trashedAt`).
  - Prevents any future “reappearance” in catalog or owner lists.

- **Linked StoryDraft**
  - The draft row(s) that point to the published mono via `publishedMonoId`.
  - Rationale: keeping the draft after “permanent delete” is confusing unless product explicitly supports “keep draft but unpublish forever”.

- **Draft dependents**
  - `draft_sentences` (`DraftSentence`) — cascade via StoryDraft.
  - `draft_vocab_entries` (`DraftVocabEntry`) — cascade via StoryDraft.
  - `draft_grammar_entries` (`DraftGrammarEntry`) — cascade via StoryDraft.
  - `draft_quiz_entries` (`DraftQuizEntry`) — cascade via StoryDraft.
  - `draft_audio` (`DraftAudio`) — cascade via StoryDraft.

- **Uploaded media files / object storage keys**
  - Cover image `coverImageUrl` (stored on StoryDraft basics and PublishedMono fields).
  - Audio objects referenced from `DraftAudio.content` (likely includes URL/key; exact shape is JSON).
  - Any future attachments referenced inside `PublishedMono.content` JSON.

- **Future social / collections (not implemented yet)**
  - Bookmarks / reactions / shares / comments referencing `PublishedMono.id`.
  - Policy must define whether to cascade delete, tombstone, or anonymize.

## 4. Policy Options

Compare policy shapes for what “permanent delete” means.

### A. Delete PublishedMono only, keep draft

**Behavior**
- Delete `PublishedMono` row.
- Keep `StoryDraft` (set `publishedMonoId = null` automatically via FK `onDelete: SetNull`).

**Pros**
- User keeps editor content (draft) after removing from public catalog.
- Minimal DB deletion risk.

**Cons**
- Product semantics: user pressed “permanent delete” in Trash but story still exists in Workspace.
- Must ensure Flutter/UX clearly says “Published version deleted; draft kept” (otherwise trust issue).
- Still requires media policy if draft retains cover/audio references.

### B. Delete draft + published mono (hard remove)

**Behavior**
- Delete all drafts linked to the PublishedMono, which cascades to sentences/vocab/grammar/quiz/audio.
- Delete the PublishedMono row.

**Pros**
- Matches user expectation of “delete forever”.
- Minimizes “zombie data” risk.

**Cons**
- Irreversible; requires strong confirmation UX.
- Needs careful sequencing/transaction to avoid partial deletion.
- Requires a media cleanup strategy to avoid orphaned objects.

### C. Retain tombstone

**Behavior**
- Delete content but keep a small “tombstone” record keyed by `PublishedMono.id` (e.g., `deletedAt`, reason, ownerId, maybe title hash).

**Pros**
- Supports future bookmarks/shares: can show “This story was deleted” instead of hard 404.
- Helps auditing/support/debugging (abuse reports, user complaints).

**Cons**
- Requires migration/new table or new columns.
- Requires API behavior changes (public detail surfaces distinguish deleted vs missing).

### D. Scheduled retention / TTL

**Behavior**
- Trash is recoverable for N days; after TTL, job permanently deletes.

**Pros**
- Prevents accidental loss while still cleaning storage.
- Great for consumer UX.

**Cons**
- Requires background job/cron and operational maturity.
- Must handle edge cases (restore right before TTL, jobs failing, idempotency).

## 5. Recommended V1 Policy

Recommend **B + (lightweight C)**:

1. **Permanent delete is only available inside Trash** (requires `trashedAt != null`).
2. Permanent delete **hard deletes**:
   - the `PublishedMono` row, **and**
   - all `StoryDraft` rows where `publishedMonoId == <id>` (and cascaded children).
3. **Tombstone (minimal):**
   - V1 can ship without a tombstone table, returning `404 published_mono_not_found` consistently.
   - If bookmarks/shares ship soon, add a `PublishedMonoTombstone` table in P4 to return a dedicated error code (e.g. `published_mono_deleted`).
4. **Media cleanup:**
   - V1: best-effort delete of locally stored files (if any) + enqueue/record keys for async cleanup.
   - P4: centralized object-store key tracking + orphan cleanup job.

Why not A?
- It creates “deleted but still in Workspace” ambiguity, and increases risk that the user thinks permanent delete didn’t work.

## 6. Backend API Design

### Endpoint

- **`DELETE /v1/published-monos/:id/permanent`**

### Preconditions

- Owner-scoped (`JwtOrDevOwnerFallbackGuard`).
- Must exist and belong to owner.
- Must be in Trash: **only when `trashedAt != null`**.
  - If `trashedAt == null`: return `400 published_mono_must_be_trashed_first` (or reuse `published_mono_not_trashed`).

### Second-confirmation mechanism

V1 options (choose one; all avoid “fat finger” deletes):

- **Body confirm phrase** (simple, localizable later):
  - Request body `{ "confirm": "DELETE" }`
  - Backend requires exact match, otherwise `400 missing_delete_confirm`.

- **One-time confirm token** (stronger, multi-step):
  - Step 1: `POST /v1/published-monos/:id/permanent/prepare` → returns short-lived token.
  - Step 2: `DELETE .../permanent` with body `{ token }`.
  - More work but prevents scripted/accidental deletes.

Recommendation for V1: **body confirm phrase**.

### Response shape

- Return `204 No Content` on success (consistent with draft delete).
- On failure:
  - `404 published_mono_not_found`
  - `400 published_mono_not_trashed` / `published_mono_must_be_trashed_first`
  - `400 missing_delete_confirm`

### Implementation notes (Prisma)

- Prefer a single `prisma.$transaction()`:
  - Read `PublishedMono` (select `id, ownerId, trashedAt`) and verify preconditions.
  - Find linked drafts: `storyDraft.findMany({ where: { ownerId, publishedMonoId: id } })`.
  - Delete linked drafts via `deleteMany` (cascades to draft_* tables).
  - Delete PublishedMono row (or `deleteMany` owner-scoped).
- Must be **idempotent-safe** at the HTTP layer:
  - If caller retries after success, return `404` (acceptable) or `204` (more idempotent); choose and test.

## 7. Flutter UX

P2 currently hides permanent delete; P3 UX should add it only once the backend exists.

### Button placement

- Add a **Permanently delete** action in `ProfileTrashScreen` per row (secondary) or in a row “more” menu.
- Consider a global “Edit” style: keep restore as primary, permanent delete as destructive secondary.

### Double confirmation copy (suggested)

- **Title:** Permanently delete story?
- **Body:** This will permanently delete the published story and its draft. This can’t be undone.
- **Buttons:** Cancel / Permanently delete
- Optional second step (extra safe): require typing **DELETE**.

### No-undo / recovery

- Do **not** offer Undo snackbar for permanent delete.
- After success: snackbar **Deleted permanently.**
- Refresh: Trash list + Profile Published + Mono feed (same refresh signal as P2).

## 8. Media Cleanup

### Local disk cleanup

- If Flutter stores downloaded media locally (cache), OS will eventually evict; do not over-engineer.
- If the app stores user-generated media files locally (creator uploads), delete local file references when delete succeeds.

### S3/R2 cleanup later

Current schema stores URLs/JSON blobs, not first-class “media objects”.

Recommended P3/P4 steps:

- **P3 (best-effort):** parse known JSON fields (cover/audio) to extract object keys when possible; attempt delete; failures should not block DB delete.
- **P4 (correctness):**
  - Introduce a `MediaObject` table: `id, ownerId, storageProvider, key, createdAt, deletedAt?`.
  - On upload, write a row; on publish, reference `mediaObjectId` (or keep key but still tracked).
  - A nightly job deletes objects where `deletedAt != null` or where no longer referenced (“mark & sweep”).

### Orphan cleanup job

- A scheduled job that:
  - Scans `MediaObject` rows with no references (or flagged deleted).
  - Attempts object-store deletion.
  - Records retries and terminal failures.

## 9. Tests Needed

### Backend tests

- **Preconditions**
  - Cannot permanent delete when `trashedAt == null`.
  - Requires confirm phrase/token.
  - Owner scoping enforced.

- **Deletion semantics**
  - After permanent delete:
    - `GET /v1/published-monos?trashed=true` no longer returns it.
    - `GET /v1/published-monos/:id` is `404`.
    - `GET /v1/mono/feed` does not include it.
  - Linked drafts (and their `draft_*` children) are deleted.

- **Idempotency / retry**
  - A second delete attempt returns `404` (or `204` if chosen).

### Flutter tests (P3 once UI exists)

- Trash screen shows destructive button only when endpoint exists (feature flag / capability check).
- Double confirm flow.
- Success refresh + navigation behavior.

## 10. Implementation Split

- **P3.0 Backend**
  - Add `DELETE /v1/published-monos/:id/permanent` with confirm phrase.
  - DB transaction delete drafts + published mono.
  - Tests in `published-monos.service.spec.ts` and `story-drafts...spec.ts` if needed.

- **P3.1 Flutter**
  - Add Permanently delete UI in Trash screen with double confirmation UX.
  - Wire refresh + snackbars.

- **P4 Hardening**
  - Tombstone table (if bookmarks/shares ship).
  - Media object tracking + orphan cleanup job + TTL retention (optional).

## 11. Exact Cursor Prompt For Backend P3

```text
You are a senior NestJS + Prisma engineer on nimon-backend.

Task: Implement P3 — Permanent delete for trashed PublishedMono (no Flutter changes in this task).

Constraints:
- Do NOT change Flutter.
- Migration is allowed only if truly required; prefer no migration for the first cut.
- Must be owner-scoped using existing JwtOrDevOwnerFallbackGuard.

Read:
- docs/P1_BACKEND_PUBLISHED_MONO_TRASH_REPORT.md
- docs/P3_PERMANENT_DELETE_POLICY_PLAN.md
- nimon-backend/prisma/schema.prisma
- nimon-backend/src/modules/published-monos/**
- nimon-backend/src/modules/story-drafts/**

Requirements:
1) Add DELETE /v1/published-monos/:id/permanent
   - Allowed only if the row exists for the owner AND trashedAt != null.
   - Require JSON body { "confirm": "DELETE" } or reject with 400 missing_delete_confirm.
   - If trashedAt is null, return 400 published_mono_must_be_trashed_first (or published_mono_not_trashed).
   - If not found, return 404 published_mono_not_found.

2) Deletion semantics:
   - In a single prisma.$transaction:
     a) Find the PublishedMono (select id, ownerId, trashedAt).
     b) Delete all StoryDraft rows where ownerId matches and publishedMonoId == id (cascade deletes draft_sentences, draft_vocab_entries, draft_grammar_entries, draft_quiz_entries, draft_audio).
     c) Delete the PublishedMono row.
   - Return 204 No Content on success.

3) Tests:
   - Add/extend published-monos.service.spec.ts:
     - cannot delete when not trashed
     - requires confirm body
     - deletes linked drafts + children (assert counts)
     - after delete, list ?trashed=true excludes it
   - Add any story-drafts spec coverage only if needed.

4) Docs:
   - Write docs/P3_BACKEND_PUBLISHED_MONO_PERMANENT_DELETE_REPORT.md with endpoints, behavior, and test output.

Commands to run:
- npm test (or targeted jest suites)
- nest build

Deliverable:
- backend code + tests + report doc
```

---

## Output Summary

- **Permanent delete recommended now?** Yes, but only after Trash exists (it does) and only inside Trash with double confirmation.
- **What should be deleted?** V1 recommended: `PublishedMono` + all linked `StoryDraft` rows + draft dependents (`draft_sentences`, vocab/grammar/quiz/audio) + best-effort media cleanup.
- **Migration needed?** Not strictly for a minimal endpoint (hard delete can use existing schema). A future tombstone/media tracking system likely **does** require migrations.
- **Backend endpoint needed?** Yes: `DELETE /v1/published-monos/:id/permanent` with `trashedAt != null` precondition + confirmation.
- **Flutter UI needed?** Yes in P3.1: add Permanently delete button in Trash screen with double confirmation; no Undo.
- **Biggest risk**: partial deletion / orphaned media objects + future bookmarks/shares needing tombstones.
- **First implementation step**: backend endpoint + transaction delete semantics + tests.

