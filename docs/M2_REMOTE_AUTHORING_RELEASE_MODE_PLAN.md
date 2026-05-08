# M2 Remote Authoring Release Mode Plan

**Status:** Plan / audit only (no code changes in this document).  
**Parent:** [NIMON_V1_RELEASE_PRIORITY_PLAN.md](NIMON_V1_RELEASE_PRIORITY_PLAN.md) — M1 auth + guards + client are **complete**; this document pins **how** the product should ship “remote authoring” (sync to Postgres) vs local demo.

**Related:** [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md), [AUTH_ACCOUNT_M1B_GUARDS_OWNER_SCOPING_REPORT.md](AUTH_ACCOUNT_M1B_GUARDS_OWNER_SCOPING_REPORT.md), [AUTH_ACCOUNT_M1C_FLUTTER_CLIENT_REPORT.md](AUTH_ACCOUNT_M1C_FLUTTER_CLIENT_REPORT.md), [AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md](AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md), [AUTH_REGISTER_UX_FIX_REPORT.md](AUTH_REGISTER_UX_FIX_REPORT.md).

---

## 1. Current Mode Behavior

### Local-first mode (default)

- **`NIMON_USE_REMOTE_DRAFTS`** omitted or **`false`** (`remote_backend_config.dart`).
- **`storyDraftRepositoryProvider`** → **`LocalStoryDraftRepository`** — drafts live in **SharedPreferences** via creator storage.
- **Postgres / Prisma Studio:** **do not** reflect creator edits (expected).
- **Auth:** Irrelevant for **persisting** drafts to the server; user may still **login** for Profile identity, but draft rows are not synced.

### Remote draft mode

- **`NIMON_USE_REMOTE_DRAFTS=true`** → **`RemoteStoryDraftRepository`**.
- **Persistence:** Local-first **then** HTTP sync (`PUT` story-drafts, publish endpoints per lifecycle standard).
- **Bearer JWT:** Required for **`/v1/story-drafts`** and **`/v1/published-monos`** (M1b guards).
- **`authHeaderBuilderProvider`** attaches **`Authorization: Bearer <access>`** (M1c).
- **Owner id:** **`currentUserIdProvider`** → JWT user id when **`AuthSessionAuthenticated`**, else **`devCurrentUserProvider`** (`NIMON_DEV_OWNER_ID` compile-time default).

### Strict remote mode

- **`NIMON_STRICT_REMOTE_DRAFTS=true`** **and** remote drafts **on**.
- Remote failures **throw** instead of silently masking with local-only success paths (`RemoteStoryDraftRepository` / published repo behavior).
- **Use:** Integration QA, staging gates, debugging contract/ETag issues.

### Guest behavior

- **Guest** (`AuthSessionUnauthenticated` / not logged in): **no** access tokens in SecureStorage.
- **Remote guarded APIs:** Requests without Bearer → **401** unless backend **dev fallback** is enabled (non-production + **`ALLOW_DEV_OWNER_FALLBACK=true`** — see M1b report).
- **Flutter UX (M1d):** Mono banner **“Remote drafts require sign-in.”** when remote drafts compile flag is on and user is not authenticated; Profile Published / remote create effectively **blocked** without JWT in production-shaped backends.

### Authenticated behavior

- **Login / register** → tokens in **SecureStorage** → **`restoreSession`** on startup (M1c/M1d).
- **Remote draft + logged-in user:** Sync uses **JWT `sub`** as owner on server (M1b); **`NIMON_DEV_OWNER_ID`** must **not** be relied on for production identity alignment — it is only a **fallback path** when session is absent (see §4).

---

## 2. Release Problem

A **public or stakeholder release** cannot depend on:

1. **Undocumented `dart-define` matrices** — teams ship builds that “work on my machine” but leave Postgres empty or Profile Published empty because remote drafts / API URL / strict flags differ.
2. **`NIMON_DEV_OWNER_ID` vs backend `DEV_OWNER_ID` mismatch** — historically caused empty Published despite successful publish ([README.md](../README.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md)).
3. **Backend dev fallback in production** — **`ALLOW_DEV_OWNER_FALLBACK`** must **never** enable anonymous server-side owner impersonation in prod ([AUTH_ACCOUNT_M1B_GUARDS_OWNER_SCOPING_REPORT.md](AUTH_ACCOUNT_M1B_GUARDS_OWNER_SCOPING_REPORT.md)).
4. **Ambiguous guest authoring** — Guest + remote **without** JWT cannot be the **supported** creator story for a production app; at best it is local-only or explicitly dev-only.

