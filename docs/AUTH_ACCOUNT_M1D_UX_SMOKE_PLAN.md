# Auth Account M1d UX Smoke Plan

**Status:** Plan / audit only (no code changes in this document).  
**Prerequisites:** M1a (backend auth), M1b (guards + owner scoping), M1c (Flutter client + Bearer).  
**Related:** [AUTH_ACCOUNT_M1A_FINAL_VERIFY_REPORT.md](AUTH_ACCOUNT_M1A_FINAL_VERIFY_REPORT.md), [AUTH_ACCOUNT_M1B_GUARDS_OWNER_SCOPING_REPORT.md](AUTH_ACCOUNT_M1B_GUARDS_OWNER_SCOPING_REPORT.md), [AUTH_ACCOUNT_M1C_FLUTTER_CLIENT_REPORT.md](AUTH_ACCOUNT_M1C_FLUTTER_CLIENT_REPORT.md), [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md).

---

## 1. Current Auth Flow

### Login

- **`LoginScreen`** (`lib/features/auth/login_screen.dart`): user enters email/password → **`authSessionProvider.notifier.login`** → **`AuthRepository.login`** (`POST /v1/auth/login`) → **`SecureAuthTokenStore.writeTokens`** → **`GET /v1/me`** → state **`AuthSessionAuthenticated`** → navigate **`context.go('/mono')`**.
- Errors surface as **`AuthRepositoryException`** with raw HTTP body / message shown inline.

### Register

- **`RegisterScreen`** (`lib/features/auth/register_screen.dart`): **`register`** → **`POST /v1/auth/register`** → same token persist + **`getMe`** + **`/mono`** as login.

### Token storage

- **`SecureAuthTokenStore`** persists **access** and **refresh** via **`flutter_secure_storage`** (keys `nimon_auth_access_token_v1`, `nimon_auth_refresh_token_v1`). Tokens are **not** in SharedPreferences.

### Session restore

- **`NimonApp`** (`lib/main.dart`): first frame calls **`authSessionProvider.notifier.restoreSession()`** → read tokens → **`getMe`**; on failure attempt **`refresh`**; else **`clearTokens`** and unauthenticated state.
- Router **does not** auto-redirect by auth state today; initial route remains **`/login`** per **`GoRouter`** config unless user navigates elsewhere.

### Bearer on guarded repositories

- **`authHeaderBuilderProvider`** reads the store and supplies **`Authorization: Bearer <access>`**.
- **`RemoteStoryDraftRepository`** and **`RemotePublishedMonoRepository`** merge those headers on **every** HTTP call when wired from **`storyDraftRepositoryProvider`** / **`remotePublishedMonoRepositoryForProfileProvider`**.
- **Owner id** for creator normalization: **`currentUserIdProvider`** → JWT **`user.id`** when authenticated, else **`devCurrentUserProvider`** (`NIMON_DEV_OWNER_ID`).

### Profile “Sign out” (gap)

- **`profile_navigation_drawer.dart`** exposes a **Sign out** tile that confirms and then **`router.go('/login')`** only. It does **not** invoke **`AuthSessionNotifier.logout()`**, so **SecureStorage tokens may remain** after “sign out” until a future M1d wires **`logout()`** (server revoke + local clear). This is a **required M1d fix** for coherent auth UX.

---

## 2. Missing UX Pieces

| Gap | Notes |
|-----|--------|
| **Logout access point wired to auth** | UI exists (drawer **Sign out**) but must call **`logout()`** + navigate; optionally duplicate in **Settings** for discoverability. |
| **Expired / invalid access token UX** | In-flight API **401** does not automatically trigger **`refresh`** + retry in repositories today; **`restoreSession`** refreshes on cold start only. Users may see opaque **`StateError` / HTTP …** in strict remote mode. |
| **Guest + remote mode warning** | **Guest >>** goes to **`/mono`** without tokens. With **`NIMON_USE_REMOTE_DRAFTS=true`** and no backend **`ALLOW_DEV_OWNER_FALLBACK`**, guarded routes **401**. No in-app banner explains this. |
| **Register validation polish** | Minimal fields; no client-side password strength, email format feedback beyond API errors. |
| **Login error messaging** | **`AuthRepositoryException.message`** may be raw JSON; no mapping to friendly codes (e.g. invalid credentials). |
| **Profile / account display** | No prominent **email / displayName / handle** from **`/v1/me`** in Profile header or Settings; user cannot see “who is logged in” without inferring from behavior. |
| **Loading state on app startup** | **`restoreSession`** sets **`AuthSessionLoading`** but there is **no global splash / blocker**; user may tap **Guest** or **LOGIN** before restore completes (usually harmless but can confuse testers). |
| **Post-logout navigation semantics** | Should land on **`/login`** with **cleared** session; optional **“don’t restore stale session”** if **`logout`** already cleared storage. |

