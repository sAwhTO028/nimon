# M16C Flutter Refresh-and-Retry Report

## Problem

Access JWTs expire in about 15 minutes while refresh tokens live longer. Authenticated API traffic used `package:http` directly in repositories with `Authorization` from `authHeaderBuilderProvider`, but there was no central **401 → refresh → retry** path. `notifyIfStrictUnauthorized401` could fire on the first 401 before any refresh attempt, so users felt logged out as soon as the access token expired.

## Scope

Flutter only: new coordinator + HTTP helper, Riverpod wiring, repository call sites, strict-401 notification ordering, tests, and this report. No backend, schema, profile layout/pagination, create shell tests, localization copy, or unrelated routes.

## Current Request Pipeline (pre-M16C)

1. **Client**: `http.Client` in each remote repository (`RemoteStoryDraftRepository`, `RemotePublishedMonoRepository`, `RemoteMeProfileRepository`, `RemoteCreatorCollectionsRepository`, `RemoteMonoSocialRepository`, `RemoteUserFollowRepository`, `RemoteFollowingMonoFeedRepository`, `RemoteUserPreferencesRepository`, `MediaUploadRepository`). **Not Dio.**
2. **Authorization**: `authHeaderBuilderProvider` reads `AuthTokenStore` and returns `Authorization: Bearer <access>`.
3. **Single client?** No global interceptor; each repo issued its own requests. M16C adds a shared optional callback `NimonSendWithAuth401Recovery` injected from `nimonSendWithAuth401RecoveryProvider`.
4. **401 handling**: Per-repo `_throwIfNotOk` / `_mapHttpError` / `_ensure2xx`; strict mode used `notifyIfStrictUnauthorized401` (bridge → `forceSessionExpired` + snackbar + `/login`).
5. **`forceSessionExpired`**: `AuthSessionNotifier.forceSessionExpired` and bridge handler in `main.dart`.
6. **Manual unauthorized**: `RemoteUserFollowRepository._mapHttpError` (401 → `StateError`), following feed `_mapHttpError`, etc. No central refresh.
7. **Smallest blast radius**: Optional `sendWithAuth401Recovery` on repos + `nimonSendWithOptional401Recovery` when null (tests unchanged).
8. **Infinite recursion**: `AuthenticatedHttp` performs at most one refresh per logical request and at most one HTTP retry; second response is returned as-is. Auth routes `/v1/auth/*` skip refresh. `AuthRepository` stays separate (login/refresh/logout/getMe never use the recovery wrapper).
9. **Concurrent 401s**: `AuthRefresh401Coordinator` keeps `Future<bool>? _inFlight`; concurrent callers `await` the same future (single refresh).

## Central Refresh Design

- **`AuthRefresh401Coordinator`**: `tryRecoverAfterUnauthorized401()` reads refresh token → `AuthRepository.refresh` → `writeTokens` (rotated pair) → `getMe` → `AuthSessionNotifier.applyAuthenticatedUser`. On missing refresh or `AuthRepositoryException`: `forceSessionExpired()`.
- **`AuthenticatedHttp.sendWith401Recovery`**: First `send(await mergeHeaders())`. If `401` and not skipped and URI not auth login/register/refresh/logout and (optional) merged headers include `Bearer`, run coordinator; if `true`, `send(await mergeHeaders())` once more.
- **`NimonSendWithAuth401Recovery`**: Factory `nimonSendWithAuth401RecoveryFromCoordinator` used by `nimonSendWithAuth401RecoveryProvider`.

## Single-flight Refresh

`_inFlight` holds the active `Future<bool>` for `_recover()`. A second caller awaiting `tryRecoverAfterUnauthorized401` receives the same future until it completes and the field is cleared.

## Retry Rules

- Retry **once** after a successful refresh.
- No refresh for: auth endpoints (path segments `v1/auth/{login,register,refresh,logout}`), `skip401Recovery: true` (reserved for explicit opt-out), requests without Bearer when `requireAuthHeaderForRecovery` is true (guest / no session).
- Retried leg does not call refresh again (no loop).

## Token Rotation Persistence

On refresh success, `StoredAuthTokens(accessToken, refreshToken)` is written via `AuthTokenStore` before `getMe`, matching M16B rotation.

## Startup Restore

`AuthSessionNotifier.restoreSession` is **unchanged**: it still does explicit `getMe` → `refresh` on failure → `writeTokens` → `getMe`. This avoids coupling startup to the HTTP wrapper and does not double-refresh with normal API traffic: startup uses `AuthRepository` only; in-flight API 401 recovery uses the same store and coordinator. If both ran at once, both might call refresh; in practice restore finishes before heavy UI traffic.

## Logout Behavior

`logout` still uses `AuthRepository.logout` with best-effort catch then `clearTokens`. That path never uses `AuthenticatedHttp`, so **logout 401 does not trigger refresh**.

## Tests Added

`test/features/auth/auth_refresh_retry_test.dart`: URI skip rules, happy-path refresh+retry+persisted rotation, concurrent 401 single refresh, refresh failure clears session, no refresh token, double-401 after refresh (no second refresh), `restoreSession` with expired access, guest 401 without Bearer, login URL 401 not refresh-retried.

## Commands Run

- `dart format` (touched Dart files)
- `flutter analyze` (paths under `lib/features/auth` and touched repositories)
- `flutter test test/features/auth/auth_refresh_retry_test.dart test/auth/auth_session_notifier_test.dart`
- `flutter test` (full suite, **635** tests, exit 0)

## Manual Verification

Not run in this session (no device). Use Part J checklist from the M16C spec on a phone with a short-lived access token.

## M16D phone smoke (follow-up)

Structured on-device verification is tracked in **`docs/M16D_AUTH_SESSION_PHONE_SMOKE_REPORT.md`**. M16C behavior is additionally covered by automated tests (`test/features/auth/auth_refresh_retry_test.dart`, full suite **635** tests at M16C closeout). **No Dart changes** are required for M16D unless on-device smoke finds a reproducible blocker.

## Risks

- **Race at cold start**: Rare overlap between `restoreSession` refresh and first protected call both refreshing; backend rotation should tolerate serialized refreshes if the second uses the already-rotated refresh from disk after the first completes.
- **Multipart uploads**: Retry rebuilds a new `MultipartRequest` (same file payload); large uploads could theoretically retry a heavy body once after refresh.
