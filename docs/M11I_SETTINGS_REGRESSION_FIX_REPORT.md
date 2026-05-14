# M11i Settings Regression Fix Report

## Problems Found

1. **Settings**: After M11h closeout, the **Reading text size** (small / standard / large) and **explanation sentence** visibility controls were no longer exposed in Settings, even though local-only providers still existed in code.
2. **Mono Reels / feed**: Users saw **HTTP 500** or empty/error states when loading `GET /v1/mono/feed`; authenticated flows could be impacted by **invalid stored preferences** or **strict locale equality** that excluded legacy rows.
3. **Dark mode**: Mono Reels and reader surfaces used **hardcoded light reader colors** (`Scaffold` / cover backgrounds), so switching Theme to Dark did not visibly change those screens despite `MaterialApp.themeMode` wiring.

## Root Cause

1. **Reading prefs**: M11 moved preferences to the backend `UserPreference` model but did not extend it with reader-specific fields or Settings UI; global text scaling still read from a **local** Riverpod notifier (`readingTextScaleSettingProvider`) instead of synced preferences.
2. **Feed**: `MonoFeedService.listFeed` used exact equality on `contentLocale` / `learningLanguage` and applied **strict validation** to user-stored preference strings that could be invalid or inconsistent with newer validation rules, risking errors or empty feeds; legacy published rows without locale tags were excluded.
3. **Theme**: `main.dart` gated `themeMode` on `prefs.loading`, forcing **system** theme during bootstrap; mono reader used fixed cream/dark-gray palette constants unrelated to `ThemeExtension` tokens.

## Restored Reading Settings

- Backend: `UserPreference.readingTextSize` (`small` | `standard` | `large`, default **standard** resolved in API responses).
- Flutter: Settings → **Reading** → **Reading text size**; PATCH persists; `MaterialApp` builder applies linear scale via `readingTextLinearScale` from `prefs.readingTextSize`.

## Explanation Toggle

- Backend: `UserPreference.showExplanations` (boolean, default **true**).
- Flutter: Settings → **Explanation sentence** (`SwitchListTile`); hides **per-sentence explanation lines** and the **footer expandable description** (`storyDescription`) in the mono reader when off; **does not** hide title or main Japanese sentence body text.

**Surfaces touched when `showExplanations` is false**:

- `_ReadingFeedPost` structured reading: explanation blocks under each sentence (via `monoLineExplanationDisplay`).
- `_PostFooterMeta` / `ExpandableFooterDescription`: subtitle/description line sourced from `item.storyDescription`.

## Mono Feed HTTP 500 Fix

**Backend**

- **Sanitized stored user preferences** when resolving effective locales (`safeStoredContentLocale`, `safeStoredLearningLanguage`) so invalid DB values fall back to guest defaults (`en` / `ja`) instead of throwing or breaking the query path.
- **Feed filter compatibility**: `WHERE` now matches `(contentLocale = effective OR contentLocale IS NULL)` and `(learningLanguage = effective OR learningLanguage IS NULL)` so untagged legacy rows remain eligible.
- **Schema**: `PublishedMono.contentLocale` and `PublishedMono.learningLanguage` are **nullable** in Prisma; migration backfills nulls to `en` / `ja` after dropping `NOT NULL`.

**Flutter**

- `RemoteMonoFeedRepository` formats HTTP errors using Nest’s JSON `message` when present (snackbar/log clarity).

**Final behavior**

- Guest defaults remain **contentLocale=en**, **learningLanguage=ja** (via effective filter + nullable OR).
- Query params still validated strictly (**400** on invalid query locale).
- Invalid **stored** preference strings no longer derail the feed.

## Dark Mode Fix

- **`main.dart`**: `themeMode` always derives from `userPreferencesNotifierProvider.prefs.themeMode` (no longer forced to system while `loading`).
- **`MonoScreen`**: Reader scaffold/cover backgrounds and inks use **`NimonColorTokens`** from `Theme.of(context)` (light/dark semantic backgrounds and text).
- **`SettingsScreen`**: Scaffold `backgroundColor` uses token `appBackground`.

## Backend Changes

- `prisma/schema.prisma`: `UserPreference.readingTextSize`, `showExplanations`; `PublishedMono` locale fields optional.
- Migration: `20260509120000_m11i_reading_prefs_feed_compat`.
- `me-preferences.dto.ts`: defaults, PATCH validation, response shape.
- `auth.service.ts`: GET/PATCH merge, boolean storage for explanations, reading size sanitization.
- `mono-feed.service.ts`: safe preference resolution + nullable-aware `WHERE`.

## Flutter Changes

- `UserPreferences` model + repository PATCH fields.
- `user_preferences_notifier.dart`: `updateReadingTextSize`, `updateShowExplanations`.
- `settings_screen.dart`: Reading section + l10n.
- `reading_text_scale.dart`, `main.dart` text scaling.
- `mono_screen.dart`: theme tokens + user preference for explanations.
- `remote_mono_feed_repository.dart`: richer HTTP error messages.

## Tests Added

- Backend: invalid stored prefs feed fallback; extended `/v1/me/preferences` tests (reading size / explanations).
- Flutter: `reading_text_scale_test.dart`; settings UI tests for reading size + explanation toggle; mono feed repo test for JSON error body.

## Commands Run

- `node ./node_modules/prisma/build/index.js generate` — PASS  
- `node ./node_modules/prisma/build/index.js migrate status` — reports pending migrations (local DB not fully migrated).  
- `node ./node_modules/jest/bin/jest.js src/modules/auth --runInBand` — PASS  
- `node ./node_modules/jest/bin/jest.js src/modules/mono-feed --runInBand` — PASS  
- `node ./node_modules/jest/bin/jest.js --runInBand` — PASS (164 tests)  
- `node ./node_modules/@nestjs/cli/bin/nest.js build` — PASS  
- `dart format` on touched Dart paths — PASS  
- `flutter analyze` on touched paths — 2 info-level deprecation infos (`RadioListTile` API).  
- `flutter test` — PASS (421 tests).

## Manual Verification

Recommended smoke:

1. Apply DB migrations (`prisma migrate deploy` / `migrate dev`) so `readingTextSize`, `showExplanations`, and nullable mono locales exist.
2. Settings → Reading text size → Large → mono reader text visibly scales (global `MediaQuery` text scaler).
3. Toggle Explanation sentence off → explanation blocks + footer description hidden; title/sentence body remain.
4. Mono feed loads as guest and authenticated user without 500; changing Content Community still refreshes feed.
5. Theme Dark → mono reader background switches to dark token surface.

## Remaining Risks

- **DB must run migrations**: Until `20260509120000_m11i_reading_prefs_feed_compat` is applied, production DBs missing columns will still error on preference endpoints or feed selects.
- **`monoReaderTranslationEnabledProvider`** remains a separate local toggle (listening UI); not synced with backend — intentional scope boundary for this milestone.
- Full-app dark polish beyond mono/settings shells is still incremental.

## Recommended Next Step

- Run **`prisma migrate deploy`** in each environment and smoke-test feed + preferences end-to-end against real Postgres.
- Optionally migrate **translation** toggles to `UserPreference` in a follow-up if product wants full server-side parity.
