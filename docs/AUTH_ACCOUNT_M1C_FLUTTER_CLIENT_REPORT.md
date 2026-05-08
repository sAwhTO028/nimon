# Auth Account M1c Flutter Client Report

Milestone **M1c** adds a Flutter auth/session foundation: secure token storage, `AuthRepository`, Riverpod session restoration, and **`Authorization: Bearer`** on **`RemoteStoryDraftRepository`** and **`RemotePublishedMonoRepository`**. Backend code was **not** modified.

---

## Files Changed

| Area | Path | Role |
|------|------|------|
| Deps | `pubspec.yaml` | Added `flutter_secure_storage`. |
| Models | `lib/features/auth/auth_models.dart` | `AuthTokens`, `StoredAuthTokens`, `AuthUser`. |
| Storage | `lib/features/auth/auth_token_store.dart` | `AuthTokenStore`, `SecureAuthTokenStore`. |
| API | `lib/features/auth/auth_repository.dart` | `/v1/auth/*`, `/v1/me`. |
| Session | `lib/features/auth/auth_session_state.dart` | Sealed session states. |
| Session | `lib/features/auth/auth_session_notifier.dart` | `restoreSession`, `login`, `register`, `logout`. |
| DI | `lib/features/auth/auth_providers.dart` | Token store, repo, `authHeaderBuilderProvider`, `authSessionProvider`. |
| Identity | `lib/features/auth/current_user_id_provider.dart` | JWT user id vs dev owner fallback. |
| UI | `lib/features/auth/login_screen.dart` | Wired LOGIN + errors + link to register. |
| UI | `lib/features/auth/register_screen.dart` | Minimal register → `/mono`. |
| App | `lib/main.dart` | `restoreSession` on startup; `/register` route; `NimonApp` → `ConsumerStatefulWidget`. |
| Drafts repo | `lib/features/create/data/remote_story_draft_repository.dart` | `_mergeAuth`, owner resolver for basics. |
| Drafts DI | `lib/features/create/data/story_draft_repository_provider.dart` | Passes auth header builder + `currentUserIdProvider`. |
| Creator | `lib/features/create/story_creator_provider.dart` | Uses `currentUserIdProvider` instead of only dev user. |
| Published | `lib/features/profile/data/remote_published_mono_repository.dart` | `_mergeAuth` on GETs. |
| Published DI | `lib/features/profile/presentation/providers/profile_published_mono_pager.dart` | Injects `authHeaderBuilderProvider`. |
| Profile | `lib/features/profile/profile_screen.dart` | Uses `remotePublishedMonoRepositoryForProfileProvider` for published GET. |
| Tests | `test/auth/*.dart`, `test/auth/in_memory_auth_token_store.dart` | Unit coverage (see below). |

---

## Dependencies Added

- **`flutter_secure_storage`** (^9.2.4) — access + refresh tokens only (never `SharedPreferences`).

---

## Auth Models

- **`AuthTokens`**: `accessToken`, `refreshToken`, `tokenType` (matches Nest `AuthTokens`).
- **`StoredAuthTokens`**: persisted pair for `AuthTokenStore`.
- **`AuthUser`**: `id`, `email`, optional `displayName` / `handle` from `/v1/me` (`user` + `profile`).

---

## Secure Token Storage

- **`AuthTokenStore`**: `readTokens`, `writeTokens`, `clearTokens`.
- **`SecureAuthTokenStore`**: `FlutterSecureStorage` with keys `nimon_auth_access_token_v1` / `nimon_auth_refresh_token_v1`.
- Tests use **`InMemoryAuthTokenStore`** (`test/auth/in_memory_auth_token_store.dart`) — no platform plugin.

---

## Auth Repository

- **`POST /v1/auth/register`**, **`POST /v1/auth/login`** → `AuthTokens`.
- **`POST /v1/auth/refresh`** body `{ "refreshToken": "..." }`.
- **`POST /v1/auth/logout`** body `{ "refreshToken": "..." }` (expects **204**).
- **`GET /v1/me`** with `Authorization: Bearer <access>` → `AuthUser`.

Base URL: **`RemoteBackendConfig.apiBaseUrl`**.

Errors surface as **`AuthRepositoryException`** (message + optional `statusCode`).

---

## Session Provider

- **`authSessionProvider`** (`AuthSessionNotifier`): states **`AuthSessionUnknown`**, **`AuthSessionLoading`**, **`AuthSessionUnauthenticated`**, **`AuthSessionAuthenticated`**.
- **`restoreSession()`**: read secure tokens → `getMe`; on failure attempt **`refresh`**; on failure **`clearTokens`**.
- **`login` / `register`**: persist tokens, **`getMe`**, set authenticated.
- **`logout`**: optional **`logout(refreshToken)`**, then **`clearTokens`**.

