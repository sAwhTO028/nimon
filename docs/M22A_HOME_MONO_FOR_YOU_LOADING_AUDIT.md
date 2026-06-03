# M22A — Home Mono “For You” Loading Audit

Date: 2026-06-03  
Scope: **Investigation only** (no code changes).

---

## Output summary

| Question | Answer |
|----------|--------|
| Is For You mock or API-backed? | **Both.** Default binary: **mock** (`NIMON_USE_REMOTE_MONO_FEED` defaults `false`). With `--dart-define=NIMON_USE_REMOTE_MONO_FEED=true`: **API** `GET /v1/mono/feed`. |
| Does the feed load full published JSON in the list API response? | **No** on the wire — response items are **summary DTOs** only. |
| Does the backend still read full `content` JSON per feed row? | **Yes** — Prisma `select: { content: true }` for every row; server parses blob for cover / `publishKind` / `hasAudio`. |
| Does Flutter parse `content.core.sentences` / learn modules in the feed list? | **No** for list rows. **Yes** after lazy `GET /v1/mono/:id` via `plainBodyFromPublishedCore` / `buildMonoContentFromPublishedCore` (sentences only; learn not built into feed reader body). |
| Does it paginate? | **Yes** when remote: cursor pages (initial **7**, load-more **10**, prefetch when ≤3 items ahead). **No** when mock: all ~**51** mock items in memory, client JLPT filter only. |
| Main bottleneck guess | **(1)** DB + Node loading/parsing full `published_monos.content` per feed page row; **(2)** per-visible-item **full detail** fetch + UI JSON parse on swipe; **(3)** `MonoScreen.build` watching whole pager + `setState` on hydration. |
| Safe next phase | **Backend:** stop selecting full `content` in list feed; add denormalized summary columns or JSON path projection. **Flutter:** pass `contentLocale` / `learningLanguage` query params; defer detail parse; narrow rebuild scope. |

---

## A. Current Flutter For You data flow

### Widget / screen

| Piece | Location |
|-------|----------|
| Home Mono shell | `lib/features/mono/mono_screen.dart` — `MonoScreen` (`showTopControls: true` on Home) |
| For You vs Following | `_MonoMainFeedKind.forYou` / `following`; horizontal `PageController` tab index 1 = For You |
| Vertical reels | `_buildMainMonoVerticalFeed(..., _MonoMainFeedKind.forYou, ...)` — `PageView.builder` (vertical swipe) |
| Feed post UI | `_ReadingFeedPost` per item |

### Remote vs mock gate

```dart
bool get _useRemoteForYouFeed =>
    RemoteBackendConfig.useRemoteMonoFeed &&
    widget.showTopControls &&
    widget.initialItemsOverride == null &&
    widget.initialItemOverride == null;
```

- **Mock path (default):** `_forYouFilteredItems` → `_mockItems` (static `List<MonoFeedItem>` from `_buildV1MonoMockItems()`, ~51 items with **full in-memory** `MonoContent` / sentence lines).
- **Remote path:** `_forYouFilteredItems` → `_remoteCatalogItemsResolved()` from pager summaries + optional hydration map.

### Provider / repository

| Layer | Type | File |
|-------|------|------|
| Provider | `StateNotifierProvider<MonoFeedPager, PaginatedState<MonoFeedSummaryDto>>` | `lib/features/mono/data/mono_feed_providers.dart` → `monoFeedPagerProvider` |
| Pager | `MonoFeedPager` — `loadFirstPage`, `refresh`, `loadMore`, `maybePrefetch`, `setFilters(level)` | same |
| Repository | `RemoteMonoFeedRepository` implements `MonoFeedRepository` | `lib/features/mono/data/remote_mono_feed_repository.dart` |
| Summary DTO | `MonoFeedSummaryDto.fromJson` | `lib/features/mono/data/mono_feed_summary_dto.dart` |
| UI model | `monoFeedItemFromMonoFeedSummary` → `MonoFeedItem` | `lib/features/mono/data/mono_feed_item_mapper.dart` |

