# M23A-6D-3 — Discovery Surface Language Badges Report

**Phase:** M23A-6D-3 only (feed summary DTO + discovery UI)  
**Badge format:** `learningLanguage · contentLocale` via existing `LanguagePairBadge` (M23A-6D-2)  
**Date:** 2026-06-03

---

## A. Files changed

### Backend

| File | Change |
|------|--------|
| `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts` | Added nullable `contentLocale`, `learningLanguage` on `MonoFeedSummaryItemDto` |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` | `mapRowToSummary` passes locale fields from existing Prisma select |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | Locale on default summary test + M23A-6D-3 block (4 tests) |

### Flutter

| File | Change |
|------|--------|
| `lib/features/mono/data/mono_feed_summary_dto.dart` | Parse/store locale pair |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | `monoFeedItemFromMonoFeedSummary` maps locale pair |
| `lib/core/settings/language_pair_badge_labels.dart` | `languagePairBadgeVisibleOnDiscoverySurfaces` |
| `lib/features/mono/widgets/mono_feed_footer_locale_chips.dart` | `MonoFeedFooterLocaleChip` for feed footer |
| `lib/features/mono/mono_screen.dart` | `_PostFooterMeta` shows locale chip beside level/mode chip |
| `lib/features/profile/public_profile_screen.dart` | Remote Monos tab rows use `languagePair` badge |

### Tests

| File | Change |
|------|--------|
| `test/core/settings/language_pair_badge_labels_test.dart` | Discovery visibility helper |
| `test/features/mono/mono_feed_summary_dto_locale_test.dart` | DTO parsing |
| `test/features/mono/mono_feed_item_mapper_locale_test.dart` | Feed summary mapper |
| `test/features/mono/mono_feed_footer_locale_chip_test.dart` | Home/Following chip widget |
| `test/features/mono/remote_mono_feed_repository_test.dart` | Repo parses locale from JSON |
| `test/features/profile/public_profile_monos_locale_badge_test.dart` | Public profile row badge |
| `test/ui/widgets/community_badge_test.dart` | Regression |

---

## B. DTO changes

`MonoFeedSummaryItemDto` now includes:

```typescript
contentLocale: string | null;
learningLanguage: string | null;
```

- Nullable for legacy rows.
- No Prisma schema change — columns already selected in `MONO_FEED_LIST_PUBLISHED_MONO_SELECT`.
- Backward compatible: clients that ignore new fields continue to work.

---

## C. Feed mapping flow

```text
published_monos (select includes contentLocale, learningLanguage)
  → MonoFeedService.mapRowToSummary
  → MonoFeedSummaryItemDto (API JSON)
  → Flutter MonoFeedSummaryDto.fromJson
  → monoFeedItemFromMonoFeedSummary → MonoFeedItem
  → Home/Following _PostFooterMeta + MonoFeedFooterLocaleChip
```

Same DTO path for:

- `GET /v1/mono/feed` (Home / For You)
- Following feed (`followingOnly: true`)
- Public profile Monos (`writerId` filter)

**Unchanged:** `resolveCatalogLanguageContext`, `publishedMonoCatalogLocaleWhere`, query filters, SQL, ranking.

---

## D. Home badge behavior

- Footer chip row: existing `_MonoStatusChip` (`N5 · Read only`) + `MonoFeedFooterLocaleChip`.
- Example: `en+my` mono → `EN · MY`.
- Both locale dimensions legacy-unknown → chip hidden (no `—` on vertical feed cards).

---

## E. Following badge behavior

- Same `_ReadingFeedPost` / `_PostFooterMeta` path as Home.
- Locale data from the same summary DTO via `followingMonoFeedPagerProvider`.

---

## F. Public profile monos behavior

- Remote Monos tab `MonoStoryListRow` uses `MonoStoryListBadgeMode.languagePair`.
- Collections tab unchanged (`CommunityBadge` on collection cards only).

---

## G. Tests added

### Backend (`mono-feed.service.spec.ts`)

**M23A-6D-3 (4 tests):**

1. `listFeed` summary locale pair  
2. Following feed locale pair  
3. `writerId` feed locale pair  
4. Legacy null fields preserved  

Plus existing summary test now asserts `contentLocale` / `learningLanguage` on default `sampleRow`.

### Flutter

| File | Tests |
|------|-------|
| `language_pair_badge_labels_test.dart` | +1 visibility helper |
| `mono_feed_summary_dto_locale_test.dart` | 2 |
| `mono_feed_item_mapper_locale_test.dart` | +1 feed summary mapper |
| `mono_feed_footer_locale_chip_test.dart` | 2 |
| `remote_mono_feed_repository_test.dart` | locale assertions on envelope test |
| `public_profile_monos_locale_badge_test.dart` | 1 |
| `community_badge_test.dart` | 1 regression |

---

## H. Exact commands + pass counts

```powershell
cd nimon-backend
node .\node_modules\jest\bin\jest.js src/modules/mono-feed/mono-feed.service.spec.ts --no-cache
```

**Result:** **34 passed** (30 prior + 4 M23A-6D-3)

```powershell
cd nimon
flutter.bat test `
  test/core/settings/language_pair_badge_labels_test.dart `
  test/features/mono/mono_feed_summary_dto_locale_test.dart `
  test/features/mono/mono_feed_item_mapper_locale_test.dart `
  test/features/mono/mono_feed_footer_locale_chip_test.dart `
  test/features/mono/remote_mono_feed_repository_test.dart `
  test/features/profile/public_profile_monos_locale_badge_test.dart `
  test/ui/widgets/community_badge_test.dart
```

**Result:** **20 passed**

---

## I. Explicitly unchanged

| Area | Status |
|------|--------|
| Search (filtering + UI) | Unchanged |
| Saved | Unchanged |
| Owner Published / collection detail rows | Unchanged (M23A-6D-2) |
| Collection cards (`CommunityBadge`) | Unchanged |
| Feed filtering / catalog lens | Unchanged |
| Catalog discovery query params | Unchanged |
| Prisma schema / migrations | Unchanged |
| Publish / creator / reader UI | Unchanged |

---

## J. Remaining work

| Item | Notes |
|------|--------|
| Optional direct-detail discovery banner | Later |
| Optional global “All languages” search toggle | Later |
| English-learning QA sweep | Release prep |
| Release readiness audit | After M23A-6D complete |

M23A-6D discovery badge track is complete (6D-1 Search lens, 6D-2 Owner/Saved/Search badges, 6D-3 Feed/Public Monos).

---

## Success criteria checklist

- [x] Feed summary DTO exposes locale pair  
- [x] Home shows dual badge  
- [x] Following shows dual badge  
- [x] Public Profile Monos shows dual badge  
- [x] Collection cards unchanged  
- [x] Feed filtering unchanged  
- [x] Discovery lens unchanged  
- [x] No schema migration  
- [x] Tests pass  

---

## Final verification

1. **No search files changed** — confirmed.  
2. **No saved files changed** — confirmed.  
3. **No owner files changed** — confirmed.  
4. **No collection card files changed** — confirmed.  
5. **No catalog filtering files changed** — `published-mono-catalog-locale.ts` untouched.  
6. **No schema/migration changed** — confirmed.  
7. **No publish/creator/reader files changed** — confirmed.  
