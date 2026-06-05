# M23A-6D-1 — Search Feed-Lens Parity Report

**Phase:** M23A-6D-1 only  
**Policy:** Search = Feed-aligned by default (`viewer.learningLanguage` + `viewer.contentLocale`, legacy OR-null rows included).  
**Date:** 2026-06-03

---

## A. Files changed

### Backend

| File | Change |
|------|--------|
| `nimon-backend/src/modules/search/search.service.ts` | Resolve catalog lens via `resolveCatalogLanguageContext` + `publishedMonoCatalogLocaleWhere` before keyword/facet filters |
| `nimon-backend/src/modules/search/search.controller.ts` | Accept `contentLocale` and `learningLanguage` query params (same contract as feed) |
| `nimon-backend/src/modules/search/search.service.spec.ts` | Updated M18A where-clause expectations; added M23A-6D-1 lens matrix tests |

### Flutter

| File | Change |
|------|--------|
| `lib/features/search/data/mono_search_remote.dart` | Optional `catalogLens` on `searchMonos` |
| `lib/features/search/data/remote_mono_search_repository.dart` | Merge `CatalogDiscoveryLens` into query when authenticated |
| `lib/features/search/presentation/mono_search_notifier.dart` | `CatalogDiscoveryLensReader`; pass lens on first page + load more; public `shouldFetchRemote` |
| `lib/features/search/presentation/mono_search_providers.dart` | Wire lens from `userPreferencesNotifierProvider` |
| `lib/features/mono/mono_search_screen.dart` | Refresh active search when prefs change |

### Tests

| File | Change |
|------|--------|
| `test/features/search/remote_mono_search_repository_test.dart` | Lens sent when auth; omitted for guest; existing params preserved |
| `test/features/search/mono_search_notifier_test.dart` | Lens reader, `shouldFetchRemote`, empty search no fetch on lens change |

---

## B. Backend search lens behavior

`GET /v1/search/monos` now builds:

```text
visibility (PUBLISHED_MONO_CATALOG_VISIBLE)
AND catalog lens (publishedMonoCatalogLocaleWhere)
AND optional q / level / category
```

**Authenticated viewer:** `resolveCatalogLanguageContext` uses `UserPreference` (`contentLocale`, `learningLanguage`) with optional query overrides — same helper as `MonoFeedService.listFeed`.

**Guest:** backend defaults `contentLocale=en`, `learningLanguage=ja` (product notation **ja+en**: Japanese learning, English content).

**Query overrides:** `learningLanguage=ja|en`, `contentLocale=my|en|ja`.

**Invalid:** `learningLanguage=ko` → `400` with `learningLanguage_invalid` (same as feed).

**Legacy rows:** `contentLocale=null` and/or `learningLanguage=null` match via OR-null clauses inside `publishedMonoCatalogLocaleWhere`.

Existing search parameters unchanged: `q`, `level`, `category`, `sort`, `cursor`, `limit`.

---

## C. Flutter query param behavior

- **Signed-in:** `RemoteMonoSearchRepository` calls `CatalogDiscoveryLens.mergeIntoQueryIfAuthenticated` so `contentLocale` + `learningLanguage` are sent only when `Authorization` is present and `CatalogDiscoveryLens.tryFromPreferences` returns a valid pair (no same-language pairs).
- **Guest:** lens params omitted; backend guest defaults apply.
- **Notifier:** reads lens on each `searchMonos` call (first page + load more).
- **Prefs refresh:** `MonoSearchScreen` listens to `userPreferencesNotifierProvider`; if `shouldFetchRemote` is true (active query, level, or category), calls `refresh()` when `contentLocale` or `learningLanguage` changes.

---

## D. Search behavior matrix

| Viewer / input | Effective lens | Sees (example rows) |
|----------------|----------------|---------------------|
| Guest (no params) | en content + ja learning (**ja+en**) | `ja+en` titles; not `en+my` |
| Auth prefs **en+my** | my + en | `en+my` titles; not `ja+my` |
| Auth prefs **ja+my** | my + ja | `ja+my` titles; not `en+my` |
| Query `learningLanguage=en&contentLocale=my` | my + en | `en+my` only |
| Query `learningLanguage=ko` | — | `400 learningLanguage_invalid` |
| Legacy `learningLanguage=null`, `contentLocale=null` | Included under active lens OR-null rule | Visible when lens matches or null |

---

## E. Tests added

### Backend (`search.service.spec.ts`)

**M23A-6D-1 block (6 tests):**

1. en+my viewer → `catalogLocaleWhere('my','en')` only  
2. ja+my viewer → `catalogLocaleWhere('my','ja')` only  
3. Guest default → `catalogLocaleWhere('en','ja')`  
4. Query override `en` + `my`  
5. Invalid `learningLanguage=ko`  
6. Legacy OR-null structure on locale clause  

**M18A block:** updated for two-clause base where (visibility + lens); keyword clause found by structure (index-independent).

### Flutter

- `remote_mono_search_repository_test.dart`: +2 (authenticated lens, guest omit)  
- `mono_search_notifier_test.dart`: +3 (lens reader, empty search no refetch, `shouldFetchRemote`)

---

## F. Exact test commands and pass counts

```powershell
cd nimon-backend
node .\node_modules\jest\bin\jest.js src/modules/search/search.service.spec.ts --no-cache
```

**Result:** 23 passed (17 M18A + 6 M23A-6D-1)

```powershell
cd nimon
flutter.bat test test/features/search/remote_mono_search_repository_test.dart test/features/search/mono_search_notifier_test.dart
```

**Result:** 21 passed (7 repository + 14 notifier)

---

## G. Unchanged surfaces

Explicit confirmation for M23A-6D-1 scope:

| Surface | Status |
|---------|--------|
| Saved / bookmarks | Unchanged |
| Owner published lists | Unchanged |
| Owner collections | Unchanged |
| Feed DTO shape (`MonoFeedSummaryItemDto`) | Unchanged |
| Feed card UI | Unchanged |
| Public profile discovery lens (already M23A-6B) | Unchanged in this phase |
| Direct mono detail | Unchanged |
| Search / Saved / Owner badges | **Not implemented** |
| Prisma schema / migrations | **None** |
| Publish validation / creator / reader UI | **Not modified in 6D-1** |

---

## H. Remaining M23A-6D work

| Item | Phase |
|------|--------|
| Dual badges on Search / Saved / Owner list rows | M23A-6D-2 |
| Feed summary DTO locale fields + Home/Following badges | M23A-6D-3 |
| Optional “All languages” search toggle | Later (out of V1 lock) |
| Direct-detail discovery banner (optional) | Later |

---

## Success criteria checklist

- [x] Search feed-aligned by catalog lens  
- [x] en+my viewer → en+my search results only (where clause)  
- [x] ja+my viewer does not use en+my lens  
- [x] Guest search uses ja+en default (`en` + `ja` in helper)  
- [x] Explicit query override works  
- [x] Invalid `learningLanguage` rejects  
- [x] Flutter sends lens when authenticated  
- [x] Search badges not implemented  
- [x] Saved / Owner / Feed DTO unchanged in this phase  
- [x] No DB migration  
- [x] Tests pass with counts above  