---

## 3. Required Smoke Test Flow

Manual checklist for **release confidence** (execute in order).

| Step | Pass criteria |
|------|----------------|
| **1. Backend running** | Nest listens (e.g. `:3000`); **`GET /v1/health`** or equivalent sanity if present; otherwise login/register responds. |
| **2. Postgres up** | **`DATABASE_URL`** valid; no connection errors in Nest logs. |
| **3. Flutter remote strict** | App built with **`NIMON_USE_REMOTE_DRAFTS=true`** and **`NIMON_STRICT_REMOTE_DRAFTS=true`** (and correct **`NIMON_API_BASE_URL`** for device vs host). |
| **4. Register new user** | Completes without error; lands on **`/mono`**. |
| **5. Create story** | Creator flow creates a draft (local + remote sync when remote mode on). |
| **6. Save draft** | With remote + strict: save completes without throw; optional **Prisma Studio** shows **`story_drafts`** row for logged-in user’s **`ownerId`**. |
| **7. Publish read-only** | Publish path succeeds; draft shows published state per UI; **`published_monos`** row exists for same owner. |
| **8. Profile Published** | **Uploaded / Published** tab lists the published mono (Bearer + owner scope). |
| **9. App restart** | Kill app; relaunch → **`restoreSession`** → still authenticated (tokens + **`getMe`** ok); lands appropriately (may still show **`/login`** until router auth redirect exists—note current behavior). |
| **10. Logout** | After M1d wiring: **Sign out** → tokens cleared; **`SecureStorage`** empty for auth keys. |
| **11. After logout** | Story-drafts / published-monos calls **401** (or user stays on login); **no** silent success on guarded APIs. |

**Android emulator:** add **`--dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000`**.

---

## 4. Backend Runtime Checklist

From **[DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md)** and **`nimon-backend/package.json`**:

| Action | Command (typical) |
|--------|---------------------|
| Start Postgres | `cd nimon-backend` → `docker compose up -d postgres` (or `docker start nimon-postgres` if existing). |
| Configure DB | **`nimon-backend/.env`**: valid **`DATABASE_URL`**, **`JWT_SECRET`** for local dev. |
| Install & run API | `npm install` → **`npm run start:dev`**. |
| Migrate status | **`npm run prisma:migrate:status`** (or project’s Prisma script alias). |
| Optional Studio | **`npm run prisma:studio`**. |

**Note:** This plan does **not** run migrations; smoke tests assume DB schema already matches team baseline.

---

## 5. Flutter Runtime Commands

**Local-first (no remote sync):**

```bash
cd <repo-root>
flutter pub get
flutter run
```

**Remote drafts + strict (recommended for M1d smoke):**

```bash
flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true
```

**Android emulator → host API:**

```bash
flutter run \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true \
  --dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000
```

See **[NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md)** for mode semantics.

---

## 6. Recommended M1d Implementation Scope

Minimal, shippable UX (no Google OAuth).

1. **Wire drawer Sign out to real logout**  
   On confirm: **`await ref.read(authSessionProvider.notifier).logout()`**, then **`context.go('/login')`**. Ensures server **`POST /v1/auth/logout`** (refresh revoke) + **`clearTokens`**.

2. **Optional: Settings row**  
   “Account” / “Sign out” duplicate for users who do not open Profile drawer.

3. **Auth identity snippet**  
   In Profile drawer header or Settings: show **`AuthUser.email`** (and **`displayName`** if non-null) from **`authSessionProvider`** when **`AuthSessionAuthenticated`**.

4. **Expired / invalid session handling (minimal)**  
   - Option A: centralized **`http.Client`** wrapper that on **401** for **`/v1/story-drafts`** / **`/v1/published-monos`** calls **`refresh`** once and retries (larger change).  
   - Option B (smaller): on known **401** from repositories in strict mode, **`clearTokens`**, **`AuthSessionUnauthenticated`**, **SnackBar** “Session expired — log in again”, **`go('/login')`**.

