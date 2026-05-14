# M11f Theme Tokens And Light Dark Report

## Scope

Add semantic color tokens + light/dark ThemeData foundation and wire the **themeMode** preference (system/light/dark) so Settings theme selection applies immediately.

Non-goals:

- Redesign every screen
- Replace every raw hex color in the app
- Full app-wide visual migration in one milestone

## Color Tokens

Semantic tokens (from `docs/M11_SETTINGS_FOUNDATION_DECISION_SPEC.md`):

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
- `disabled`: provided (light/dark variants)

## Theme Extension

Added `NimonColorTokens` ThemeExtension:

- File: `lib/core/design_system/nimon_color_tokens.dart`
- Includes `light` and `dark` constants, `copyWith`, and `lerp`.
- Exposed via `ThemeData.colors` extension for gradual adoption.

## ThemeData Wiring

Updated `lib/core/theme.dart`:

- `buildTheme()` uses `NimonColorTokens.light`
- `buildDarkTheme()` uses `NimonColorTokens.dark`
- Sets:
  - `colorScheme` (primary/surface/error + on-colors)
  - `scaffoldBackgroundColor` = `appBackground`
  - `cardColor` = `surface`
  - `dividerColor` = `border`
  - includes `NimonColorTokens` in `ThemeData.extensions`

## ThemeMode Preference Wiring

Source of truth:

- `userPreferencesNotifierProvider` (`prefs.themeMode` string from backend)

Mapping:

- `system` → `ThemeMode.system`
- `light` → `ThemeMode.light`
- `dark` → `ThemeMode.dark`

Implementation:

- `lib/features/settings/theme_mode_resolver.dart` (`resolveThemeModeFromPreference`)
- `main.dart` now uses this mapping to set `MaterialApp.themeMode`

## Migrated Surfaces

High-level foundation (no huge UI diffs):

- Settings / Profile drawer / Edit profile now benefit from:
  - updated `ThemeData` scaffold background + surface colors
  - consistent light/dark switching via `ThemeMode` preference

No attempt was made to replace all raw colors in `profile_screen.dart` / `mono_screen.dart` (intentionally deferred).

## Tests Added

- `test/features/settings/theme_mode_resolver_test.dart` (system/light/dark mapping)
- `test/core/design_system/nimon_color_tokens_test.dart` (token constants match spec)

Existing Settings tests already verify theme preference PATCH is invoked.

## Commands Run

- `dart format` (touched files)
- `flutter analyze` (touched paths)
  - Note: Settings still reports info-level `RadioListTile` deprecation messages.
- `flutter test test/features/settings`
- `flutter test` (full suite)

## Manual Verification

- Open Settings → Theme → choose System / Light / Dark
- App theme should switch immediately after successful PATCH (no restart required)
- Re-open app should keep selected theme mode (server preference)

## Remaining Risks

- ColorScheme uses a minimal mapping; some Material3 derived container colors may not perfectly match product design. This is acceptable for foundation, and can be refined after initial rollout.
- Some screens still set explicit colors; those will be migrated incrementally using `ThemeData.colors`.

## Recommended Next Step

- Incrementally migrate key surfaces (Mono reader/footer, Profile header/drawer) to tokens where needed.
- Proceed with **M11e** (content community + learning language feed integration) after theme foundation.

