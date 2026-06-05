# M23A-6C — Discovery Policy Lock Audit (Search / Saved / Owner / Feed Badges)

Date: 2026-06-03  
Role: Principal Architect — **investigation and product policy recommendation only**  
Prerequisites: M23A-6.0 audit, M23A-6A backend catalog, M23A-6B Flutter discovery refresh, M22F-1/M22F-2 owner/collection reports.

No code, tests, or migrations were changed.

---

## Executive summary

Core **discovery** surfaces (For You, Following, public profile Monos/Collections) now use the M23A-6A catalog lens (`learningLanguage` + `contentLocale`, with legacy null OR). Remaining ambiguity is **policy**, not plumbing:

| Surface | Current code behavior | Recommended V1 policy |
|---------|----------------------|------------------------|
| **Search** | Global catalog + keywords; **no** locale filter | **Feed-aligned** (same lens as For You) |
| **Saved** | All bookmarks; **no** locale filter; **community badge only** | **Show all** + **dual badges** (learn + community) |
| **Owner profile** | All owner content; **no** locale filter; **community badge only** | **Show all** + dual badges |
| **Public profile** | Viewer-lens filtered (M23A-6A/6B) | **Keep** (unchanged) |
| **Direct detail** | Catalog-visible only; **no** viewer lens | **Allow** direct open; optional banner later |
| **Home feed cards** | Summary DTO **omits** locale fields on wire; **no** badges | **Phase after DTO lock** — compact dual badges |

---

## Section A — Current behavior summary (from code)

### Search

| Layer | Behavior |
|-------|----------|
| **Endpoint** | `GET /v1/search/monos` (`SearchController`, `OptionalJwtUserGuard`) |
| **Backend filter** | `PUBLISHED_MONO_CATALOG_VISIBLE` + optional `level`, `category`, keyword tokens on title/description/writer profile. **Does not** call `resolveCatalogLanguageContext` or `publishedMonoCatalogLocaleWhere`. |
| **Backend response** | `PublishedMonoSearchListItemDto` extends `PublishedMonoListItemDto` — includes **`contentLocale`** and **`learningLanguage`** per row (`search.service.ts` selects columns; `publishedMonoListItemFromRow`). |
| **Flutter repo** | `RemoteMonoSearchRepository` — `q`, `level`, `category`, `sort`, `cursor`, `limit` only. **No** `contentLocale` / `learningLanguage` query params. **No** `CatalogDiscoveryLens`. |
| **Flutter state** | `MonoSearchNotifier` — debounced query/facets; **`refresh()`** exists but is **not** wired to `userPreferencesNotifier` prefs changes. |
| **Flutter UI** | `mono_search_screen.dart` — `MonoStoryListRow` **without** `showCommunityBadge` (locale data on `MonoSearchResult.listItem` is unused in UI). |

**Implication:** Viewer `ja+my` searching a title that only exists on an `en+my` mono can still see it in results (parity break vs For You).

---

### Saved

| Layer | Behavior |
|-------|----------|
| **Endpoint** | `GET /v1/me/bookmarks` (auth required) |
| **Backend filter** | `userId` + `publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE` only. **No** `contentLocale` / `learningLanguage` filter. |
| **Backend response** | Bookmark rows include mono `contentLocale`, `learningLanguage` (`mono-social.service.ts` select). |
| **Flutter** | `profile_saved_mono_pager` → `RemoteMonoSocialRepository`; maps **`contentLocale`** onto `MonoFeedItem`; **does not** map `learningLanguage`. |
| **Flutter UI** | `profile_saved_remote_tab.dart` — `showCommunityBadge: true` (M22F-1 **community-only** `CommunityBadge`). |
| **Prefs refresh** | Saved pager **not** refreshed when learning/community prefs change (unlike For You / Following). |

---

### Owner Published

| Layer | Behavior |
|-------|----------|
| **Endpoint** | `GET /v1/published-monos` (owner JWT) |
| **Backend filter** | `ownerId` + catalog visibility (or trash). **No** viewer lens. |
| **Backend response** | List items include `contentLocale`, `learningLanguage` (M22F-1). |
| **Flutter UI** | `profile_screen.dart` Published → Monos — `MonoStoryListRow` with `showCommunityBadge: true` when `isBackendPublished`. **Community badge only.** |

---

### Owner Collections

