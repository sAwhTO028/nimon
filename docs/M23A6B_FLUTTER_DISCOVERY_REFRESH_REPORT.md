# M23A-6B — Flutter Discovery Refresh + Locale Query Params Report

Date: 2026-06-03  
Phase: **M23A-6B** (Flutter discovery consistency only; builds on M23A-6A backend catalog)

---

## A. Files changed

| File | Change |
|------|--------|
| `lib/core/settings/catalog_discovery_lens.dart` | **New** — lens from prefs + authenticated query merge |
| `lib/features/mono/data/mono_feed_repository.dart` | Optional `catalogLens` on `fetchFeedPage` |
| `lib/features/mono/data/remote_mono_feed_repository.dart` | Merge lens into feed query when JWT present |
| `lib/features/mono/data/remote_following_mono_feed_repository.dart` | Same for following feed |
| `lib/features/mono/data/mono_feed_providers.dart` | Pagers read prefs lens on each fetch |
| `lib/features/profile/data/remote_public_creator_profile_repository.dart` | `catalogLens` on `fetchCreatorMonoPage` |
| `lib/features/profile/data/remote_creator_collections_repository.dart` | `catalogLens` on public list + detail |
| `lib/features/profile/presentation/providers/public_profile_monos_notifier.dart` | Pass lens from prefs |
| `lib/features/profile/public_profile_screen.dart` | Monos tab refresh on prefs change + lens on collections load |
| `lib/features/profile/public_creator_collection_detail_screen.dart` | Pass lens on public collection monos |
| `test/core/settings/catalog_discovery_lens_test.dart` | **New** |
| `test/features/mono/remote_mono_feed_repository_test.dart` | Lens query tests |
| `test/features/mono/remote_following_mono_feed_repository_test.dart` | Lens query test |
| `test/features/mono/mono_feed_pager_test.dart` | `catalogLens` on mock repo |
| `test/features/profile/public_profile_monos_prefs_refresh_test.dart` | **New** |
| `test/features/profile/remote_public_creator_profile_repository_test.dart` | Lens on writerId feed |

**Not modified:** Backend, search, saved/bookmarks, owner published/collections, collection add rule, publish/creator/reader UI, feed DTO/summary shape, Prisma/migrations.

---

## B. Flutter discovery refresh audit (before → after)

| Surface | Refreshed on `contentLocale` / `learningLanguage` change (before) | After M23A-6B |
|---------|---------------------------------------------------------------------|---------------|
| Home For You (`monoFeedPagerProvider`) | **Yes** (`user_preferences_notifier`) | **Yes** (unchanged) |
| Following (`followingMonoFeedPagerProvider`) | **Yes** | **Yes** (unchanged) |
| Public profile **Collections** | **Yes** (tab 1 reload or `setState`) | **Yes** (unchanged + explicit lens on fetch) |
| Public profile **Monos** | **No** (gap) | **Yes** — refresh when on Monos tab; deferred refresh when on other tab via `_publicMonosNeedsRefresh` |
| Search / Saved / Owner | N/A (out of scope) | Unchanged |

| Request path | Auth for lens | Explicit query params (after) |
|--------------|---------------|-------------------------------|
| `GET /v1/mono/feed` (For You) | Optional JWT | `contentLocale` + `learningLanguage` when authenticated |
| `GET /v1/mono/feed?following=true` | Required JWT | Same |
| `GET /v1/mono/feed?writerId=` | Optional JWT | Same |
| `GET /v1/users/:id/creator-collections` | Optional JWT | Same |
| `GET /v1/users/:id/creator-collections/:id/monos` | Optional JWT | Same |

Guest (no `Authorization` header): query params **omitted**; backend guest default `ja+en` unchanged.

---

## C. Public profile Monos fix

**Problem (M23A-6.0):** `ref.listen(userPreferencesNotifierProvider)` reset collections and called `setState` when not on Collections tab, but never refreshed `publicProfileMonosProvider`.

**Fix:**

