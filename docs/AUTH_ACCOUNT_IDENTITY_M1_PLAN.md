# Auth & Account Identity M1 Plan

**Status:** Audit + plan only (no code changes in this task).  
**Parent:** [NIMON_V1_RELEASE_PRIORITY_PLAN.md](NIMON_V1_RELEASE_PRIORITY_PLAN.md) — **M1** is **Auth & account identity**.  
**Related:** [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md).

---

## 1. Current Auth State

### Flutter

- **`LoginScreen`** (`lib/features/auth/login_screen.dart`) is **demo-only**: email/password fields and **Sign up with Google** do **not** call the backend. **LOGIN** and **Guest** both `context.go('/mono')` with a comment *“auth logic TBD”*.
- **`devCurrentUserProvider`** (`lib/features/auth/dev_current_user_provider.dart`) exposes a fixed **`DevCurrentUser.userId`** equal to **`RemoteBackendConfig.devOwnerId`** (compile-time `NIMON_DEV_OWNER_ID`, defaulting to `00000000-0000-0000-0000-000000000001`) so creator basics match the Nest “dev owner” in remote mode.
- **No** `AuthRepository`, **no** session store, **no** `Authorization` header on HTTP clients today.
- **Dependencies** (`pubspec.yaml`): `http`, `shared_preferences` — **no** `flutter_secure_storage` or OAuth packages yet (adding them is an implementation task, not done in this audit doc).

### Backend

- **`AuthModule`** and **`UsersModule`** are **empty** Nest modules (`@Module({})`) — no controllers, no JWT, no password hashing.
- **`story-drafts.service.ts`** resolves **every** `ownerId` for list/get/update/publish via **`getDevOwnerId()`** (`process.env.DEV_OWNER_ID` or default `00000000-0000-0000-0000-000000000001`) and **`ensureDevOwnerUser`**, which **upserts** a `User` row with that **fixed id** if missing.
- **`published-monos.service.ts`** likewise scopes **list** and **getById** to **`getDevOwnerId()`** — not the caller’s identity.
- **Controllers** are **unauthenticated**; there is no global guard on `/v1/story-drafts` or `/v1/published-monos`.

### Prisma

- **`User`** exists with `id`, timestamps, and **optional** `email @unique` — comment in schema: *“optional for V1; auth is not implemented yet”*.
- **`StoryDraft.ownerId`** and **`PublishedMono.ownerId`** are real FKs to **`users.id`**; today those rows are consistently tied to the **dev owner UUID** in typical dev setups.

---

## 2. Release Problem

**`DEV_OWNER_ID` / `NIMON_DEV_OWNER_ID` is a coordination hack, not identity.**

- **Single shared owner:** All creators and readers in production would share one logical user id unless every install ships the same UUID — impossible for multi-tenant safety.
- **No proof of caller:** Any client could hit open APIs; **`ownerId` in request bodies** must not be trusted (`story-drafts.service.ts` already rejects `basics.ownerId` when it disagrees with **`getDevOwnerId()`**, but **`getDevOwnerId()`** itself is still env-driven, not caller-derived).
- **Misconfiguration = silent wrong product behavior:** Documented in **`DEV_RUN_COMMANDS.md`** — Flutter **`NIMON_DEV_OWNER_ID`** and backend **`DEV_OWNER_ID`** mismatch yields **empty Profile → Published** despite successful publish.
- **Compliance / abuse:** Without authentication there is no accountable account, session revocation, or per-user rate limiting tied to identity.

For production, **owner must come from verified session** (e.g. JWT **`sub` = `users.id`**), not from env or client-selected UUIDs.

---

## 3. Recommended V1 Auth Strategy

**Simplest safe V1 path:**

