# Draft Sentence Duplicate Order Fix Report

## Problem

`PrismaClientKnownRequestError` (P2002) on `tx.draftSentence.createMany()`: unique constraint on `(draftId, order)` when the client sent duplicate `orderIndex` values or when reordering produced colliding orders.

## Root Cause

`StoryDraftsService.updateDraft` trusted `sentence.orderIndex` for the DB `order` column when present:

```typescript
const order = typeof orderIndex === 'number' ? orderIndex : idx;
```

Two sentences with the same `orderIndex` (or a buggy client) produced two rows with the same `order` for one `draftId`, violating `@@unique([draftId, order])`.

## Backend Fix

- **Canonical order** is the **JSON array order** of `body.sentences` (first element = first sentence in the story).
- **DB `DraftSentence.order`** is always **`0 .. n-1`** matching that array index.
- Stored JSON **`content.orderIndex`** is set to the same index so GET responses and `mapFullDraft` stay consistent.
- If the payload contains **duplicate `orderIndex` values**, the save still succeeds; a **warning** is logged with `draftId` and the duplicated indices (no story text).

## Order Normalization Policy

| Input | DB `order` | `content.orderIndex` |
|-------|------------|----------------------|
| Sentence at array index `i` | `i` | `i` |
| Client `orderIndex` duplicates | Ignored for uniqueness | Overwritten to `i` |

Reorder is expressed by **reordering the array**, not by assigning sparse or duplicate `orderIndex` values.

## Concurrency Notes

- Replacement already runs inside **`prisma.$transaction`** (deleteMany + createMany).
- **If-Match / etag** reduces lost updates from overlapping saves but does not serialize all writers; two concurrent PUTs with the same etag can still race. Further mitigation (per-draft lock, stronger isolation) is optional follow-up if observed in production.

## Flutter Audit

- `RemoteStoryDraftRepository._dtoToJsonMap` now sets **`orderIndex: i`** for each sentence in list order before PUT, matching backend expectations and avoiding stale duplicate indices in the wire payload.

## Tests Added

- **Reorder**: persisted rows use sequential `order` `[0, 1, 2]` and preserve **array** order of `japaneseText`; `content.orderIndex` matches.
- **Duplicate `orderIndex`**: save succeeds, three rows, sequential orders, warning logged (logger mocked).

## Commands Run

```bash
cd nimon-backend
pnpm jest src/modules/story-drafts --runInBand
pnpm jest --runInBand
pnpm nest build
```

If Flutter touched:

```bash
dart format lib/features/create/data/remote_story_draft_repository.dart
flutter analyze lib/features/create/data/remote_story_draft_repository.dart
flutter test test/features/create
flutter test
```

## Manual Verification

1. Save a draft with sentences that previously duplicated `orderIndex` → should return 200 and list sentences in UI order.
2. Reorder sentences in the creator → persisted order matches UI list order.

## Remaining Risks

- Very old clients that only send `orderIndex` without reordering the array may see different behavior until they send list order correctly; Flutter now normalizes on write.

## Recommended Next Step

- Monitor logs for `duplicate orderIndex` to find any remaining buggy clients; consider deprecating reliance on client `orderIndex` in API docs.
