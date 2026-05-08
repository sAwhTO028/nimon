# Auth Account M1d Implementation Report

**Date:** 2026-05-03  
**Scope:** Minimal auth UX (M1d) — logout wiring, account identity, guest+remote warning, strict **401** handling, tests. **No backend** or **schema** changes.

**Plan reference:** [AUTH_ACCOUNT_M1D_UX_SMOKE_PLAN.md](AUTH_ACCOUNT_M1D_UX_SMOKE_PLAN.md).

---

## Files Changed

| Path | Change |
|------|--------|
| `lib/features/auth/auth_session_expired_bridge.dart` | **New** — `nimonAppNavigatorKey`, `AuthSessionExpiredBridge` for strict **401** UX. |
| `lib/features/auth/auth_strict_unauthorized.dart` | **New** — `notifyIfStrictUnauthorized401` for guarded repositories. |
| `lib/features/auth/guest_remote_draft_warning.dart` | **New** — `guestRemoteDraftWarningVisibleProvider`, `computeGuestRemoteDraftWarning`. |
| `lib/features/auth/auth_session_notifier.dart` | **`forceSessionExpired()`** — clear SecureStorage + unauthenticated (no `/logout` HTTP). |
| `lib/main.dart` | `GoRouter(navigatorKey: nimonAppNavigatorKey)`; register expired bridge before **`restoreSession()`**. |
| `lib/features/profile/profile_navigation_drawer.dart` | **`ConsumerStatefulWidget`**; **`logout()`** + identity from **`authSessionProvider`**; dialog copy update. |
| `lib/features/mono/mono_screen.dart` | Banner when **`guestRemoteDraftWarningVisibleProvider`** (remote + not signed in). |
| `lib/features/settings/settings_screen.dart` | **Account** row — email or “Not signed in”. |
| `lib/features/create/data/remote_story_draft_repository.dart` | **`notifyIfStrictUnauthorized401`** in **`_throwIfNotOk`**. |
| `lib/features/profile/data/remote_published_mono_repository.dart` | Same for **`_throwIfNotOk`**. |
| `test/auth/auth_session_notifier_test.dart` | **`forceSessionExpired`** test. |
| `test/auth/guest_remote_draft_warning_test.dart` | **New** — pure **`computeGuestRemoteDraftWarning`** tests. |

---

## Logout Wiring

- **`ProfileNavigationDrawer`** Sign out confirmation → **`await ref.read(authSessionProvider.notifier).logout()`** → **`GoRouter.go('/login')`**.
- **`AuthSessionNotifier.logout()`** unchanged: best-effort **`POST /v1/auth/logout`**, always **`clearTokens()`**.
- Confirmation dialog text updated to describe device sign-out.

---

## Account Identity Display

- **Profile drawer** header: **`AuthSessionAuthenticated`** → **`displayName`** or **`email`** as title; **`@handle`** or **`email`** as subtitle; otherwise **“Guest”** / **“Not signed in”**. Demo **`displayName` / `handle`** props remain fallbacks when profile fields are empty.
- **Settings → Account**: subtitle **`user.email`** or **`user.id`** when authenticated; **“Not signed in”** otherwise.

---

## Guest Remote Warning

- **`guestRemoteDraftWarningVisibleProvider`**: **`RemoteBackendConfig.useRemoteDrafts`** and session **not** **`AuthSessionAuthenticated`** (includes loading/unknown — banner may show briefly during **`restoreSession`**).
- **`MonoScreen`**: when **`showTopControls`** and provider true, thin **errorContainer** banner: **“Remote drafts require sign-in.”**

---

## 401 / Expired Session Handling

- **`notifyIfStrictUnauthorized401`** runs only when **`RemoteBackendConfig.strictRemoteDrafts`** and **`statusCode == 401`**, before **`StateError`** throw.
- **`AuthSessionExpiredBridge`** (registered in **`NimonApp`**): **`forceSessionExpired()`** → SnackBar **“Session expired — sign in again.”** → **`go('/login')`** via **`nimonAppNavigatorKey`**.
- **Deferred:** automatic **401** retry with refresh token inside **`http.Client`** (not implemented).

---

## Tests Added

| Test | File |
|------|------|
| **`forceSessionExpired`** clears store, no HTTP | `auth_session_notifier_test.dart` |
| **`computeGuestRemoteDraftWarning`** matrix | `guest_remote_draft_warning_test.dart` |

Widget test for drawer Sign out deferred (would require drawer harness).

---

## Flutter Analyze Result

| Scope | Result |
|-------|--------|
| **Core auth + repos** (`auth_session_expired_bridge`, `auth_strict_unauthorized`, `guest_remote_draft_warning`, `auth_session_notifier`, remote repos) | **`No issues found!`** |
| **`settings_screen.dart`** | Pre-existing **Radio** deprecation infos (unchanged pattern). |
| **`mono_screen.dart`** | Large file with many pre-existing infos/warnings; M1d added only import + banner block. |

---

## Flutter Test Result

| Command | Result |
|---------|--------|
| **`flutter test test/auth/`** | **All passed** |
| **`flutter test`** (full suite) | **97 tests, All tests passed!** |

---

## Risks

- **Banner during `AuthSessionLoading`:** Guest warning may flash until **`restoreSession`** completes (acceptable for M1d).
- **`nimonAppNavigatorKey.currentContext`:** If **401** fires before first frame mounts navigator, SnackBar/route may skip (rare).
- **Strict 401** fires **before** repository **`throw`**: user still sees error from **`StateError`** in UI paths that surface it — session is cleared in parallel.

---

## Manual Smoke Checklist

Use **[AUTH_ACCOUNT_M1D_UX_SMOKE_PLAN.md §3](AUTH_ACCOUNT_M1D_UX_SMOKE_PLAN.md)** plus:

1. Sign out from Profile drawer → **`/login`** → SecureStorage keys cleared (manual inspection / logging).
2. Remote strict run → trigger **401** (e.g. revoke refresh server-side or stale token) → SnackBar + **`/login`**.
3. **`NIMON_USE_REMOTE_DRAFTS=true`** without login → Mono banner visible.

---

## Recommended Next Step

- **401 retry:** Single **`refresh`** + one replay inside repositories or shared **`http`** wrapper.
- **Router:** Optional **`redirect`** from **`/mono`** when guest+remote (product decision).
- **Settings:** Dedicated **Sign out** tile duplicating drawer (optional).

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Logout wired?** | **Yes** — **`logout()`** then **`go('/login')`**. |
| **Tokens cleared on logout?** | **Yes** — existing **`AuthSessionNotifier.logout()`**. |
| **Account identity shown?** | **Yes** — drawer + Settings **Account**. |
| **Guest remote warning?** | **Yes** — Mono banner + **`guestRemoteDraftWarningVisibleProvider`**. |
| **401 handling?** | **Added** for strict remote via bridge + **`forceSessionExpired`** (global redirect). |
| **`flutter test test/auth`?** | **Passed** |
| **`flutter test` full?** | **Passed (97)** |
| **Next step** | Refresh-on-401 retry, auth-aware **`GoRouter`** redirect (optional). |