| Layer | Behavior |
|-------|----------|
| **List** | `GET /v1/me/creator-collections` — `listMine`; item counts use **`PUBLISHED_MONO_CATALOG_VISIBLE` only** (not viewer lens). |
| **Detail** | `GET /v1/me/creator-collections/:id/monos` — all visible monos in collection; **no** locale filter. |
| **Flutter UI** | Collection cards: `CommunityBadge` on collection `contentLocale` (community only). Detail rows: `showCommunityBadge: true` on mono rows. |
| **Add rule** | `assertCollectionContentLocaleCompatible` — **contentLocale only** (M22F-2); `learningLanguage` not checked. |

**Public vs owner count mismatch:** Public profile collection counts use viewer lens; owner `listMine` counts do not — documented in M23A-6.0; still true.

---

### Feed cards (Home For You / Following / public profile Monos list)

| Layer | Behavior |
|-------|----------|
| **Backend list** | `MonoFeedService.listFeed` — Prisma select includes `contentLocale`, `learningLanguage` (`MONO_FEED_LIST_PUBLISHED_MONO_SELECT`). |
| **Backend DTO** | `MonoFeedSummaryItemDto` — **does not** include `contentLocale` or `learningLanguage` (`mono-feed.dto.ts`). `mapRowToSummary` drops them. |
| **Flutter DTO** | `MonoFeedSummaryDto` — no locale fields. |
| **Flutter model** | `MonoFeedItem` — has optional `contentLocale` but **`monoFeedItemFromMonoFeedSummary` does not set it** (always null on home reels). No `learningLanguage` field on `MonoFeedItem`. |
| **Flutter UI** | Reels/cards on `mono_screen.dart` — **no** `CommunityBadge` / learning badge on catalog feed cards. |

Public profile Monos tab uses the same feed summary path → same omission on cards.

---

### Direct detail

| Layer | Behavior |
|-------|----------|
| **Endpoint** | `GET /v1/mono/:id` (`MonoFeedService.getPublicMonoById`) |
| **Backend filter** | `id` + `PUBLISHED_MONO_CATALOG_VISIBLE` only. **No** `publishedMonoCatalogLocaleWhere`. |
| **Backend response** | `publishedMonoDetailFromRow` — `learningLanguage` / `contentLocale` from row + content root (detail select uses full `content`; denormalized columns on list endpoints are richer). |
| **Flutter** | `RemoteMonoFeedRepository.fetchMonoDetail` parses both fields; reader uses `learningLanguage` for ruby suppression (M23A-5B). |
| **Access** | Deep link / share / saved open can load mono **even when** absent from current For You lens. |

---

## Section B — Search policy options

### Option 1 — Search follows feed lens (recommended V1)

Apply `resolveCatalogLanguageContext` + `publishedMonoCatalogLocaleWhere` to search `where` (same as `MonoFeedService.listFeed`).

| | |
|--|--|
| **UX pros** | No “found in search but missing from Home” surprises; matches mental model of “my learning feed”. |
| **UX cons** | User cannot discover other-language monos via search without a future “all languages” mode. |
| **Backend complexity** | **Low** — reuse existing catalog helper; add query params on `SearchController` (mirror feed). |
| **Flutter complexity** | **Low** — pass `CatalogDiscoveryLens` on `RemoteMonoSearchRepository` (same as M23A-6B feed); optional prefs-driven `refresh()` on search screen. |
| **Risk** | Medium — users who relied on global search lose cross-lens discovery until Option 3. |

### Option 2 — Search is global

Keep current `SearchService` (visibility + keywords only).

| | |
|--|--|
| **UX pros** | Maximum discoverability; good for power users and admins. |
| **UX cons** | **Contradicts For You**; confuses English-learning users who see `en+my` in search but not Home. |
| **Backend complexity** | None. |
| **Flutter complexity** | None for filter; still should show **badges** on rows (data already present). |
| **Risk** | **High** product inconsistency post M23A-6A. |

### Option 3 — Default lens + optional “all languages” filter

Feed-aligned default; toggle or chip for global search.

| | |
|--|--|
| **UX pros** | Best long-term; satisfies both consistency and exploration. |
| **UX cons** | More UI and test surface; needs copy and empty states. |
| **Backend complexity** | **Medium** — explicit `scope=lens|global` query or omit locale filter when flag set. |
| **Flutter complexity** | **Medium** — filter chip + state on `MonoSearchNotifier`. |
| **Risk** | Scope creep for V1. |

### Recommendation

**V1: Option 1 (feed-aligned).** Defer Option 3 to M23A-6E or later. Option 2 is not acceptable as default after English discovery shipped.

---

## Section C — Saved policy options

### Option 1 — Saved shows all (recommended V1)

