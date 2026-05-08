# M9 Edit Profile V1 Plan

## Scope
Smallest useful V1 "Edit profile" for the creator-facing profile surface.

In-scope (V1 essentials):
- Profile image/avatar
- Profile cover image
- Display name
- Handle/username **only if already supported by the account/profile model**
- Bio
- Email shown as **read-only**
- Phone number only if the backend already supports it safely (otherwise defer)

Non-goals:
- Do not redesign unrelated profile UI.
- Do not touch learner Saved collections UX.
- Keep changes tightly scoped to profile identity fields + rendering/refresh.

## Deferred From V1
- Change password
- Change email
- Phone verification / OTP flows
- Account deletion
- Privacy settings
- Social links
- Advanced username availability workflow (reserve/check/claim)

## Current Backend Audit
Prisma schema (`nimon-backend/prisma/schema.prisma`) already has:
- `User`
  - `email` (nullable, unique)
  - no phone field
- `UserProfile`
  - `displayName` (nullable)
  - `handle` (nullable, unique)
  - `avatarUrl` (nullable)
  - `bio` (nullable)
  - **no profile cover image field**

Public profile endpoint:
- `GET /v1/users/:userId/public-profile` (`nimon-backend/src/modules/users/users.controller.ts`)
- Response assembled by `UsersService.getPublicCreatorProfile` (`nimon-backend/src/modules/users/users.service.ts`) returns:
  - `userId`, `handle`, `displayName`, `avatarUrl`, `bio`
  - followers/following counts and `isFollowingByMe`
  - **no cover image**

Authenticated "me" endpoint:
- `GET /v1/me` (`nimon-backend/src/modules/auth/me.controller.ts`)
- Flutter `AuthRepository.getMe` expects `user` + optional `profile` containing `displayName` + `handle`.

Media upload:
- Flutter already uses `/v1/media/upload/cover` and `/v1/media/upload/audio` via `MediaUploadRepository`.
- Backend upload infra exists (per prior milestones); plan should reuse it for avatar/cover images.

## Current Flutter Audit
Existing identity/session plumbing:
- `authSessionProvider` provides `AuthSessionAuthenticated(user)` where `user.id`, `user.email`, `user.displayName`, `user.handle` are available.

Profile surfaces:
- Owner profile screen: `lib/features/profile/profile_screen.dart`
- Public profile screen: `lib/features/profile/public_profile_screen.dart`
- Public profile data is fetched from backend and already supports showing:
  - `displayName`, `handle`, `avatarUrl`, `bio`

Media upload client:
- `lib/features/create/data/media_upload_repository.dart` + provider
- Currently supports uploading "cover" (image) and "audio".
  - This can be reused for profile avatar/cover if the backend accepts those uploads (either with new endpoints or aliasing to existing upload kinds).

## V1 Fields
### Proposed V1 model shape (logical)
- `avatarUrl`: String? (public)
- `coverImageUrl`: String? (public) **(new)**
- `displayName`: String? (public)
- `handle`: String? (public) (already present; keep nullable)
- `bio`: String? (public)
- `email`: String? (private; read-only in Edit Profile UI)
- `phone`: String? (defer unless already present; currently not in schema)

### Storage recommendation (backend)
- Keep identity fields in `UserProfile` where possible:
  - `avatarUrl`, `displayName`, `handle`, `bio`
  - add `coverImageUrl` to `UserProfile`
- Keep `email` in `User` (already).
- Defer phone unless a safe account model exists (it does not appear in current Prisma schema).

## Backend API Proposal
### 1) Read my editable profile
Add:
- `GET /v1/me/profile`

Returns:
```json
{
  "user": { "id": "...", "email": "..." },
  "profile": {
    "displayName": "...",
    "handle": "...",
    "avatarUrl": "...",
    "coverImageUrl": "...",
    "bio": "..."
  }
}
```

### 2) Update my profile
Add:
- `PATCH /v1/me/profile`

Body (all optional; patch semantics):
```json
{
  "displayName": "string | null",
  "handle": "string | null",
  "avatarUrl": "string | null",
  "coverImageUrl": "string | null",
  "bio": "string | null"
}
```

Notes:
- Auth required (JWT).
- Handle uniqueness enforced by DB; map Prisma unique constraint errors to a friendly `409 handle_taken` (V1 minimal).
- Keep this endpoint focused: no email/password/phone changes.

### 3) Public profile includes cover image
Extend:
- `GET /v1/users/:userId/public-profile` response to include `coverImageUrl`.

## Media Upload Proposal
Goal: reuse the existing upload infrastructure without creating a large new subsystem.

Options:
1) **Add new upload kinds** (cleanest API):
   - `POST /v1/media/upload/avatar`
   - `POST /v1/media/upload/profile-cover`
   - both return `{ url, mediaType, originalName, sizeBytes }` like existing cover upload.

