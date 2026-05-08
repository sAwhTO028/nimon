# Auth Register UX Fix Report

**Date:** 2026-05-03  
**Scope:** Register screen confirm-password validation + friendly network errors. **No backend** or API contract changes.

**Backend alignment:** Nest `RegisterDto` uses `@MinLength(8)` on password — client uses **`kRegisterMinPasswordLength = 8`**.

---

## Files Changed

| Path | Change |
|------|--------|
| `lib/features/auth/register_validation.dart` | **New** — constants, **`validateRegisterForm`** helper for tests / reuse. |
| `lib/features/auth/register_screen.dart` | Confirm password field (obscured), per-field validation, loading disables submit. |
| `lib/features/auth/auth_repository.dart` | **`_withFriendlyNetwork`** wraps HTTP calls; **`ClientException`** / **`SocketException`** → **`AuthRepositoryException`** with friendly copy; **`kDebugMode`** logs only. |
| `test/auth/register_validation_test.dart` | **New** — pure validation tests. |
| `test/auth/auth_repository_test.dart` | **`ClientException`** → friendly message. |

---

## Confirm Password Added

- **`Confirm password`** `TextField`, **`obscureText: true`**, autofill **`newPassword`**.
- Password fields retain **`obscureText: true`**.

---

## Validation Rules

| Rule | Message |
|------|---------|
| Email empty | **Enter your email.** |
| Password length &lt; 8 | **Password must be at least 8 characters.** |
| Password ≠ confirm | **Passwords do not match.** |

All three can show as **`errorText`** on their fields simultaneously on submit. Inline edits clear the corresponding field error.

---

## Friendly Network Error

- **`AuthRepository`** detects **`http.ClientException`**, **`SocketException`**, and common connection **`toString()`** patterns.
- Surfaces **`Cannot connect to server. Please check that the backend is running.`** as **`AuthRepositoryException.message`** (no raw URI in UI).
- **`register`**, **`login`**, **`refresh`**, **`logout`**, **`getMe`** wrapped consistently.
- **`kDebugMode`**: logs exception type + **`RemoteBackendConfig.apiBaseUrl`** via **`debugPrint`** only (developer-facing).

---

## Tests Added

| File | Coverage |
|------|----------|
| `register_validation_test.dart` | **`validateRegisterForm`** — empty email, short password, mismatch, valid. |
| `auth_repository_test.dart` | **`MockClient`** throws **`ClientException`** → friendly message. |

---

## Flutter Analyze Result

**Command:** `flutter analyze` on touched register/auth files.

**Result:** **No issues found.**

---

## Flutter Test Result

| Scope | Result |
|-------|--------|
| **`flutter test test/auth/`** | **All passed** |
| **`flutter test`** (full suite) | **102 tests, all passed** |

---

## Manual Test Notes

1. Register with mismatched passwords → three fields validate; confirm shows **Passwords do not match.**
2. Stop Nest; attempt register → inline/network area shows friendly message **without** `uri=http://...`.
3. Backend running; valid register → still navigates to **`/mono`**.

---

## Recommended Next Step

- Optional: apply the same **field-level** validation pattern to **`LoginScreen`** for consistency.
- Optional: map Nest **409** / validation body to shorter messages (still client-only parsing).

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Confirm password added?** | **Yes** |
| **Password mismatch validation?** | **Yes** |
| **Raw ClientException hidden?** | **Yes** (friendly **`AuthRepositoryException`**) |
| **Friendly backend connection error?** | **Yes** |
| **`flutter test test/auth` passed?** | **Yes** |
| **`flutter test` full passed?** | **Yes** (**102**) |
