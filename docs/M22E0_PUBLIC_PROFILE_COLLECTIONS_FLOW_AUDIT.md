# M22E-0 — Public Profile Collections Current Flow Audit

Date: 2026-06-03  
Scope: **Investigation only** — no code, migrations, or behavior changes.  
Context: Home / For You feed filters correctly by `learningLanguage` + `contentLocale` (M22D). Public profile **Monos** tab aligns with feed; **Collections** tab may diverge.

Prior audits: `docs/M22D0_CURRENT_LANGUAGE_FEED_PUBLISH_FLOW_AUDIT.md`, `docs/M22D1_LANGUAGE_STANDARD_AND_PUBLISH_STAMP_FIX_REPORT.md`.

---

## A. Executive summary

1. **Public profile screen** is `PublicProfileScreen` (`lib/features/profile/public_profile_screen.dart`), route `/profile/public?userId=`. Remote profiles use a **2-tab** layout (`Monos` | `Collections`) via `PublicProfileRemoteNestedScroll` + `TabBarView`.
2. **Collections tab (remote)** is **API-backed**, not mock: `GET /v1/users/:userId/creator-collections`. Legacy `?creator=` debug routes use mock `PublicFolder` data only.
3. **Monos tab (remote)** uses **`GET /v1/mono/feed?writerId=`** (same catalog feed as Home), with **viewer language filtering** when JWT is present (`OptionalJwtUserGuard` on feed controller).
4. **Collections APIs have no language filtering** — no `contentLocale` / `learningLanguage` on collection queries, no viewer `UserPreference` lookup, no query params for locale.
5. **Collection `itemCount` and item lists** count/list all **catalog-visible** monos (`PUBLISHED_MONO_CATALOG_VISIBLE`: not trashed, not draft-dirty-hidden) **regardless of viewer community**.
6. **Public collection endpoints are unauthenticated at the controller layer** (`PublicCreatorCollectionsController` has **no** `OptionalJwtUserGuard`). Flutter may send Bearer, but the backend **does not** use viewer identity for collections.
7. **Collection list/detail DTOs** use `PublishedMonoListItemDto` built from **full `published_monos` row** (`include: { publishedMono: true }` / `content: true` for covers) — **not** M22B `MONO_FEED_LIST_PUBLISHED_MONO_SELECT` (no `content` JSONB on feed list).
8. **`creator_mono_collections` has no language columns** — visibility is per-collection `visibility` (`public` | `private`); language lives only on **`published_monos.contentLocale` / `learningLanguage`**.
9. **Flutter does not filter** collections or collection items by viewer prefs; **no refresh** of public collections when Settings `contentLocale` / `learningLanguage` changes (unlike mono feed pagers).
10. **Main suspected issue:** **Policy mismatch** — Monos tab respects viewer `my`+`ja` (feed); Collections tab shows **all** catalog-visible items for the creator, including `en`-community monos, with **raw `itemCount`** → confusing UX (collections show stories Monos tab hides, or counts disagree).

---

## B. Flutter public profile collections flow

### Widgets

| Piece | File / type |
|-------|-------------|
| Screen | `PublicProfileScreen` — `lib/features/profile/public_profile_screen.dart` |
| Tab chrome | `PublicProfileRemoteNestedScroll` — `lib/features/profile/public_profile_remote_nested_scroll.dart` (`Tab`: Monos, Collections) |
| Collection cards (remote) | `_RemotePublicCollectionCard` → `CollectionListRow` (same file, ~1689) |
| Collection detail | `PublicCreatorCollectionDetailScreen` — `lib/features/profile/public_creator_collection_detail_screen.dart` |
| Legacy mock collections | `_PublicCollectionsTab` + `PublicCollectionListRow` — mock `PublicFolder` from `PublicProfileBundle` (`public_profile_data.dart`) |

**Same as own profile?** **No.** Owner **Published → Collections** uses `ProfileScreen` + `myCreatorCollectionsNotifierProvider` + `GET /v1/me/creator-collections`. Public profile uses **local state** on `PublicProfileScreen` (`_publicCollections`) + `fetchPublicCollections(userId)`. Detail routes differ: owner `/profile/creator-collections/detail`, public `/profile/public/collections/detail`.

### What the UI shows

