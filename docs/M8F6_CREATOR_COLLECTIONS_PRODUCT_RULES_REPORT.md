# M8f6 - Creator Collections Product Rules Fix Report

## Scope
This change set updates Creator Collections to match the product rules:

- Single-collection membership for a published mono (enforced at DB + API semantics).
- "Move to collection" semantics for add and bulk-add APIs.
- Bottom sheet UX cleanup ("Cancel" and no extra Cancel button).
- Owner + public collection list rows use the folder-like `CollectionListRow` design.
- Collection rows open a collection detail screen; tapping a mono opens the mono reader.

## Backend
### Single-collection membership (DB)
- Enforced with a unique index on `creator_mono_collection_items.publishedMonoId`.
- Migration also deletes any accidental duplicates (keeps newest by `createdAt`).

### Move semantics (API)
Owner endpoints:
- `POST /v1/me/creator-collections/:id/items`
  - If already in target collection: no-op (`created=false`).
  - If in another collection: moves the existing row into the target (`created=true`).
- `POST /v1/me/creator-collections/:id/items/bulk`
  - Each eligible mono is either skipped (already in target) or moved/inserted into target.

### Owner collection detail support
Added owner monos endpoint:
- `GET /v1/me/creator-collections/:id/monos` (auth required)
  - Lists published monos in the collection (still respects catalog visibility rules).

## Flutter
### Add-to-collection sheet
- "Back" button is now "Cancel".
- Removed the extra bottom Cancel text button.
- Header copy is now "Move to collection" for `createAndAdd` (reflects move semantics).

### Collection list row design
Owner profile Collections tab and public profile Collections tab use the shared folder-like `CollectionListRow`.

### Navigation
- Owner: tapping a collection row opens owner collection detail screen.
- Public: tapping a collection row opens the public collection detail screen.
- In both detail screens, tapping a mono opens the mono reader with the correct list and initial index.

## Verification
Ran:
- Flutter tests: `flutter test`
- Backend creator-collections Jest suite
- Backend build: `nest build`

