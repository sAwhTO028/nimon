# M9f Profile Identity Propagation Fix Report

## Problem

After **Edit Profile → Save**, `PATCH /v1/me/profile` persisted `displayName`, `handle`, `bio`, `avatarUrl`, and `coverImageUrl`, but many surfaces still showed **stale or placeholder** identity:

- Owner profile header: text updated from public profile fetch, but **avatar stayed a generic glyph**.
- Remote public profile UI: **banner always used the decorative fallback** even when `coverImageUrl` was present in the API payload.
- Mono reels / reader footer: **generic person icon** even when the feed returned writer name/handle (and **no avatar** on feed rows before this fix).
- Published tab reader, collection detail → reader: **hardcoded** `Just4withYou` / **`You` / `@you`** instead of live profile-backed fields from the API.

## Root Cause

1. **Backend** joined `UserProfile` for **displayName/handle** on `GET /v1/mono/feed` but **not `avatarUrl`**, and **published-mono list/detail** DTOs exposed **no writer identity** fields—only `ownerId`—so Flutter fell back to placeholders after merge/hydration.
2. **Flutter `PublicCreatorProfile`** did not parse **`coverImageUrl`**, and the remote **`PublicProfileScreen` header** always rendered **`_CoverFallback`** instead of **`_CoverImage`**.
3. **Flutter owner header** never read **`avatarUrl`** from `currentUserPublicProfileProvider`—only names/bio/stats.
4. **Reader footer** (`_PostFooterMeta`) always drew a **glyph**, ignoring any future avatar field.
5. **Refresh scope** after save was too narrow: **`currentUserPublicProfileProvider` + `restoreSession()`** only; **mono feeds and published/saved pagers** kept old rows in memory.

## Identity Source Audit

| Surface | displayName | handle | avatarUrl | coverImageUrl | Primary source | Refreshes after save? |
|--------|-------------|--------|-----------|---------------|----------------|------------------------|
| 1 Owner profile header | `currentUserPublicProfile` → session fallback | profile / session | **`currentUserPublicProfile`** (NEW) | N/A | `GET …/public-profile` | Invalidate + rebuild |
| 2 Public profile header | `PublicCreatorProfile` | same | `_Avatar` | **`_CoverImage(rp.coverImageUrl)`** (FIXED) | `GET …/public-profile` | Pull-to-refresh / reopen |
| 3 Mono feed / reels footer | `MonoFeedSummaryDto` → `MonoFeedItem` | same | **`writerAvatarUrl`** on DTO/item (NEW) | N/A — story cover separate | **`GET /v1/mono/feed`** (+ profile join) | Pager **`refresh()`** on save |
| 4 Mono reader footer | merged `PublishedMonoDetailDto` + feed base | same | **`writerAvatarUrl`** | story `coverImageUrl` | **`GET /v1/mono/:id`** + enriched detail | Hydration replaces base |
| 5 Published tab list rows | N/A per row author chip in list | N/A | N/A | thumbnail from mono | pager DTO | Pager **`refresh()`** |
| 6 Published tab reader/detail | **`PublishedMonoDetailDto.writer*`** (+ mapper fallbacks) | same | **`writerAvatarUrl`** | mono cover | **`GET /v1/published-monos/:id`** enriched | Repo fetch each open + list refresh |
| 7 Owner collection list → reader | DTO **`writer*`** preferred; **`currentUserPublicProfile`** fallback | same | profile / DTO | story cover | **`GET …/collections/.../monos`** enriched | Reload page + notifier **`load()`** |
| 8 Public collection rows → reader | DTO **`writer*`** preferred; **`PublicCreatorCollectionDetailArgs`** fallback | same | args + DTO | story cover | public collection monos endpoint | Navigate with args |
| 9 Saved tab | bookmark feed maps **`writerAvatarUrl`** from API when present | same |远程 social/repo | … | **`GET`** bookmark page | **`profileSavedMonoPager`** **`refresh()`** |

