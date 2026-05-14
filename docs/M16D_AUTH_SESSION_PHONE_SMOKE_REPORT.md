# M16D Auth Session Phone Smoke Report

## Scope

On-device verification that M16B refresh rotation + M16C central **401 → refresh → retry** keep users signed in when the access JWT expires (~15m in production). **No code changes** unless smoke exposes a reproducible blocker. No changes to public profile, pagination, backend schema, or session-management UI.

**Automation note:** This document was prepared in a development environment **without** access to the author’s phone or LAN. Sections below list **procedure** and **recorded result**. Until a human completes the steps on hardware, results are **pending**.

## Environment

| Item | Notes |
|------|--------|
| Phone | Physical device on same LAN as dev machine |
| Backend | `nimon-backend` reachable at LAN IP (not `localhost` from phone) |
| Listen address | `0.0.0.0:3000` (or equivalent) so the phone can connect |
| Flutter API base | `--dart-define=NIMON_API_BASE_URL=http://<LAN_IP>:3000` |
| Remote flags | `NIMON_USE_REMOTE_MONO_FEED=true`, `NIMON_USE_REMOTE_DRAFTS=true` per project norms |

Example run (adjust IP to your LAN):

```text
flutter run `
  --dart-define=NIMON_API_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true `
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

## Temporary Expiry Config

**Local smoke only:** set backend access lifetime short enough to force expiry during a session.

- Set `JWT_EXPIRES_IN=60s` (or project-equivalent env) for **access** token only.
- Leave **refresh** token expiry unchanged.
- Restart backend after editing env.

**Result:** Pending — operator confirms env applied and server restarted.

## Silent Refresh Smoke

**Procedure (M16D Part C):**

1. Log in.
2. Open a screen that calls an authenticated API.
3. Wait **70–90s** after login (access ~60s).
4. Perform authenticated actions: React, Save, Follow, own profile, workspace/drafts, optional media upload.

**Expected:** No logout, no forced login screen, no raw 401 surfaced; actions succeed; tokens rotate silently.

**Result:** Pending.

## App Restart Restore Smoke

**Procedure (M16D Part D):**

1. Log in.
2. Wait until access token has expired.
3. Force-quit the app completely.
4. Relaunch.

**Expected:** `restoreSession` refreshes if needed; user stays logged in; `/v1/me` path succeeds; login screen only if refresh token is invalid.

**Result:** Pending.

## Concurrent 401 Smoke

**Procedure (M16D Part E):**

1. Log in; wait for access expiry.
2. Rapidly trigger multiple authenticated calls (pull-to-refresh profile, React/Save, tab switches).

**Expected:** At most one refresh visible in backend logs (if logging); no duplicate logout; requests recover.

**Result:** Pending.

## Refresh Failure Smoke

**Procedure (M16D Part F):**

1. Log in.
2. Revoke/delete current refresh token (DB or second client logout), if available.
3. Wait for access expiry; trigger a protected API call.

**Expected:** Refresh fails → tokens cleared → session-expired / login prompt; no crash; no infinite spinner.

**Result:** Pending.

## Logout Smoke

**Procedure (M16D Part G):**

1. Log in, then log out from the app.
2. Confirm local tokens cleared.
3. As guest, trigger a protected action.

**Expected:** Login prompt; no silent re-login; backend refresh row revoked (verify in DB/logs if needed).

**Result:** Pending.

## Bugs Found

None recorded — **device smoke not executed in this environment.**

## Fixes Applied

None — **no code changes** for M16D closeout unless a blocker is found during smoke.

## Release Readiness

| Gate | Status |
|------|--------|
| M16B backend rotation | Passed (per M16B milestone) |
| M16C Flutter refresh/retry + unit tests | Passed (**635** tests at M16C closeout) |
| M16D on-device smoke (this doc) | **Pending** until operator completes Parts C–G and updates results above |

**Recommendation:** Complete the pending rows on a real device with `JWT_EXPIRES_IN=60s` before treating M16D as fully closed. Revert short JWT expiry before any shared/staging deploy.

## Remaining Risks

- LAN/firewall misconfiguration (phone cannot reach `192.168.x.x:3000`).
- Clock skew between phone and server (rare JWT edge cases).
- Operator error leaving `JWT_EXPIRES_IN=60s` on a long-lived environment.

## Automated tests (no rerun required for M16D if no code changes)

Prior verification (M16C):

- `flutter test test/features/auth/…` including `auth_refresh_retry_test.dart`
- Full `flutter test` — **635** tests, exit 0

If any code is changed after smoke, rerun: `dart format` (touched files), `flutter analyze` (touched paths), `flutter test test/features/auth`, `flutter test`.
