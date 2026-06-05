# M23A-6D-2 — Dual Language Badges Report

**Phase:** M23A-6D-2 only (display-only)  
**Format:** `learningLanguage · contentLocale` (e.g. `EN · MY`, `JA · EN`)  
**Date:** 2026-06-03

---

## A. Files changed

### New

| File | Purpose |
|------|---------|
| `lib/core/settings/language_pair_badge_labels.dart` | Short labels + semantics for dual badge |
| `lib/ui/widgets/language_pair_badge.dart` | `LanguagePairBadge` chip widget |
| `test/core/settings/language_pair_badge_labels_test.dart` | Label unit tests |
| `test/ui/widgets/language_pair_badge_test.dart` | Widget tests |
| `test/features/profile/mono_story_list_row_badge_test.dart` | Row badge mode tests |
| `test/features/mono/remote_mono_social_bookmark_locale_test.dart` | Saved API → `MonoFeedItem` mapping |
| `test/features/mono/mono_feed_item_mapper_locale_test.dart` | Search mapper locale pair |

### Updated

| File | Change |
|------|--------|
| `lib/features/profile/mono_story_list_row.dart` | `MonoStoryListBadgeMode` + `LanguagePairBadge` in chip row |
| `lib/features/mono/mono_feed_models.dart` | `learningLanguage` on `MonoFeedItem` |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | Map `learningLanguage` from list/detail DTOs |
| `lib/features/mono/data/remote_mono_social_repository.dart` | Parse `learningLanguage` on bookmarks |
| `lib/features/mono/mono_search_screen.dart` | Dual badge on search rows |
| `lib/features/profile/presentation/profile_saved_remote_tab.dart` | Dual badge on Saved rows |
| `lib/features/profile/profile_screen.dart` | `_OneShortItem.learningLanguage`; Owner Published dual badge |
| `lib/features/profile/owner_creator_collection_detail_screen.dart` | Dual badge on collection mono rows |

**Not changed:** `nimon-backend/**`, feed summary DTO, Home/Following UI, public profile Monos rows, collection list cards (`CollectionListRow` + `CommunityBadge`).

---

## B. Badge design

**Widget:** `LanguagePairBadge(learningLanguage:, contentLocale:)`

**Display rules** (`language_pair_badge_labels.dart`):

| Input | Chip text |
|-------|-----------|
| `en` + `my` | `EN · MY` |
| `ja` + `en` | `JA · EN` |
| `null` + `my` | `— · MY` |
| `en` + `null` | `EN · —` |
| both null | `—` |

- Compact chip styling aligned with `CommunityBadge` (no flag emoji).
- Full legacy neutral style when both dimensions unset (`—` only).
- Semantics: separate learning vs community phrases (e.g. “Learning language English. Community language Myanmar.”).

**Row API:** `MonoStoryListBadgeMode` — `none` | `community` | `languagePair`. Legacy `showCommunityBadge: true` still maps to `community` when `badgeMode` is `none`.

---

## C. Data mapping changes

| Surface | Before | After |
|---------|--------|-------|
| Search | DTO had both fields; row showed no locale chip | `r.listItem` → dual badge |
| Saved bookmarks | Only `contentLocale` on `MonoFeedItem` | + `learningLanguage` from API JSON |
| Owner Published | `_OneShortItem` had `contentLocale` only | + `learningLanguage` from `PublishedMonoListItemDto` |
| Owner collection detail | `MonoFeedItem` via list DTO mapper | `learningLanguage` already on DTO; row uses dual badge |
| Detail merge | — | `monoFeedItemMergePublishedDetail` preserves locale pair |

No backend or DTO schema changes.

---

## D. Search badge behavior

- Search filtering unchanged (M23A-6D-1 lens intact).
- Each result row: `MonoStoryListBadgeMode.languagePair` with `listItem.learningLanguage` + `listItem.contentLocale`.
- Example: `en+my` mono → `EN · MY`.

---

## E. Saved badge behavior

- Saved list still loads all bookmarks (no prefs-based filter/refresh).
- `GET /v1/me/bookmarks` response: both fields parsed into `MonoFeedItem`.
- Rows use dual badge instead of community-only `MY`/`EN`/`JA`.

---

## F. Owner badge behavior

| UI | Badge |
|----|-------|
| Owner Published > Monos | `languagePair` when `isBackendPublished` |
| Owner collection detail mono rows | `languagePair` |
| Owner collection **cards** (list) | Unchanged `CommunityBadge` (`MY` / `EN` / `MIX`) — collection has only `contentLocale` |

Owner APIs and filters unchanged (show all published).

---

## G. Tests added

| Test file | Cases |
|-----------|-------|
| `language_pair_badge_labels_test.dart` | EN·MY, JA·EN, null fallbacks |
| `language_pair_badge_test.dart` | Widget EN·MY, JA·EN, legacy — |
| `mono_story_list_row_badge_test.dart` | languagePair vs community modes |
| `remote_mono_social_bookmark_locale_test.dart` | Saved maps `learningLanguage` |
| `mono_feed_item_mapper_locale_test.dart` | Search mapper carries pair |
| `community_badge_test.dart` | Regression (unchanged) |

---

## H. Exact test commands and pass counts

```powershell
cd nimon
flutter.bat test `
  test/core/settings/language_pair_badge_labels_test.dart `
  test/ui/widgets/language_pair_badge_test.dart `
  test/features/profile/mono_story_list_row_badge_test.dart `
  test/features/mono/remote_mono_social_bookmark_locale_test.dart `
  test/features/mono/mono_feed_item_mapper_locale_test.dart `
  test/ui/widgets/community_badge_test.dart
```

**Result:** **11 passed** (3 + 3 + 2 + 1 + 1 + 1)

No backend tests (none required).

---

## I. Explicitly unchanged behavior

| Area | Status |
|------|--------|
| Search filtering (catalog lens) | Unchanged |
| Saved filtering | Unchanged (all saved items) |
| Owner filtering | Unchanged |
| Feed summary DTO | Unchanged |
| Home / Following feed cards | Unchanged |
| Public profile Monos tab rows | Unchanged |
| Backend APIs / DTOs | Unchanged |
| Prisma schema / migrations | Unchanged |
| Collection add rule | Unchanged |
| Publish / creator / reader UI | Unchanged |

---

## J. Remaining M23A-6D work

| Item | Phase |
|------|--------|
| Feed summary DTO + `contentLocale` / `learningLanguage` on summary items | M23A-6D-3 |
| Home / Following / Public Profile Monos dual badges | M23A-6D-3 |
| Optional direct-detail discovery banner | Later |
| Optional global “All languages” search toggle | Later |

---

## Success criteria checklist

- [x] Search rows show dual language badge  
- [x] Saved rows show dual language badge  
- [x] Owner Published rows show dual language badge  
- [x] Owner collection detail rows show dual language badge  
- [x] Collection cards keep community badge  
- [x] Saved unfiltered  
- [x] Owner unfiltered  
- [x] Search filtering unchanged  
- [x] Feed DTO unchanged  
- [x] Home/Following cards unchanged  
- [x] No backend code changed  
- [x] Tests pass (11)  

---

## Final verification

1. **No backend files changed** — confirmed (Flutter-only diff).  
2. **No feed DTO files changed** — `MonoFeedSummaryDto` untouched.  
3. **No Home/Following feed UI changed** — no edits to feed card builders.  
4. **No Saved filtering changed** — bookmark query unchanged.  
5. **No Owner filtering changed** — published/collection APIs unchanged.  
6. **No collection add rule changed** — `add_to_collection_locale_policy` untouched.  
7. **No schema/migration changed** — none.  