Keep `listMyBookmarks` without locale filter.

| | |
|--|--|
| **UX pros** | Saved = personal library; bookmarking is intentional cross-lens memory. |
| **UX cons** | List may include monos user cannot re-find in Home (mitigate with badges). |
| **Backend** | None. |
| **Flutter** | Map `learningLanguage` to `MonoFeedItem`; show **dual badges**; no prefs-based hide. |

### Option 2 — Saved follows current lens

Filter bookmarks by catalog lens in SQL.

| | |
|--|--|
| **UX pros** | Matches For You. |
| **UX cons** | **Bookmarks “disappear”** when user changes Settings — high support burden. |
| **Backend** | Low — join filter on published mono. |
| **Flutter** | Refresh saved on prefs change. |

### Option 3 — Default lens + “All saved” tab

| | |
|--|--|
| **UX pros** | Compromise. |
| **UX cons** | Two tabs, more design work. |
| **Complexity** | Medium. |

### Recommendation

**V1: Option 1 (show all)** with **community + learning badges** on each row. Do **not** filter saved by lens. Optionally refresh saved list on prefs change is **not required** for V1 (content unchanged); badge labels still help orientation.

---

## Section D — Owner profile policy options

### Option 1 — Owner sees all with badges (recommended V1)

Keep owner list endpoints unfiltered; extend badges to show learning + community.

| | |
|--|--|
| **UX pros** | Creator management surface — owner must see every published mono and draft regardless of current learning Settings. |
| **UX cons** | Long lists without lens filter (acceptable for owner). |
| **Backend** | None for filter. |
| **Flutter** | Extend badge widget or add second chip for `learningLanguage`. |

### Option 2 — Owner follows current lens

| | |
|--|--|
| **UX pros** | Mirrors discovery. |
| **UX cons** | Owner thinks content was **deleted** when switching from English to Japanese learning. **Unacceptable** for publish workflow. |
| **Risk** | **Critical** for creators. |

### Option 3 — Default lens + “All” filter on Published tab

| | |
|--|--|
| **UX pros** | Optional focus mode. |
| **UX cons** | Extra UI; owner still needs “All” as default for management. |

### Recommendation

**V1: Option 1.** Owner Published, Workspace, Saved (own), and owner collection detail remain **unfiltered**. Improve **badges** only. Do not hide owner content by Settings lens.

**Note:** Public profile of that owner remains viewer-lens filtered (already correct) — owner vs visitor asymmetry is intentional.

---

## Section E — Feed card badge policy

### Does feed DTO have locale fields today?

| Location | `contentLocale` | `learningLanguage` |
|----------|-----------------|-------------------|
| DB / Prisma select (`MONO_FEED_LIST_PUBLISHED_MONO_SELECT`) | Selected | Selected |
| `MonoFeedSummaryItemDto` (backend wire) | **No** | **No** |
| `MonoFeedSummaryDto` (Flutter) | **No** | **No** |
| `MonoFeedItem` (Flutter) | Field exists; **null** from feed mapper | **No field** |

Search/owner/bookmark **list** DTOs already expose both fields; only **feed summary** path strips them.

### Changes needed for feed card badges

**Backend (required for home/for you/public monos tab cards):**

1. Add `contentLocale?: string | null` and `learningLanguage?: string | null` to `MonoFeedSummaryItemDto`.
2. Map from row in `mapRowToSummary` (values already loaded in query).
3. Update API contract doc / optional OpenAPI if maintained.

**Flutter:**

1. Parse fields on `MonoFeedSummaryDto.fromJson`.
2. Add `learningLanguage?` to `MonoFeedItem` (or carry via parallel map — prefer single model).
3. Set both in `monoFeedItemFromMonoFeedSummary`.
4. UI: extend `CommunityBadge` or add `LanguagePairBadge` showing compact **`EN · MY`** (learning · community) per product examples.

### Existing UI components

| Component | Shows today |
|-----------|-------------|
| `CommunityBadge` | **Community only** (`MY` / `EN` / `JA` / `—`) — M22F-1 explicitly excludes learning |
| `MonoStoryListRow` | Optional `showCommunityBadge` + `contentLocale` |
| `content_community.dart` | Short labels for community wire codes |

No existing widget shows **learning** target on list rows.

### V1 badge recommendation

