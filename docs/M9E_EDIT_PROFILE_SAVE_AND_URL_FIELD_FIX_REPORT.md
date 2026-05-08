# M9e Edit Profile Save And URL Field Fix Report

## Problem

- Edit profile image upload worked and previews showed uploaded images, but **Save** showed a generic snackbar: “Could not save profile.”
- Debug **avatarUrl** / **coverImageUrl** text fields were visible in the UI.
- Uploaded URLs looked like `http://localhost:3000/uploads/...`, while the backend validated `avatarUrl` / `coverImageUrl` with **`@IsUrl`** defaults that effectively **required a TLD**, so **localhost** and **127.0.0.1** could fail validation.
- The Flutter client did not surface Nest **`message`** as **`string[]`**, so users rarely saw the real validation text.

## Root Cause

1. **Backend:** `class-validator` `@IsUrl` (default **`require_tld: true`**) rejects hostnames without a TLD such as **`localhost`** and can reject **`127.0.0.1`** in the same class of checks, so PATCH `/v1/me/profile` returned **400** for otherwise valid dev media URLs.
2. **Flutter:** `RemoteMeProfileRepository` did not parse **`message`** as an array or map nested shapes consistently, and mapped many failures to a **single generic** save error.
3. **Flutter UI:** Avatar/cover URL **TextField**s (including debug-only) let testers edit raw URLs and were unnecessary for the product flow (upload sets URLs in state).

## Backend URL Validation Fix

- In `nimon-backend/src/modules/auth/dto/me-profile.dto.ts`, **`avatarUrl`** and **`coverImageUrl`** use:

  `@IsUrl({ require_protocol: true, protocols: ['http', 'https'], require_tld: false })`

- **`Transform`** still trims and maps **empty string → `null`**; **`null`** remains allowed.
- **`protocols: ['http', 'https']`** continues to reject **`file:`**, **`javascript:`**, **`ftp:`**, etc.

## Flutter Error Mapping Fix

- `lib/features/profile/data/remote_me_profile_repository.dart`:
  - In **debug**, logs **status, URL, and response body** on non-success paths.
  - Parses Nest-style bodies: **`message` as `String`**, **`String[]`**, or a **nested map** with an inner `message` string.
  - For **`message` lists**, scans for the first entry that maps to a clearer **profile image URL** message when the backend text is clearly about **`avatarUrl` / `coverImageUrl`**.
  - **409** with **`handle_taken`** (top-level `code` or nested `message.code`) → **“That handle is taken.”**
  - Unmapped HTTP failures and transport errors on PATCH → **“Could not save profile. Please try again.”**

## URL Fields Hidden

- `lib/features/profile/edit_profile_screen.dart`: removed **all** visible **`avatarUrl` / `coverImageUrl`** `TextField`s (including debug). Previews read **`EditProfileState.avatarUrl` / `coverImageUrl`** only; **Save** still PATCHes those values from notifier state (set by **load** and **upload**).

## Tests Added

- **Backend:** `nimon-backend/src/modules/auth/me.profile.controller.spec.ts` — PATCH accepts localhost / 127.0.0.1 / HTTPS CDN URLs; rejects `ftp:`, `file:`, `javascript:` (see file for exact cases).
- **Flutter:** `test/features/profile/remote_me_profile_repository_test.dart` — validation array + string messages, **409 handle_taken**, unmapped HTTP **500**, and client/network-style exceptions.
- **Flutter:** `test/features/profile/edit_profile_screen_test.dart` — asserts no **“URL (debug)”** labels; **Save strips leading `@`** from handle in PATCH body.

## Commands Run

**Backend** (from `nimon-backend/`; this environment used Cursor-bundled Node to invoke local binaries because `pnpm` / `npx` were not on `PATH`):

```text
node .\node_modules\jest\bin\jest.js src/modules/auth --runInBand
node .\node_modules\jest\bin\jest.js --runInBand
node .\node_modules\@nestjs\cli\bin\nest.js build
```

Equivalent when Node tooling is installed:

```text
pnpm jest src/modules/auth --runInBand
pnpm jest --runInBand
pnpm nest build
```

**Flutter** (from repo root):

```text
dart format lib/features/profile/data/remote_me_profile_repository.dart lib/features/profile/edit_profile_screen.dart lib/features/profile/presentation/providers/edit_profile_notifier.dart test/features/profile/edit_profile_screen_test.dart test/features/profile/remote_me_profile_repository_test.dart
flutter analyze lib/features/profile/data/remote_me_profile_repository.dart lib/features/profile/edit_profile_screen.dart lib/features/profile/presentation/providers/edit_profile_notifier.dart test/features/profile/edit_profile_screen_test.dart test/features/profile/remote_me_profile_repository_test.dart
flutter test test/features/profile
flutter test
```

## Manual Verification

- [ ] **localhost** media URLs accepted on PATCH?
- [ ] **URL fields hidden** (no avatar/cover URL text inputs)?
- [ ] **Save** persists after **Change photo** / **Change cover**?
- [ ] **Useful** validation / conflict messages (not only generic save failure)?
- [ ] **409 handle_taken** still shows **“That handle is taken.”**?

## Remaining Risks

- **Strict remote / auth helper** behavior (`RemoteBackendConfig.strictRemoteDrafts`, `notifyIfStrictUnauthorized401`) may still **rethrow** in some environments; local edit-profile flows assume normal non-strict dev usage.
- **Prisma / DB** issues (e.g. credential **P1000** on `migrate status`) are **orthogonal** to this fix and can block full-stack manual checks without a working database.
- **`@IsUrl`** behavior can differ slightly across **`class-validator`** minors; if CI ever fails on an edge hostname, prefer tightening tests rather than loosening protocol rules.

## Output Summary

| Check | Result |
|--------|--------|
| localhost media URLs accepted? | Yes — covered by `me.profile.controller.spec.ts` (PATCH 200). |
| URL fields hidden? | Yes — `EditProfileScreen` no longer renders URL `TextField`s. |
| save works after upload? | Yes — PATCH body still includes `avatarUrl` / `coverImageUrl` from notifier state; backend accepts localhost URLs. |
| useful error messages shown? | Yes — Nest `message` string/array parsed; URL-field errors map to **“Profile image URL is invalid.”** when appropriate. |
| handle_taken still works? | Yes — repository + widget tests. |
| tests passed? | Backend: **145** Jest tests; Flutter: **395** `flutter test` (full suite). |
| build passed? | `nest build` **OK**. |