1. On prefs change: set `_publicMonosNeedsRefresh = true` and `_publicCollectionsLoaded = false`.
2. If **Monos tab** (index 0): `publicProfileMonosProvider.refresh(_routeUserId)` immediately.
3. If **Collections tab** (index 1): `_loadPublicCollections(force: true)` (existing).
4. If user switches to **Monos** later: `_onPublicProfileTabTick` clears flag and refreshes monos once.

Profile header and owner tabs are not reloaded; only monos/collections data paths refresh.

---

## D. Explicit query param decision

**Implemented** (low risk):

- `CatalogDiscoveryLens.tryFromPreferences()` normalizes prefs via existing `normalizeContentLocaleWireCode` / `safeLearningLanguageWireCode` and skips invalid same-language pairs (`ja+ja`, `en+en`).
- `CatalogDiscoveryLens.mergeIntoQueryIfAuthenticated()` adds params only when `Authorization` is present — guests keep backend defaults; JWT prefs remain authoritative fallback.
- Pagers and public profile notifiers read **current** prefs on every fetch so query params stay aligned after settings change without extra wiring.

**Why not JWT-only:** Explicit params improve debuggability (visible in logs/Proxyman) and match M23A-6A backend override contract; backend still resolves prefs when params omitted.

---

## E. Tests added / updated

| Test file | What it covers |
|-----------|----------------|
| `catalog_discovery_lens_test.dart` | en+my lens, same-language null, guest skip, auth merge |
| `remote_mono_feed_repository_test.dart` | Lens in query with auth; omitted for guest |
| `remote_following_mono_feed_repository_test.dart` | Lens + `following=true` |
| `remote_public_creator_profile_repository_test.dart` | writerId feed + lens |
| `public_profile_monos_prefs_refresh_test.dart` | Notifier lens; widget prefs → monos refresh (content + learning) |
| `mono_feed_pager_test.dart` | Mock signature update |

Home/Following pager behavior unchanged (still refresh via `user_preferences_notifier`); no new pager-specific tests required beyond repository lens tests.

---

## F. Test commands and pass counts

From repo root:

```powershell
flutter test test/core/settings/catalog_discovery_lens_test.dart test/features/mono/remote_mono_feed_repository_test.dart test/features/mono/remote_following_mono_feed_repository_test.dart test/features/mono/mono_feed_pager_test.dart test/features/profile/public_profile_monos_prefs_refresh_test.dart test/features/profile/remote_public_creator_profile_repository_test.dart
```

**Result:** **31** tests passed, **0** failed.

---

## G. Unchanged surfaces

| Area | Status |
|------|--------|
| Backend (`nimon-backend/`) | **No files changed** |
| Search | Unchanged |
| Saved / bookmarks | Unchanged |
| Owner published / owner collections | Unchanged |
| Collection add rule | Unchanged |
| Feed DTO / `MonoFeedSummaryDto` | **Unchanged** (no `learningLanguage` on feed cards) |
| Creator / reader / publish validation | Unchanged |
| DB schema / migrations | None |

---

## H. Remaining M23A-6 work (M23A-6C+ / product)

1. **Search policy** — feed-aligned vs global catalog (M23A-6.0 Section I).
2. **Saved tab policy** — show all bookmarks vs current lens.
3. **Owner profile policy** — show all published vs lens + badges.
4. **Feed card UX (M23A-6C)** — optional `contentLocale` / `learningLanguage` on feed summary wire + UI badges.

---

## Final verification

| # | Requirement | Confirmed |
|---|-------------|-----------|
| 1 | No backend files changed | Yes |
| 2 | No search files changed | Yes |
| 3 | No saved/bookmark files changed | Yes |
| 4 | No owner published/collection behavior changed | Yes |
| 5 | No collection add rule changed | Yes |
| 6 | No schema/migration changed | Yes |
| 7 | No publish/creator/reader files changed | Yes |

---

## Success criteria

- [x] Public profile Monos refreshes on learning/content preference change
- [x] Home / Following refresh unchanged
- [x] Public collections consistent (reload + explicit lens)
- [x] Explicit catalog query params when authenticated
- [x] No backend / search / saved / owner changes
- [x] Tests: **31/31** passed

---

*M23A-6B complete.*
