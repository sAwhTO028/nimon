# M11j Dark Mode Surface Polish Report

## Problem

Global dark mode (M11f theme tokens) was active, but several surfaces still used hardcoded light greys, white sheet backgrounds, or low-contrast black/grey text. That produced bright list regions on Profile, off-white bottom sheets (including “Select vocabulary from story”), a light-tinted bottom dock, and weak contrast on the mono reader action rail and create flow chrome.

## Screenshot Audit

| Area | Issue | Direction |
|------|--------|-----------|
| Profile — Published / folder lists | `0xFFF5F5F5` list scrims, black/white chips and selection rings | `appBackground`, `surface`, `actionPrimary`, `border`, `textPrimary` / `textSecondary` |
| Floating dock | White-lerp pill | `surface` alpha-blend over `appBackground` |
| Create — default scaffold | White scaffold, blue/grey CREATE | `appBackground`, `actionPrimary`, `disabled` |
| Storytelling — top pill | White glass | `surface` + `appBackground` alpha blend |
| Vocabulary — pick-from-story sheet | Fixed cream `_sheetBg`, dark ink on title/body | `surface` sheet; inner area `appBackground` + `border`; title/body `textPrimary` / `textSecondary`; actions `actionPrimary` |
| Profile modals / processing sheet | `Colors.white`, grey callouts, black body text | `surface`, `textSecondary`, `border`, `appBackground` callouts, scheme `error` / `onError` for delete |

## Profile Dark Mode Fixes

- Replaced list `ColoredBox` and collection detail scaffold backgrounds with `Theme.of(context).colors.appBackground`.
- **Tab chips** (`_FilterRow`): selected fill `actionPrimary`, label `colorScheme.onPrimary`; unselected `surface` + `border`; “Add” chip `surface` + `border` + `textPrimary`.
- **Selection badges** (Published / collection / trash lists): `actionPrimary` / `surface`, `border`, check icon `onPrimary` or `textSecondary`.
- **Bottom sheets** opened from profile: `backgroundColor: theme.colors.surface`; body copy `textSecondary`; primary actions `actionPrimary` + `onPrimary`; outlined secondaries `border` + `textPrimary`; delete actions use `colorScheme.error` / `onError`.
- **Processing draft sheet**: readiness panel `appBackground` + `border`; messaging `textPrimary` / `textSecondary`; upload / continue `actionPrimary` with explicit disabled colors from `disabled`.

## Add/Create Dark Mode Fixes

- **`CreateScreen`** (non–review-entry): scaffold and app bar `appBackground`; title `textPrimary`; CREATE button `actionPrimary` when enabled, muted `disabled` + `textSecondary` when disabled.
- **`StoryCreatorSentencesScreen`** — **`_GlassPillSurface`**: frosted pill uses `Color.alphaBlend(surface @ ~0.82, appBackground)` and token-based shadow instead of `Colors.white` / black shadow.

## Bottom Sheet / Dialog Fixes

- **`StoryCreatorVocabKanjiEditorScreen`**: pick-story, term edit, and details sheets use `Theme.of(context).colors.surface` instead of fixed `_sheetBg`.
- **`_PickVocabularyFromStorySheet`**: title/subtitle/help `textPrimary` / `textSecondary`; selection container `appBackground` + `border`; empty state `surface` + `border`; status strip `appBackground` + `border`; footer `surface`, divider `border`, Cancel `textPrimary`, Add `actionPrimary` with disabled styling.
- **`_EmptyState`** (vocabulary module): `surface` + `border`, body `textSecondary`.
- **`showAddToCollectionSheet`**: sheet background `surface`.

## Mono Reader Action Rail Fixes

(Completed in-session before this report; unchanged behavior.)

- **`mono_screen.dart`** — `_BottomActionRail` / `_RailActionSlot`: inactive react/learn/save/share icons use `textPrimary`; active react `react`; saved bookmark `actionPrimary`; labels `textSecondary`.
- **`nimon_furigana_preview_style`**: creator sentence base text uses `textPrimary` so Japanese body is readable on dark cards.

## Theme Token Changes

No schema changes to `NimonColorTokens` — consumption-only wiring to existing `appBackground`, `surface`, `textPrimary`, `textSecondary`, `actionPrimary`, `border`, `react`, `disabled`, plus `ColorScheme` `error` / `onError` / `onPrimary` where appropriate.

## Tests Added

- `test/features/theme/m11j_dark_mode_polish_test.dart`: dark token luminance smoke checks, `buildDarkTheme` extension parity, modal `surface` widget smoke, `resolveThemeModeFromPreference('dark')`, rail-related text luminance note.

## Commands Run

Run locally from the project root:

- `dart format` on touched Dart sources under `lib/` and `test/features/theme/m11j_dark_mode_polish_test.dart`
- `flutter analyze` on those same paths (pre-existing infos/warnings remain in large legacy files such as `profile_screen.dart`)
- `flutter test test/features/profile` — passed
- `flutter test test/features/mono` — passed
- `flutter test` — passed (421+ tests)

**Note:** `test/features/theme/m11j_dark_mode_polish_test.dart` uses a small `ThemeData` + `NimonColorTokens` helper instead of `buildDarkTheme()` so tests do not trigger `google_fonts` HTTP font loads under `flutter test`.

## Manual Verification

1. Enable dark mode in Settings; open Profile → Published: list area matches app background; chips and selection rings readable.
2. Open Create → CREATE chrome and storytelling top pill: no white scaffold/pill.
3. Vocabulary → pick term from story: sheet and footer match dark theme; selection area readable.
4. Mono reader: side rail icons and labels readable; heart stays red when active.

## Remaining Risks

- Other creator editors (quiz, grammar, listening) may still contain isolated hardcoded colours; only vocabulary module empty-state + sheets and storytelling pill were swept in this pass.
- Visual tuning (exact alpha on glass pill / dock) may need product design review on real devices.

## Recommended Next Step

Run a focused grep for `Colors.white` / `Color(0xFFF…)` under `lib/features/create/` and `lib/ui/` and migrate remaining surfaces incrementally, or schedule a short design review for blur/glass surfaces in dark mode.