**Not used for For You list:** `FutureProvider` loading all rows at once. Pagination is explicit `StateNotifier` + cursor.

### API / mock source

| Mode | Source |
|------|--------|
| Remote | `GET {apiBaseUrl}/v1/mono/feed?limit=&cursor=&sort=recent&level=&category=` |
| Mock | `MonoScreen._mockItems` — no HTTP |

`apiBaseUrl`: `NimonApiConfig.apiBaseUrl` (`lib/core/config/nimon_api_config.dart`). Default `http://192.168.11.5:3000`; Render example `https://nimon-api-global-test.onrender.com` via `--dart-define` (see `docs/M20G_RELEASE_APK_GLOBAL_API_VERIFY_REPORT.md`).

`useRemoteMonoFeed`: `RemoteBackendConfig.useRemoteMonoFeed` — `bool.fromEnvironment('NIMON_USE_REMOTE_MONO_FEED', defaultValue: false)`.

### Pagination status (Flutter)

| Policy | Value | Where |
|--------|-------|--------|
| Initial page limit | **7** | `MonoReelsPaginationPolicy.initialLimit` |
| Load-more limit | **10** | `MonoReelsPaginationPolicy.nextLimit` |
| Prefetch threshold | ≤ **3** items before end | `maybePrefetch` on `PageView.onPageChanged` |
| Client max limit sent | clamped to **30** | `RemoteMonoFeedRepository._clampMonoLimit` |
| JLPT filter | `setFilters(level: …)` → query `level` | `All` → `null` |

Appended pages dedupe by `monoId`. **Does not** load entire catalog in one request when remote.

### JSON parsing status (Flutter)

**Feed list (`GET /v1/mono/feed`):**

- One `jsonDecode` per HTTP response in `RemoteMonoFeedRepository.fetchFeedPage`.
- Per row: `MonoFeedSummaryDto.fromJson` — scalar fields only (title, level, description, writer, counts, etc.).
- **Does not** parse `content`, `content.core.sentences`, `learn.vocabularyKanji`, `grammar`, or `quiz` in list path (those keys are absent from summary JSON).

**Summary → `MonoFeedItem`:**

- `bodyText: ''`, `content: null`, `needsRemoteDetailHydration: true` (mapper comment: no sentences until detail).

**Lazy detail (`GET /v1/mono/:monoId`):**

- Triggered by `_ensureDetailLoaded` when `needsRemoteDetailHydration` (on page change, after first page load, and in `build` post-frame for current index).
- `fetchMonoDetail` → `PublishedMonoDetailDto` with **`content` and `contentSummary` full maps**.
- `monoFeedItemMergePublishedDetail` → `plainBodyFromPublishedCore` / `buildMonoContentFromPublishedCore` parse **`content.core.sentences` only** (`lib/features/profile/data/published_mono_detail_parser.dart`).
- **Learn modules** (`content.learn.*`) are not mapped into horizontal reader `MonoContent` in the mapper; `publishedContentHasLearnPayload` is used for access flags only.

### Init / refresh triggers

| Event | Action |
|-------|--------|
| `initState` (remote) | `setFilters(level)` + `loadFirstPage()` |
| JLPT menu change | `_clearRemoteHydration()`, `setFilters`, `loadFirstPage()` |
| Refresh icon | `_clearRemoteHydration()`, `monoFeedPagerProvider.refresh()` |
| `profileProcessingListRefreshProvider` | `_clearRemoteHydration()`, `refresh()` |
| Settings `contentLocale` / `learningLanguage` change | `monoFeedPagerProvider.refresh()` (`user_preferences_notifier.dart`) — **Flutter does not add locale query params to feed GET**; relies on backend reading user prefs when JWT present |

---

## B. Current backend feed / data flow

### Endpoint serving For You

