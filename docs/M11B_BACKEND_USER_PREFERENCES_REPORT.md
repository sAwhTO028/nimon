# M11b Backend User Preferences Report

## Scope

Add backend persistence + API for V1 Settings foundation preferences:

- `appLocale` (UI language)
- `contentLocale` (community/content region)
- `learningLanguage` (target learning language)
- `themeMode` (system/light/dark)

Out of scope (explicitly deferred):

- Push notifications implementation (V1.5)
- Flutter Settings UI (M11c)
- Feed filtering/pagination changes (M11e/M11g)

## Files Changed

- `nimon-backend/prisma/schema.prisma`
- `nimon-backend/prisma/migrations/20260508190000_m11_user_preferences/migration.sql`
- `nimon-backend/src/modules/auth/dto/me-preferences.dto.ts`
- `nimon-backend/src/modules/auth/me.controller.ts`
- `nimon-backend/src/modules/auth/auth.service.ts`
- `nimon-backend/src/modules/auth/me.profile.controller.spec.ts`

## Prisma Model / Migration

### Model

Added `UserPreference`:

- `userId` (PK, FK → `User.id`, cascade delete)
- `appLocale` `String?`
- `contentLocale` `String?`
- `learningLanguage` `String?`
- `themeMode` `String?`
- `createdAt`, `updatedAt`

`User` now has optional relation:

- `preferences UserPreference?`

### Migration

Added migration directory:

- `prisma/migrations/20260508190000_m11_user_preferences/migration.sql`

Note: Prisma `migrate dev` could not be executed in this environment due to local Postgres auth (`P1000`), so the migration SQL is checked in following the repo’s existing migration style.

## GET /v1/me/preferences

Route:

- `GET /v1/me/preferences` (JWT required)

Behavior:

- If no DB row exists, returns defaults:

```json
{
  "appLocale": "system",
  "contentLocale": "en",
  "learningLanguage": "ja",
  "themeMode": "system"
}
```

- If a row exists, response always returns **effective values** (no nulls).

## PATCH /v1/me/preferences

Route:

- `PATCH /v1/me/preferences` (JWT required)

Patch semantics:

- Only provided fields update; omitted fields are unchanged.
- `null` is accepted and means “use default”.

Storage policy (chosen for V1):

- **Store explicit values when non-default**
- **Store `null` to mean default**
- Response always resolves defaults and returns effective values.

## Defaults / Normalization

Defaults (effective values):

- `appLocale`: `system`
- `contentLocale`: `en`
- `learningLanguage`: `ja`
- `themeMode`: `system`

Normalization:

- For `appLocale` / `themeMode`, incoming `"system"` is treated as default and stored as `null`.
- For `contentLocale` / `learningLanguage`, incoming default values (`"en"`, `"ja"`) are stored as `null`.

## Validation Rules

DTO: `PatchMePreferencesDto` (class-validator)

- `appLocale`: optional; `null` or one of `system|en|ja|my`
- `contentLocale`: optional; `null` or one of `my|en|ja`
- `learningLanguage`: optional; `null` or `ja`
- `themeMode`: optional; `null` or one of `system|light|dark`

Invalid values return **400**.

## Tests Added

Controller tests added under `MeController preferences`:

- GET requires auth
- GET defaults when missing row
- PATCH creates/upserts row and resolves defaults
- PATCH updates one field without clearing others
- PATCH accepts null and response resolves defaults
- Invalid `appLocale` rejected (400)
- Invalid `contentLocale` rejected (400)
- Invalid `learningLanguage` rejected (400)
- Invalid `themeMode` rejected (400)

## Commands Run

In this Windows environment (no `pnpm` on PATH), used Cursor-bundled Node + local binaries:

- `node ./node_modules/prisma/build/index.js format`
- `node ./node_modules/prisma/build/index.js generate`
- `node ./node_modules/jest/bin/jest.js src/modules/auth --runInBand`
- `node ./node_modules/jest/bin/jest.js --runInBand`
- `node ./node_modules/@nestjs/cli/bin/nest.js build`

Attempted (failed due to local DB auth):

- `node ./node_modules/prisma/build/index.js migrate status` → `P1000`
- `node ./node_modules/prisma/build/index.js migrate dev --create-only …` → `P1000`

Equivalent when `pnpm` is available:

- `pnpm prisma generate`
- `pnpm prisma migrate status`
- `pnpm jest src/modules/auth --runInBand`
- `pnpm jest --runInBand`
- `pnpm nest build`

## Manual Verification

- Sign in, call `GET /v1/me/preferences` → defaults returned when empty DB
- `PATCH /v1/me/preferences` with `{ "contentLocale": "my" }` → response shows `contentLocale=my`
- `PATCH` with `{ "themeMode": null }` → response shows `themeMode=system`
- Invalid values (e.g. `appLocale=fr`) → 400

## Remaining Risks

- Migration SQL was authored without running Prisma migrate locally (environment DB auth issue). It follows the repo’s existing migration conventions, but should be applied/validated in a properly configured Postgres environment.
- Allowed value lists are intentionally small for V1 (`learningLanguage` only `ja`). Expanding to more locales/languages should update DTO allowlists and add tests.

## Recommended Next Step

Proceed to **M11c** (Flutter Settings screen shell), then **M11d** (App language `.arb` integration). Feed integration with these preferences should be done in **M11e**.

