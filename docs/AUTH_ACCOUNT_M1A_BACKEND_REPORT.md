# Auth Account M1a Backend Report

**Date:** 2026-05-03  
**Scope:** M1a — Prisma auth schema + Nest auth service + JWT + `/v1/auth/*` + `GET /v1/me` (per `docs/AUTH_ACCOUNT_IDENTITY_M1_PLAN.md`).  
**Out of scope:** Story-drafts / published-monos guards, `DEV_OWNER_ID` removal, Flutter (unchanged).

---

## Files Changed

| Path | Change |
|------|--------|
| `nimon-backend/prisma/schema.prisma` | `User.passwordHash`; `UserProfile`; `RefreshToken`; relations on `User` |
| `nimon-backend/prisma/migrations/20260503120000_auth_account_m1a/migration.sql` | New migration SQL |
| `nimon-backend/package.json` | Dependencies: `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt`; dev: `@types/bcrypt`, `@types/passport-jwt` |
| `nimon-backend/.env.example` | `JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN` |
| `nimon-backend/src/modules/auth/auth.config.ts` | **New** — JWT secret resolution (prod vs dev fallback) |
| `nimon-backend/src/modules/auth/dto/register.dto.ts` | **New** |
| `nimon-backend/src/modules/auth/dto/login.dto.ts` | **New** |
| `nimon-backend/src/modules/auth/dto/refresh.dto.ts` | **New** — used for refresh + logout body |
| `nimon-backend/src/modules/auth/auth.service.ts` | **New** — register, login, refresh, logout, getMe |
| `nimon-backend/src/modules/auth/auth.controller.ts` | **New** — `v1/auth/*` |
| `nimon-backend/src/modules/auth/me.controller.ts` | **New** — `GET /v1/me` |
| `nimon-backend/src/modules/auth/jwt.strategy.ts` | **New** |
| `nimon-backend/src/modules/auth/jwt-auth.guard.ts` | **New** |
| `nimon-backend/src/modules/auth/auth.module.ts` | **Replaced** empty stub with full module |

---

## Prisma Changes

- **`users`:** nullable **`passwordHash`** — existing rows (including dev owner) stay valid with `NULL`.
- **`user_profiles`:** 1:1 with `User` (`userId` PK), optional `displayName`, **nullable unique** `handle`, `avatarUrl`, `bio`, timestamps.
- **`refresh_tokens`:** opaque refresh tokens stored as **SHA-256 hex** in `tokenHash` (unique), `expiresAt`, optional `revokedAt`, `createdAt`, FK to `User`.

---

## Migration Result

- **Command run (this environment):** `node ./node_modules/prisma/build/index.js migrate dev` (with existing migration directory `20260503120000_auth_account_m1a`).
- **Result:** **Applied** to local Postgres at `localhost:5432` — *“Your database is now in sync with your schema.”*
- **If your machine has no DB:** run Docker Postgres / set `DATABASE_URL`, then `prisma migrate deploy` (or `migrate dev` in dev) — **do not** use `migrate reset` per project rules.

---

## Dependencies Added

Runtime: `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt`  
Dev: `@types/bcrypt`, `@types/passport-jwt`

> **Local follow-up:** This repo uses a **pnpm** lockfile. Run **`pnpm install`** (or **`npm install`**) in `nimon-backend/` so `node_modules` contains the new packages. **Build and Jest were not able to pass in the agent environment until install completes** (see below).

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `JWT_SECRET` | HMAC secret; **required length ≥ 32 in production** (`NODE_ENV=production`); if missing in non-production, a **documented dev-only fallback** is used (see `auth.config.ts` + console warning) |
| `JWT_EXPIRES_IN` | Access token lifetime (default **`15m`**) |
| `JWT_REFRESH_EXPIRES_IN` | **Integer seconds** for refresh token lifetime (default **604800** = 7 days) |

---

## Auth Routes Added

| Method | Path | Auth |
|--------|------|------|
| POST | `/v1/auth/register` | None |
| POST | `/v1/auth/login` | None |
| POST | `/v1/auth/refresh` | None (body: `refreshToken`) |
| POST | `/v1/auth/logout` | None (body: `refreshToken`; revokes server-side) |
| GET | `/v1/me` | **Bearer JWT** (`JwtAuthGuard`) |

