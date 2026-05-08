# M9a Backend Edit Profile API Report

## Files Changed
- `nimon-backend/prisma/schema.prisma`
- `nimon-backend/prisma/migrations/20260507202000_m9a_user_profile_cover_image_url/migration.sql`
- `nimon-backend/src/modules/auth/dto/me-profile.dto.ts`
- `nimon-backend/src/modules/auth/auth.service.ts`
- `nimon-backend/src/modules/auth/me.controller.ts`
- `nimon-backend/src/modules/auth/me.profile.controller.spec.ts` (new)
- `nimon-backend/src/modules/users/users.dto.ts`
- `nimon-backend/src/modules/users/users.service.ts`
- `nimon-backend/src/modules/users/users.service.spec.ts`

## Prisma Migration
- Adds nullable `coverImageUrl` column to `user_profiles`.

## GET /v1/me/profile
- Auth required (JWT).
- Returns:
  - `user.id`, `user.email` (readonly)
  - `profile.displayName`, `handle`, `avatarUrl`, `coverImageUrl`, `bio`

## PATCH /v1/me/profile
- Auth required (JWT).
- Patch semantics: all fields optional.
- Empty string is normalized to `null`.
- Returns the same response envelope as GET.

## Validation Rules
- `displayName`: trim; empty -> null; max 80
- `handle`: trim; strip leading `@`; lowercase; empty -> null; `[a-z0-9_]` only; 3..20 chars; unique
- `bio`: trim; empty -> null; max 240
- `avatarUrl`/`coverImageUrl`: trim; empty -> null; http(s) URL only
- `email`: rejected (non-whitelisted) by ValidationPipe

## Handle Uniqueness
- Prisma `P2002` on `user_profiles.handle` mapped to HTTP 409 with code `handle_taken`.

## Public Profile Cover Field
- `GET /v1/users/:userId/public-profile` now includes `coverImageUrl`.

## Tests Added
- Auth required for GET/PATCH `/v1/me/profile`
- PATCH normalization/validation (trim, handle normalization, url validation)
- PATCH rejects non-whitelisted `email`
- Duplicate handle -> 409 `handle_taken`
- Public profile includes `coverImageUrl` (service spec)

## Prisma Generate / Migration Result
- `prisma generate` expected to succeed.
- Migration is additive (`ALTER TABLE`), safe for existing rows.

## Backend Test Result
- See Commands Run section.

## Backend Build Result
- See Commands Run section.

## Remaining Risks
- Error response shape for `handle_taken` should be stabilized across the API (currently returns a conflict payload).
- Legacy users without `user_profiles` rows are handled via upsert, but GET may still return `profile: null` for truly missing profile.

## Recommended Next Step
- M9b: Flutter Edit Profile form + route + refresh wiring.

