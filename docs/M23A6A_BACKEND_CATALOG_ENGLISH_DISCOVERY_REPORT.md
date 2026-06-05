# M23A-6A — Backend Catalog English Discovery Report

Date: 2026-06-03  
Phase: **M23A-6A** (backend catalog helper + discovery tests only)

---

## A. Files changed

| File | Change |
|------|--------|
| `nimon-backend/src/modules/published-monos/published-mono-catalog-locale.ts` | `CatalogLearningLanguage` = `'ja' \| 'en'`; preserve `en` in `safeStoredLearningLanguage`; accept `en` query; reject `ko` |
| `nimon-backend/src/modules/published-monos/published-mono-catalog-locale.spec.ts` | +6 tests for `en` preservation, query override, rejection |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | `feedLocaleWhere` typing + **M23A-6A** describe (+7 tests) |
| `nimon-backend/src/modules/creator-collections/creator-collections.service.spec.ts` | `catalogVisibleForLocale` accepts `en` + **M23A-6A** public collection tests (+5) |

**Not modified:** Flutter, search, bookmarks, owner published/collections, collection add rule, reader/creator UI, publish/import validation, HTML generator, Prisma schema/migrations, feed DTO shape.

---

## B. Catalog helper behavior before / after

| Behavior | Before M23A-6A | After M23A-6A |
|----------|----------------|---------------|
| `CatalogLearningLanguage` | `'ja'` only | `'ja' \| 'en'` |
| Stored pref `en` | Coerced → `ja` | Preserved → `en` |
| Stored pref `ja` | `ja` | `ja` |
| Stored null / unknown (`ko`, etc.) | `ja` | `ja` (unchanged) |
| Query `learningLanguage=en` | `400 learningLanguage_invalid` | Accepted |
| Query `learningLanguage=ko` | `400` | `400` (unchanged) |
| `publishedMonoCatalogLocaleWhere` | OR-null on `contentLocale` + `learningLanguage` | Same structure; effective `en` used when resolved |
| Guest default | `contentLocale=en`, `learningLanguage=ja` | **Unchanged** |
| `contentLocale` handling | Unchanged | Unchanged |

---

## C. Effective lens matrix

| Viewer | Effective lens (after) | Mono shown in catalog SQL | Mono hidden |
|--------|------------------------|---------------------------|-------------|
| Guest | `en` + `ja` | `ja+en`, null legacy | `en+my`, `ja+my` (non-null mismatch) |
| Prefs `en` + `my` | `my` + `en` | `en+my`, null legacy | `ja+my`, `en+en`, etc. |
| Prefs `ja` + `my` | `my` + `ja` | `ja+my`, null legacy | `en+my` |
| Prefs `en` + `ja` | `ja` + `en` | `en+ja`, null legacy | `en+my`-only collections (itemCount 0) |
| Query `learningLanguage=en&contentLocale=my` | `my` + `en` | Same as `en+my` prefs | — |

Invalid pairs (`ja+ja`, `en+en`) remain blocked at prefs/publish layers; catalog helper does not synthesize them.

---

## D. Feed test matrix (M23A-6A)

| Case | Test name | Assertion |
|------|-----------|-----------|
| A — `en+my` viewer | `en+my viewer feed filter is my+en` | `findMany` where includes `feedLocaleWhere('my','en')`, not `my+ja` |
| B — `ja+my` viewer | `ja+my viewer feed filter excludes en+my lens` | `my+ja` only |
| C — Guest | `guest default feed filter is en+ja` | `en+ja` |
| D — Query override | `query override learningLanguage=en contentLocale=my` | `my+en` |
| E — Invalid override | `invalid query learningLanguage=ko throws` | `BadRequestException`, `findMany` not called |
| Following | `following feed uses en+my lens` | `my+en` + `ownerId in followed` |
| Public profile Monos | `writerId feed uses en+my lens` | `my+en` + `writerId` |

SQL still applies OR-null legacy inclusion on both columns (existing contract).

---

## E. Public profile / collection behavior

Public profile **Monos** uses `GET /v1/mono/feed?writerId=` — same `listFeed` path; **writerId + catalog lens** tests added.

Public **collections** (M22E-1 block + M23A-6A):

| Viewer | Collection contents | List behavior | Detail behavior |
|--------|---------------------|---------------|-----------------|
| `en+my` | `en+my` + `ja+my` items | Visible, `itemCount=1`, cover from visible item | `catalogVisibleForLocale('my','en')`; one item returned |
| `ja+my` | same | `itemCount=1` via `my+ja` filter | One `ja+my` item |
| `en+ja` | only `en+my` items | Collection **hidden** (`itemCount=0` → filtered out) | Empty items, `nextCursor` null |

