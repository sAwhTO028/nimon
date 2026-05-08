# OptionalJwtUserGuard dependency injection fix

## Root cause

`OptionalJwtUserGuard` is injectable and depends on `JwtService`, `PrismaService`, and `ConfigService`. Controllers that reference the guard class in `@UseGuards(OptionalJwtUserGuard)` are instantiated in **their feature module’s** DI context. Nest must resolve `JwtService` in that module.

`JwtService` is registered by `JwtModule`, which is configured only inside `AuthModule`. Unless the feature module **imports `AuthModule`** (which re-exports `JwtModule`), Nest cannot inject `JwtService` into the guard when used from that module’s controllers.

`ConfigService` is available globally via `ConfigModule.forRoot({ isGlobal: true })` in `AppModule`. `PrismaService` is available via `PrismaModule` imports. The missing piece was consistently **`JwtService`** from exported `JwtModule`.

## Modules fixed

| Module | Change |
|--------|--------|
| `MonoFeedModule` | Added `AuthModule` to `imports` (fixes DI for `MonoFeedController` using `OptionalJwtUserGuard`). |
| `UsersModule` | Already imported `AuthModule` (no change this pass). |

## AuthModule export status

No structural change was required. `AuthModule` already:

- Imports `JwtModule.registerAsync(...)` with shared secret / expiry from `auth.config`.
- Provides `OptionalJwtUserGuard`.
- **Exports** `JwtModule` (so `JwtService` is visible to importers) and **exports** `OptionalJwtUserGuard`.

Duplicate JWT configuration was avoided; feature modules import `AuthModule` only.

## Other controllers using this guard

Project-wide search (`OptionalJwtUserGuard` / `@UseGuards(OptionalJwtUserGuard)`):

- `MonoFeedController` → `MonoFeedModule` (fixed).
- `UsersController` → `UsersModule` (already imports `AuthModule`).

No other modules reference this guard.

## Commands run

From `nimon-backend`:

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
npm run start:dev
```

**Agent environment (2026-05-07):**

| Command | Result |
|---------|--------|
| `node ./node_modules/@nestjs/cli/bin/nest.js build` | **Passed** (exit code 0). |
| `nest start` / `npm run start:dev` | Not fully verified here (`express` missing from `node_modules` in this sandbox — run `npm install` and start locally). |

## Final server start result

After a normal `npm install`, **`npm run start:dev`** should pass Nest DI initialization (no `JwtService` error for `MonoFeedModule` / `UsersModule`). Verify locally.

Behavior of public endpoints using `OptionalJwtUserGuard` is unchanged: valid Bearer JWT attaches `req.user`; missing or invalid token does not return 401.