| HTTP | Handler |
|------|---------|
| `GET /v1/mono/feed` | `MonoFeedController.listFeed` → `MonoFeedService.listFeed` |
| `GET /v1/mono/:monoId` | `MonoFeedController.getOne` → `MonoFeedService.getPublicMonoById` (reader detail) |

Module: `nimon-backend/src/modules/mono-feed/`.  
Owner list remains `GET /v1/published-monos` (not the Home For You catalog).

### Service / validation

- **List:** `MonoFeedService.listFeed` — public catalog over `published_monos` with `PUBLISHED_MONO_CATALOG_VISIBLE` (non-trashed, not hidden while draft has `hasUnpublishedCoreChanges`).
- **Detail:** `getPublicMonoById` → `publishedMonoDetailFromRow` — returns **full `content` JSON** to client.

### Prisma query (list)

`prisma.publishedMono.findMany`:

- `orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }]`
- `take: limit + 1` (cursor page)
- **Select includes `content: true`** (full JSON column) plus normalized columns: `title`, `category`, `level`, `description`, `contentLocale`, `learningLanguage`, `createdAt`, `updatedAt`, owner profile.
- Response mapping uses `extractContentMeta(row.content)` — reads `core.coverImageUrl`, `publishKind`, `learn.audio.storyAudio.sourceUrl` only; **does not return raw `content` in JSON**.

### Pagination

| Param | Backend behavior |
|-------|------------------|
| `limit` | Default **15**, max **30** (`DEFAULT_LIMIT`, `MAX_LIMIT` in `mono-feed.service.ts`) |
| `cursor` | Base64url JSON `{ u: updatedAt ISO, i: id }`; filter `updatedAt` / `id` tuple |
| `sort` | Only `recent` supported |
| `hasMore` / `nextCursor` | Standard take+1 pattern |

Flutter sends smaller limits (7/10) than backend default 15.

### Filtering

| Filter | Server-side? |
|--------|----------------|
| `level` | Yes — `where.level` |
| `category` | Yes |
| `writerId` | Yes |
| `following=true` | Yes — `ownerId in` followed users (auth required) |
| `contentLocale` | Yes — query override or **logged-in user** `userPreference.contentLocale`; legacy rows with `null` included |
| `learningLanguage` | Yes — same pattern (`ja` only enforced) |
| Content community (app “Myanmar” etc.) | Mapped to DB column **`contentLocale`** (`en` / `my` / `ja`), not a separate `contentCommunity` column |

### Sort

- **`updatedAt` desc**, then **`id` desc** (not `publishedAt`; `publishedAt` in DTO = `createdAt`).

### Extra queries per page

After page of IDs: `monoReaction.groupBy` (likes), `monoBookmark.findMany`, `monoReaction.findMany` for current user — bounded to page size.

### Detail endpoint payload

`getPublicMonoById` selects **`content: true`** and returns full published JSON (plus social fields). This is the payload Flutter decodes and parses for sentences on the UI isolate.

---

## C. Current database shape

### Table

**`published_monos`** (`@@map("published_monos")` in `nimon-backend/prisma/schema.prisma`).

### Columns (feed-relevant)

| Column | Role |
|--------|------|
| `id`, `ownerId` | Identity |
| `title`, `category`, `level`, `description` | **Normalized summary** (duplicated from content for list/filter) |
| `contentLocale`, `learningLanguage` | **Normalized** locale tags (M11e); nullable for legacy |
| `content` | **Large JSONB** — `core` (sentences, cover, duration), `learn` (vocab, grammar, quiz, audio), `publishKind`, `sourceDraftId`, etc. |
| `createdAt`, `updatedAt` | Sort / cursor |
| `trashedAt` | Visibility (null = catalog-visible) |

**Not normalized into separate tables for published read path:** sentences, vocab, grammar, quiz rows (unlike `draft_*` tables for drafts).

### Indexes (Prisma / migrations)

