# M22E-1 — Public Profile Collections Language Filter Fix

Date: 2026-06-03  
Source audit: `docs/M22E0_PUBLIC_PROFILE_COLLECTIONS_FLOW_AUDIT.md`

---

## A. Root cause

Public profile **Monos** used `GET /v1/mono/feed?writerId=` with `OptionalJwtUserGuard` and `MonoFeedService.listFeed` language predicates (`contentLocale` + `learningLanguage`, legacy `OR null`).

Public profile **Collections** used `GET /v1/users/:userId/creator-collections` and `.../monos` **without** JWT resolution or locale filters. `itemCount` and item lists included every catalog-visible mono regardless of viewer community.

Result: a `my`+`ja` viewer could see collection cards and detail rows for `en`+`ja` monos while the Monos tab correctly hid them.

---

## B. Product rule locked

| Rule | Implementation |
|------|----------------|
| No collection-level language metadata | Unchanged — filter via `published_monos` tags only |
| Mixed-language collections allowed | Yes — per-item visibility |
| Collection visible iff ≥1 viewer-visible item | Public list omits `itemCount === 0` after filter |
| Same policy as Mono feed | Shared `resolveCatalogLanguageContext` + `publishedMonoCatalogLocaleWhere` |
| `commonLanguage` | Not used |
| Guest defaults | `en` + `ja` |
| Authenticated | `UserPreference` + optional query overrides |
| Owner `/v1/me/creator-collections` | Unfiltered catalog counts (unchanged) |

---

## C. Backend changes

### Shared catalog locale helper

- **New:** `nimon-backend/src/modules/published-monos/published-mono-catalog-locale.ts`
- **New tests:** `published-mono-catalog-locale.spec.ts`
- Exports: `resolveCatalogLanguageContext`, `publishedMonoCatalogLocaleWhere`, safe defaults, query validation.

### Mono feed (refactor only)

- `mono-feed.service.ts` uses shared helper — **same feed behavior**, no controller changes.

### Public collections

- `public-creator-collections.controller.ts`: `OptionalJwtUserGuard` on both routes; optional `contentLocale` / `learningLanguage` query params (parity with feed).
- `creator-collections.service.ts`:
  - `listPublicForUser(targetUserId, viewer)` — filtered `groupBy` counts, hide zero-count collections, derived cover from first **viewer-visible** mono via `coverImageUrl` column (no `content` JSONB).
  - `listPublicCollectionMonos(..., viewer)` — `publishedMono` where = catalog visible **AND** locale predicate; list mapping via `publishedMonoListItemFromCatalogSummaryRow` + `PUBLIC_COLLECTION_MONO_SELECT` (no full `content` select).

### Owner APIs

- `listMine`, `listMineCollectionMonos`, `derivedCoversForCollections` (owner path) — still use `PUBLISHED_MONO_CATALOG_VISIBLE` only.

### DTO

- `CreatorMonoCollectionDto.itemCount` comment updated: viewer-visible count on public APIs.

---

## D. Flutter changes

- `public_profile_screen.dart`: `ref.listen(userPreferencesNotifierProvider)` clears `_publicCollectionsLoaded` and reloads collections when `contentLocale` or `learningLanguage` changes (reload immediately if Collections tab active).
- `remote_creator_collections_repository.dart`: debug logs for public list/detail — response count, item count, `authPresent` (no token).

No query params added on Flutter — backend derives locale from JWT + prefs (same as feed).

---

## E. Query / filter behavior

For public collection endpoints, effective tags:

1. Guest / no JWT → `en` + `ja`
2. Authenticated → `user_preferences` (invalid stored → safe `en`/`ja`)
3. Query `contentLocale` / `learningLanguage` → override prefs (invalid → 400)

Published mono predicate (per item):

```
PUBLISHED_MONO_CATALOG_VISIBLE
AND (contentLocale = effective OR contentLocale IS NULL)
AND (learningLanguage = effective OR learningLanguage IS NULL)
```

---

## F. Tests run

```text
published-mono-catalog-locale.spec.ts — pass
creator-collections.service.spec.ts — pass (incl. M22E-1 cases A–F)
creator-collections.dto.spec.ts — pass (suite)
mono-feed.service.spec.ts — pass (regression after shared helper)
```

New cases cover: my+ja filtered count/hide empty collection, detail items only my, guest en+ja, listMine unfiltered.

---

## G. Performance decisions

| Area | Decision |
|------|----------|
| Public collection **list** covers | Use `published_monos.coverImageUrl` only — **no `content` JSONB** |
| Public collection **detail** items | `PUBLIC_COLLECTION_MONO_SELECT` — denormalized columns + `publishedMonoListItemFromCatalogSummaryRow` — **no `content` JSONB** |
| Owner list covers | Still use `content` JSON for derived cover (unchanged; lower risk) |
| Owner detail monos | Still `include: { publishedMono: true }` (unchanged) |

---

## H. Manual verification

1. Login: Content community = **Myanmar**, Learning = **Japanese**.
2. Open a creator public profile with a mixed collection (`my`+`ja` and `en`+`ja` monos).
3. **Monos** tab: only `my`+`ja` rows.
4. **Collections** tab: collection visible with **itemCount = 1**.
5. Collection detail: only `my`+`ja` mono.
6. Settings → Content community = **International / English** → return to profile.
7. Collections reload; same collection shows **en** item (count updates).
8. Log out (guest) → collections follow **en**+`ja` defaults for visible items.

---

## Files touched

**Backend:** `published-mono-catalog-locale.ts`, `.spec.ts`, `published-mono-common.ts`, `mono-feed.service.ts`, `creator-collections.service.ts`, `public-creator-collections.controller.ts`, `creator-collections.dto.ts`, `creator-collections.service.spec.ts`

**Flutter:** `public_profile_screen.dart`, `remote_creator_collections_repository.dart`

**Docs:** `docs/M22E1_PUBLIC_PROFILE_COLLECTIONS_LANGUAGE_FILTER_FIX_REPORT.md`
