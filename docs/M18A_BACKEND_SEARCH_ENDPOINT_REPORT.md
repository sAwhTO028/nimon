# M18A — Backend published mono search endpoint (report)

## Endpoint

| Method | Path |
|--------|------|
| `GET` | `/v1/search/monos` |

- **Auth:** `OptionalJwtUserGuard` — anonymous allowed; when a valid Bearer JWT is present, `isBookmarkedByMe` / `myReaction` reflect the viewer; `likesCount` is always populated from `mono_reactions`.

## Query parameters

| Param | Required | Description |
|-------|----------|-------------|
| `q` | No | Free text; trimmed; empty → browse (filters only). Split on whitespace into tokens (max 12, string max 240 chars). **AND** across tokens: each token must match at least one of title, description, `UserProfile.displayName`, or `UserProfile.handle` (case-insensitive `contains`). |
| `level` | No | One of `N5`, `N4`, `N3`, `N2`, `N1`. Invalid value → `400` `BadRequestException` message `invalid_level`. |
| `category` | No | Exact match on `published_monos.category` (trimmed). |
| `sort` | No | **`latest`** only in M18A. Accepts `''`, `latest`, or `recent` (alias). Anything else → `400` `unsupported_sort` (same style as owner published list). |
| `limit` | No | Default **20**, clamped **1–50** (same as `GET /v1/published-monos`). |
| `cursor` | No | Opaque cursor; invalid → `400` `invalid_cursor` (no DB call). |

## Visibility

All queries merge **`PUBLISHED_MONO_CATALOG_VISIBLE`** from `published-mono-visibility.ts`:

- `trashedAt: null`
- Exclude rows with a linked `StoryDraft` where `hasUnpublishedCoreChanges === true`

Same rules as Mono Home feed and owner published tab catalog.

## Sort & pagination

- **Order:** `updatedAt` desc, `id` desc (stable tie-break).
- **Page size:** `take = limit + 1`; if more than `limit` rows, `hasMore: true` and `nextCursor` encodes `{ u: updatedAt ISO, i: id }` as **base64url JSON** (compatible with owner list / mono feed cursors).
- **`totalCount`:** `publishedMono.count(where)` on the **first** page only (`cursor` absent); `null` on continuation pages.

## Response shape

```json
{
  "items": [],
  "hasMore": true,
  "nextCursor": "...",
  "totalCount": 0
}
```

### Item DTO (`PublishedMonoSearchListItemDto`)

Each element is **`PublishedMonoListItemDto`** (from `published-monos.dto.ts`) **plus**:

| Field | Source |
|-------|--------|
| `shareUrl` | `PublicWebBaseUrlService.monoShareUrl(id)` |
| `likesCount` | `mono_reactions` groupBy `heart` for page ids |
| `isBookmarkedByMe` | `mono_bookmarks` when `viewerUserId` set, else `false` |
| `myReaction` | `mono_reactions` heart row for viewer, else `null` |

Writer fields (`writerDisplayName`, `writerHandle`, `writerAvatarUrl`) come from **`owner.profile`** join (live profile), using `attachWriterProfileToListItem` + `publishedMonoListItemFromRow` from `published-mono-common.ts`.

## Implementation files

| File | Role |
|------|------|
| `src/modules/search/search.module.ts` | Nest module wiring |
| `src/modules/search/search.controller.ts` | `GET v1/search/monos` |
| `src/modules/search/search.service.ts` | Prisma query + mapping |
| `src/modules/search/search.dto.ts` | Response / item types |
| `src/modules/search/search.service.spec.ts` | Unit tests (mock Prisma) |
| `src/app.module.ts` | Registers `SearchModule` |

## Tests (`search.service.spec.ts`)

1. Empty `q` → where equals catalog predicate only.  
2. `q` builds title `contains` + description + owner profile OR.  
3. Description branch present.  
4. Profile `displayName` / `handle` branches.  
5. Level filter predicate.  
6. Category filter predicate.  
7. `q` + level + category `AND`.  
8. Trashed excluded via catalog `trashedAt`.  
9. Draft-hiding `NOT` matches `PUBLISHED_MONO_CATALOG_VISIBLE.NOT`.  
10. `limit` 20 with 21 rows → 20 items, `hasMore`, `nextCursor`, `totalCount` 35.  
11. Second page: no duplicate ids, `totalCount` null.  
12. Invalid level.  
13. Unsupported `sort`.  
14. Optional viewer → bookmark + reaction queries and DTO flags.  
15. `shareUrl` on items.  
16. Invalid cursor throws before `findMany`.  
17. Multi-token `q` → `AND` of per-token clauses.

**Commands run**

```text
node node_modules/jest/bin/jest.js src/modules/search --runInBand
node node_modules/jest/bin/jest.js src/modules/published-monos --runInBand
node node_modules/jest/bin/jest.js --runInBand
node node_modules/@nestjs/cli/bin/nest.js build
```

## Remaining work (M18B+)

- Flutter: `RemoteSearchRepository`, Riverpod state, UI (search field, chips, sort, list, empty/loading/error, load more) per `docs/M18_V1_SEARCH_AND_FILTER_PLAN.md`.
- **Popular sort** and analytics — deferred (V1.1).
- Optional: DB indexes for `title`/`description`/`UserProfile` if `contains` performance needs tuning on large catalogs.