| Piece | Recommendation |
|-------|------------------|
| **Primary credential** | **Email + password** registration and login. |
| **Session** | **JWT access token** (short TTL, e.g. 15–60 minutes). |
| **Refresh** | **Optional but recommended:** opaque **refresh token** stored server-side (see §4) or rotating JWT refresh — enables mobile UX without re-login on every short access expiry. |
| **Google sign-in** | **Phase 2** after email/password is stable — avoids OAuth + App Store / SHA configuration in the same milestone as schema + guards. Document **`POST /v1/auth/google`** as later (§5). |
| **Flutter storage** | **`flutter_secure_storage`** (or platform equivalent) for **access + refresh** tokens — **not** SharedPreferences. |
| **Password storage** | Server: **bcrypt** or **Argon2** — never store plaintext. |

This aligns with **`NIMON_V1_RELEASE_PRIORITY_PLAN.md`** §13 (JWT, guards, SecureStorage) while keeping M1 implementable by a solo developer.

---

## 4. Prisma Schema Plan

### `users` — **exists** (extend)

| Field | Status | Notes |
|-------|--------|--------|
| `id` | **exists** | UUID PK — use as JWT **`sub`**. |
| `email` | **exists** | Make **required** for email/password path (`@unique` already). |
| `passwordHash` | **add** | Nullable until OAuth-only users exist; omit on OAuth-linked-only users if product allows passwordless. |
| `createdAt` / `updatedAt` | **exists** | Keep. |

### `user_profiles` — **add** (1:1 with `User`)

Display fields not mixed into auth row:

- `userId` @id / FK to `users.id` **onDelete Cascade**
- `displayName` String?
- `handle` String? @unique (if product requires unique @handle)
- `avatarUrl` String?
- `bio` String?
- Optional denormalized **`followersCount` / `followingCount`** later (follow milestone — not blocking M1 auth).

### `refresh_tokens` — **add** (if refresh flow used)

- `id` UUID PK
- `userId` FK → `users`
- `tokenHash` (hash of opaque token — store hash only)
- `expiresAt`
- `createdAt`
- `revokedAt` nullable  
Supports **`POST /v1/auth/logout`** by revoking current refresh token(s).

### `oauth_accounts` — **add later** (Google phase)

- `userId`, `provider` (`google`), `providerSubject`, optional `email`, unique `(provider, providerSubject)`

### Already correct without change for M1

- **`story_drafts`**, **`published_monos`** — keep **`ownerId`** FK to **`users.id`**; **no** duplicate “owner email” on drafts.

---

## 5. Backend API Plan

All **REST**, JSON, version prefix **`/v1`**.

| Method | Path | Purpose |
|--------|------|---------|
| **POST** | `/v1/auth/register` | Body: `{ email, password }` → create user, hash password, return **access token** (+ refresh if enabled) + minimal user DTO. **409** if email taken. |
| **POST** | `/v1/auth/login` | Body: `{ email, password }` → **401** on bad credentials. |
| **POST** | `/v1/auth/refresh` | Body: `{ refreshToken }` (if using refresh) → new access token (and rotated refresh if policy requires). |
| **POST** | `/v1/auth/logout` | Optional: revoke refresh token(s) for current device; **Authorization** with access token or body refresh token. |
| **GET** | `/v1/me` | **Bearer** required → `{ user, profile? }` for bootstrap. |

**Later phase (not M1a):**

| **POST** | `/v1/auth/google` | Body: `{ idToken }` → verify with Google, upsert user + `oauth_accounts`, issue JWT. |

**Health** (`GET /health`) remains unauthenticated.

---

## 6. Backend Guard / Ownership Plan

### JWT payload

- **`sub`**: `users.id` (UUID string)
- Standard **`exp`**, **`iat`**; optional **`email`** claim for debugging only — **authorization uses `sub` only**.

### Story drafts (`/v1/story-drafts/**`)

