# M11k Premium Blue Gray Theme Refinement Report

## Scope

Token-level refinement to Nimon’s official **muted blue‑gray** light/dark palettes (M11k), plus **`ColorScheme` / AppBar alignment** in `theme.dart`. No layout changes, business logic changes, backend changes, or broad widget rewrites. Component code was touched only where theme integration already existed (dock shadow deprecation cleanup).

## Design Direction

Premium, calm, minimal reading-app aesthetic: cool desaturated neutrals, soft contrast, trustworthy polish—high-end SaaS without saturated accents.

## Official Light Palette

| Token          | Hex       |
|----------------|-----------|
| appBackground  | `#F6F8FB` |
| surface        | `#DFE6EE` |
| border         | `#B8C2CE` |
| textSecondary  | `#7A8796` |
| textPrimary    | `#3B4450` |
| actionPrimary  | `#3B4450` |
| disabled       | `#B8C2CE` |
| success        | `#6F9F8B` |
| warning        | `#B89A5E` |
| error          | `#B86B6B` |
| info           | `#6F8FA8` |
| react          | `#C76B6B` |

Primary button / on-primary pairing: **`onPrimary` = `appBackground` (`#F6F8FB`)** for readable restrained contrast.

## Official Dark Palette

| Token          | Hex       |
|----------------|-----------|
| appBackground  | `#1F2630` |
| surface        | `#2A3440` |
| border         | `#4D5A69` |
| textSecondary  | `#A8B4C2` |
| textPrimary    | `#E8EDF3` |
| actionPrimary  | `#E8EDF3` |
| disabled       | `#4D5A69` |
| success        | `#8FBFA5` |
| warning        | `#C7AE7A` |
| error          | `#C98484` |
| info           | `#8FAFCB` |
| react          | `#C98484` |

Primary button / on-primary pairing: **`onPrimary` = `appBackground` (`#1F2630`)**.

No **`elevatedSurface`** token added (keep single surface semantic; layering via `surface` vs `appBackground`).

## Token Changes

Updated `lib/core/design_system/nimon_color_tokens.dart`:

- **`NimonColorTokens.light`** / **`.dark`** static consts replaced with M11k official values above.
- Semantic names unchanged (`appBackground`, `surface`, …) so existing `Theme.of(context).colors` call sites inherit the new identity.

## ColorScheme Changes

Updated `lib/core/theme.dart`:

- **Light:** `primary` / `secondary` = `actionPrimary`; **`onPrimary` / `onSecondary` / `onError` = `appBackground`**; `surface` = token `surface`; scaffold = `appBackground`.
- **Dark:** same structure with dark tokens (`onPrimary` = dark `appBackground` `#1F2630`).
- **AppBar:** `backgroundColor` = `appBackground`, `surfaceTintColor` transparent, `foregroundColor` / title color = `textPrimary` (light theme keeps existing title sizing/weight).

## Button / Chip / Tab Adjustments

No bespoke widget rewires required for M11k: **FilledButton** and token-driven **`colorScheme.onPrimary`** now match the restrained charcoal/light pairings globally. Existing profile filter chips (**`_FilterRow`**), create CTA, bottom-sheet primaries, and mono reader rail already consume **`NimonColorTokens`** / **`ColorScheme`**; they pick up the new palette automatically.

Note: **`actionPrimary` and `textPrimary` are identical** in both official palettes by design; “selected” bookmark vs outline icon still differs by glyph; rail inactive vs muted states rely on **`textSecondary`**.

## Surface Layering

- **Chrome / scaffold:** `appBackground`
- **Cards, modal sheets pattern, dock fill (alpha-blended surface over background):** `surface`
- **Dividers / outlines:** `border`
- **Copy:** `textPrimary` / `textSecondary`

## Light Mode QA

Spot-check: Profile lists (app background vs rows), mono feed chrome, settings, edit profile, collections, Add/Create—should read as **soft blue‑gray**, not stark white slabs (cards/sheets use `#DFE6EE`).

## Dark Mode QA

Spot-check: Profile header/lists/chips/dock, mono reader rail, storytelling editor pill, semantics/vocab sheets, settings—should stay **cool and calm** without pure black fills.

## Hardcoded Color Audit

Grep for legacy M11f hex anchors (`#F8FAFC`, `#0F172A`, `#1E293B`, `#B8C0FF`, `#D6D1FF`) in `*.dart`: **removed from token/theme sources**; no remaining occurrences outside historical docs. **`Colors.black` / `Colors.white`** left in place where used for shadows, transparency, or non-theme chrome (e.g. dock shadow, transparent layers)—not systematically stripped per M11k instructions.

## Tests Added

| File | Role |
|------|------|
| `test/core/design_system/nimon_color_tokens_test.dart` | Asserts **full** M11k light/dark official hex set |
| `test/features/theme/m11k_premium_blue_gray_theme_test.dart` | Spec spot checks, `ThemeMode` resolver, light/dark surface smoke, primary/onPrimary pairing |
| `test/features/theme/m11j_dark_mode_polish_test.dart` | Retained luminance/smoke complements (still valid on new chroma) |

## Commands Run

From repo root (local run):

- `dart format` on `lib/core/design_system/nimon_color_tokens.dart`, `lib/core/theme.dart`, `lib/widgets/floating_dock_nav_bar.dart`, `test/core/design_system/nimon_color_tokens_test.dart`, `test/features/theme/m11k_premium_blue_gray_theme_test.dart`
- `flutter analyze` on those same paths — **no issues found**
- `flutter test test/features/theme` — passed
- `flutter test test/features/settings` — passed
- `flutter test test/features/profile` — passed
- `flutter test test/features/mono` — passed
- `flutter test` — **full suite passed**

## Manual Verification

1. Toggle **Light** theme: scaffold `#F6F8FB`, cards/sheets visibly cooler gray-blue `#DFE6EE`, primary buttons dark charcoal fill with pale label.
2. Toggle **Dark** theme: scaffold `#1F2630`, surfaces `#2A3440`, primary buttons pale fill with dark label `#1F2630`.
3. React/heart keeps **muted** `react` token (no neon coral).

## Remaining Risks

- Screens with **direct `Colors.white` / `#FFFFFF`** for cards may still visually “jump” lighter than `#DFE6EE` surfaces until migrated to tokens.
- **`google_fonts`**: widget tests avoid `buildTheme()` network where noted; token tests remain offline-safe.

## Recommended Next Step

Optional second pass: grep **`Colors.white` / `0xFFFFFFFF`** under `lib/features/` limited to scaffold/card/sheet `color:` assignments and migrate stragglers to **`theme.colors.surface`** / **`appBackground`**.