`main.ts` already allows `Authorization` in CORS `allowedHeaders`.

---

## Password Handling

- **bcrypt** (cost **12**) for `passwordHash`.
- **Register / login** never return `passwordHash`.
- **Duplicate email:** `409` `ConflictException` (pre-check + `P2002` catch).
- **Invalid login:** `401` `UnauthorizedException` with message **"Invalid credentials"** (user not found, no `passwordHash`, or wrong password).

---

## User Profile Bootstrap

- **On register:** creates **`UserProfile`** with `displayName` = local part of email (before `@`); `handle` left **`null`** to avoid unique collisions until product defines handle rules.
- **`GET /v1/me`:** returns `{ user: { id, email }, profile: { ... } | null }` with ISO strings for profile timestamps.

---

## Tests Added

- **`src/modules/auth/auth.service.spec.ts`** — unit tests: register hash not plaintext, duplicate email, login success + wrong password + no `passwordHash`, refresh unknown token, getMe shape, **JWT `signAsync` called with `sub` + `email`**.

**Limitation:** Full HTTP e2e for `GET /v1/me` not added; guard behavior is covered indirectly via `AuthService` + `JwtStrategy` integration in a later milestone if desired.

---

## Prisma Generate Result

- **Command:** `node ./node_modules/prisma/build/index.js generate`
- **Result:** **Success** (Prisma Client v7.7.0 generated with new models).

---

## Backend Test Result

- **Command:** `node ./node_modules/jest/bin/jest.js src/modules/auth/auth.service.spec.ts`
- **Result in this environment:** **Not run to completion** — Jest/bcrypt require packages installed via **`pnpm install` / `npm install`**. After install, re-run the command; tests are expected to pass (they use real `bcrypt` for hash assertions).

---

## Backend Build Result

- **Command:** `node ./node_modules/@nestjs/cli/bin/nest.js build`
- **Result in this environment:** **Failed** with `TS2307` **Cannot find module** for `@nestjs/jwt`, `@nestjs/passport`, `bcrypt`, `passport-jwt` until **`pnpm install` / `npm install`** updates `node_modules`.
- **After install:** re-run `nest build` — expected **pass**.

---

## Risks

1. **Install not run:** CI/local must run package install or build fails.
2. **Dev JWT fallback:** Must set a strong `JWT_SECRET` in any shared/staging/prod environment.
3. **Login session rotation:** **Login** revokes other active refresh tokens for the same user (simple single-device-ish policy); adjust if multi-device refresh is required.
4. **Refresh token reuse:** No detection of reuse attacks in M1a — acceptable for V1a; harden in a later pass.
5. **Unauthenticated APIs:** Story-drafts and published-monos remain **unchanged** (per M1a) — still **not** production-safe until **M1b** guards.

---

## Recommended Next Step

1. In `nimon-backend/`: **`pnpm install`** (or `npm install`), then **`nest build`**, then **`jest src/modules/auth/auth.service.spec.ts`**, then full **`npm test`** as needed.  
2. **M1b:** `JwtAuthGuard` on `story-drafts` and `published-monos`; derive **`ownerId` from JWT `sub`**; restrict or remove **`DEV_OWNER_ID`** in production.

---

### Output summary

| Question | Answer |
|----------|--------|
| **Prisma models changed** | **`User`** (+`passwordHash`); **new** `UserProfile`, `RefreshToken` |
| **Migration created/applied?** | **Yes** — `20260503120000_auth_account_m1a` (applied in this run against local DB) |
| **Dependencies added** | `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt`, `@types/bcrypt`, `@types/passport-jwt` |
| **Auth routes added** | `POST /v1/auth/register`, `login`, `refresh`, `logout`; `GET /v1/me` |
| **Refresh token implemented?** | **Yes** — opaque token + SHA-256 storage; refresh + logout |
| **Tests passed?** | **Pending** — run after `pnpm install` / `npm install` |
| **Backend build passed?** | **Pending** — run after install |
| **Next step** | **Install deps → build + test**; then **M1b** (guards + owner scoping) or **fix** any install issues first |