5. **Guest + remote warning**  
   If **`RemoteBackendConfig.useRemoteDrafts`** and **`authSessionProvider`** is not authenticated, show a **one-line banner** on **`/mono`** or creator entry: “Remote drafts require sign-in” (or only when first remote call fails).

6. **Startup**  
   Optional **short** splash or ignore input until **`restoreSession`** completes **or** document that QA waits ~1s before tapping Guest.

**Out of scope for M1d:** Google sign-in, follow/saved/react, Drift migration, router mega-refactor.

---

## 7. Tests Needed

| Layer | Test |
|-------|------|
| **Unit** | Widget/integration-style test: after **`logout()`**, **`SecureAuthTokenStore`** / overridden store has **no** tokens (extends existing **`InMemoryAuthTokenStore`** pattern). |
| **Widget** | Login/register: empty fields show validation; API error shows message (golden or pump). |
| **Session** | **`restoreSession`** with valid stored tokens yields **`AuthSessionAuthenticated`**; corrupt tokens → unauthenticated. |
| **Manual** | Full smoke checklist in §3 with **strict remote** on real device/emulator. |

Existing **93** Flutter tests remain regression gates; add targeted tests only for new M1d surfaces.

---

## 8. Risks

| Risk | Impact |
|------|--------|
| **Sign out without clearing tokens** | Next **`restoreSession`** may **re-login** user unexpectedly → privacy / QA confusion. **Fix in M1d.** |
| **401 mid-session** | Users see harsh errors in **strict** mode; may lose unsynced local edits if they misunderstand. |
| **Guest + remote** | Silent failures or empty Profile until user understands login requirement. |
| **Refresh token reuse** | Revoked refresh after logout should fail; ensure **`logout`** called when possible. |
| **Router vs session** | **`initialLocation: /login`** without auth-aware redirect can confuse “am I logged in?” until UI shows identity. |

---

## 9. Exact Cursor Prompt For M1d Implementation

Copy-paste for a focused implementation pass:

```text
Implement M1d — auth UX only (minimal code). Do not modify nimon-backend, database schema, or unrelated refactors.

Goals:
1. Wire Profile drawer Sign out (lib/features/profile/profile_navigation_drawer.dart) to call
   ref.read(authSessionProvider.notifier).logout() before navigating to /login.
   Ensure SecureStorage tokens are cleared (logout already clears in AuthSessionNotifier).

2. Optionally add a duplicate “Sign out” or Account section in lib/features/settings/settings_screen.dart
   that calls the same logout + go('/login').

3. Show authenticated user identity (email from AuthSessionAuthenticated / AuthUser) in Profile drawer
   header area OR Settings — minimal text row; no new backend fields.

4. Minimal expired-session UX: when RemoteBackendConfig.strictRemoteDrafts is true and a guarded API
   returns 401, clear session tokens via AuthSessionNotifier or token store, set unauthenticated state,
   snackbar “Session expired — sign in again”, navigate to /login. Prefer a small helper or repository
   hook; avoid rewriting all HTTP.

5. When NIMON_USE_REMOTE_DRAFTS is true and user is not authenticated, show a dismissible banner on
   Mono shell or first creator entry explaining remote drafts require sign-in (Guest bypasses tokens).

6. Add/update tests: logout clears tokens (use InMemoryAuthTokenStore override); widget test for
   sign-out flow if feasible.

7. Update docs/AUTH_ACCOUNT_M1D_UX_SMOKE_PLAN.md implementation status or add AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md
   only if the user wants a report.

Constraints: no Google OAuth, no Drift migration, no changes to backend routes.
Run: dart format on touched files, flutter analyze on touched paths, flutter test.
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Logout UI needed?** | **Yes — wiring**: drawer UI exists but must call **`logout()`** so tokens clear; optional Settings duplicate. |
| **Expired token UX needed?** | **Yes** — at least **clear + redirect + message** on **401** in strict remote; optional refresh-retry later. |
| **Guest remote mode warning needed?** | **Yes** — avoids silent **401** confusion when **`NIMON_USE_REMOTE_DRAFTS=true`**. |
| **Recommended first M1d implementation** | **(1)** Wire **`logout()`** on drawer Sign out **`+`** **`go('/login')`**. **(2)** Show **email** from session in Profile or Settings. **(3)** Banner for guest+remote. **(4)** Minimal **401** handler. |
| **Manual smoke checklist ready?** | **Yes** — see **§3** and **§5** commands. |