- Apply **`JwtAuthGuard`** (or global guard with `@Public()` on auth routes + health).
- **`ownerId` for all queries and mutations** := **`req.user.id`** from JWT — **remove `getDevOwnerId()`** from production code paths.
- **`createDraft`**: **ignore** any `ownerId` in request body for assignment; set **`ownerId = req.user.id`** only.
- **`updateDraft`**: keep existing check that **`body.basics.ownerId`** (if present) matches server-side owner — or **strip** `ownerId` from client payload entirely in DTO layer so client cannot send it.
- **Development-only:** If **`ALLOW_DEV_OWNER_FALLBACK=true`** (or `NODE_ENV !== 'production'` **and** explicit flag), allow **`DEV_OWNER_ID`** only for local testing **without** JWT — document as **dangerous**; **never** enable in production.

### Published monos (`/v1/published-monos/**`)

- **`list`**: `where: { ownerId: req.user.id }` — user sees **their** published monos for Profile.
- **`getById`**: return row **if** `publishedMono.ownerId === req.user.id` (or add public read path later for catalog — then split **“my published”** vs **public catalog** routes).

### Future routes (saved / follow / reactions)

- Same pattern: **`userId` / `followerId`** from JWT; **never** from unchecked query body for cross-user actions.

---

## 7. Flutter Auth Plan

### `AuthRepository` (new)

- **`register(email, password)`**, **`login(email, password)`**, **`logout()`**, optionally **`refresh()`**.
- Parses responses; persists tokens via session layer; exposes **`Stream` or `AsyncNotifier`** of **`AuthState`** (`unauthenticated` | `authenticated(user)`).

### `SessionProvider` / `authStateProvider`

- Holds **current user id**, **email**, **profile snapshot** from **`GET /v1/me`** after login.
- **Replaces** **`devCurrentUserProvider`** for production code paths: **`SessionUser.userId`** is the only owner id used when wiring **`StoryBasics.creatorOwnerId`** in creator flows.

### SecureStorage

- Keys e.g. `access_token`, `refresh_token` — read on startup before declaring session restored.

### Login screen

- Call **`AuthRepository.login`**; on success navigate to shell (e.g. `/mono`) and **invalidate** draft/profile providers as needed so lists refetch with auth.

### Register screen

- New route **`/register`** (or modal) calling **`register`**; then auto-login or explicit login.

### Logout

- Clear SecureStorage, revoke refresh on server if implemented, set auth state to unauthenticated, **`go('/login')`**, clear in-memory Riverpod caches that contain user data (scoped invalidation per cache policy — avoid global app invalidate).

### App startup session restore

- **`main.dart` / app shell**: before **`MaterialApp.router`**, **`Future`** read tokens → if access valid (or refresh succeeds) → **`authenticated`**; else **guest/unauthenticated** route.

### Replacing `devCurrentUserProvider`

- **Pattern:** `currentUserIdProvider` = `authStateProvider.select((s) => s.user?.id)` with **fallback** only when **`kDebugMode && useLegacyDevOwner`** — remove fallback in release builds (**§12 M1e**).

---

## 8. Remote Repository Changes

Today **`RemoteStoryDraftRepository`** and **`RemotePublishedMonoRepository`** use **`http.Client`** with headers **`Content-Type: application/json`** (and **`If-Match`** where applicable) — **no** `Authorization`.

### Required pattern

- Central **`AuthHttpClient`** or interceptor:

```dart
headers: {
  'Content-Type': 'application/json',
  if (accessToken != null) 'Authorization': 'Bearer $accessToken',
}
```

- **`RemoteStoryDraftRepository`**: inject token getter **`Future<String?> Function()`** or read **`ref.read(sessionProvider).accessToken`** when constructed from a Riverpod-aware factory (avoid circular deps — often **`Provider<http.Client>`** that closes over ref).

- **`RemotePublishedMonoRepository`**: same for **`GET /v1/published-monos`** and **`GET .../:id`**.

- **`basics.ownerId` / `creatorOwnerId`**: should match **`sub`** after auth — either set from **`SessionUser.userId`** on save mapping or **omit** from payload if backend ignores/strips for authenticated routes.

### Future repositories

- Any **`/v1/saved-*`**, **`/v1/users/*/follow`**, catalog endpoints — **same** Bearer rule; **401** → trigger refresh once or logout + login UX.