**Conclusion:** Releases need a **single named policy** (defaults per channel) + **smoke gate** so “release binary” implies predictable server coupling.

---

## 3. Recommended Release Policy

| Channel | Default authoring sync | Strict remote | Auth expectation |
|---------|-------------------------|---------------|------------------|
| **Public store / production** | **Remote drafts ON** | **Recommended ON** for shipped QA builds; product may choose OFF only if UX accepts silent local fallback (risky for support). | **Must be logged in** to create/sync/publish to tenant Postgres. **Guest** may use **local-first** paths only if product explicitly keeps **`NIMON_USE_REMOTE_DRAFTS=false`** for that build — **not** recommended if “creator” is in scope. |
| **Private beta / TestFlight / internal** | **Remote ON**, **strict ON** | Same as prod unless dogfooding resilience. | Same JWT requirement; optional staging **`API_BASE_URL`**. |
| **Dev / demo** | Remote ON optional; strict ON when fixing integration | **`ALLOW_DEV_OWNER_FALLBACK`** only on **non-prod** backend + Flutter remote warning understood. | Login encouraged; guest allowed for **Mono demo** / local creator per wireframe. |

### Guest behavior (policy)

- **Guest may explore** Mono / Profile UI per wireframe.
- **Guest must not** be the documented path for **server-backed draft rows** in production — guards require JWT (unless intentional dev fallback).

### Authenticated creator behavior (policy)

- **Register/login** → remote repository receives Bearer token → **ownerId = JWT sub** on server.
- **Publish** → **`published_monos`** scoped to same user for Profile → Published list/detail.

---

## 4. Dart Define / Flavor Policy

| Define | Purpose | Production | Staging | Dev |
|--------|---------|------------|---------|-----|
| **`NIMON_USE_REMOTE_DRAFTS`** | Chooses **Remote** vs **Local** repository implementation | **`true`** for any build where creators must sync to backend | **`true`** | **`true`** when testing API; **`false`** for offline-only UI work |
| **`NIMON_STRICT_REMOTE_DRAFTS`** | Fail loudly on remote errors | **`true`** recommended for release candidates | **`true`** default | **`true`** when debugging sync |
| **`NIMON_API_BASE_URL`** | API origin | **HTTPS prod API** from secrets/CI | Staging URL | `localhost` / `10.0.2.2` |
| **`NIMON_DEV_OWNER_ID`** | Compile-time UUID for **guest / dev owner string** in Flutter basics normalization | **Do not use** as substitute for JWT identity in prod — **legacy alignment** for dev only when no session | Same | Allowed for emulator coordination with **`DEV_OWNER_ID`** |

**Rule:** Production binaries should **document** the tuple **`(USE_REMOTE_DRAFTS, STRICT, API_BASE_URL)`** in release notes or CI artifact metadata — not left implicit.

---

## 5. Backend Policy

| Setting | Policy |
|---------|--------|
| **`ALLOW_DEV_OWNER_FALLBACK`** | **Development / staging only** when intentionally testing without Flutter JWT. **Forbidden** in production (M1b). |
| **`DEV_OWNER_ID`** | **Legacy dev coordination** with Flutter **`NIMON_DEV_OWNER_ID`** when no real user session — **not** a multi-tenant production identity. |
| **Production JWT** | **All** guarded draft/published routes require valid Bearer; **`sub`** = `users.id`. |
| **Migrate / deploy** | **`prisma migrate deploy`** per environment; **`JWT_SECRET`** ≥ 32 chars in prod (M1a verify report). |

---

## 6. Flutter UX Policy

| Topic | Policy |
|-------|--------|
| **Guest + remote warning** | Show when **`useRemoteDrafts`** && not **`AuthSessionAuthenticated`** (M1d) — cannot be dismissed as optional for release notes if remote drafts default ON. |
| **Login for create/publish** | **Required** for server sync in production-shaped backends; product may add **router/create gate** later (§8). |
| **401 handling** | Strict mode: clear session + snackbar + **`/login`** (M1d bridge); refresh-retry deferred. |
| **Session restore** | Tokens in SecureStorage; **`restoreSession`** on app start (M1c). |
| **Logout** | Drawer **`logout()`** clears tokens + **`/login`** (M1d). |