## Backend DTO Fixes

- **`mono-feed.dto` / `MonoFeedService.listFeed`**: `writerAvatarUrl` added; Prisma owner profile select includes **`avatarUrl`**.
- **`published-monos.dto`**: **`writerDisplayName`**, **`writerHandle`**, **`writerAvatarUrl`** on **`PublishedMonoListItemDto`** (and therefore detail).
- **`published-mono-common`**: `attachWriterProfileToListItem` / `attachWriterProfileToDetail`; list rows default **`writer*`** to **`null`** then services stamp from **`UserProfile`**.
- **`PublishedMonosService`**: **`listPublishedMonos`** (one **`writerProfile(ownerId)`** per page, stamped on each item) / **`getPublishedMonoById`** load **`UserProfile`** for the owner and attach writer fields.
- **`MonoFeedService.getPublicMonoById`**: detail stamped with **`UserProfile`** for the mono’s **`ownerId`**.
- **`CreatorCollectionsService`**: **`listMineCollectionMonos`** / **`listPublicCollectionMonos`** stamp items with **collection owner** profile (`ownerId` / `profileUserId`).

## Owner Profile Avatar Fix

- **`profile_screen.dart`**: `_ProfileSummaryRow` accepts **`avatarUrl`**; **`_OwnerProfileAvatar`** shows **`Image.network`** when non-empty (else placeholder).

## Public Profile Cover Fix

- **`PublicCreatorProfile`**: **`coverImageUrl`** parsed from JSON.
- **`public_profile_screen.dart`**: Remote path uses **`_CoverImage(url: rp.coverImageUrl)`** instead of unconditional **`_CoverFallback`**.

## Mono/Reels Identity Fix

- **`MonoFeedSummaryDto`**: **`writerAvatarUrl`**.
- **`MonoFeedItem`**: **`writerAvatarUrl`** optional.
- **`mono_feed_item_mapper`**: Normalize handle display; propagate avatar; **`monoFeedItemMergePublishedDetail`** overwrites identity from hydrated detail **`writer*`** fields.
- **`mono_screen.dart`**: **`_PostFooterMeta`** renders **`_WriterFooterAvatar`** when URL present.

## Published Mono Identity Fix

- **`published_mono_reader_mapper`**: Builds **`MonoFeedItem`** from **`PublishedMonoDetailDto.writer*`** instead of **`Just4withYou`** defaults.
- **`profile_screen.dart` **`_openPublishedTabReader`** continues to **`get()`** detail; backend now returns **writer** fields.

## Collection Detail Identity Fix

- Backend collection mono pages return **writer** fields on each **`PublishedMonoListItemDto`**.
- **`owner_creator_collection_detail_screen`**: Loads **`currentUserPublicProfileProvider.future`** for fallbacks (**replaces You/@you**).
- **`public_creator_collection_detail_screen`**: **`PublicCreatorCollectionDetailArgs.writerAvatarUrl`** passed from **`PublicProfileScreen`**.
- **`monoFeedItemFromPublishedMonoListItemDto`**: **DTO writers win** over string fallbacks.

## Refresh / Invalidation Fix

- **`edit_profile_notifier.save`**: After success, **`unawaited` `refresh()`** on **`monoFeedPagerProvider`**, **`followingMonoFeedPagerProvider`**, **`profilePublishedMonoPagerProvider`**, **`profileSavedMonoPagerProvider`**, plus **`myCreatorCollectionsNotifier.load()`**, in addition to existing **`invalidate(currentUserPublicProfileProvider)`** and **`restoreSession()`**.

## Tests Added

**Backend**