---

## 9. Migration / Backfill Strategy

**No destructive SQL** in this plan; operations are **additive** and **optional** DBA assistance.

| Situation | Approach |
|-----------|----------|
| **Existing dev `User` row** (`00000000-0000-0000-0000-000000000001`) | Keep for **legacy dev** machines. New registrations create **new** `users.id` values. |
| **Existing `story_drafts` / `published_monos` tied to dev UUID** | **Developers:** continue using old UUID only when logging in as that user is impossible — **after** auth, either (a) one-time **manual** SQL `UPDATE ... SET ownerId = '<new_user_id>'` in **local** DB only with backup, or (b) **abandon** dev data and re-seed. **Do not** ship destructive scripts in app code. |
| **Staging/prod** | First real users have **no** prior rows; migrations add columns/tables only. |
| **Alignment with Flutter** | Remove **`NIMON_DEV_OWNER_ID`** from **release** builds; dev can still pass it only when using **legacy unauthenticated** backend — discouraged once guards land. |

---

## 10. Test Strategy

### Backend (Jest)

| Case | Expectation |
|------|-------------|
| **register** | 201, user created, password hashed; duplicate email **409**. |
| **login** | 200 + JWT; wrong password **401**. |
| **unauthorized** | **GET /v1/me** without `Authorization` → **401**. |
| **story draft owner scoped** | User A creates draft; User B **GET/PUT** same `draftId` → **404** or **403** (draft not found / forbidden). |
| **published monos scoped** | User A’s mono not listed under User B’s token. |

Use **`@nestjs/testing`** with **Prisma** test DB or mocked `PrismaService` per existing **`story-drafts.service.spec.ts`** patterns.

### Flutter

| Case | Expectation |
|------|-------------|
| **Login success** | Mock **`http`** or fake **`AuthRepository`** → navigates, session non-null. |
| **Token persisted** | After login, SecureStorage contains token (mock platform channels in unit tests or use **`flutter_secure_storage` test mocks** when package added). |
| **Session restored** | Startup with stored valid token → **`authenticated`** without login screen. |
| **Logout clears session** | Tokens removed; next API call has no Bearer (or fails **401**). |
| **Repository auth header** | Mock client captures headers — **`Authorization: Bearer`** present on draft/published requests when session active. |

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| **Security** | HTTPS only in prod; short access TTL; refresh rotation; rate-limit login; never log tokens. |
| **Migration** | Developers confused when old drafts “disappear” — document re-seed vs manual owner update; backup DB before any manual `UPDATE`. |
| **Token leakage** | SecureStorage + clear on logout; no tokens in `debugPrint` in release. |
| **Google sign-in** | Deferred — reduces scope; when added, verify `id_token` server-side only. |
| **Owner mismatch** | Strip client `ownerId`; single source from JWT; integration tests for A/B isolation. |
| **Dual mode** | **`DEV_OWNER_ID`** fallback vs JWT — risk of shipping fallback enabled; **fail CI** if production env contains `ALLOW_DEV_OWNER_FALLBACK`. |

---

## 12. Implementation Milestones

| ID | Scope |
|----|--------|
| **M1a** | Prisma: `passwordHash`, `user_profiles`, optional `refresh_tokens`; Nest: **`@nestjs/jwt`**, **`passport-jwt`** (or manual JWT), **`AuthService`** register/login, **`AuthController`**, **`/v1/me`**, bcrypt — **no** guards on drafts yet. |
| **M1b** | **`JwtAuthGuard`**; refactor **`StoryDraftsService`** / **`PublishedMonosService`** to accept **`userId: string`** from guard; remove **`getDevOwnerId()`** from prod paths; optional dev flag. |
| **M1c** | Flutter: add **`flutter_secure_storage`**, **`AuthRepository`**, **`sessionProvider`**, startup restore; **no** UI polish required beyond minimal. |
| **M1d** | **`login_screen`** / **`register`** wiring, error states, **`go_router`** redirect unauthenticated → `/login`. |
| **M1e** | Release flavor: no **`NIMON_DEV_OWNER_ID`** requirement; **`RemoteStoryDraftRepository`** uses Bearer; **`devCurrentUserProvider`** deprecated or debug-only. |
| **M1f** | Tests (§10), **`README.md`** / **`DEV_RUN_COMMANDS.md`** update for auth env vars; remove stale “empty Published” workaround copy where obsolete. |