| State | UI |
|-------|-----|
| Loading (first load) | `CircularProgressIndicator` in collections tab |
| Error, empty list | Message + **Retry** (`_loadPublicCollections(force: true)`) |
| Success, zero collections | `"No collections yet."` |
| Success, has rows | **Collection cards** (title, description, `N stories`, cover) — **not** inline mono rows |
| Detail | Lazy-loaded **mono list rows** (`MonoStoryListRow`) after navigation |

**Cards vs items:** Tab shows **collection metadata only**. **Items load lazily** on detail screen (`fetchPublicCollectionMonos`, page size 24, cursor pagination, manual “Load more”).

### Data flow

| Layer | Name |
|-------|------|
| Provider (monos tab only) | `publicProfileMonosProvider` — `lib/features/profile/presentation/providers/public_profile_monos_notifier.dart` |
| Collections state | **Widget-local** on `PublicProfileScreen` (not a Riverpod provider) |
| Repository | `RemoteCreatorCollectionsRepository` — `lib/features/profile/data/remote_creator_collections_repository.dart` |
| Provider wiring | `remoteCreatorCollectionsRepositoryProvider` — `lib/features/profile/presentation/providers/my_creator_collections_notifier.dart` |
| Model | `CreatorMonoCollection` — `lib/features/profile/data/creator_mono_collection.dart` |
| Item DTO | `PublishedMonoListItemDto` — `lib/features/profile/data/published_mono_dto.dart` |
| Item UI model | `MonoFeedItem` via `monoFeedItemFromPublishedMonoListItemDto` — `lib/features/mono/data/mono_feed_item_mapper.dart` |

### API endpoints (Flutter)

| Action | Method | Path |
|--------|--------|------|
| Public profile header | GET | `/v1/users/:userId/public-profile` |
| Public collections list | GET | `/v1/users/:userId/creator-collections` |
| Public collection monos | GET | `/v1/users/:userId/creator-collections/:collectionId/monos?limit=&cursor=` |
| Public Monos tab | GET | `/v1/mono/feed?writerId=:userId&limit=&cursor=` |

**Mock/local:** Only when `userId` empty and legacy `?creator=` debug mock active (`legacyDemoCreatorProfileActive`). Production path requires `userId`.

### Pagination / cache / auth / locale

| Topic | Behavior |
|-------|----------|
| List pagination | **None** — full collection list in one response |
| Detail pagination | **Yes** — cursor on `monos` endpoint |
| Cache | `_publicCollectionsLoaded` prevents refetch until pull-refresh or profile reload clears it |
| Auth header | **Optional** — `_mergeAuth` / `authHeaderBuilderProvider` on public GETs (guest-safe) |
| Viewer `contentLocale` / `learningLanguage` | **Not sent** on collection requests; **not applied** in Flutter |
| Mono feed relation | Monos tab **does not** reuse collection API; separate feed call with implicit viewer prefs via JWT |

### Refresh triggers

| Trigger | Collections reload? | Monos reload? |
|---------|---------------------|---------------|
| Open profile (`userId`) | No (until Collections tab) | Yes (`loadInitial`) |
| Switch to Collections tab | Yes (`_loadPublicCollections`) | — |
| Pull-to-refresh | Yes (`force: true`) | Yes (`refresh`) |
| Change Settings language | **No** | Feed pagers refresh globally; **public profile collections cache unchanged** |
| Re-open same profile session | No if `_publicCollectionsLoaded` | Provider may retain state (`autoDispose` family) |

---

## C. Backend collections flow

### Endpoints

| Endpoint | Controller | Service method | Auth |
|----------|------------|----------------|------|
| `GET /v1/users/:userId/creator-collections` | `PublicCreatorCollectionsController` | `listPublicForUser` | **None** (public) |
| `GET /v1/users/:userId/creator-collections/:collectionId/monos` | same | `listPublicCollectionMonos` | **None** |
| `GET /v1/me/creator-collections` | `MeCreatorCollectionsController` | `listMine` | `JwtAuthGuard` |
| `GET /v1/me/creator-collections/:id/monos` | same | `listMineCollectionMonos` | `JwtAuthGuard` |

Files:

- `nimon-backend/src/modules/creator-collections/public-creator-collections.controller.ts`
- `nimon-backend/src/modules/creator-collections/me-creator-collections.controller.ts`
- `nimon-backend/src/modules/creator-collections/creator-collections.service.ts`
- `nimon-backend/src/modules/creator-collections/creator-collections.dto.ts`

