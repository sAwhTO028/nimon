# M11c Flutter Settings Shell Report

## Scope

Build a **Settings V1 shell** that:

- Loads/stores preferences via backend **M11b**:
  - `GET /v1/me/preferences`
  - `PATCH /v1/me/preferences`
- Provides clean UI sections for V1:
  - App Language (stored only; applying localization deferred)
  - Content Community (stored only; feed integration deferred)
  - Learning Language foundation (Japanese only in V1)
  - Theme mode (stored only; applying theme tokens/migration deferred)
  - Account: Edit profile + Sign out
  - Notifications placeholder (disabled / Coming soon)
  - About: App version placeholder

Out of scope for M11c:

- Full `.arb` locale switching (M11d)
- Feed filtering integration (M11e)
- Mono reels pagination changes (M11g)
- Push notifications implementation (V1.5)
- Full theme token migration (M11f)

## Files Changed

- `lib/features/settings/data/user_preferences_repository.dart`
- `lib/features/settings/presentation/providers/user_preferences_notifier.dart`
- `lib/features/settings/settings_screen.dart`
- `test/features/settings/settings_screen_test.dart`
- `test/features/profile/profile_navigation_drawer_trash_test.dart`

## Repository / API

Added `UserPreferencesRepository` with remote implementation:

- Fetch: `GET /v1/me/preferences`
- Patch: `PATCH /v1/me/preferences` (patch semantics; only provided fields)

Model: `UserPreferences`

- `appLocale` (`system|en|ja|my`)
- `contentLocale` (`my|en|ja`)
- `learningLanguage` (`ja`)
- `themeMode` (`system|light|dark`)

Defaults:

- `appLocale=system`
- `contentLocale=en`
- `learningLanguage=ja`
- `themeMode=system`

## State Provider

Added `userPreferencesNotifierProvider` (`UserPreferencesNotifier`) which:

- `load()` on screen open
- `updateAppLocale`, `updateContentLocale`, `updateLearningLanguage`, `updateThemeMode`
- Tracks `loading`, `saving`, `errorMessage`
- On save failure:
  - surfaces error via `errorMessage`
  - best-effort reload to re-sync UI to server truth

## Settings Screen

Updated `SettingsScreen` to match M11a V1 scope:

- **Language**
  - App Language: System / English / 日本語 / မြန်မာ
  - Content Community: Myanmar / International / English / Japanese
  - Learning Language: Japanese + “More languages (Coming soon)” disabled row
- **Appearance**
  - Theme: System / Light / Dark
- **Account**
  - Edit profile → `/profile/edit`
  - Sign out → confirmation dialog → `authSessionProvider.logout()` → `/login`
- **Notifications**
  - Disabled list row with subtitle **Coming soon**
- **About**
  - App version placeholder text (package-info integration deferred)

Auth behavior:

- Signed-in only for now: guests see **Sign in required** screen with button to `/login`.

## Navigation Entry

- Route already exists in `main.dart`: `/settings` → `SettingsScreen`
- Profile drawer already includes **Settings** row; test added to lock it in.

## Current Deferred Behavior

These preferences are **stored** but not fully applied yet:

- App Language: does not switch `.arb` locale at runtime (M11d)
- Content Community / Learning Language: does not affect feed queries yet (M11e)
- Theme: does not migrate to semantic tokens / full app theming yet (M11f)

## Tests Added

`test/features/settings/settings_screen_test.dart`:

- Renders sections (with scroll to below-the-fold sections)
- App Language selector patches `appLocale`
- Content Community selector patches `contentLocale`
- Learning Language shows Japanese + Coming soon row
- Theme selector patches `themeMode`
- Notifications row disabled + Coming soon
- Edit profile navigates to `/profile/edit`
- Sign out routes to `/login`

`test/features/profile/profile_navigation_drawer_trash_test.dart`:

- Adds assertion that drawer includes **Settings** row

## Commands Run

- `dart format lib/features/settings test/features/settings`
- `flutter analyze lib/features/settings test/features/settings`
  - Note: `flutter analyze` reports **info-level** deprecations for `RadioListTile.groupValue/onChanged` (no functional impact for V1 shell).
- `flutter test test/features/settings` (PASS)
- `flutter test test/features/profile` (PASS)
- `flutter test` (PASS)

## Manual Verification

- Open Settings while signed in:
  - Shows Language / Appearance / Account / Notifications / About sections
  - Changing selectors calls PATCH and persists (verify via backend logs or re-open)
- Open Settings while signed out:
  - Shows “Sign in required”
- Notifications row shows **Coming soon** and is disabled
- Edit profile opens `/profile/edit`
- Sign out returns to `/login`

## Remaining Risks

- The screen uses `RadioListTile` (deprecated API warnings); can migrate to `RadioGroup` later without changing product decisions.
- Backend value allowlists are intentionally small for V1 (e.g. learningLanguage `ja` only); expanding requires coordinated backend + Flutter updates.
- Since app-wide application of locale/theme is deferred, users may expect immediate UI change; copy/tooltips may be added in M11d/M11f if needed.

## Recommended Next Step

- **M11d**: App language integration (`.arb` switching)
- **M11e**: Content community + learning language feed integration