---

## 13. Exact Cursor Prompt For M1a

Use as a single implementation task (backend only; migrations allowed in implementation work — **not** part of this audit task):

> **M1a — Backend schema + auth service (Nimon)**  
>  
> 1. **Prisma:** Extend `User` with `passwordHash String?` (or required after registration-only flow). Add `UserProfile` model (`userId` FK → `User`, `displayName`, `handle`, `avatarUrl`, timestamps). Optionally add `RefreshToken` model (`userId`, `tokenHash`, `expiresAt`, `revokedAt`). Run `prisma migrate dev` with a descriptive migration name.  
> 2. **Dependencies:** Add `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt` (and types).  
> 3. **Auth module:** Implement `AuthService` with `register({ email, password })` and `login({ email, password })` — hash with bcrypt cost factor appropriate for 2025; return `{ accessToken, refreshToken? }` + user id + email. Issue JWT with `sub = user.id`, `exp` ~15–60 min. If refresh tokens: persist hashed refresh in DB.  
> 4. **Controllers:** `POST /v1/auth/register`, `POST /v1/auth/login`, optional `POST /v1/auth/refresh`, `GET /v1/me` (JWT guard). Use `class-validator` DTOs.  
> 5. **Do not** attach guards to `story-drafts` or `published-monos` yet (M1b). Keep existing `DEV_OWNER_ID` behavior unchanged until M1b.  
> 6. **Tests:** Unit tests for `AuthService` (register duplicate email, login wrong password, JWT contains correct `sub`).  
> 7. Document new env vars: `JWT_SECRET`, `JWT_EXPIRES_IN`, optional refresh secret/TTL.  
>  
> Follow existing Nest module layout under `nimon-backend/src/modules/auth/`. Do not change Flutter in this task.

---

### Output summary

| Question | Answer |
|----------|--------|
| **Recommended auth strategy** | **Email/password + JWT access** (+ optional **refresh token** in DB); **SecureStorage** on Flutter; **ownerId = JWT `sub`** on all guarded routes. |
| **Google sign-in now or later?** | **Later (phase 2)** — ship **`POST /v1/auth/google`** after email/password is stable. |
| **Prisma changes needed** | **Extend `User`** (`passwordHash`, required `email` for password users); **add `UserProfile`**; **optional `RefreshToken`**; **later `OAuthAccount`** for Google. |
| **Backend routes needed** | **`POST /v1/auth/register`**, **`POST /v1/auth/login`**, optional **`/refresh`**, **`/logout`**, **`GET /v1/me`**; **`/auth/google`** deferred. |
| **Flutter files likely to change** | **`lib/features/auth/login_screen.dart`**, new **`register_screen`**, **`dev_current_user_provider.dart`** (replace/supersede), **`main.dart`** (session bootstrap), **`RemoteStoryDraftRepository`**, **`RemotePublishedMonoRepository`**, **`story_creator_provider.dart`** (owner id from session), **`go_router`** config, **`profile_navigation_drawer.dart`** (logout). **`pubspec.yaml`** when adding **`flutter_secure_storage`**. |
| **Biggest risk** | **Shipping with `DEV_OWNER_ID` fallback enabled** or trusting client-supplied **`ownerId`** — mitigated by M1b guards and stripping owner from DTOs. |
| **First implementation step** | **M1a** — Prisma auth-related fields + **`AuthService`** + register/login/**`/me`** endpoints (**§13 prompt**), then M1b guards. |