---

## Authorization Header Wiring

- **`authHeaderBuilderProvider`**: async closure reading **`SecureAuthTokenStore`** → `{ Authorization: Bearer <access> }`.
- **`RemoteStoryDraftRepository`**: optional **`StoryDraftAuthHeaderBuilder`** merged into every HTTP call via **`_mergeAuth`**.
- **`RemotePublishedMonoRepository`**: optional **`PublishedMonoAuthHeaderBuilder`**, same pattern.
- **`storyDraftRepositoryProvider`** / **`remotePublishedMonoRepositoryForProfileProvider`** pass **`ref.watch(authHeaderBuilderProvider)`** so new tokens are picked up after login without restarting the app.

---

## Login Screen Changes

- **`LOGIN`** → **`authSessionProvider.notifier.login`**, loading indicator, inline error text, success → **`context.go('/mono')`**.
- **`Guest >>`** → **`/mono`** (local-first / no Bearer; remote guarded APIs still need login or backend dev fallback).
- **`Create account`** → **`/register`**.
- **Google**: snackbar “coming soon” (not implemented).

---

## Dev Owner Fallback Policy

- **`devCurrentUserProvider`** remains for **compile-time dev owner id** (`NIMON_DEV_OWNER_ID`).
- **`currentUserIdProvider`**: if **`AuthSessionAuthenticated`**, use **`user.id`**; else **`devCurrentUserProvider.userId`**.
- Remote drafts still normalize **`creatorOwnerId`** to **`currentUserIdProvider`** for Nest consistency.
- **Unauthenticated + remote + no backend `ALLOW_DEV_OWNER_FALLBACK`**: story-drafts / published-monos will **401** until login (same as M1b).

---

## Tests Added

| File | Intent |
|------|--------|
| `test/auth/auth_token_store_test.dart` | In-memory store round-trip. |
| `test/auth/auth_repository_test.dart` | Login + `getMe` parse; Bearer on `/v1/me`. |
| `test/auth/auth_session_notifier_test.dart` | Login persists tokens; logout clears. |
| `test/auth/remote_story_draft_repository_auth_test.dart` | `listDraftIds` sends `Authorization`. |
| `test/auth/remote_published_mono_repository_auth_test.dart` | `list` sends `Authorization`. |

---

## Flutter Pub Get Result

Succeeded (`flutter_secure_storage` and platform implementations resolved). Pub printed advisory decode warnings from pub.dev (environment/tooling); resolution completed.

---

## Flutter Analyze Result

- **Project-wide**: many existing infos/warnings (e.g. `withOpacity` deprecations).
- **M1c-scoped paths** (`lib/features/auth/**`, updated repos/providers, `test/auth`): **no errors**; remaining **info** in `story_creator_provider` and `main.dart` only (pre-existing style).

---

## Flutter Test Result

- **`flutter test test/auth/`**: all auth tests passed.
- **`flutter test` (full suite)**: **93 tests passed** (`All tests passed!`).

---

## Risks

- **Guest + `NIMON_USE_REMOTE_DRAFTS`**: without tokens (and without backend dev fallback), remote APIs fail until login.
- **Secure storage** platform setup (Keychain / Keystore) is standard but environment-specific if CI runs integration tests without mocks.

---

## Recommended Next Step

- **M1d** (or product milestone): persist refresh rotation policy, token expiry handling UX, **logout** entry in Settings, and Flutter integration/e2e hitting real Nest with JWT.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Dependencies added** | **`flutter_secure_storage`**. |
| **Login wired** | **Yes** — `authSessionProvider.notifier.login`, `/mono` on success. |
| **Register UI** | **Added** — `/register` minimal screen + `AuthRepository.register`. |
| **Tokens in SecureStorage** | **Yes** — `SecureAuthTokenStore` (not SharedPreferences). |
| **`RemoteStoryDraftRepository` Bearer** | **Yes** — `_mergeAuth` on all draft HTTP calls. |
| **`RemotePublishedMonoRepository` Bearer** | **Yes** — list/fetch/get. |
| **`flutter analyze` 0 errors** | **Yes** for new auth code; repo has historical infos/warnings elsewhere. |
| **`flutter test` passed** | **Yes** — full suite **93** passed. |
| **Next** | **M1d** / polish logout UX + CI mocks for secure storage if needed. |