- `mono-feed.service.spec.ts`: `writerAvatarUrl` on list rows; **`getPublicMonoById`** **`writer*`** from profile join (+ **`userProfile` mock** in **`mkSvc`**).
- `published-monos.service.spec.ts`: **`listPublishedMonos`** / **`getPublishedMonoById`** writer stamping; mocks include **`userProfile.findUnique`** where needed.
- `creator-collections.service.spec.ts`: **`listPublicCollectionMonos`** writer stamping; prisma mocks include **`userProfile`**.

**Flutter**

- `mono_feed_item_mapper_test.dart`: DTO writer preference; **`writerAvatarUrl`** on summary mapping.
- `mono_feed_pager_test.dart` / `remote_public_creator_profile_repository_test.ts`: **`writerAvatarUrl` / `coverImageUrl`** coverage.
- `PublicCreatorProfile` test/fixture constructions updated with **`coverImageUrl`**.

## Commands Run

From **`nimon-backend`** (Windows agent shell had no **`pnpm`** / **`npm`** on PATH; used Cursor-bundled **Node** with local binaries):

- `node ./node_modules/prisma/build/index.js generate` — OK
- `node ./node_modules/jest/bin/jest.js src/modules/users --runInBand` — 4 tests passed
- `node ./node_modules/jest/bin/jest.js src/modules/mono --runInBand` — 18 tests passed
- `node ./node_modules/jest/bin/jest.js src/modules/creator-collections --runInBand` — 19 tests passed
- `node ./node_modules/jest/bin/jest.js --runInBand` — 148 tests passed (after **`listPublishedMonos`** writer stamp fix)
- `node ./node_modules/@nestjs/cli/bin/nest.js build` — OK

Equivalent with **`pnpm`**: `pnpm prisma generate`, `pnpm jest …`, `pnpm nest build`.

From repo root (**Flutter**):

- `dart format lib/features/profile lib/features/mono lib/features/auth test/features/profile test/features/mono` — OK
- `flutter analyze lib/features/profile lib/features/mono lib/features/auth` — completes with existing **warnings / infos** on `profile_screen.dart` (no new compile errors observed)
- `flutter test test/features/profile` — 120 passed
- `flutter test test/features/mono` — 51 passed
- `flutter test` — all passed (~3.5 min)

## Manual Verification

- [ ] Owner header shows **network avatar** after setting avatar URL + save.
- [ ] Public profile (remote) shows **cover image** when `coverImageUrl` set.
- [ ] Mono For You / Following footer shows **name/handle/avatar** consistent with creator profile after save + feed refresh.
- [ ] Published tab → reader shows **correct** creator identity for own monos — not **`Just4withYou`** placeholders.
- [ ] Owner / public collection → reader matches **same** identity.
- [ ] Handle conflict / 401 paths unchanged.

## Remaining Risks

- **`currentUserPublicProfileProvider` `catch (_) => null`**: Offline/errors still drop metrics/avatar until retry; unchanged behavior besides new consumers (owner collections await `.future`).
- **Mono pager `refresh`** while user is mid-feed may reset scroll — acceptable tradeoff for V1 correctness after profile edit.
- **Strict mode / bookmark feed**: If bookmark API shape omits **`writerAvatarUrl`**, avatar may stay placeholder until mono detail hydration.

## Output Summary

| Check | Result |
|--------|--------|
| Owner avatar fixed? | **Yes** — `avatarUrl` from `currentUserPublicProfileProvider`. |
| Public cover fixed? | **Yes** — `coverImageUrl` parsed + `_CoverImage`. |
| Mono reels identity fixed? | **Yes** — feed `writerAvatarUrl` + footer image. |
| Published mono identity fixed? | **Yes** — API `writer*` on list/detail + reader mapper. |
| Collection mono identity fixed? | **Yes** — backend stamp + owner/public fallbacks. |
| Backend returns live profile identity? | **Yes** — joins + `attachWriterProfile*`. |
| Refresh/invalidation? | **Yes** — feeder + published/saved pagers + collections reload. |
| Tests / build | **Yes** — Jest 148/148; **nest build** OK; **`flutter test`** full suite OK. |