| Surface | V1 badge |
|---------|----------|
| **Home / Following reels** | **Defer** until feed DTO ships — avoid N+1 detail fetches |
| **Search results** | **Dual chip** `EN · MY` (data already on list DTO) — can ship without feed DTO change |
| **Saved** | Dual chip (requires mapping `learningLanguage` on bookmark → `MonoFeedItem`) |
| **Owner Published / collection detail** | Dual chip (API already has fields) |
| **Public profile Monos** | Dual chip **after** feed summary DTO exposes fields **or** hydrate from writer feed if DTO updated |

**Community-only badge is insufficient** for English Learning V1 — users cannot distinguish `ja+my` vs `en+my` with community-only `MY`.

**Recommended compact format:** `{learning} · {community}` e.g. `EN · MY`, `JA · EN`, with semantics tooltips. Legacy null → `— · —` or single `—`.

---

## Section F — Direct detail policy

### Should `GET /v1/mono/:id` stay unfiltered by viewer lens?

**Recommendation: Yes.**

| Reason | Detail |
|--------|--------|
| **Share links** | URLs must work for recipients regardless of lens. |
| **Saved / notifications** | User may open bookmarked mono outside current lens. |
| **Owner/creator** | Creator preview of own mono must not 404 by visitor lens rules. |
| **Already implemented** | Only `PUBLISHED_MONO_CATALOG_VISIBLE` gate. |

### Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| User opens `en+my` mono while on `ja+my` Settings | Low | Expected; reader already respects `learningLanguage` (M23A-5B) |
| User expects mono to appear in Home after detail open | Medium | Optional **non-blocking** banner: “Outside your current learning feed” (Flutter-only, M23A-6E) |
| SEO/guest access | Low | Guest detail works; lens is discovery-only |

**Do not** add catalog locale filter to detail endpoint in V1.

---

## Section G — Recommended M23A-6D implementation phases

Execute in order to minimize parity regressions and avoid double work on DTOs.

### Phase 6D-1 — Search feed-lens parity (highest product risk)

- Backend: `SearchService` + `SearchController` — catalog helper + optional query params.
- Flutter: `CatalogDiscoveryLens` on `RemoteMonoSearchRepository`; prefs `refresh` on search when returning to screen (optional).
- Tests: backend search matrix; Flutter repo query tests.

**Outcome:** Search matches For You for `en+my` / `ja+my` viewers.

---

### Phase 6D-2 — Dual badges on list surfaces that already have locale DTOs

- New `LanguagePairBadge` (or extend `CommunityBadge`) — learning + community.
- Flutter: Search rows, Saved rows, Owner Published, owner collection detail.
- Map `learningLanguage` on bookmarks → `MonoFeedItem`.

**Outcome:** Orientation without feed contract change.

---

### Phase 6D-3 — Feed summary DTO + Home/Following/public Monos cards

- Backend: `MonoFeedSummaryItemDto` + `mapRowToSummary`.
- Flutter: `MonoFeedSummaryDto`, `MonoFeedItem`, `monoFeedItemFromMonoFeedSummary`, reels chip row.

**Outcome:** Home cards show `EN · MY` consistently.

---

### Phase 6D-4 — Polish (optional / M23A-6E)

- Direct-detail “outside your feed” banner (compare mono locales to `CatalogDiscoveryLens.tryFromPreferences`).
- Search “All languages” toggle (Option 3).
- Saved prefs refresh (nice-to-have, not required if showing all).
- Owner Published “filter by lens” chip (Option 3) — **not** default.

---

## Section H — File list (by phase)

### Phase 6D-1 — Search

| Area | Files |
|------|--------|
| Backend | `nimon-backend/src/modules/search/search.service.ts`, `search.controller.ts`, `search.service.spec.ts` |
| Flutter | `lib/features/search/data/remote_mono_search_repository.dart`, `lib/features/search/presentation/mono_search_notifier.dart` (optional prefs listen), `lib/features/mono/mono_search_screen.dart` |
| Tests | `test/features/search/*`, backend search specs |

### Phase 6D-2 — Badges (non-feed DTO)

| Area | Files |
|------|--------|
| Flutter UI | `lib/ui/widgets/community_badge.dart` or new `language_pair_badge.dart`, `lib/features/profile/mono_story_list_row.dart`, `lib/features/mono/mono_search_screen.dart`, `lib/features/profile/presentation/profile_saved_remote_tab.dart`, `lib/features/profile/profile_screen.dart`, `lib/features/profile/owner_creator_collection_detail_screen.dart` |
| Flutter data | `lib/features/mono/mono_feed_models.dart`, `lib/features/mono/data/remote_mono_social_repository.dart` |
| Tests | `test/ui/widgets/*`, `test/features/profile/*_badge*` |

