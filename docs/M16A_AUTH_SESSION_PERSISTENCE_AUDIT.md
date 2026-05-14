# M16A Auth Session Persistence Audit

## Problem

The Nimon mobile app is perceived to **log users out after a short time**, which hurts UX. This milestone is **audit only**: map the current backend + Flutter auth/session behavior against common industry practice (OWASP-oriented) before any code or config changes.

## Research Basis

Findings below are compared informally to widely recommended patterns from:

- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — short-lived server-verified sessions, secure storage, rotation, explicit logout/revocation, minimize session fixation.
- [OWASP OAuth 2.0 Security Best Current Practice](https://cheatsheetseries.owasp.org/cheatsheets/OAuth2_Cheat_Sheet.html) — refresh token handling, rotation, reuse detection for public/native clients.
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html) — validate `exp`, avoid long-lived JWTs as sole session, pair with refresh where appropriate.
- **Flutter:** [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) — platform keychain/Keystore-backed storage for secrets.
- **NestJS:** [`@nestjs/jwt`](https://docs.nestjs.com/security/authentication) + Passport JWT — access token signing and validation; refresh flows are application-defined.

Repo docs consulted (no code edits): `AUTH_ACCOUNT_M1C_FLUTTER_CLIENT_REPORT.md`, `M13C_PROTECTED_ACTION_CONNECTIVITY_REPORT.md`, `M13D_CONNECTIVITY_LIVE_WIRING_REPORT.md`.

---

## Backend Current State

### 1. Token types issued

| Artifact | Type | Notes |
|----------|------|--------|
| **Access** | **JWT** (HS256) | Payload: `sub` (user id), `email`. From `JwtService.signAsync` in `auth.service.ts`. |
| **Refresh** | **Opaque random** (48 bytes, `base64url`) | Never stored plaintext in DB; **SHA-256 hex** in `RefreshToken.tokenHash`. |
| **Session cookie** | **No** | Bearer JWT in `Authorization` header. |

### 2. Access token expiry

| Source | Value |
|--------|--------|
| **Env** | `JWT_EXPIRES_IN` (see `nimon-backend/.env.example`: `JWT_EXPIRES_IN=15m`) |
| **Code default** | `'15m'` if env missing — `resolveAccessExpiresIn()` in `auth.config.ts` |
| **Where applied** | `JwtModule.registerAsync` → `signOptions.expiresIn` in `auth.module.ts` |

### 3. Refresh token

| Question | Answer |
|----------|--------|
| **Exists?** | **Yes.** |
| **Lifetime** | `JWT_REFRESH_EXPIRES_IN` interpreted as **seconds** (integer). Default **604800** (7 days) if unset — `resolveRefreshExpiresSeconds()` in `auth.config.ts`. Documented in `.env.example`. |
| **Where stored (server)** | Prisma model **`RefreshToken`**: `tokenHash` (unique), `expiresAt`, `revokedAt`, `userId`, timestamps. **No** `deviceId`, `lastUsedAt`, or `tokenVersion` columns. |
| **Rotation on refresh?** | **No.** `AuthService.refresh()` validates the row, mints a **new access** JWT, and returns the **same** `refreshTokenPlain` string. DB row is **not** replaced or re-hashed on refresh. |
| **Revoked on logout?** | **Yes.** `logout()` sets `revokedAt` for matching `tokenHash`. |
| **Replay / reuse detection?** | **No explicit reuse attack handling.** Because the same refresh string is always valid until expiry/revoke, a **stolen refresh** remains usable for the full window. Rotating to a new refresh and invalidating the old one on each use is **not** implemented. |
| **Login behavior** | `login()` **revokes all** non-revoked, non-expired refresh rows for that `userId`, then creates **one** new refresh row (good for session fixation / “new login kills old sessions”). |
| **Register behavior** | Creates initial refresh row in a transaction; does **not** revoke other rows (first login for new user). |

### 4. Server-side session table

**Yes — `RefreshToken`** (see `prisma/schema.prisma`):

- `id`, `userId`, `tokenHash` (@unique), `expiresAt`, `revokedAt?`, `createdAt`
- **No** separate `UserSession` / `AuthSession` model, **no** `deviceId`, **no** `lastUsedAt`, **no** `tokenVersion` for invalidating all access JWTs.

### 5. Logout

| Layer | Behavior |
|-------|----------|
| **API** | `POST /v1/auth/logout` with body `{ refreshToken }` → `AuthService.logout` → `updateMany` set `revokedAt`. HTTP **204** on success (`auth.controller.ts`). |
| **Access JWT** | **Not** blacklisted server-side; an access JWT remains valid until its **`exp`** (Passport JWT `ignoreExpiration: false` in `jwt.strategy.ts`). |

### 6. Guards / validation

| Guard / strategy | Behavior |
|------------------|----------|
| **`JwtStrategy`** | `ExtractJwt.fromAuthHeaderAsBearerToken()`, `ignoreExpiration: false`, validates signature + **`exp`**, then loads `User` by `sub`; rejects if user missing. **No** `RefreshToken` lookup on each request. |
| **`JwtAuthGuard`** | Standard Passport `AuthGuard('jwt')` — used on `/v1/me*`. |
| **`OptionalJwtUserGuard`** | If Bearer present, `jwt.verify` + user lookup; on any error **allows guest** (no 401). |
| **`JwtOrDevOwnerFallbackGuard`** | JWT path same idea; optional dev owner fallback when not production + env flag. |

### 7. Access token expired

| Aspect | Behavior |
|--------|----------|
| **Protected routes** | Expired/invalid JWT → **401 Unauthorized** (Nest/Passport default). No custom `access_expired` code observed in auth module. |
| **Body shape** | Standard Nest `UnauthorizedException` (not a dedicated JSON error contract in the audited files). |

---

## Flutter Current State

### 1. Access token storage

**`flutter_secure_storage`** — `SecureAuthTokenStore` keys `nimon_auth_access_token_v1` / `nimon_auth_refresh_token_v1` (`auth_token_store.dart`). Android uses `encryptedSharedPreferences: true`. **Not** `SharedPreferences` for tokens (per M1c report).

### 2. Refresh token storage

**Yes** — same secure store as access.

### 3. App startup / restore

**`NimonApp.initState`** (post-frame): registers `AuthSessionExpiredBridge`, then **`restoreSession()`** (`main.dart`).

**`AuthSessionNotifier.restoreSession()`** (`auth_session_notifier.dart`):

1. Read tokens from secure store; if both empty → unauthenticated.
2. **`getMe(accessToken)`**; if failure **and** refresh non-empty → **`refresh(refreshToken)`**, **persist** returned pair, **`getMe`** again.
3. If still no user → **`clearTokens()`** + unauthenticated.
4. On any unexpected exception → clear + unauthenticated.

**Important nuance:** Refresh is attempted when **`getMe` fails** (any `AuthRepositoryException`), **not** only when JWT decode says expired — so network errors can also trigger refresh attempt.

### 4. HTTP client / attaching auth

- **No global Dio-style interceptor** in the audited tree.
- **`authHeaderBuilderProvider`**: async closure reads store → `Authorization: Bearer <access>` if access non-empty (`auth_providers.dart`).
- **Repositories** (e.g. `RemoteStoryDraftRepository`, `RemotePublishedMonoRepository`, profile/settings repos) merge headers from optional builders passed at construction (DI from Riverpod).

### 5. Handling 401

| Path | Behavior |
|------|----------|
| **General API** | Repositories typically throw on non-2xx (`_throwIfNotOk` patterns). **No** automatic “refresh then retry” on 401 in the audited HTTP layer. |
| **Strict remote + 401** | If `RemoteBackendConfig.strictRemoteDrafts` is **true**, several repos call **`notifyIfStrictUnauthorized401(r)`** (`auth_strict_unauthorized.dart`). That triggers the bridge → **`forceSessionExpired()`** (clears tokens, unauthenticated) + SnackBar + **`GoRouter.go('/login')`** (`main.dart`). **Default** `strictRemoteDrafts` is **false** — so in typical release/dev without dart-define, **401 does not** go through this bridge. |

### 6. Timer-based logout

**None found** under `lib/features/auth` (no periodic expiry timer or JWT decode for proactive refresh).

### 7. Protected actions / guest

- **`protected_action_guard.dart`** (M13C): uses `authSessionProvider` + connectivity; guest sees login prompt for gated actions.
- **Session state vs token reality:** Riverpod can remain **`AuthSessionAuthenticated`** while the **persisted access JWT is expired** (no proactive refresh). The next **Bearer** request sends the expired token → **401** from API. Unless strict bridge fires, the user may see **raw HTTP errors** rather than a clean “session extended” flow.

---

## Current Expiry / Reproduction (trace only — no code)

Suggested manual trace (no logging added in M16A):

1. **Login** in the app; confirm network response includes `accessToken` + `refreshToken`.
2. **Decode access JWT** (e.g. jwt.io locally) and note **`exp`** — should align with **`JWT_EXPIRES_IN`** (default **15 minutes** from issuance).
3. **Wait** until after `exp` (or temporarily use a shorter `JWT_EXPIRES_IN` in a local backend only if you control env — **out of scope for committed M16A**).
4. Trigger an authenticated call that sends **`Authorization: Bearer`** (e.g. open profile remote tab, save draft with remote on).
5. **Observe:** backend **401**; Flutter throws/presents error per repo; **Riverpod** may still show authenticated until something clears session; **strict** mode would force login via bridge.

Cold start after access expiry but **before** refresh expiry: **`restoreSession`** should call **`getMe` → fail → `refresh` → succeed** and restore user — if refresh still valid.

---

## Gap vs Best Practice

| Practice (target) | Nimon today |
|-------------------|-------------|
| Short-lived access JWT | **Yes** (~15m default). |
| Long-lived refresh | **Yes** (opaque, default 7d). |
| **Refresh rotation** + server-side family invalidation on reuse | **No** — same refresh string and DB row across refreshes. |
| Server stores **hashed** refresh | **Yes.** |
| Logout revokes refresh | **Yes** (row `revokedAt`). |
| Access invalid immediately on logout | **No** — JWT valid until natural **exp** (no server-side access revocation list). |
| Client **401 → single-flight refresh → retry** | **No** — not implemented in shared HTTP layer. |
| Proactive refresh before `exp` | **No.** |
| Clear auth only after refresh fails | **Partially** — true on **bootstrap**; during runtime, **no** unified refresh-on-401, so UX depends on each feature’s error handling. |
| Secure storage for tokens | **Yes** (`flutter_secure_storage`). |

**Primary UX gap:** **Access token lifetime (~15m)** combined with **no automatic refresh-and-retry** on API 401 means the app **feels** like it “logs out” or breaks soon after login during active use, even though the **refresh token may still be valid for days**.

Secondary gap: **no refresh rotation / reuse detection** — weaker alignment with OWASP OAuth BCP for native clients.

---

## Recommended Session Model (evaluation)

Industry-style **V1** target (as in the task brief):

- **Access:** ~**15 minutes** (already aligned).
- **Refresh:** **~30 days** (product choice; today default is **7 days** in backend code unless env overrides).
- **Rotation:** new refresh on every refresh response; old refresh row revoked; **detect reuse** of old refresh as potential theft.
- **Server:** hashed refresh + metadata (`deviceId` optional later).
- **Logout:** revoke current refresh (+ optional “logout all devices”).
- **401 flow:** client attempts **one** coordinated refresh, retries failed request, logs out only if refresh fails.
- **Startup:** load from secure storage → refresh if access missing/expired → `/v1/me` → authenticated state.

**Guest mode** remains compatible: optional JWT routes and `currentUserIdProvider` dev fallback stay orthogonal.

**Protected actions (M13C):** should ideally treat “needs login” only when **no valid session after refresh**, not merely when Riverpod still holds a stale authenticated state — may need tighter coupling once M16C exists.

This model is **appropriate for Nimon V1** if product accepts operational complexity (rotation, tests, concurrency).

---

## Product / Security Decisions (for later milestones)

1. **Access JWT lifetime** — keep 15m vs shorten/extend.
2. **Refresh lifetime** — 7d vs 30d vs sliding.
3. **Absolute max session** — cap wall-clock session regardless of refresh activity?
4. **Idle timeout** — V1 none vs server-side `lastUsedAt` policy later.
5. **Max concurrent refresh sessions per user** — unlimited vs cap.
6. **Logout** — current device only (revoke one row) vs **logout all** (revoke all rows for user).
7. **Refresh storage on device** — already secure store; confirm iOS/Android backup/export policies if needed.
8. **Rotation strategy** — strict one-time use vs grace window for network duplicates.
9. **Schema** — extend `RefreshToken` vs new `UserSession` table with metadata.
10. **Stolen refresh** — rotation + reuse detection; optional binding to app attestation later.

---

## Proposed Implementation Milestones (no code in M16A)

### M16B — Backend refresh session foundation

- Prisma: optional columns (`lastUsedAt`, `replacedById`, `deviceLabel`, etc.) as needed for rotation/replay.
- **Login/register/refresh:** issue new access; on refresh **mint new opaque refresh**, revoke or supersede old row, return new pair.
- **`POST /v1/auth/refresh`:** document error codes (`invalid_refresh`, `reuse_detected`) if product wants structured clients.
- **`POST /v1/auth/logout`:** keep revoke; optional `logout_all`.
- **Tests:** rotation, reuse rejection, logout revoke, expired refresh.

### M16C — Flutter token storage + refresh coordination

- Keep secure storage; add **single-flight** refresh lock (mutex) for concurrent 401s.
- **401 interceptor layer** (central `http` wrapper or thin client) for repos that use Bearer auth: refresh → update store → **retry once**.
- **Bootstrap:** optionally decode JWT `exp` (without trusting it alone) to refresh **before** first `getMe` if near expiry.
- **Logout:** unchanged contract; ensure refresh failure clears state consistently.
- **Tests:** restore after restart, refresh on 401, single refresh under concurrency, guest unchanged.

### M16D — Device / session polish (optional)

- List/revoke sessions API; “logout all devices”; admin/security docs; hardening (rate limits on refresh — backend).

---

## Tests Needed (later)

**Backend** (illustrative):

- Login/register return access + refresh; refresh returns **new** refresh; old refresh fails.
- Reused refresh after rotation → **401** / specific error.
- Logout revokes; subsequent refresh fails.
- Expired refresh fails.
- Protected route works with newly issued access after refresh.

**Flutter** (illustrative):

- Cold start with expired access + valid refresh → authenticated after restore.
- API 401 → refresh success → original request succeeds.
- Refresh failure → logged out + storage cleared.
- Parallel 401s → **one** refresh.
- Guest flows unchanged; M13C prompts only where appropriate after refresh failure.

---

## Risks

- **Changing refresh semantics** (rotation) **breaks** any old app builds that expect the same refresh string forever — coordinate client/server release.
- **Single-flight refresh** is easy to get wrong (deadlocks, infinite retry); needs tight test coverage.
- **JWT access** still cannot be revoked instantly without denylist or very short TTL — product must accept **≤15m** exposure after password change/logout unless adding access revocation machinery.

---

## Part I — Output Summary

| Question | Answer |
|----------|--------|
| **Current access token expiry?** | **`JWT_EXPIRES_IN`**, default **`15m`** (`auth.config.ts`, `.env.example`, `auth.module.ts`). |
| **Refresh token exists?** | **Yes** — opaque, server hashed in **`RefreshToken`**, client in **secure storage**. |
| **Server-side session exists?** | **Yes** — **`RefreshToken`** rows (not a full session table with device metadata). |
| **Token storage method?** | **`flutter_secure_storage`** for access + refresh. |
| **App startup restore?** | **`restoreSession()`**: `getMe` → on failure **`refresh`** → persist → `getMe` again; else clear. |
| **401 handling?** | **Generally: no auto-refresh**; strict remote flag enables **immediate clear + `/login`** via **`AuthSessionExpiredBridge`**. |
| **Root cause of “quick logout”?** | **Short access JWT without runtime refresh-and-retry**; UI/session can stay “logged in” while APIs start returning **401**; user experience matches “kicked out” or broken saves. |
| **Recommended session model?** | **Short access + long refresh + rotation + server revoke + client 401 refresh queue + startup refresh-if-needed** (see gaps table). |
| **Backend changes needed?** | **Yes for industry-complete:** refresh **rotation**, optional **reuse detection**, optional **metadata**, structured errors; **not** required for minimal “refresh on 401” if server already returns same refresh (but rotation is still strongly recommended). |
| **Flutter changes needed?** | **Yes:** centralized **401 → refresh → retry**, optional **proactive** refresh, **single-flight** lock; possibly tighten protected-action vs token skew. |
| **Split M16B / M16C / M16D?** | **Yes** — backend contract + rotation first (**M16B**), client interceptor + bootstrap (**M16C**), optional session UX (**M16D**). |

---

*M16A: audit complete. No application code, schema, expiry, guards, or UI were modified.*