2) **Reuse existing cover upload endpoint** (fastest, but semantically muddy):
   - Use `/v1/media/upload/cover` for both story covers and profile images.
   - Still acceptable for V1 if the backend stores only URLs and the CDN path is not type-sensitive.

Recommendation (V1):
- Prefer option (1) if adding two routes is trivial given existing media module.
- Otherwise, option (2) is acceptable as long as URL output is stable and public.

## Flutter UX Proposal
Entry:
- Owner profile menu (or header actions) -> **Edit profile**

Screen layout (V1 minimal):
- App bar: title "Edit profile", actions: Cancel (back) and Save
- Top: avatar editor (tap to pick image)
- Cover editor (tap to pick image)
- Fields:
  - Display name (text)
  - Handle (text; optional; show rules)
  - Bio (multiline)
  - Email (read-only)
  - Phone: only show if backend already supports it (likely hidden for V1)

Save flow:
- On Save: PATCH `/v1/me/profile`
- Show loading state; disable Save while submitting
- Success snackbar + pop back to profile
- Errors: inline/snackbar for validation/uniqueness/network

## Validation Rules
V1 suggested rules (small + predictable):
- `displayName`: trim; allow empty -> treat as null
- `handle`:
  - trim
  - allow empty -> null
  - allow leading `@` in UI but store without `@` (optional)
  - basic charset: `[a-z0-9_]{3,20}` (exact rule depends on existing product conventions)
  - on conflict -> show "That handle is taken."
- `bio`: trim; max length (e.g. 160–240 chars)
- `avatarUrl` / `coverImageUrl`: must be valid http(s) URL (server-side), or null
- Email: read-only

## Refresh / Cache Policy
After successful PATCH:
- Refresh `authSessionProvider` / "me" state if it is used for displayName/handle in UI
- Refresh owner profile header state
- Ensure public profile fetch (if open) re-reads data (invalidate cache / refetch)

Immediate update targets:
- Owner Profile header
- Public Profile screen for self-preview
- Any surfaces that display author identity from profile fields (e.g. writer display name/handle in feeds) should use the refreshed values on next fetch.

## Tests Needed
Backend:
- Auth required for GET/PATCH `/v1/me/profile`
- PATCH validation (empty strings -> null, length limits)
- Handle uniqueness mapping to 409
- Public profile includes cover URL (when set)

Flutter:
- Edit profile form renders current values
- Save calls PATCH and updates UI (snackbar + pop)
- Avatar/cover picker triggers upload and sets URL
- Profile refresh: owner header updates, public profile updates after refresh

## Implementation Split
### M9a - Backend profile API + schema
- Add `UserProfile.coverImageUrl`
- Add `/v1/me/profile` GET + PATCH
- Extend public profile response to include `coverImageUrl`
- Add DTOs + validation + tests

### M9b - Flutter edit profile form
- Route + entry point from profile menu
- Form + validation + loading/error states
- Wire to new profile repository + session refresh

### M9c - Avatar/cover upload wiring
- Reuse `MediaUploadRepository` (or add small profile-specific wrapper)
- Add pickers + upload progress + error mapping
- Ensure uploaded URL is applied via PATCH

### M9d - Smoke/closeout
- End-to-end manual smoke checklist
- Add/update docs + verify no regressions in Profile/Public Profile

## Risks
- Handle uniqueness & formatting rules can balloon; keep V1 rules minimal.
- Cover image is not currently in backend profile schema; requires DB migration.
- Refresh propagation: multiple places may read identity fields (session vs public profile); ensure consistent invalidation/refetch.
- Upload endpoints: if backend pathing is strict, reusing `/upload/cover` may be undesirable; add dedicated endpoints if simple.

## Recommended First Step
**M9a: add `UserProfile.coverImageUrl` + `/v1/me/profile` endpoints**, and extend the public profile response. This unblocks Flutter UX while keeping the first milestone narrowly testable.

---

## Output summary
- Should Edit Profile be next?: **Yes** — it’s a small, high-impact V1 capability given auth + profile/public-profile + media upload already exist.
- V1 fields included: **avatar, cover image, display name, handle (if present), bio, email read-only**
- V1 fields deferred: **password/email change, phone verification, deletion, privacy, social links**
- Backend schema changes needed?: **Yes** — add `UserProfile.coverImageUrl` (phone not present; defer).
- Media upload reuse possible?: **Yes** — Flutter already has `MediaUploadRepository` for image/audio; backend can add avatar/profile-cover upload endpoints or reuse existing cover upload.
- Recommended M9a first task?: **Add backend profile schema + GET/PATCH `/v1/me/profile` + public profile includes cover image**, with tests.

