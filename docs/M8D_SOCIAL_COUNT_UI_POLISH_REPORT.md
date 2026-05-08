# M8d Social Count UI Polish Report

## Files Changed

- `lib/core/format_social_count.dart` (new) — `formatSocialCount`, `monoReactRailPrimaryLabel`, `monoReactRailSemanticsLabel`.
- `lib/features/mono/mono_screen.dart` — pass `likesCountNotifier` into `_ReadingFeedPost` / `_ReadModeLearnGroupCollapsible` / `_BottomActionRail`; React slot shows compact count synced to notifier; semantics include like count when &gt; 0.
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart` — Likes metric uses `item.likesCount` + `formatSocialCount` (removed mock likes hash).
- `lib/features/profile/public_profile_screen.dart` — remote header `_CountChip` and legacy `_StatChip` counts use `formatSocialCount`; slightly increased label/value spacing in `_CountChip`.
- `test/core/format_social_count_test.dart` (new)
- `test/features/mono/social_count_ui_behavior_test.dart` (new) — lightweight optimistic UI behavior harnesses.
- `docs/M8D_SOCIAL_COUNT_UI_POLISH_REPORT.md` (this file)

## Product Decision Applied

Per `docs/M8_DISCOVERY_AND_POLISH_PLAN.md` §6: present social counts consistently, optional abbreviation, no backend changes. Aligns with post–M8c1 Saved-only work (`docs/M8C1_SAVED_ONLY_POLISH_REPORT.md`).

## Likes Count (Mono)

- **Feed / reader** right rail: under the heart, the primary label is **`React`** when `likesCount == 0` (avoids a noisy `"0"` in a narrow column). When `likesCount > 0`, the label shows **`formatSocialCount(likesCount)`** (e.g. `1`, `1.2K`, `12K`).
- The count is driven by the existing **`ValueNotifier<int>`** map (`_likesCountNotifierFor`), already updated optimistically in **`_toggleReact`** and reconciled with the API response.
- **Story options** panel metrics row: always shows a **Likes** card with **`formatSocialCount(item.likesCount)`**, including **`0`**, since the row is a deliberate stats strip (not the compact rail).

## Public Profile Counts

- **Remote profile** (`_CountChip`): **Followers** / **Following** values use **`formatSocialCount`**. **Followers** still flows through **`_followersCountOptimistic`** on follow/unfollow (existing M7 behavior); server response overwrites optimistic state on success.
- **Legacy mock header** (`_StatChip` on cover): Stories / Followers / Following strings use the same formatter for consistency.

## Count Formatting Rules

| Range | Example output |
|------|----------------|
| 0–999 | `0` … `999` |
| 1,000–9,999 | `1K`, `1.2K`, `10K` (9,999 → `10K`) |
| 10,000–999,999 | `10K`, `12K`, `999K` (whole thousands, rounded) |
| ≥ 1,000,000 | `1M`, `1.2M`, `13M` (≥ 10M rounds to whole M) |

Negatives clamp to **`0`**.

## Tests Added

- **`format_social_count_test.dart`**: formatter boundaries + rail label / semantics helpers.
- **`social_count_ui_behavior_test.dart`**: widget harnesses that mirror optimistic **react ↔ likes** and **follow ↔ followers** display updates using the same formatting helpers (without full `MonoScreen` / `PublicProfileScreen` pumps).

## Flutter Analyze (touched paths)

```text
flutter analyze lib/core/format_social_count.dart lib/features/mono/mono_screen.dart lib/ui/bottom_sheets/mono_story_options_sheet.dart lib/features/profile/public_profile_screen.dart test/core/format_social_count_test.dart test/features/mono/social_count_ui_behavior_test.dart
```

Result: **No issues found.**

## Flutter Test

- Full suite: **`flutter test`** — **All tests passed** (342 tests in this workspace run).

## Remaining Risks / Follow-ups

- **Profile connections** screen titles remain text-only (no count in app bar); acceptable for M8d scope.
- **Mono feed cards** (non-reader chrome) do not add a second likes line; counts appear on the **rail** and in **story options**.
- Large numbers are English-style (`K` / `M`); **M8e** localization would revisit strings.

## Recommended Next Step (M8e)

Per `docs/M8_DISCOVERY_AND_POLISH_PLAN.md` §7 and §8: **M8e — Share sheet + localization** (`share_mono_link.dart`, optional `share_plus`, ARB / `intl` for share and social gate copy).
