# M11e Content Locale Feed Integration Report

## Scope

Integrate **Content Community** (`contentLocale`) and **Learning Language** (`learningLanguage`) into the Mono feed (`GET /v1/mono/feed`) with:

- Backend defaults from `UserPreference` for authenticated users
- Guest defaults (`contentLocale=en`, `learningLanguage=ja`)
- Query param overrides
- Flutter Settings → feed refresh (reload from first page)

Non-goals (per spec):

- No recommendation/ranking algorithm changes
- No App Language behavior changes
- No notifications implementation

## Current Schema Audit

### User preferences (already existed from M11b)

`UserPreference` already stores:

- `contentLocale String?`
- `learningLanguage String?`

### Published content used by feed (audit result)

Before M11e, `PublishedMono` had **no** usable fields for:

- `language`
- `targetLanguage`
- `learningLanguage`
- `locale`
- `contentLocale`
- `audience`
- `writerLocale`

Feed filtering therefore required adding **minimal columns**.

## Backend Preference Defaults

### PublishedMono columns added (minimal)

Added to `PublishedMono`:

- `contentLocale String @default("en")`
- `learningLanguage String @default("ja")`

Migration:

- `prisma/migrations/20260508210000_m11e_published_mono_locales/migration.sql`

Publish flow:

- `StoryDraftsService.publishReadOnly` and `.publishFullLearn` now stamp:
  - `contentLocale: 'en'`
  - `learningLanguage: 'ja'`

## Feed Query Params

`GET /v1/mono/feed` now supports:

- `contentLocale` in `{en,my,ja}`
- `learningLanguage` in `{ja}` (V1 constraint)

Resolution rules:

- **Guest**: defaults to `en` / `ja`
- **Authenticated + params absent**: uses stored `UserPreference` (falling back to defaults when null/missing)
- **Query params override**: always win over stored preferences
- Invalid params throw `400` (`contentLocale_invalid` / `learningLanguage_invalid`)

Filtering is applied via Prisma `where` on `PublishedMono`:

- `contentLocale == effectiveContentLocale`
- `learningLanguage == effectiveLearningLanguage`

## Flutter Settings Refresh Behavior

When `contentLocale` or `learningLanguage` is updated from Settings:

- `monoFeedPagerProvider.refresh()` is triggered
- `followingMonoFeedPagerProvider.refresh()` is triggered
- Both refresh paths reset cursor (`nextCursor: null`) and reload from first page (existing behavior of `refresh()`)

Backend remains the source of truth for defaults (Flutter does not add query params yet).

## Tests Added

### Backend

Updated `src/modules/mono-feed/mono-feed.service.spec.ts` to cover:

- Guest defaults applied (`en` / `ja`)
- Authenticated defaults from `UserPreference` when params are absent
- Query params override saved preferences
- Invalid query params rejected

### Flutter

Added `test/features/settings/user_preferences_notifier_feed_refresh_test.dart` to verify:

- `updateContentLocale()` triggers refresh on both feed pagers
- `updateLearningLanguage()` triggers refresh on both feed pagers

## Commands Run

Backend:

- `prisma generate`
- `jest src/modules/mono-feed --runInBand`
- `jest --runInBand`
- `nest build`

Flutter:

- `dart format` on touched files
- `flutter analyze` on touched paths
- `flutter test test/features/settings`
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification

- Change **Content Community** in Settings → Mono feed reloads from first page
- Change **Learning Language** in Settings → Mono feed reloads from first page

## Remaining Risks

- Publish flow currently stamps defaults (`en`/`ja`) unconditionally; when authoring supports multiple communities/languages, we should stamp from draft metadata or creator settings.
- `learningLanguage` allowlist is V1-only (`ja`). Expanding to more targets will require relaxing validation + ensuring content is tagged.

## Recommended Next Step

- Add community/language selectors to authoring/publish pipeline so new content can be tagged with non-default `contentLocale` / `learningLanguage` (still keeping feed filtering simple).

