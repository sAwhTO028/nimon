# M17K — Guest mode sign-in gating + Following empty-state dark mode

## Summary

Guest users tapping **Add** or **Profile** on the main floating dock (and the mono reader dock) no longer navigate away; they get the same **protected-action** bottom sheet used elsewhere (`ensureProtectedActionAllowed` → `showProtectedActionPrompt`), with a **Sign in required** title and localized body copy.

The **Following** tab guest empty state uses **theme semantic colors** (`onSurface` / `onSurfaceVariant`) and adds a **Sign in** button to `/login`.

The **remote drafts** info strip uses a **neutral surface** background and `onSurface` / `onSurfaceVariant` for readable light/dark contrast (no low-contrast `onErrorContainer` on translucent `errorContainer`).

## Part A — Add / Profile tab gates

- **Handler:** `lib/ui/shell/floating_dock_tab_handler.dart` — `handleFloatingDockTabSelection` runs `ensureProtectedActionAllowed` for index `1` (Add → `ProtectedActionType.createStory`) and `2` (Profile → `ProtectedActionType.editProfile`) before navigation or `openCreate`.
- **Shell:** `lib/main.dart` — `AppShell` delegates dock taps to the handler with the real `StatefulNavigationShell`.
- **Mono reader dock:** `lib/features/mono/mono_screen.dart` — same handler with `navigationShell: null` (uses `go.go` paths as before for Mono / More).

## Part B — Following guest CTA

- **Widget:** `lib/features/mono/mono_following_guest_auth_panel.dart` — localized title/body + `FilledButton` → `context.go('/login')`.
- **Mono screen** replaces the old private auth-gate widget with `MonoFollowingGuestAuthPanel`.

## Part C — Dark mode text

- Guest Following panel and **authenticated** “nothing here yet” Following empty state no longer use hardcoded `#1A1917` / `#5C5A55`; they use `ColorScheme.onSurface` and `onSurfaceVariant`.

## Part D — Remote drafts banner

- Copy from **`monoGuestRemoteDraftsBanner`** (EN/JA/MY) with English fallback when `AppLocalizations` is absent (e.g. some widget tests).
- Styling: `surfaceContainerHighest` + theme text/icon colors.

## Part E — Protected prompt title + copy

- `lib/core/validation/protected_action.dart` — login-required sheet shows **`settingsSignInRequiredTitle`** then body.
- EN/JA/MY ARB + `validation_fallback_messages.dart`: **`validationProtectedCreateStoryLogin`** and **`validationProtectedEditProfileLogin`** aligned with M17K product copy (create/publish Monos; view/manage profile).

## Tests

- `test/ui/shell/floating_dock_guest_gate_test.dart` — guest Add/Profile → sign-in sheet, no route change; authenticated → `/create` and `/more`.
- `test/features/mono/mono_following_guest_panel_test.dart` — guest strings + dark theme color assertions.
- `test/support/auth_session_test_overrides.dart` — **`guestAuthSessionOverride`** for guest dock tests.

**Commands run:** `dart format` (touched files), `flutter test test/features/auth test/features/mono test/features/profile`, `flutter test` (full suite), targeted new tests.

## Remaining risks

- **Profile tab** reuses `ProtectedActionType.editProfile` for “open profile shell”; message is “view and manage profile,” which matches intent even though the enum name says “edit.”
- **Offline guest:** Add/Profile still show the **offline snackbar** first (existing protected-action order), not the login sheet — unchanged behavior.

## Part H checklist

| Item | Status |
| --- | --- |
| Add tab guest sign-in prompt | Yes (`createStory` + existing sheet + title) |
| Profile tab guest sign-in prompt | Yes (`editProfile` + same sheet) |
| Following tab Sign in CTA | Yes (`MonoFollowingGuestAuthPanel`) |
| Dark mode Following text | Yes (semantic colors) |
| Authenticated navigation preserved | Yes (handler tests + suites) |
| Tests passed | Yes for `test/features/auth`, `mono`, `profile` |
| Docs | This file |
