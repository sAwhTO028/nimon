# M22F-2 — Collection Community Metadata and Same-Community Add Rule

**Phase:** Implementation complete.  
**Prior:** [M22F0 audit](./M22F0_LANGUAGE_FLAGS_AND_COLLECTION_COMMUNITY_AUDIT.md), [M22F-1 owner mono flags](./M22F1_OWNER_MONO_COMMUNITY_FLAGS_REPORT.md)

---

## A. Product rule locked

| Rule | Behavior |
|------|----------|
| Collection `contentLocale` | Optional community tag on `creator_mono_collections` (`en` \| `my` \| `ja`) |
| `null` collection locale | **Legacy / mixed / unset** — no add restriction (M22F-2) |
| New collections | Receive `contentLocale` at create (explicit body or **UserPreference** default, else `en`) |
| Non-null collection | Only published monos with **matching** `contentLocale` may be added |
| Mismatch | HTTP **400** `content_locale_mismatch` (bulk includes `publishedMonoIds` when applicable) |
| Bulk add | **Fails entire request** before transaction if any eligible mono mismatches |
| Learning language | **Not** enforced on collection add in V1 |
| Owner lists | Still **unfiltered** (all collections / monos) |
| Public M22E | Filtering **unchanged**; DTO may include `contentLocale` as data only |

---

## B. DB migration and backfill

**Migration:** `prisma/migrations/20260604120000_m22f2_collection_content_locale/migration.sql`

- Adds nullable `contentLocale` to `creator_mono_collections`.
- **Backfill (SQL):** For each collection, if every catalog-visible item (`trashedAt IS NULL`) shares one **non-null** `published_monos.contentLocale`, sets collection to that value.
- Empty collections, mixed locales, or all-null items → remain `null`.

**Prisma:** `CreatorMonoCollection.contentLocale String?`

---

## C. Backend DTO/API changes

| API | Change |
|-----|--------|
| `GET /v1/me/creator-collections` | `CreatorMonoCollectionDto.contentLocale` |
| `GET /v1/users/:id/public/creator-collections` | Same field (no filter change) |
| `POST /v1/me/creator-collections` | Optional `contentLocale` in body; server resolves default from prefs |
| `PATCH` collection | **No** `contentLocale` edit in this phase |
| `POST .../items` / `.../items/bulk` | Locale validation when collection locale set |

**Helper:** `collection-content-locale.ts` — normalize, resolve create default, `assertCollectionContentLocaleCompatible`, `assertBulkCollectionContentLocaleCompatible`.

---

## D. Add-to-collection validation

**Backend (authoritative):**

1. Load collection `contentLocale`.
2. Load mono `contentLocale` (owner-scoped).
3. If collection locale **not null** and mono locale ≠ collection → `BadRequestException({ message: 'content_locale_mismatch', ... })`.
4. Bulk: validate all owned eligible IDs first; fail whole batch on any mismatch.

**Flutter (UX):**

- `add_to_collection_locale_policy.dart` — mixed selection block, per-collection disable with “Different community”.
- Sheet blocks opening when selected monos span multiple known communities.
- Legacy (`contentLocale == null`) collections remain selectable for any mono.
- Repository maps `content_locale_mismatch` → friendly `StateError`.

---

## E. Flutter UI changes

| Surface | Change |
|---------|--------|
| `CollectionListRow` | Optional `showCommunityBadge` + `contentLocale`; owner Published > Collections enables badge (`legacyAsMixed: true` → **MIX** when null) |
| `CommunityBadge` | `legacyAsMixed` flag for collection cards |
| Add-to-collection sheet | Collection rows show badge + disabled state + reason |
| Create collection | Sends default locale from `userPreferencesNotifier` (silent, no picker) |
| Owner collection detail | Collection-level badge above description |
| Public profile | **No** `showCommunityBadge` on collection rows (default false) |

**Labels:** `contentCommunityCollectionBadgeShortLabel` — `MY`/`EN`/`JA` or **`MIX`** for legacy collections.

---

## F. Legacy / mixed collection behavior

- Pre-migration and backfill-skipped collections keep `contentLocale = null`.
- UI shows **MIX** badge with semantics “Legacy or mixed community”.
- Add/move still allowed across communities (same as pre-M22F-2).
- New collections created after deploy get a concrete locale and enforce matching adds.

---

## G. Tests run

### Backend

```text
jest creator-collections.service.spec collection-content-locale.spec
Test Suites: 2 passed
Tests:       38 passed
```

Covers: create defaults, explicit locale, listMine DTO, add/bulk mismatch, legacy null allows add, helper unit tests.

### Flutter

```text
flutter test \
  test/features/profile/add_to_collection_locale_policy_test.dart \
  test/features/profile/creator_mono_collection_locale_test.dart \
  test/core/settings/content_community_collection_badge_test.dart \
  test/ui/widgets/community_badge_test.dart
All tests passed (7).
```

---

## H. Manual verification

1. Set Content community = **Myanmar** in Settings.
2. Create new collection → card shows **MY** (after refresh).
3. Add **MY** published mono → success.
4. Try **EN** mono → picker shows “Different community” / backend `content_locale_mismatch` if forced.
5. Legacy collection (pre-backfill or empty/mixed) → **MIX** badge; mixed adds still work.
6. Own Profile → Published → Collections shows community badges.
7. Public profile collections still filter by viewer locale (M22E); no new public badges.
8. Old mixed collections load without crash.

---

## I. Remaining follow-ups

- Collection **edit** / change `contentLocale` after create (with item compatibility checks).
- Explicit community **picker** on create collection UI.
- Auto-stamp legacy collection locale when last foreign mono removed.
- Admin/report for mixed collections to migrate manually.
- Optional: show collection badge on public profile (lighter styling).

---

## Key files

**Backend:** `schema.prisma`, migration `20260604120000_m22f2_collection_content_locale`, `creator-collections.dto.ts`, `creator-collections.service.ts`, `collection-content-locale.ts`, specs.

**Flutter:** `creator_mono_collection.dart`, `remote_creator_collections_repository.dart`, `my_creator_collections_notifier.dart`, `public_profile_widgets.dart`, `add_to_collection_sheet.dart`, `add_to_collection_locale_policy.dart`, `profile_screen.dart`, `owner_creator_collection_detail_screen.dart`, `content_community.dart`, `community_badge.dart`, tests.
