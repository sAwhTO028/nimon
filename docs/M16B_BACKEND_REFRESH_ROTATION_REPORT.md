# M16B Backend Refresh Token Rotation Report

## Problem

Access JWTs expire on a short clock (default **15m**, `JWT_EXPIRES_IN`). The Flutter client will gain **401 → refresh → retry** in **M16C**; for that to be safe, the backend must **rotate** opaque refresh tokens so a used refresh cannot be replayed indefinitely. Prior to M16B, `POST /v1/auth/refresh` returned the **same** plaintext refresh token and left the `RefreshToken` row unchanged (no rotation, no replay hardening).

See baseline: [M16A_AUTH_SESSION_PERSISTENCE_AUDIT.md](./M16A_AUTH_SESSION_PERSISTENCE_AUDIT.md).

## Scope

- **Changed:** `nimon-backend/src/modules/auth/auth.service.ts`, `auth.service.spec.ts`.
- **Unchanged:** Flutter, access token TTL, Prisma schema, auth controller routes/DTOs, guards, public profile, validation, localization.
- **Deferred:** Logout-all-devices UI, session list, `lastUsedAt` / `replacedBy` columns (**M16D** risk if product wants forensics).

## Current Refresh Flow (pre-M16B, documented for audit)

1. **Register:** Transaction creates `User`, `UserProfile`, `RefreshToken` (SHA-256 of opaque refresh), returns `{ accessToken, refreshToken, tokenType }`.
2. **Login:** `updateMany` revokes prior active refresh rows for user; creates one new `RefreshToken` row; returns same token shape.
3. **Refresh (`POST /v1/auth/refresh`):** Body `{ refreshToken }` → `AuthService.refresh` → looked up row by hash; if valid, issued **new access JWT** but returned **the same** refresh plaintext; **no** row rotation.
4. **Logout (`POST /v1/auth/logout`):** Body `{ refreshToken }` → `updateMany` set `revokedAt` where hash matches and not already revoked → **204**.
5. **Prisma `RefreshToken`:** `id`, `userId`, `tokenHash` (@unique), `expiresAt`, `revokedAt?`, `createdAt` — no `deviceId` / `lastUsedAt`.
6. **Errors:** Unknown / invalid refresh used `UnauthorizedException('Invalid refresh token')` (401).

## Rotation Behavior (M16B)

On **successful** refresh:

1. Hash presented plaintext with existing **SHA-256** helper.
2. `findUnique` by `tokenHash`.
3. **Reject** with `UnauthorizedException('Invalid refresh token')` if: no row, **expired** (`expiresAt <= now`), or user missing.
4. **Reuse path:** If row exists and **`revokedAt != null`**, treat as reuse → **`updateMany`** revokes all still-valid refresh rows for that `userId`, then same `UnauthorizedException` (no extra detail).
5. **Happy path:** In a **`$transaction`**: re-read row by hash; if no longer active, throw; **`update`** row `revokedAt = now`**; **`create`** new row with new opaque token (48 bytes `base64url`), new hash, new `expiresAt` from `JWT_REFRESH_EXPIRES_IN`; sign new access JWT; return **`{ accessToken, refreshToken: <new plain>, tokenType: 'Bearer' }`**.

The client **must** persist the new refresh token (Flutter `restoreSession` / future interceptor already expects the JSON pair from `AuthRepository`).

## Reuse Detection Policy

| Scenario | Action |
|----------|--------|
| Unknown hash | 401, message `Invalid refresh token`. |
| Valid hash, **expired**, not revoked | 401, same message; **no** cascade revoke of other sessions. |
| Valid hash, **`revokedAt` set** (logout or post-rotation) | **Cascade:** revoke all active refresh tokens for that `userId`, then 401 with same message. |

Rationale: presenting a **revoked** refresh (especially after rotation) is consistent with **token reuse / theft** signal per OWASP-style guidance; killing all refresh sessions for that user limits blast radius. Trade-off: a stale client holding an **old** refresh after another device rotated will force **re-login everywhere** for that account when the stale client tries refresh.

## Logout Revocation

- **Unchanged contract:** `POST /v1/auth/logout` with `{ refreshToken }` → `updateMany` where `tokenHash` matches and `revokedAt` is null.
- **Idempotent:** Unknown hash or already-revoked row → **0** rows updated, **no** throw (still **204**).
- Documented in code comments on `logout`.

## Response Shape

- **Still** `AuthTokens`: `accessToken`, `refreshToken`, `tokenType: 'Bearer'` — **Flutter-compatible** with existing `AuthRepository._tokensFromJson` / login / register.
- **No** `user` object added to refresh response (not required for M16B).

## Schema Changes

**None.** Rotation uses existing `RefreshToken` create + update. Optional metadata (`lastUsedAt`, `replacedByTokenHash`, `revokedReason`) left for **M16D** if needed.

## Tests Added

In `auth.service.spec.ts`:

| Test | Intent |
|------|--------|
| `refresh` rejects unknown | 401 path, generic message |
| `refresh` rotates | Transaction `update` + `create`; new refresh ≠ input; new row hash matches new plain |
| `refresh` rejects expired | No cascade `updateMany` |
| `refresh` reuse revoked | Cascade `updateMany` for user, 401, no `$transaction` |
| `refresh` race inside transaction | Stale row in tx → 401 |
| `logout` revokes | `updateMany` with hash + `revokedAt: null` |
| `logout` idempotent | Two calls, `count: 0` safe |

Existing **login/register/getMe/patchMeProfile** tests unchanged in intent.

## Commands Run

```text
cd nimon-backend
node ./node_modules/jest/bin/jest.js src/modules/auth --runInBand
node ./node_modules/jest/bin/jest.js --runInBand
node ./node_modules/@nestjs/cli/bin/nest.js build
```

Results: **auth** suites passed; full **234** tests passed; **`nest build`** succeeded.

## Risks

- **Legitimate stale client** after rotation elsewhere triggers **global refresh revoke** when reuse path runs — acceptable security trade-off for M16B; product may later soften with “refresh families” or grace windows (**M16D**).
- **Concurrent double refresh** with same plain: first tx wins; second tx sees revoked row → 401 (client should single-flight in M16C).
- Access JWT still **not** server-revoked on logout (unchanged; short TTL mitigates).

## Recommended Next Step

**M16C:** Flutter central **401 → refresh (single-flight) → retry**, persist rotated refresh from response, then re-run minimal auth/widget tests if desired.

**M16D:** Optional session metadata, logout-all API, rate limits on `/v1/auth/refresh`.
