# M9d Edit Profile V1 Closeout Report

## Scope Completed

Audit against `docs/M9_EDIT_PROFILE_V1_PLAN.md` and milestones M9a-M9c:

| V1 item | Status |
| ------- | ------ |
| Avatar image | Done: gallery picker + upload via existing media API; URL persisted with Save (`PATCH /v1/me/profile` `avatarUrl`). |
| Cover image | Done: same as avatar for upload path; `coverImageUrl` on profile + public profile DTO. |
| Display name | Done: editable field + PATCH. |
| Handle | Done: editable + backend uniqueness + Flutter maps `handle_taken`. |
| Bio | Done: multiline field + PATCH. |
| Email read-only | Done: disabled/read-only in Edit Profile; not accepted on PATCH (backend whitelist). |
| Password / email / phone / account deletion | Explicitly out of scope for V1 (unchanged). |

## Deferred From V1

Aligned with the plan and prior reports:

- Change password
- Change email
- Phone verification / OTP
- Account deletion
- Privacy settings
- Social links
- Advanced handle reservation / availability UX

## Backend Verification

### Migration (repository)

- **Present**: `nimon-backend/prisma/migrations/20260507202000_m9a_user_profile_cover_image_url/migration.sql` adds nullable `coverImageUrl` on `user_profiles`.
- **Schema**: `UserProfile.coverImageUrl` is in `nimon-backend/prisma/schema.prisma` (per M9a).

### API behavior (documented + tests)

- **GET `/v1/me/profile`**: JWT required; returns user id/email + profile fields including `coverImageUrl`.
- **PATCH `/v1/me/profile`**: Patch semantics; trim/normalize per DTO; rejects non-whitelisted fields (e.g. email).
- **Public profile**: `GET /v1/users/:userId/public-profile` includes `coverImageUrl`.
- **`handle_taken`**: Duplicate handle maps to HTTP 409 with conflict payload; user-facing Flutter message: "That handle is taken."

### Automated commands (this closeout run)

| Command | Result |
| ------- | ------ |
| `node ./node_modules/prisma/build/index.js generate` (from `nimon-backend`) | **Pass** (Prisma Client generated). |
| `node ./node_modules/prisma/build/index.js migrate status` (from `nimon-backend`) | **Fail**: `P1000` authentication failed for configured Postgres (`localhost:5432`). Migration SQL exists in repo; **apply/status against a real DB must be confirmed locally** with valid credentials. |
| `node_modules/.bin/jest.cmd src/modules/users --runInBand` | **Pass** (4 tests). |
| `node_modules/.bin/jest.cmd src/modules/auth --runInBand` | **Pass** (14 tests). |
| `node_modules/.bin/jest.cmd --runInBand` | **Pass** (17 suites, 140 tests). |
| `node_modules/.bin/nest.cmd build` | **Pass** (exit code 0). |

**Backend verified for code + tests + build in this environment.** **Database migrate status is not verified here** due to local DB auth.

## Flutter Verification

### Routes and entry points

- **Route**: `/profile/edit` registers `EditProfileScreen` (`lib/main.dart`).
- **Owner entry**: `ProfileNavigationDrawer` navigates to `/profile/edit`.
- **Public**: No "Edit profile" on `PublicProfileScreen` (widget test: `public_profile_no_edit_profile_action_test.dart`).

### Edit Profile UX

- Load from `GET /v1/me/profile`; Save calls `PATCH /v1/me/profile`.
- **Upload**: `Change photo` / `Change cover`; uses `image_picker` + `MediaUploadRepository.uploadCover` (`POST /v1/media/upload/cover`) for both until dedicated endpoints exist (M9c).
- **Save after upload**: Required to persist URLs (product rule unchanged).
- **Refresh after save**: Session refresh (`restoreSession`) + invalidate `currentUserPublicProfileProvider` (M9b).

### Automated commands (this closeout run)

| Command | Result |
| ------- | ------ |
| `flutter analyze` on M9 Edit Profile paths only (`edit_profile_screen.dart`, `edit_profile_notifier.dart`, `remote_me_profile_repository.dart`, `profile_navigation_drawer.dart`, `main.dart`) | **Pass** (no issues). |
| `flutter analyze lib/features/profile` | **Non-clean**: 48 issues, mostly pre-existing warnings/info in `profile_screen.dart` and shared profile data files (not introduced by M9 edit-profile slice). |
| `flutter test test/features/profile` | **Pass** (112 tests). |
| `flutter test` | **Pass** (387 tests). |

**Flutter verified** for M9 edit-profile behavior via targeted analyze + full profile suite + full repo tests.

## Commands Run

Summarized above. Exact working directories:

- Backend: `nimon-backend`
- Flutter: repo root `nimon`

## Manual Smoke Checklist

Use a signed-in account against a running API with migrations applied.

| Step | Expected |
| ---- | -------- |
| Open Profile -> drawer -> **Edit profile** | Navigates to Edit Profile. |
| Fields load | Display name, handle, bio, avatar/cover previews, read-only email. |
| Edit display name + bio -> **Save** | Success snackbar; pop; header/public preview refresh after refetch. |
| Change handle to an unused valid handle -> **Save** | Persists; session/header updates. |
| Change handle to an existing handle -> **Save** | Snackbar shows "That handle is taken." |
| **Change photo** -> pick image | Upload progress; preview updates. |
| **Save** | `avatarUrl` persisted; refresh behavior runs. |
| **Change cover** -> pick image | Upload progress; preview updates. |
| **Save** | `coverImageUrl` persisted. |
| Open **public profile** for same user (or preview) | Cover renders where remote bundle supplies `coverImageUrl`; no Edit profile affordance. |

**Manual smoke results (this session):** Not executed against a live device/API here. Operators should run the checklist after fixing local DB credentials and deploying migrations.

## Known Follow-ups

1. **Dedicated upload endpoints**: `POST /v1/media/upload/avatar` and/or `/profile-cover` (or typed variants) so avatar vs story-cover storage/policy can diverge.
2. **Avatar crop / compression**: Circle crop and tighter size presets beyond current `pickImage` limits.
3. **Richer validation error mapping**: Nest ValidationPipe errors -> consistent Flutter snackbars (field-level if desired).
4. **Owner profile header cover**: Public profile can show cover; owner summary header may still omit large cover art by design (see M9b report); add minimal banner if product wants parity.

## Release Readiness

- **Code + automated tests**: Backend Jest + Nest build + Flutter tests green in this closeout run.
- **Database**: Confirm `migrate deploy` (or equivalent) in each environment; **local `migrate status` failed on auth** in this workspace.
- **Manual smoke**: Recommended once DB and API base URL are correctly configured for staging/production.

## Recommended Next Milestone

- **M10 or post-M9**: Dedicated profile media upload API + owner-header cover rendering polish + validation UX hardening (pick items from Known Follow-ups by priority).

---

## Output summary

| Question | Answer |
| -------- | ------ |
| Edit Profile V1 closeout-ready? | **Yes for code and automated verification**, pending **DB migration applied** and **manual smoke** on a real environment. |
| Backend verified? | **Yes** (generate, Jest modules + full, Nest build). **Migrate status**: **not verified** (P1000). |
| Flutter verified? | **Yes** (M9-path analyze clean; `test/features/profile` + full `flutter test` passed). |
| Migration applied/status? | **SQL migration exists in repo**; **status against DB failed** here (`P1000`); apply in target env separately. |
| Manual smoke pass/fail? | **Not run** in this session; checklist provided above. |
| Remaining follow-ups? | Dedicated upload endpoints; avatar crop/compression; richer validation UX; optional owner cover banner. |