### Phase 6D-3 — Feed DTO

| Area | Files |
|------|--------|
| Backend | `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts`, `mono-feed.service.ts`, `mono-feed.service.spec.ts` |
| Flutter | `lib/features/mono/data/mono_feed_summary_dto.dart`, `mono_feed_item_mapper.dart`, `lib/features/mono/mono_screen.dart` (reels metadata) |
| Contract | `docs/NIMON_API_QUERY_CONTRACT.md` (if updated for summaries) |

### Unchanged in 6D-1..3 (unless explicitly scoped)

- `published-mono-catalog-locale.ts` (already done in 6A)
- Collection add rule (`collection-content-locale.ts`)
- Owner list **filtering** (`published-monos.service.ts` stays unfiltered)
- Bookmarks **filtering** (`mono-social.service.ts` stays unfiltered)
- Reader / creator / publish validation

---

## Section I — Risk matrix

| Risk | Severity | Notes |
|------|----------|-------|
| Saved items hidden when user changes Settings | **Critical** if Option 2 chosen | Avoid — use show-all |
| Search shows monos absent from For You | **High** today | Fix in 6D-1 |
| Owner cannot find own `en+my` publish in Published tab | **Critical** if owner lens filter | Avoid — show-all owner |
| Badge clutter on small rows | **Medium** | Use compact `EN · MY`; limit to one chip |
| Backend/frontend DTO mismatch on feed | **Medium** | Lock DTO in 6D-3 before UI |
| Public profile count vs owner count mismatch | **Medium** | Known; document in owner UI copy later |
| `learningLanguage` confused with UI locale | **Low** | Tooltips: “Learning” vs “Community” |
| Direct detail vs feed inconsistency | **Low** | Accept; optional banner later |
| Legacy null rows show `—` badges | **Low** | Same as M22F-1 legacy community rule |

---

## Section J — Final V1 policy (locked recommendation)

| Surface | V1 policy | Rationale |
|---------|-----------|-----------|
| **Search** | **Feed-aligned** — `viewer.learningLanguage` + `viewer.contentLocale` (+ legacy null OR). No global default. | Eliminates search vs Home contradiction. |
| **Saved** | **Show all** saved bookmarks. **Dual badges** (learning + community). No lens filter. | Saved is memory, not discovery. |
| **Owner profile** | **Show all** published, drafts, collection monos. **Dual badges**. No lens filter. | Creator management; Settings must not hide own work. |
| **Public profile** | **Keep** viewer-lens filtered (current). | Discovery for visitors. |
| **Direct detail** | **Remain allowed** for any catalog-visible mono; **no** viewer-lens filter on `GET /v1/mono/:id`. Optional informational banner later. | Share/saved/deep links. |
| **Feed cards (Home/Following)** | **After DTO lock:** show **dual badges** on summary cards. Until then, no fake badges without data. | Requires `MonoFeedSummaryItemDto` change (6D-3). |

### Explicit non-goals for V1 (defer)

- Search “All languages” toggle.
- Saved “All / Current lens” tabs.
- Owner Published lens filter.
- Collection add rule changes (stay **contentLocale-only** per M22F-2).
- Filtering bookmarks or owner lists by learning language.

---

## Alignment with proposed defaults (evaluation)

The mission’s default recommendations are **accepted** with one sequencing note: **feed card badges depend on DTO work** — implement Search parity and owner/saved/search row badges first (data already on list DTOs), then feed summary DTO for Home.

---

## References

| Doc | Use |
|-----|-----|
| `docs/M23A60_LEARNING_LANGUAGE_DISCOVERY_AUDIT.md` | Pre-6A/6B gap analysis |
| `docs/M23A6A_BACKEND_CATALOG_ENGLISH_DISCOVERY_REPORT.md` | Catalog helper behavior |
| `docs/M23A6B_FLUTTER_DISCOVERY_REFRESH_REPORT.md` | Refresh + query params on discovery |
| `docs/M22F1_OWNER_MONO_COMMUNITY_FLAGS_REPORT.md` | Owner community-only badges |
| `docs/M22F2_COLLECTION_COMMUNITY_AND_ADD_RULE_REPORT.md` | Collection contentLocale-only add rule |

---

## Success criteria

- [x] Sections A–J complete
- [x] Current behavior from code (not assumptions)
- [x] Clear V1 recommendations for Search, Saved, Owner, Direct detail, Feed badges
- [x] M23A-6D phase plan and file list
- [x] No code, tests, or migrations

---

*M23A-6C investigation complete.*
