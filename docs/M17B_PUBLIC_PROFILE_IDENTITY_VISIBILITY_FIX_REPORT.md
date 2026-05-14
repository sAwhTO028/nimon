# M17B Public Profile Identity Visibility Fix Report

## Problem

On device, public profile showed cover, avatar, stats, bio, actions, and tabs, but the **display name** and **handle** looked missing. M17A noted likely causes: missing explicit text colors on the headline, empty `handle` in the API with no fallback, and tight hero-to-identity spacing after M14J-A10.

## Scope

- **In scope:** `PublicCreatorProfile` parsing, public header identity `Text` styling and fallback logic in `public_profile_screen.dart`, focused widget/unit tests in `public_profile_identity_visibility_test.dart`, this report.
- **Out of scope:** Backend, public mono pagination, owner profile, collections loading beyond using the new writer handle label, routes, follow/share behavior, cover height constants, hero `Stack` / avatar overlay layout, localization strings, V1 limits policy.

## Payload / Fallback Findings

- V1 `GET /v1/users/:id/public-profile` DTO (`users.dto.ts`) exposes **`userId`**, **`handle`**, **`displayName`**, **`bio`**, counts, **`isFollowingByMe`** — no `username` field today.
- **Flutter** now parses optional **`username`** from JSON for forward compatibility if the API adds it later.
- **Primary line (`publicProfileMainDisplayName`):** first non-empty of trimmed **`displayName` → `username` → `handle` → `'Creator'`**.
- **Secondary line (`publicProfileSecondaryHandleLine`):** first non-empty of **`handle` → `username`**, normalized to a single leading **`@`**. Omitted when the formatted value would **duplicate** the primary line (e.g. only `@solo` exists and is already the main title).
- **Collections navigation** uses **`publicProfileWriterHandleLabel`** so writer handle stays consistent when the secondary row is omitted.

## Fix Applied

1. **`PublicCreatorProfile`** (`remote_public_creator_profile_repository.dart`): added optional `username`; added `publicProfileMainDisplayName`, `publicProfileSecondaryHandleLine`, and `publicProfileWriterHandleLabel`.
2. **`public_profile_screen.dart`**: identity block uses the new main/secondary strings; **explicit** `ColorScheme.onSurface` / `onSurfaceVariant` on name, handle, and bio; `maxLines` + `TextOverflow.ellipsis` on name, handle, and bio (bio `maxLines: 4`); **`kPublicProfileIdentityBelowHero` increased to 64** in **M17B-2** (within 52–72; clears hero-to-title on devices without restoring 104+).
3. **M17B-2:** `PublicCreatorProfile.fromJson` merges nested/snake_case identity keys; `applyMonoWriterIdentityFallback` + `publicProfileNeedsMonoWriterIdentity` fill header from the first mono row **only** when the public-profile payload has no display/handle/username; guarded `debugPrint` on successful fetch (**debug** only).

## Display Logic

| Output | Rule |
|--------|------|
| Main title | `displayName` ?? `username` ?? `handle` ?? `'Creator'` |
| Handle row | `(handle ?? username)` → strip leading `@`, re-prefix once as `@core`; skip if identical to main string |
| Writer handle for deep links | Secondary line if present; else normalized `@` from handle or username; else `@reader` |

## Styling

- Display name: `headlineSmall` + **`color: scheme.onSurface`**.
- Handle: `titleSmall` + **`color: scheme.onSurfaceVariant`** (unchanged semantic role).
- Bio: `bodyMedium` + **`color: scheme.onSurfaceVariant`**, `maxLines: 4`, ellipsis.

## Spacing

- **M17B:** `kPublicProfileIdentityBelowHero = 52`; **M17B-2:** **64** (still within product max 72), hero overlay inset, cover slot height, action row padding — A10 architecture preserved.
- **Tests:** action row → TabBar and TabBar → first mono vertical gaps remain **≤ 40** on the reference profile used in M17B tests.

## Tests Added

- **`test/features/profile/public_profile_identity_visibility_test.dart`**
  - Unit: main/secondary fallbacks, duplicate suppression, `fromJson` `username`.
  - Widget: name/handle/username visibility, explicit colors (light + dark), bio order under handle, gap bounds, avatar/stats presence, `PageStorageKey('public_profile_remote_monos')` unchanged for monos tab.

## Commands Run

