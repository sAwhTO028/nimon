# M11 Settings Foundation Decision Spec

## Goals

We need a **Settings foundation** for Nimon V1/V1.5 so that core user preferences (language, community/content region, learning target, theme, account actions) have a **single source of truth** and behave consistently across:

- Mono feed/reels pagination + prefetch behavior
- Feed filtering defaults (guest vs authenticated)
- Cross-surface identity and preference propagation
- Multi-device consistency (where applicable)

This decision spec defines the **product rules** and a minimal technical model so implementation can proceed in small milestones without rewriting preference plumbing later.

## Non-goals

Deferred from M11 / V1:

- Push notifications implementation (tokens, triggers, delivery, deep links)
- Change password
- Change email
- Phone verification / OTP flows
- Privacy settings
- Blocked users
- Advanced feed personalization (ranking, interests, topic training)
- Completing translation coverage for every string if not ready for V1

## Mono Reels Pagination Decision

### Decision

Mono Reels (feed/reels) pagination will use **cursor-based pagination** with proactive prefetch:

- **Initial page size**: 7 items
- **Next page size**: 10 items
- **Prefetch threshold**: when **remaining <= 3** items in the current list
- **Do not wait** until the final item to request more
- **Do not refresh the whole feed on swipe**
- **Deduplicate** by `monoId` when merging pages

Refresh behavior:

- **No refresh on every swipe**
- **Refresh only** on:
  - Pull-to-refresh
  - Filter change
  - Settings change (content locale / learning language that impacts feed defaults)
  - Profile identity update (author identity propagation fix cases)

### Recommended state shape

`MonoFeedPagerState`:

- `items` (List)
- `nextCursor` (String?)
- `isInitialLoading` (bool)
- `isLoadingMore` (bool)
- `hasMore` (bool)
- `error` (Object/String?)
- `activeFilters` (shape used by feed, e.g. sort/category/level/following/contentLocale/learningLanguage)

### Recommended method shape

- `loadInitial()`
- `loadMore()`
- `refresh()`
- `maybePrefetch(currentIndex)`

Notes:

- `maybePrefetch` should be called on **index change** and trigger `loadMore()` when `hasMore && !isLoadingMore` and `remaining <= 3`.
- Prefer “merge new page → dedupe by monoId → append” to avoid duplicates when cursor pages overlap or when the backend returns repeated items.

## Language Model Decision

Settings must cleanly separate three different concepts.

### 1) App Language (UI Language)

Purpose:

- Controls **UI strings** (Flutter localizations via `.arb`).

Values:

- `system` (null / follow OS)
- `en`
- `ja`
- `my`

Notes:

- Changing App Language should **not** change feed content defaults unless the user also changes Content Community.

### 2) Content Community / Content Locale (Community Content Region)

Purpose:

- Controls which **creator community/content region** the user sees by default.
- Used to scope feed defaults (and later discovery surfaces).

Values:

- BCP-47 compatible where possible: `my`, `en`, `ja`, etc.

Example:

- `contentLocale=my` means *Japanese-learning content produced for Myanmar learners* (Myanmar community).

### 3) Learning Language (Target Language Being Learned)

Purpose:

- Controls the **target language being learned** (e.g. Japanese).
- Affects feed defaults and later learning UX.

V1 default:

- `ja`

Future:

- `ko`, `en`, `th`, `zh-Hans`, `zh-Hant`, etc.

### Language code guidance (BCP-47)

Use BCP-47 compatible language codes where possible:

- `en`
- `ja`
- `my`
- `ko`
- `th`
- `zh-Hans`
- `zh-Hant`

## User Preference Model Proposal

### Backend model

Proposed schema concept:

`UserPreference`:

- `userId`
- `appLocale` `String?` // null/system, en, ja, my
- `contentLocale` `String?` // my, en, etc. (server default if null)
- `learningLanguage` `String?` // default ja if null (or explicitly set on create)
- `themeMode` `String?` // system/light/dark
- `createdAt`
- `updatedAt`

### Behavior and rationale

- **`appLocale`**:
  - Primarily client-side behavior (controls `.arb` selection)
  - Still valuable to sync across devices; backend storage allows this.
- **`contentLocale`** and **`learningLanguage`**:
  - Affect backend feed defaults for authenticated users.
  - Can be overridden per-request via query parameters.