**Owner surfaces unchanged:** `listMine` / `listMineCollectionMonos` still use `PUBLISHED_MONO_CATALOG_VISIBLE` only (regression test retained).

---

## F. Exact tests added

### `published-mono-catalog-locale.spec.ts` (+6)

1. `publishedMonoCatalogLocaleWhere supports en learning language`
2. `safeStoredLearningLanguage preserves en and ja`
3. `ensureAllowedLearningLanguageQuery accepts en and rejects ko`
4. `resolveCatalogLanguageContext preserves en prefs for authenticated viewer`
5. `learningLanguage query override en wins over ja prefs`
6. `rejects invalid learningLanguage query`

### `mono-feed.service.spec.ts` — describe `M23A-6A English catalog discovery` (+7)

1. `en+my viewer feed filter is my+en (not coerced to ja)`
2. `ja+my viewer feed filter excludes en+my lens`
3. `guest default feed filter is en+ja`
4. `query override learningLanguage=en contentLocale=my applies my+en filter`
5. `invalid query learningLanguage=ko throws learningLanguage_invalid`
6. `following feed uses en+my lens for en+my viewer`
7. `writerId feed uses en+my lens for en+my viewer (public profile Monos)`

### `creator-collections.service.spec.ts` — inside `M22E-1 public viewer language filter` (+5)

1. `en+my viewer sees mixed collection with itemCount 1 and en+my cover`
2. `en+my viewer listPublicCollectionMonos returns only en+my-visible items`
3. `ja+my viewer on same mixed collection uses my+ja filter and one item`
4. `en+ja viewer hides collection with only en+my items`
5. `en+ja viewer listPublicCollectionMonos returns empty for en+my-only collection`

---

## G. Test commands and pass counts

From `nimon-backend/`:

```powershell
node .\node_modules\jest\bin\jest.js src/modules/published-monos/published-mono-catalog-locale.spec.ts src/modules/mono-feed/mono-feed.service.spec.ts src/modules/creator-collections/creator-collections.service.spec.ts --no-cache
```

**Result:** **3** test suites passed, **80** tests passed, **0** failed.

| Suite | Tests |
|-------|-------|
| `published-mono-catalog-locale.spec.ts` | 12 |
| `mono-feed.service.spec.ts` | 30 |
| `creator-collections.service.spec.ts` | 38 |

---

## H. Explicitly unchanged surfaces

| Surface | Status |
|---------|--------|
| `SearchService` | No catalog locale import; no locale filter |
| `MonoSocialService.listMyBookmarks` | No locale filter |
| `PublishedMonosService.listPublishedMonos` | Owner list; no locale filter |
| `CreatorCollectionsService.listMine` / `listMineCollectionMonos` | No viewer lens |
| Collection add rule (`assertCollectionContentLocaleCompatible`) | contentLocale-only |
| `MonoFeedService.getPublicMonoById` | No viewer lens |
| Feed response DTO / `mapRowToSummary` | No shape change |
| Flutter | **No files changed** |
| DB schema / migrations | **None** |

---

## I. Remaining M23A-6B work

1. **Flutter:** Refresh public profile **Monos** tab when `contentLocale` / `learningLanguage` prefs change (Collections tab already listens).
2. **Flutter (optional):** Send explicit `contentLocale` / `learningLanguage` query params on feed and public collection requests.
3. **Product + backend:** Search policy — feed-aligned vs global.
4. **Product + backend:** Saved tab and owner published — filter vs show-all with badges.
5. **UX (optional):** Feed card badges for learning + community on list rows (feed DTO still omits locale fields on wire).

---

## Final verification checklist

| # | Requirement | Confirmed |
|---|-------------|-----------|
| 1 | No Flutter files changed | Yes |
| 2 | No search files changed | Yes |
| 3 | No saved/bookmark behavior changed | Yes |
| 4 | No owner published/collection behavior changed | Yes |
| 5 | No collection add rule changed | Yes |
| 6 | No feed DTO shape changed | Yes |
| 7 | No schema/migration changed | Yes |

---

## Success criteria

- [x] `en` catalog learning language preserved (not coerced to `ja`)
- [x] `en+my` viewer lens uses `my+en` in feed / following / writerId feed
- [x] `ja+my` viewer does not use `en` lens
- [x] Public collections list/detail use same catalog helper
- [x] Query `learningLanguage=en` works; `ko` rejects
- [x] Search / saved / owner paths unchanged
- [x] Tests pass: **80/80**

---

*M23A-6A complete.*
