# M8f7 Creator Collections UX Polish Report

## Scope
- Polish creator collections UX without changing membership/move semantics.
- Keep learner Saved collections untouched.
- Owner-only management: rename/delete collections, remove items in owner detail.
- Public profile remains view-only.

## Owner Collection Detail Design
- Updated owner collection detail to match the public collection detail row design.
- Uses `MonoStoryListRow` (thumb + JLPT badge + title + preview text + spacing).
- Tapping a mono opens the reader with correct list + index.

## Standard Back Icon
- Owner collection detail now uses the standard `NimonBackButton` in the app bar.

## Collection Cover Derivation
Backend now returns a usable `coverImageUrl` on collection list rows:
- If `collection.coverImageUrl` is set: use it.
- Else derive from the first **catalog-visible** mono in the collection whose published content has `core.coverImageUrl`.
- Applies to:
  - `GET /v1/me/creator-collections`
  - `GET /v1/users/:userId/creator-collections`

Flutter already renders `CollectionListRow.coverImageUrl` when present; fallback remains the folder/placeholder styling.

## Owner Rename
- Owner collections list overflow menu now supports **Rename**.
- Calls `PATCH /v1/me/creator-collections/:id` with `{ title }`.
- Refreshes the owner collections provider after success.
- Empty title is blocked with a snackbar.

## Owner Delete Policy
Policy:
- Delete is only allowed for empty collections.
- Backend enforces this and returns `409 collection_not_empty` when items exist.
- Flutter maps this to: “Remove all stories before deleting this collection.”

## Remove From Collection
- Owner collection detail rows have an overflow action to **Remove from collection**.
- Calls `DELETE /v1/me/creator-collections/:id/items/:publishedMonoId`.
- Refreshes detail + owner collections list.

## Public View-only Policy
- Public collections list/detail remain view-only:
  - No rename
  - No delete
  - No remove-from-collection actions

## Backend Changes
- `CreatorCollectionsService`:
  - Derive list cover images from first visible mono.
  - Enforce delete policy (`409 collection_not_empty`).

## Flutter Changes
- Owner detail: parity layout with public detail + standard back button + remove action.
- Owner collections list: real overflow menu actions (rename/delete).
- Repository: maps `409 collection_not_empty` to a friendly message.
- Public collection list: removed trailing overflow icon entirely.

## Tests Added
- Backend:
  - cover derivation + explicit cover wins
  - delete policy conflict when non-empty
- Flutter:
  - public collections list has no overflow menu icon
  - owner collection detail uses `MonoStoryListRow` + `NimonBackButton`
  - `CollectionListRow` renders an image when `coverImageUrl` exists
  - repository tests for PATCH + 409 delete mapping

## Commands Run
- Backend:
  - `pnpm prisma generate`
  - `pnpm jest src/modules/creator-collections --runInBand`
- Flutter:
  - `flutter test test/features/profile`
  - `flutter test`

## Manual Verification
- Owner profile → Published → Collections:
  - Cover thumbnail shows when available.
  - Overflow menu shows Rename/Delete.
  - Delete blocked when non-empty; succeeds when empty.
- Owner collection detail:
  - Rows match public style.
  - Remove from collection works and updates counts.
- Public profile:
  - No owner actions visible; list/detail open only.

## Remaining Risks
- UI delete enablement is best-effort using `itemCount` (visible-only). Backend remains the source of truth and will block delete if hidden items exist.