**Compare:** `GET /v1/users/:userId/public-profile` uses **`OptionalJwtUserGuard`** (`users.controller.ts`) for `isFollowingByMe` — collections do **not**.

### DTOs

**List:** `{ collections: CreatorMonoCollectionDto[] }` — `id`, `ownerId`, `title`, `description`, `coverImageUrl`, `visibility`, **`itemCount`**, timestamps.

**Monos page:** `{ items: PublishedMonoListItemDto[], nextCursor }` — list item built via `publishedMonoListItemFromRow` (reads **`content` JSONB** for cover, publishKind, etc.).

### Query behavior (`listPublicForUser`)

1. `creatorMonoCollection.findMany` — `ownerId = target`, `visibility = 'public'`, ordered by `sortOrder`, `createdAt`.
2. `visibleItemCountsForCollections` — `groupBy` on `creatorMonoCollectionItem` where `publishedMono` satisfies **`PUBLISHED_MONO_CATALOG_VISIBLE` only**.
3. `derivedCoversForCollections` — first visible item per collection; selects **`publishedMono.content`** (full JSONB).

**No filter on:** `published_monos.contentLocale`, `published_monos.learningLanguage`, viewer prefs, `commonLanguage`.

### Query behavior (`listPublicCollectionMonos`)

1. Verify collection `public` + `ownerId = profileUserId`.
2. `creatorMonoCollectionItem.findMany` — `collectionId`, `publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE`, cursor pagination.
3. `include: { publishedMono: true }` — **entire row** including `content` JSONB.
4. Map to `PublishedMonoListItemDto` + writer profile from collection **owner** (not viewer).

**Missing mono handling:** Items whose `publishedMono` fails catalog visibility are **excluded** by Prisma relation filter (not returned). Orphan item rows with deleted monos would not appear (FK cascade on `publishedMono`).

### Language / guest behavior

| Concern | Collections API | Mono feed (`listFeed`) |
|---------|-------------------|-------------------------|
| Viewer `UserPreference` | **Not used** | Used when `userId` from JWT |
| Query `contentLocale` / `learningLanguage` | **Not accepted** | Accepted; override prefs |
| Guest default | N/A (no filtering) | `en` + `ja` |
| `OR null` legacy on mono tags | **No** | **Yes** |
| `commonLanguage` | **Absent** | **Absent** |

---

## D. Database shape

### `creator_mono_collections`

| Column | Notes |
|--------|--------|
| `id`, `ownerId`, `title`, `description`, `coverImageUrl` | Collection metadata |
| `visibility` | Default `"public"`; public list filters `public` only |
| `sortOrder` | Collection ordering on profile |
| `createdAt`, `updatedAt` | — |
| **Language fields** | **None** |

Index: `@@index([ownerId, sortOrder, createdAt])`

### `creator_mono_collection_items`

| Column | Notes |
|--------|--------|
| `id`, `collectionId`, `publishedMonoId`, `sortOrder`, `createdAt` | Join table |
| `@@unique([publishedMonoId])` | One collection per mono (product rule) |

Indexes: `publishedMonoId`, `collectionId` (via FK)

### `published_monos` (relevant)

| Column | Notes |
|--------|--------|
| `contentLocale`, `learningLanguage` | Feed/catalog language tags (M22D publish stamping) |
| `content` | Full publish JSONB |
| `trashedAt` | Excluded when set (catalog visibility) |
| Denormalized summary cols | Used by **feed** (`coverImageUrl`, `publishKind`, counts, …) — **not** used by collection item queries today |

Relation: `CreatorMonoCollectionItem.publishedMono` → `PublishedMono`

---

## E. Current language / filter behavior

| Mechanism | Collections (public) | Monos tab (public profile) |
|-----------|----------------------|----------------------------|
| Viewer prefs | Ignored | Applied via feed + JWT |
| Guest | All catalog-visible items | `en`+`ja` feed filter |
| `contentLocale` on mono | Stored on row; **not filtered** in collection APIs | Filtered in `listFeed` |
| `learningLanguage` on mono | Stored on row; **not filtered** | Filtered in `listFeed` |
| Null-tagged monos (`contentLocale`/`learningLanguage` null) | **Included** in counts/lists | **Included** in feed (`OR null`) |
| `commonLanguage` | Not used | Not used |
| Owner prefs | Not used for public viewer | Not used (viewer prefs, not owner) |