- **`themeMode`**:
  - Client rendering decision (ThemeData), but syncing across devices is desirable.

## Feed Integration Proposal

### Backend feed behavior

`GET /v1/mono/feed`

- If **authenticated**, default to user preference `contentLocale` / `learningLanguage` (once M11b is implemented).
- Query params can override:
  - `?contentLocale=my`
  - `?learningLanguage=ja`
- Guest defaults:
  - `contentLocale=en` (or server default)
  - `learningLanguage=ja`

Additional notes:

- Cursor pagination must remain stable under these filters.
- Consider adding preference-derived defaults into response metadata later (not required for V1).

### Flutter behavior

- Settings change invalidates and reloads from first page when relevant:
  - **Mono feed pager**
  - **Following feed pager**
  - **Profile published filters/pagers** if they depend on the same feed query defaults
- Reload behavior:
  - Reload from the **first page** for affected feeds
  - Do not mutate existing mono content objects in place; replace via pager refresh

## Notification Decision

### V1

- Notifications row is visible in Settings but **disabled** or labeled **“Coming soon”**
- No push token registration
- No notification database table
- No notification triggers

### V1.5

- Device token registration
- Follow/react/new mono notifications
- Notification list screen
- Deep links to mono/profile
- Preference toggles (at least on/off; later granularity)

## Theme Token Decision

Theme must use **semantic design tokens** rather than scattered raw hex values in widgets.

### Proposed semantic tokens

Light:

- `appBackground`: `#F8FAFC`
- `surface`: `#FFFFFF`
- `textPrimary`: `#0F172A`
- `textSecondary`: `#64748B`
- `actionPrimary`: `#B8C0FF`
- `border`: `#E2E8F0`

Dark:

- `appBackground`: `#0F172A`
- `surface`: `#1E293B`
- `textPrimary`: `#F1F5F9`
- `textSecondary`: `#94A3B8`
- `actionPrimary`: `#D6D1FF`
- `border`: `#334155`

Additional:

- `success`: `#22C55E`
- `warning`: `#F59E0B`
- `error`: `#EF4444`
- `info`: `#3B82F6`
- `react`: `#EF4444`
- `disabled` (light/dark variants as needed)

### Technical guidance

- Use `ThemeData` + `ThemeExtension` for tokens.
- Avoid raw hex values in widgets; read tokens from theme.
- Gradual migration is allowed: implement tokens first, then migrate screens incrementally.

## V1 Settings Scope

V1 Settings must be useful but small:

- App language selector
- Content community selector
- Learning language selector / foundation
- Theme mode selector
- Account section:
  - Edit profile
  - Sign out
- About section:
  - App version
- Notifications placeholder only (disabled / coming soon)

## Implementation Split

Milestone split for small, reviewable increments:

- **M11a**: Decision spec (this doc)
- **M11b**: Backend user preferences API/schema
- **M11c**: Flutter settings screen shell
- **M11d**: App language integration (Flutter `.arb`)
- **M11e**: Content locale + learning language feed integration
- **M11f**: Theme tokens and light/dark mode
- **M11g**: Pagination prefetch audit/fix (Reels pager)
- **M11h**: Settings closeout

## Risks

- Feed behavior can become confusing if **App Language** and **Content Locale** are mixed; keep them separate in UI labels and state.
- Implementing notifications now would significantly expand release risk; deferring to V1.5 reduces scope creep.
- Full theme migration may touch many files; plan for gradual migration using tokens.
- Pagination changes can regress feed behavior; test with small page sizes and dedupe-by-id.

## Recommended Next Step

Implement **M11b** (backend user preferences API/schema), then **M11c** (Flutter Settings screen shell).

## Output Summary

- Decision spec created? **Yes** (`docs/M11_SETTINGS_FOUNDATION_DECISION_SPEC.md`)
- Pagination decision documented? **Yes** (cursor + 7/10 + prefetch <= 3 + dedupe + refresh rules)
- Language model separated? **Yes** (App Language vs Content Locale vs Learning Language)
- Notification deferred? **Yes** (V1 placeholder, V1.5 implementation)
- Theme tokens documented? **Yes** (semantic tokens + ThemeExtension guidance)
- Implementation split defined? **Yes** (M11a–M11h)

