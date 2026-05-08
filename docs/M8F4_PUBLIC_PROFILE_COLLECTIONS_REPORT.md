# M8f4 Public Profile Collections Report

Flutter-only milestone: public creator collections on learner-facing **remote** public profiles (`?userId=`), with guest-safe GET wiring, Monos vs Collections segmentation, collection detail, and reader navigation using `MonoReaderMenuOrigin.publicCreatorProfile`.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/profile/data/published_mono_dto.dart` | Added `publishedMonoListItemDtoFromBackendJson` for collection mono list rows (aligned with published_mono list parsing). |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | Added `monoFeedItemFromPublishedMonoListItemDto` for catalog list rows + creator display strings. |
| `lib/features/profile/data/remote_creator_collections_repository.dart` | Added `PublicCollectionMonosPage`, `fetchPublicCollections`, `fetchPublicCollectionMonos` (optional auth via existing `_mergeAuth`). |
| `lib/features/profile/public_creator_collection_detail_screen.dart` | **New** — title/description, paged monos, retry, reader push with public origin. |
| `lib/features/profile/public_profile_screen.dart` | Remote profile: `SegmentedButton` Monos \| Collections; collections list + `_RemotePublicCollectionCard`; pull-to-refresh reloads collections. |
| `lib/main.dart` | Child route `collections/detail` under `/profile/public`. |
| `test/features/profile/remote_creator_collections_repository_test.dart` | URL/query tests for public GETs + guest auth header. |
| `test/features/mono/mono_feed_item_mapper_test.dart` | Mapper unit test for published list DTO → `MonoFeedItem`. |
| `test/features/profile/public_profile_collections_tab_test.dart` | **New** — widget tests for tab, empty state, row copy, navigation to detail + `/mono-reader`. |

## Public Repository Methods

- **`fetchPublicCollections(userId)`** → `GET /v1/users/:userId/creator-collections` → parses `{ collections: [...] }` into `CreatorMonoCollection` (includes **`itemCount`**).
- **`fetchPublicCollectionMonos(userId, collectionId, { cursor, limit })`** → `GET /v1/users/:userId/creator-collections/:collectionId/monos` → `{ items, nextCursor }` parsed via `publishedMonoListItemDtoFromBackendJson`.

Headers use the same **`_mergeAuth`** pattern as owner routes; when the auth builder returns an empty map, requests behave as **guest** (no `Authorization` header).

## Public Profile Collections Tab

- **Monos** tab: unchanged behavior — still **`fetchCreatorMonoPage`** (`/v1/mono/feed` + `writerId`) for **all published** catalog monos for that creator.
- **Collections** tab: loads public collections on first selection (and on pull-to-refresh). Shows loading / error+retry, empty copy **“No collections yet.”**, and rows with optional cover, title, optional description, and **`N monos` / `1 mono`** count labels.

## Collection Detail Screen

- Route: **`/profile/public/collections/detail`** with **`PublicCreatorCollectionDetailArgs`** as `extra` (metadata from list row; no separate public GET-one-collection API).
- Loads monos via **`fetchPublicCollectionMonos`** with load-more when `hasMore` / cursor.
- Tap mono → **`/mono-reader`** with full **`items`** list + **`initialIndex`** and **`MonoReaderMenuOrigin.publicCreatorProfile`**.

## Reader Origin / Menu Policy

- **`MonoReaderMenuOrigin.publicCreatorProfile`** keeps the **owner** dock hidden for viewers while preserving the **public** reader flow (same origin as Monos tab on this profile).

## Tests Added

- Repository: public URLs, query params (`cursor`, `limit`), guest omitting `Authorization`.
- Mapper: `monoFeedItemFromPublishedMonoListItemDto` hydration + access flags.
- Widget: segmented control key `public_profile_mono_collections_segments`, Collections empty state, row title + **“3 monos”**, navigation to detail and stub **`/mono-reader`**.

Saved-tab regression: **not** altered; learner Saved copy/tests unchanged.

## Flutter Analyze Result

```
Analyzing 9 items...
No issues found! (ran in ~23s)
```
(Command: `flutter analyze` on touched paths.)

## Flutter Test Result

- `flutter test test/features/profile test/features/mono/mono_feed_item_mapper_test.dart` — **passed**
- `flutter test` (full suite) — **passed** (exit code 0)

## Remaining Risks

- **Deep links**: Opening **`/profile/public/collections/detail`** without valid `extra` shows a minimal “Missing collection.” scaffold (metadata must come from navigation `extra` today).
- **Pagination**: If the backend omits `hasMore` but returns a null `nextCursor`, load-more may stop earlier than intended (client infers `hasMore` from cursor when bool absent).

## Recommended Next Step

**M8f5** (if defined in `docs/M8F_CREATOR_COLLECTIONS_PLAN.md`): optional polish — deep-link query fallback (`userId` + `collectionId`) with an extra round-trip only if a future API exists, or UX tweaks (grid layout, share collection URL). Confirm the next milestone label in the M8F plan index.
