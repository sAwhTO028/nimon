# M11d App Language Integration Report

## Scope

Wire **App Language** (`appLocale`) to `MaterialApp.locale` using Flutter localization foundations.

In-scope:

- ARB / gen-l10n foundation (en/ja/my)
- Locale selection in `MaterialApp` driven by **stored preference**
- Localize **Settings screen** strings only (limited scope)

Out of scope:

- Translating the entire app
- Content community / learning language behavior changes
- Feed integration
- Theme migration
- Push notifications

## Localization Setup

Before:

- `flutter_localizations` delegates were already configured in `main.dart`.
- No `l10n.yaml` and no `.arb` files existed.
- App locale was previously read from local `appLocaleSettingProvider` (shared prefs).

After:

- Added `l10n.yaml` and `lib/l10n/*.arb`.
- Enabled `flutter: generate: true` in `pubspec.yaml`.
- Switched to generated `AppLocalizations` (`lib/l10n/app_localizations.dart`) for:
  - `supportedLocales`
  - `localizationsDelegates`

## ARB Files

Added:

- `lib/l10n/app_en.arb`
- `lib/l10n/app_ja.arb`
- `lib/l10n/app_my.arb`

Includes minimal Settings-related strings:

- Settings title/sections
- App language + language labels
- Content community
- Learning language
- Theme
- Notifications + Coming soon
- Edit profile / Sign out + dialog copy
- About + app version placeholder

## Locale Preference Wiring

Source of truth:

- `userPreferencesNotifierProvider` (`UserPreferencesState.prefs.appLocale`)

Behavior:

- `system` → `MaterialApp.locale = null` (follow OS)
- `en` → `Locale('en')`
- `ja` → `Locale('ja')`
- `my` → `Locale('my')`

Implementation:

- `lib/features/settings/app_locale_resolver.dart` exposes `resolveMaterialLocaleFromAppLocaleCode`.
- `main.dart` watches `userPreferencesNotifierProvider` and uses:
  - `supportedLocales: AppLocalizations.supportedLocales`
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`
  - `locale: resolveMaterialLocaleFromAppLocaleCode(code)`

Bootstrap:

- `UserPreferencesNotifier` now calls `load()` once at provider creation so locale is available globally (defaults to system while loading).

## Settings Localization

`lib/features/settings/settings_screen.dart` now uses `AppLocalizations.of(context)!` for:

- App bar title
- Section headers
- Settings row labels + subtitles
- Sign-in required copy
- Sign out dialog copy

Limited scope: other app screens remain unchanged for now.

## Tests Added

- `test/features/settings/app_locale_resolver_test.dart`
  - verifies code → `Locale?` mapping (`system` → null; `en/ja/my` → expected locales)
- Updated `test/features/settings/settings_screen_test.dart` to mount with:
  - `supportedLocales: AppLocalizations.supportedLocales`
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`

## Commands Run

- `flutter gen-l10n`
- `dart format` (touched files)
- `flutter analyze lib/main.dart lib/features/settings test/features/settings`
  - Note: `RadioListTile.groupValue/onChanged` deprecation info remains; no functional impact for V1.
- `flutter test test/features/settings`
- `flutter test`

## Manual Verification

- Open Settings → App Language → select:
  - English / 日本語 / မြန်မာ / System
- Return to app shell; verify:
  - Settings labels reflect chosen language (for strings covered by ARB)
  - Other screens may still show English (expected; deferred)

## Remaining Risks

- `flutter analyze` reports info-level deprecations for `RadioListTile`; can migrate to `RadioGroup` later.
- Only a subset of strings are localized in M11d (Settings-focused). Full app localization is deferred.
- Locale updates rely on preference load timing; we default to system while loading to avoid startup regressions.

## Recommended Next Step

- **M11e**: Content community + learning language feed integration (using preferences).
- Expand localization coverage incrementally after M11d foundation.