| Index | Columns |
|-------|---------|
| `published_monos_ownerId_updatedAt_idx` | `ownerId`, `updatedAt` |
| `published_monos_ownerId_trashedAt_idx` | `ownerId`, `trashedAt` |
| `published_monos_contentLocale_learningLanguage_updatedAt_idx` | `contentLocale`, `learningLanguage`, `updatedAt` |

**Missing for global feed sort:** dedicated index on **`(updatedAt desc, id desc)`** under catalog visibility predicate (feed uses global `updatedAt` ordering, not `ownerId`).

**No index** on `level` or `category` alone (filters use `AND` on visibility + locale + optional equality).

### Supabase / SQL history

- Initial: `prisma/migrations/20260421082646_init_add_flow_v1/migration.sql` — `content JSONB NOT NULL DEFAULT '{}'`.
- Locales: `20260508210000_m11e_published_mono_locales/migration.sql`.
- Trash: `20260505183000_published_mono_trash/migration.sql`.
- Feed compat: `20260509120000_m11i_reading_prefs_feed_compat/migration.sql`.

---

## D. Performance risk list

| ID | Risk | Severity | Notes |
|----|------|----------|-------|
| R1 | Prisma loads **full `content` JSONB** for every row in `GET /v1/mono/feed` | **BLOCKER** | Large DB I/O + Node parse per item even though API response is summary-only. Scales with story/learn size × page size. |
| R2 | **Detail fetch** returns full `content` per swipe; Flutter parses all **sentences** on UI isolate | **HIGH** | `_ensureDetailLoaded` + `buildMonoContentFromPublishedCore`; full JSON over network per visible mono. |
| R3 | `ref.watch(monoFeedPagerProvider)` at top of `MonoScreen.build` | **HIGH** | Any pager state change (load more, refresh, error) rebuilds large `MonoScreen` subtree. |
| R4 | `setState` on each successful detail hydration | **HIGH** | Rebuilds feed + map update per mono id. |
| R5 | Mock mode loads **~51 full `MonoFeedItem`s** with embedded `MonoContent` | **MEDIUM** | Default dev/QA path; no pagination; all sentences in RAM. |
| R6 | Feed GET does not pass **`contentLocale` / `learningLanguage` query** from Flutter | **MEDIUM** | Works when authenticated (server reads prefs); guest/catalog may not match Settings until refresh/auth. |
| R7 | Global feed sort on `updatedAt` without ideal composite catalog index | **MEDIUM** | May seq-scan or use partial index less optimally at scale. |
| R8 | Per-page N+1-style social queries (likes/bookmarks/reactions) | **LOW–MEDIUM** | Batched by `in: ids` — acceptable for page size ≤30. |
| R9 | `profileProcessingListRefreshProvider` → full feed **refresh** + hydration clear | **MEDIUM** | Correctness-driven; causes reload storms after publish. |
| R10 | Learn JSON present in detail payload but unused in feed reader | **LOW** | Still transferred in `GET /v1/mono/:id` body for full-learn monos. |
| R11 | No `FutureProvider` “load all monos” anti-pattern | — | **Mitigated** — pager design is sound for remote mode. |

**Not observed:** parsing `learn.vocabularyKanji` / `grammar` / `quiz` in the **feed list** builder.

---

## E. Recommended target design

1. **Feed list endpoint returns summary only**  
   - Response: existing `MonoFeedSummaryItemDto` fields.  
   - DB: **do not select `content`** in list query; use columns + optional small denormalized fields (`coverImageUrl`, `publishKind`, `hasAudio` booleans).

2. **Cursor pagination**  
   - Server default limit **15**, max **30** (already implemented).  
   - Align Flutter policy to **15 initial / 15 load-more** (or keep 7/10 but document tradeoff).

3. **Detail endpoint**  
   - `GET /v1/mono/:id` returns reader payload; consider split: **core-only** for horizontal reader vs **`/learn`** for Learn hub (lazy).

4. **Learn modules**  
   - Load vocab/grammar/quiz/audio only when user opens Learn — not in feed list or initial reader hydrate.