---

## 7. Smoke Test Release Gate

Manual checklist before tagging a **release candidate** (adjust URLs/devices):

1. **Register** new account → lands shell (`/mono`).
2. **Login** existing account.
3. **Create** draft (creator flow).
4. **Save** with **remote + strict** → no silent failure; Postgres **`story_drafts`** reflects owner.
5. **Publish** (read-only or full-learn per scope) → **`published_monos`** row exists.
6. **Profile → Published** lists mono for **same** user (Bearer scoped).
7. **Logout** → tokens cleared; guarded calls **401** if attempted without login.
8. **Restart app** → **restoreSession** → still logged in (or explicit login if refresh revoked).
9. **Login again** → **same** drafts/published visible for that account.

**Android emulator:** `--dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000` plus remote flags.

---

## 8. Required Code Changes (minimal, if any)

Documentation-only milestone **M2 plan** does not mandate implementation here; likely follow-ups:

| Item | Purpose |
|------|---------|
| **README / run scripts** | Pin **release** `dart-define` sets (shell/ps1) per §3. |
| **Flavor / `--dart-define-from-file`** | Avoid manual typos in CI (Flutter 3.16+ file defines). |
| **Router redirect** | Optional: block **`/create`** when remote drafts && guest (product decision). |
| **Create gate** | Optional modal “Sign in to sync drafts” instead of raw 401. |

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| **Wrong `NIMON_API_BASE_URL`** | CI inject prod/staging URL; smoke gate §7. |
| **Guest attempting remote create** | Banner + future gate; backend 401 in prod. |
| **Stale tokens** | **`forceSessionExpired`** on strict 401 (M1d); refresh rotation later. |
| **Strict remote user confusion** | Document that strict is for **truthful errors**; support knows SnackBar copy. |
| **Local-only data invisible in DB** | Lifecycle doc table — expected when **`USE_REMOTE_DRAFTS=false`**. |

---

## 10. Recommended Next Step

**Option A — Manual smoke first:** Run §7 on a **staging** backend + **release-flag** Flutter build (`remote=true`, `strict=true`, correct API URL). Records evidence before code gates.

**Option B — Implement release-mode guards:** Add optional **`/create`** auth redirect + scripted **`dart-define`** artifacts — best **after** one successful manual smoke so behavior is validated.

**Recommendation:** **Smoke test first** (lower risk of baking wrong assumptions into gates).

---

## 11. Exact Cursor Prompt For M2 Implementation

Use when moving from **plan** to **code**:

```text
Implement M2 release-mode authoring polish (minimal).

Goal: Align README + optional scripts with docs/M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md —
document production vs dev dart-define sets; add optional `--dart-define-from-file` example
for CI; do not change backend.

Optional (product approval): When RemoteBackendConfig.useRemoteDrafts is true and
authSessionProvider is unauthenticated, redirect /create to /login with a short message,
or show a non-blocking modal — keep router changes minimal.

Constraints: no schema migrations; no Google sign-in; no Drift.

Verify: flutter test; manual smoke checklist section 7 from M2 plan.
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Recommended public release mode** | **`NIMON_USE_REMOTE_DRAFTS=true`**, **`NIMON_API_BASE_URL=<prod HTTPS>`**, **`NIMON_STRICT_REMOTE_DRAFTS=true`** (recommended), **JWT login required** for creator sync. |
| **Guest can create remote drafts?** | **No** as a **supported** production path — server requires Bearer (unless explicit **non-prod** backend fallback). Guest may still **edit locally** if build uses **local-first** (`USE_REMOTE_DRAFTS=false`). |
| **Local-first still allowed?** | **Yes** — default compile flags remain **local-first** for offline/UI work; **not** the recommended **public creator** story when backend sync is required. |
| **`NIMON_DEV_OWNER_ID` release use?** | **No** for real user identity — **legacy dev alignment only** when no JWT; production owner is **JWT `sub`**. |
| **Next implementation step** | Run **§7 smoke** on staging; then optional **create-route gate** + **documented define files** per §8. |