**Flutter:** No `contentLocale` / `learningLanguage` references under `lib/features/profile/` for collections.

---

## F. Behavior matrix (current implementation)

Assumptions: items are **catalog-visible** (not trashed, not dirty-hidden). “Show” = appears in that UI surface.

| Case | Monos tab (feed `writerId`) | Collection card (list) | Collection detail (items) |
|------|----------------------------|------------------------|---------------------------|
| **A** Viewer `ja`+`my`, mono `ja`+`my | **Show** | **Show**; count includes mono | **Show** mono |
| **B** Viewer `ja`+`my`, mono `ja`+`en` | **Hide** | **Show**; count includes mono | **Show** mono (locale mismatch vs viewer) |
| **C** Guest `en`+`ja`, mono `ja`+`en` | **Show** | **Show** | **Show** |
| **D** Viewer `ja`+`en`, mono `ja`+`en` | **Show** | **Show** | **Show** |
| **E** Mixed `ja`+`my` + `ja`+`en`, viewer `ja`+`my` | **Show** only `my` mono(s) | **Show** collection; **count = all visible items (e.g. 2)** | **Show both** monos |
| **F** All items `ja`+`en`, viewer `ja`+`my` | **Hide** all (empty Monos tab) | **Show** collection if `visibility=public` and count > 0 | **Show** all `en` items; card says “N stories” |

**Zero visible catalog items (all trashed/hidden):** List still returns collection; **`itemCount = 0`**; card shows **“0 stories”** (not hidden). Detail: **“No monos in this collection yet.”**

---

## G. Differences from Home Mono feed

| Aspect | `GET /v1/mono/feed` | Public collections |
|--------|---------------------|----------------------|
| Language filter | **Yes** (`contentLocale` + `learningLanguage`, `OR null`) | **No** |
| Viewer JWT | `OptionalJwtUserGuard` → prefs | Auth header ignored by controller |
| Visibility | `PUBLISHED_MONO_CATALOG_VISIBLE` | Same on **items** only |
| Payload | M22B summary `select` (no `content`) | Full `publishedMono` + `content` for list mapping / covers |
| Scope | Global catalog (+ optional `writerId`) | Per-creator collections |
| Pagination | Yes | List: no; items: yes |

**Same:** Catalog visibility predicate (`trashedAt`, draft dirty flag). **Not same:** Language gating, viewer resolution, payload shape.

---

## H. Performance risks

| Risk | Severity | Detail |
|------|----------|--------|
| Full `content` JSONB on collection item fetch | **HIGH** | `listPublicCollectionMonos` uses `include: { publishedMono: true }` |
| Full `content` for derived covers | **MEDIUM** | `derivedCoversForCollections` selects `content` per first item |
| No list pagination for collections | **LOW–MEDIUM** | All public collections returned at once (quota-capped per user) |
| Flutter cache stale after language change | **MEDIUM** | `_publicCollectionsLoaded` without prefs listener |
| N+1 pattern | **LOW** | Batch `groupBy` + one `findMany` for covers per list call |

---

## I. Bugs / risks found

| ID | Risk | Class | Notes |
|----|------|-------|-------|
| R1 | Collection APIs omit viewer language filter | **BLOCKER** | Core mismatch with feed / Monos tab after M22D |
| R2 | `itemCount` is unfiltered raw catalog count | **HIGH** | Misleading vs viewer-visible items (cases B, E, F) |
| R3 | Public endpoints ignore JWT viewer (no `OptionalJwtUserGuard`) | **HIGH** | Even if Flutter sends auth, backend cannot apply prefs |
| R4 | Collections shown with items viewer cannot see on Monos tab | **HIGH** | Cross-tab inconsistency |
| R5 | Detail shows wrong-community monos to `my` viewers | **HIGH** | Reader opens `en` mono from `my` profile collection |
| R6 | No hide-empty-collections when filtered count = 0 | **MEDIUM** | Case F: Monos empty, collections show “N stories” |
| R7 | Collections not refreshed on Settings language change | **MEDIUM** | Stale list until tab revisit or pull-refresh |
| R8 | Collection item payload uses full `content` JSON | **MEDIUM** | M22B regression vs feed; larger responses |
| R9 | Zero `itemCount` collections still listed | **LOW** | “0 stories” cards |
| R10 | Owner vs public use same unfiltered service logic | **LOW** | Owner detail also unfiltered (expected for owner?) |
| R11 | `commonLanguage` | **N/A** | Not present (correct for V1) |
| R12 | Draft id vs published id | **LOW** | Items correctly use `publishedMonoId` FK |

---

## J. Recommended fix options (do not implement)

1. **Shared catalog language predicate** — Extract feed’s `contentLocale` + `learningLanguage` + `OR null` block; apply to `visibleItemCountsForCollections`, `listPublicCollectionMonos`, and optionally `derivedCoversForCollections` (first **visible-to-viewer** mono).
2. **`OptionalJwtUserGuard` on public collection routes** — Resolve `viewerUserId`; default guest `en`+`ja`; optional query overrides mirroring feed.
3. **Filtered `itemCount`** — Return count of items matching viewer language (and visibility), not raw catalog count.
4. **Hide collections with zero viewer-visible items** — Or show with explicit empty state; product decision (section L).
5. **Flutter: pass nothing extra if backend derives from JWT** — Or pass `contentLocale`/`learningLanguage` query params when guest.
6. **Refresh public collections on prefs change** — `ref.listen(userPreferencesNotifierProvider, …)` or invalidate on tab focus.
7. **M22B alignment for collection monos** — `select` denormalized columns; stop loading full `content` for list rows; map to summary DTO or thin list DTO.
8. **Tests** — Backend: `my` viewer sees only `my` items in public collection monos; `en` mono excluded; filtered count; guest `en`; M22B no `content` select. Flutter: widget/integration with mocked API.

---

## K. Files likely to modify in next phase

### Backend

- `nimon-backend/src/modules/creator-collections/creator-collections.service.ts`
- `nimon-backend/src/modules/creator-collections/public-creator-collections.controller.ts`
- `nimon-backend/src/modules/creator-collections/creator-collections.dto.ts` (optional query DTOs)
- `nimon-backend/src/modules/creator-collections/creator-collections.service.spec.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` (shared locale where-clause helper — optional extract)
- `nimon-backend/src/modules/published-monos/published-mono-visibility.ts` or new `published-mono-catalog-locale.ts`

### Flutter

- `lib/features/profile/public_profile_screen.dart`
- `lib/features/profile/public_creator_collection_detail_screen.dart`
- `lib/features/profile/data/remote_creator_collections_repository.dart`
- `lib/features/profile/presentation/providers/my_creator_collections_notifier.dart` (if owner parity desired)
- `lib/features/settings/presentation/providers/user_preferences_notifier.dart` (refresh hook — optional)
- `test/` — new collection locale filter tests

### Docs

- `docs/M22E1_*.md` (implementation report, future)

---

## L. Product questions (unresolved)

1. Should a **collection** have its own community language metadata, or only inherit from contained monos?
2. Are **mixed-language collections** allowed (some `my`, some `en` monos in one playlist)?
3. Should a collection **appear** on public profile if the viewer sees **zero** items after locale filter?
4. Should **`itemCount` on the card** be total items or **viewer-visible** items?
5. Should **guests** always use `en`+`ja` defaults for collection filtering (parity with feed)?
6. Should the **owner** viewing their own public profile see **all** items regardless of viewer filter (owner bypass)?
7. Should **collection detail** hide non-matching items or return 404 when collection has no visible items?
8. Should **derived cover** use first **viewer-visible** mono vs first catalog-visible mono?

---

## References (code anchors)

- Public collections load: `PublicProfileScreen._loadPublicCollections` → `RemoteCreatorCollectionsRepository.fetchPublicCollections`
- Public Monos load: `PublicProfileMonosNotifier` → `fetchCreatorMonoPage` → `/v1/mono/feed?writerId=`
- Backend public list: `CreatorCollectionsService.listPublicForUser`
- Backend public items: `CreatorCollectionsService.listPublicCollectionMonos`
- Feed language filter: `MonoFeedService.listFeed` (~lines 257–296 in `mono-feed.service.ts`)
- Catalog visibility: `PUBLISHED_MONO_CATALOG_VISIBLE` in `published-mono-visibility.ts`