```text
dart format lib/features/profile/data/remote_public_creator_profile_repository.dart lib/features/profile/public_profile_screen.dart test/features/profile/public_profile_identity_visibility_test.dart
flutter analyze lib/features/profile/data/remote_public_creator_profile_repository.dart lib/features/profile/public_profile_screen.dart test/features/profile/public_profile_identity_visibility_test.dart
flutter test test/features/profile/public_profile_identity_visibility_test.dart
flutter test test/features/profile
```

## Manual Verification

Pending on a physical device (Part E checklist from M17B spec): confirm name, `@` handle/username, bio, avatar/stats, gaps, and light/dark readability on the previously problematic public profile.

## Risks

- **`username` in JSON** is not sent by the current backend; fallback helps only when the field is added or in tests. Creators with **empty `handle` and empty `displayName`** still show **`Creator`** as the main line until the API supplies more identity fields.
- **Bio `maxLines: 4`** truncates very long bios with ellipsis (UX trade-off for layout stability).

---

## M17B-2 Real Payload Follow-up

### Actual public-profile identity fields (V1 backend)

`nimon-backend` `PublicCreatorProfileResponseDto` / `UsersService.getPublicCreatorProfile` returns a **flat** JSON object: `userId`, `handle`, `displayName`, `avatarUrl`, `coverImageUrl`, `bio`, `followersCount`, `followingCount`, `isFollowingByMe` — **no** `username` and **no** nested `profile` envelope in production.

### Root cause on phone (hypothesis → fix)

1. **Data gap:** Public profile JSON can still arrive with **empty `displayName` / `handle` / `username`** while **`bio` is populated** (valid DB state). Mono list `GET /v1/mono/feed?writerId=` continues to ship **`writerDisplayName` / `writerHandle`**, so the header looked “empty” even though rows carried the real creator labels.
2. **Alternate JSON shapes (defensive):** Proxies, older builds, or future API versions might nest identity under `profile`, `user`, or `writer`, or use **snake_case** keys. The Flutter parser now merges those layers when present.
3. **Layout cushion:** Hero-to-identity spacer increased **52 → 64** (within the allowed 52–72 band) to reduce any device-specific crowding under the in-cover overlay, **without** changing cover height or avatar/stat architecture.
4. **Fixture blind spot:** Widget tests always loaded **default mono fixtures** whose `writerDisplayName` was **`PublicName`**. After M17B, identity logic merged **mono writer over the profile on every build**, so tests still “passed” while masking the real bug. **M17B-2** applies mono writer merge **only when** `publicProfileNeedsMonoWriterIdentity(profile)` is true (all of `displayName`, `handle`, and `username` empty on the parsed public-profile payload).

### Mapper / layout changes (exact)

| Layer | Change |
|-------|--------|
| `PublicCreatorProfile.fromJson` | Merge identity from root + optional `profile`, `writer`, `user` (+ `user.profile`); accept `display_name`, `writerDisplayName`, `writerHandle`, etc.; optional `avatarUrl` from nested `profile` / `user`. |
| `applyMonoWriterIdentityFallback` | New top-level helper: copy first mono’s writer name/handle into empty profile fields when `writerId` matches (or mono `writerId` blank). |
| `fetchPublicCreatorProfile` | **`kDebugMode` only:** one-line `debugPrint('[public-profile-identity] …')` after parse (not in release). |
| `public_profile_screen.dart` | `rpIdentity` = merge **only if** `publicProfileNeedsMonoWriterIdentity(rp)`; identity spacer **64**. |

### Why M17B tests missed it

Tests used **rich mono pages** (`writerDisplayName: 'PublicName'`) for every pump, so the UI never reproduced “profile empty + feed has real writer” vs “profile has real strings”. **M17B-2** adds **Case 1–4** and **mono-writer widget** coverage plus **repository** tests for nested JSON.

### New / updated regression tests

- `test/features/profile/public_profile_identity_visibility_test.dart` — Cases 1–4, mono writer fill, `applyMonoWriterIdentityFallback` unit, nested `fromJson` group.
- `test/features/profile/remote_public_creator_profile_repository_test.dart` — nested profile / writer parse + `applyMonoWriterIdentityFallback` unit.

### Manual phone result

**Pending** — re-check the same device: expect name/handle from profile API when present; otherwise from first mono row; otherwise **Creator** above bio; confirm `[public-profile-identity]` log in **debug** builds if needed.
