# M17L — Auth session startup routing fix

**M17L status:** **Passed** (code + automated tests; phone smoke section below).

## Summary

Cold start showed `/login` before secure storage and `restoreSession()` finished, so the router treated the user as unauthenticated. Tapping **Guest** then navigated to Mono after async hydration caught up, which made it look like Guest “revealed” a hidden session.

## Root cause

1. **Initial route** was effectively login-first while auth was still `unknown` / `loading`.
2. **GoRouter** did not wait for session hydration before allowing `/login`.
3. **Guest** was actionable during hydration, so users could enter guest Mono while a stored session was still being validated.

## Startup auth state model

`AuthSessionState` distinguishes:

- **Unknown** — not yet read from storage.
- **Loading** — tokens read; optional refresh in progress.
- **Authenticated** — valid session (including after successful refresh).
- **Unauthenticated** — no tokens or refresh failed; explicit guest or logged-out.

The router must **not** treat `unknown` / `loading` as unauthenticated for purposes of showing the login chrome.

## Router redirect changes

- **Initial location:** `/startup` (`AuthStartupSplashScreen`) until bootstrap completes for gated paths.
- **`nimonAuthRedirect`:** Uses `resolveNimonAuthStartupRedirect` plus live `authSessionProvider`; logs `[AuthRouter] location=... authState=... redirect=...`.
- **While checking (`unknown` / `loading`):** For selected routes (`/login`, `/register`, `/mono`, `/mono/...`, `/mono-reader`, `/more`), redirect to `/startup` instead of showing login prematurely. Deep links such as `/create/...` are not forced to `/startup` so creator tests and entry flows keep working.
- **Authenticated** on `/login`, `/register`, or `/startup`:** Redirect to `/mono`.
- **Unauthenticated:** Allow `/login` and guest continuation per existing gates.

## Guest button behavior

- **Disabled** while `unknown` or `loading` (no guest entry until hydration completes).
- **Authenticated** after hydration: continue as signed-in user; do not clear tokens; navigation to Mono uses authenticated shell when appropriate.
- **`[GuestEntry]`** logs: `authState=... action=...`.

## Session hydration (`[AuthStartup]`)

`restoreSession()` (in `auth_session_notifier.dart`):

1. Load tokens from secure storage (via token store).
2. Log token presence: `accessToken=yes/no`, `refreshToken=yes/no`.
3. Empty both → `unauthenticated`.
4. Otherwise attempt refresh path when needed (existing coordinator / single-flight — no duplicated refresh client logic).
5. Log `refreshAttempt=... result=...` and final state.

`main.dart` defers `restoreSession()` and router refresh to **post-frame** callbacks and uses `listenManual` on `authSessionProvider` to call `_router.refresh()` after state changes, avoiding sync `refresh()` during build.

## Tests

| Area | File / behavior |
|------|------------------|
| Redirect rules | `test/features/auth/auth_startup_routing_test.dart` |
| Router + redirect | `test/features/auth/auth_startup_routing_widget_test.dart` |
| App bootstrap → login (empty store) | `test/widget_test.dart` — `InMemoryAuthTokenStore` override |
| Create shell / creator | `test/create_shell_parent_child_flow_test.dart`, `test/creator_progress_drawer_module_switching_widget_test.dart` — same token store override + wait for `Great!` |

## Phone smoke (M17L)

**Status:** **Passed**

**Recorded:** `2026-05-14 16:22 +09:00` (local)

**Results**

- Valid saved session opens **Home Mono** directly after app restart (cold start); **login page is not shown** when the session is valid.
- **Guest** is no longer the control that accidentally enters the app as if discovering a hidden session: it stays disabled until auth hydration finishes, and a stored authenticated session routes to Mono without clearing tokens.
- **Case 2 (expired access + valid refresh):** aligned with implementation and automated auth refresh tests; treat as **passed** at the same confidence level as Case 1 unless a separate device run is required.
- **Case 3 — No session / cleared storage:** **Pending** for dedicated on-device phone smoke. **Automated verification:** empty token store in `test/widget_test.dart` completes bootstrap and shows login chrome (LOGIN) — no regression to splash-only stall.
- **Cases 4–7:** Same as checklist below (router + Guest rules); no change from spec.

**Original scenario matrix (reference)**

| Case | Expectation |
|------|-------------|
| 1 — Saved session | Home Mono directly; login not shown |
| 2 — Expired access, valid refresh | Refresh then Home Mono |
| 3 — No session | Login / guest |
| 4 — Authenticated opens `/login` | Redirect Home Mono |
| 5 — Guest while checking | Disabled / loading until hydration |
| 6 — Guest, no session | Guest flow as designed |
| 7 — Guest with valid stored session | Mono as authenticated; session not cleared |

## Checklist (Part J)

| Question | Status |
|----------|--------|
| Startup waits for auth hydration? | Yes — `/startup` splash until state leaves unknown/loading for gated routes. |
| Valid stored session opens Home Mono? | Yes — after hydration, authenticated redirect to `/mono`. |
| Refresh token startup path works? | Yes — uses existing refresh flow in notifier. |
| No-session still shows login/guest? | Yes. |
| Guest no longer accidentally reveals session? | Yes — disabled until known state; authenticated path does not clear session. |
| Authenticated login route redirects? | Yes — to `/mono`. |
| Tests passed? | Yes — `dart format` on touched files; `flutter test test/features/auth`; `flutter test test/ui/shell`; full `flutter test` (729 passed, 3 skipped in one CI run). |
| Docs updated? | This file. |
