# M8 Profile Trash UI Real Stats Fix Report

## Files Changed

| Area | Files |
|------|--------|
| Pagination | `lib/core/pagination/paginated_state.dart` |
| Published pager | `lib/features/profile/presentation/providers/profile_published_mono_pager.dart` |
| Providers | `lib/features/profile/data/profile_public_providers.dart` |
| Owner stats helpers | `lib/features/profile/presentation/owner_profile_header_stats.dart` |
| Own profile | `lib/features/profile/profile_screen.dart` |
| Trash UI | `lib/features/profile/profile_trash_screen.dart` |
| Public profile (remote) | `lib/features/profile/public_profile_screen.dart` |
| Tests | `test/features/profile/owner_profile_header_stats_test.dart`, `test/features/profile/profile_trash_row_overflow_test.dart` |

## Trash Layout Fix

**Cause:** `ListTile` `trailing` placed a vertical **Restore** + **Permanently delete** column in a narrow slot, causing horizontal overflow on small phones.

**Change:** Each trash row is now a bordered card: **leading thumbnail**, **Expanded** title/subtitle, then **Wrap** under the text with **Restore** (tonal filled) and **Permanently delete** (destructive `TextButton`, compact tap targets). Double confirmation dialogs are unchanged.

## Own Profile Real Stats

**Published:** `PaginatedState` now carries optional `totalCount` from `GET /v1/published-monos`. The profile header uses `publishedCountLabelForOwnerHeader`: prefers API `totalCount`; if absent and `hasMore`, shows `formatSocialCount(n)+` (approximate until fully loaded); loading shows `…`. When `NIMON_USE_REMOTE_DRAFTS` is false, the legacy mock list length is used.

**Followers / Following:** New `currentUserPublicProfileProvider` calls `GET /v1/users/:userId/public-profile` for the signed-in user (same payload as other learners see). Header uses `socialMetricLabel` with `formatSocialCount`. Loading shows `…`; fetch failure shows `—`; guests / remote off use `0`.

**Identity copy:** Display name, handle, and bio prefer the public profile response when available; otherwise session fields and the previous default tagline.

## Public Profile Design Restore

**Remote `userId` route** now mirrors the legacy mock **hero** layout: gradient **cover** (no per-user cover in API), overlapping **avatar** (`avatarUrl` or person icon), three **Monos / Followers / Following** stat chips (`formatSocialCount` / monos label with `+` when more pages exist), large **name / handle / bio**, **Follow + Share** row (Share copies canonical URL and uses `NimonAppStrings.shareLinkCopied`), divider, **Monos** section with the existing feed-backed list.

**Collections:** Remote profile does **not** show a Collections tab (collections remain deferred per M8c). Mock-only `?creator=` UI is unchanged.

## Collections/Remote Profile Policy

- Remote profiles: **Monos only** in the main body; no folder/collection UI or misleading copy.
- Owner preview (`from=owner`): informational banner only when viewing self; mock path unchanged.

## Tests Added

- `owner_profile_header_stats_test.dart` — published label rules, `socialMetricLabel` + `AsyncValue`.
- `profile_trash_row_overflow_test.dart` — narrow-width layout smoke (mirrors Wrap pattern; no overflow exception).

## Flutter Analyze Result

`flutter analyze lib/core/pagination/paginated_state.dart lib/features/profile/` completed with **no new errors** in touched code (pre-existing warnings remain in `profile_screen.dart` and other profile files).

## Flutter Test Result

- `flutter test test/features/profile/` — **pass**
- `flutter test` (full suite) — **351 tests passed**

## Manual Verification Steps

1. **Trash:** Enable remote drafts, open Trash, confirm Restore + Permanently delete on one row, narrow simulator width — no overflow yellow/black stripes.
2. **Own profile:** With backend + auth, confirm Published / Followers / Following match API (Published total when backend sends `totalCount`).
3. **Public profile:** Open `/profile/public?userId=<uuid>` — hero header, stats, Follow/Share, Monos list; pull-to-refresh reloads profile + monos.

## Remaining Risks

- Published count without `totalCount` is **approximate** (`n+`) until the user loads all pages.
- `currentUserPublicProfileProvider` swallows errors (`null`); header shows `—` for social metrics on failure.
- Share URL is a static marketing-style pattern (`https://nimon.app/profile/public?userId=…`); deep-link handling may vary by environment.