5. **Feed rows**  
   - Must not include `content`, `sentences[]`, or `learn.*` arrays.

6. **Locale filters**  
   - Server-side on `contentLocale` / `learningLanguage` (already).  
   - Flutter should pass explicit query params from `UserPreferences` on every feed request (guest + authed).

7. **Flutter state**  
   - Keep `StateNotifier` pager; avoid watching entire pager in root `build` — watch `select`/`Listenable` for loading flags only.  
   - Hydrate detail in isolate or `compute()` if JSON large; cache by `monoId`.

---

## F. Exact implementation plan (next prompt — do not implement here)

### Backend

| File | Change |
|------|--------|
| `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` | Remove `content: true` from list `select`; use denormalized fields or SQL JSON operators for cover/audio/publishKind only. |
| `nimon-backend/prisma/schema.prisma` + new migration | Add nullable `coverImageUrl`, `publishKind`, `hasAudio` (or similar) on `published_monos`; backfill on publish. |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` (publish paths) | Populate denormalized columns when writing `published_monos`. |
| `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts` | Document summary-only contract. |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | Assert list query does not require full content blob. |
| Optional: `GET /v1/mono/:id/core` vs `/full` | Split payload for reader vs learn. |

### Flutter

| File | Change |
|------|--------|
| `lib/features/mono/data/remote_mono_feed_repository.dart` | Add `contentLocale` / `learningLanguage` query params from prefs. |
| `lib/features/mono/data/mono_feed_providers.dart` | Tune limits; optional `select` rebuild optimization. |
| `lib/features/mono/mono_screen.dart` | Narrow `ref.watch`; debounce hydration; optional isolate parse. |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | Unchanged contract if summary stable. |
| `lib/features/profile/data/published_mono_detail_parser.dart` | Use only when opening reader / after explicit fetch. |

### Tests

| File | Change |
|------|--------|
| `test/features/mono/remote_mono_feed_repository_test.dart` | Query params + payload size assumptions. |
| `test/features/mono/mono_feed_pager_test.dart` | Pagination limits. |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | List select shape. |
| Integration: feed response must not contain `content` key | Contract test. |

---

## G. Measurement plan (later)

| Metric | How |
|--------|-----|
| Feed response payload size | Log `resp.body.length` in `RemoteMonoFeedRepository.fetchFeedPage` (debug) or Charles/mitmproxy |
| Feed endpoint latency | Server log `listFeed` duration; APM on Render |
| Items per request | `items.length`, `limit` query param |
| JSON decode time | Dart `Timeline` around `jsonDecode` + `fromJson` loop |
| DB time / rows read | Postgres `EXPLAIN ANALYZE` on feed query with/without `content` |
| Flutter frame jank | DevTools performance overlay on vertical swipe + load-more |
| Memory after opening For You | DevTools memory — mock vs remote; count hydrated entries in `_hydratedRemoteItems` |
| Detail fetch size | `GET /v1/mono/:id` body bytes per mono |

---

## Appendix — Key code references

| Concern | Path |
|---------|------|
| For You UI | `lib/features/mono/mono_screen.dart` — `_useRemoteForYouFeed`, `_buildMainMonoVerticalFeed`, `_ensureDetailLoaded` |
| Pager | `lib/features/mono/data/mono_feed_providers.dart` |
| Feed HTTP | `lib/features/mono/data/remote_mono_feed_repository.dart` — `fetchFeedPage`, `fetchMonoDetail` |
| Summary mapping | `lib/features/mono/data/mono_feed_item_mapper.dart` |
| Backend feed | `nimon-backend/src/modules/mono-feed/mono-feed.controller.ts`, `mono-feed.service.ts` |
| Legacy quiz-style limits (unrelated to feed) | N/A here |
| Published content shape | `nimon-backend/prisma/schema.prisma` — `PublishedMono` |

---

*End of M22A audit.*
