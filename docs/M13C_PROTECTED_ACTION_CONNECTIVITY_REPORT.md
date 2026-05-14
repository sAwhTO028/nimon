# M13C Protected Action and Connectivity UX Report

## Problem

Guest and offline limitations were implemented with ad hoc snackbars and string literals. Publish validation (M13B) was centralized, but other protected actions were not using a single decision + UX path.

## Scope

- **Flutter only** — no backend or validation-rule changes.
- **Does not** alter M13B publish validation ordering beyond inserting **publish story** protected check **before** preflight.
- Live connectivity is implemented in **M13D** (`connectivity_plus` + `nimonConnectivityStatusProvider`); see [M13D Connectivity Live Wiring Report](M13D_CONNECTIVITY_LIVE_WIRING_REPORT.md).

## Protected Actions Covered

| Action | Mechanism |
|--------|-----------|
| React | `ensureProtectedActionAllowed` in `_toggleReact`; repository failures map via `offlineUserMessageIfRecognized` |
| Follow | Mono footer + public profile `_toggleFollow`; same offline mapping |
| Save / bookmark | `_toggleBookmark` after ownership gate |
| Create story | Add tab `_createNewStory` + `CreateScreen._handleCreate` |
| Publish story | `performCreatorDrawerPublish`: protect → M13B preflight → publish |
| Create collection | Start of `showAddToCollectionSheet` |
| Upload media | Story cover (`CreateScreen`), audio sheet open (`_showUpsertSheet`), profile avatar/cover taps |
| Edit profile | `EditProfileScreen` post-frame gate + upload guards |

## Central Guard

- **`lib/core/validation/protected_action_guard.dart`** — `ensureProtectedActionAllowed(BuildContext context, { required ProtectedActionType action })`.
- Uses **`ProviderScope.containerOf`** + **`authSessionProvider`** + **`nimonNetworkOnlineProvider`**.
- **Network**: floating **`SnackBar`** with **`network.offline`**.
- **Login**: existing **`showProtectedActionPrompt`** (Sign in / Not now).

## Connectivity Handling

- **`nimonNetworkOnlinePod`** (`StateProvider<bool>`, default **`true`**) + **`nimonNetworkOnlineProvider`** (`Provider<bool>` watching the pod).
- **M13D:** **`nimonConnectivityStatusProvider`** drives the pod from **`connectivity_plus`** at app startup (`lib/core/networking/connectivity_status.dart`, `lib/main.dart`).
- **Transport errors**: **`lib/core/networking/network_error_mapping.dart`** — `offlineUserMessageIfRecognized` / `isLikelyOfflineFailure` for `SocketException`, `HttpException`, `ClientException`-style failures.

## Guest UX

All login-required actions use **`validationFallbackMessagesEn`** keys:

- `protected.react.login` … `protected.editProfile.login`

plus **`protected.generic.forbidden`** / **`protected.generic.disabled`** for non-login denial paths.

## Offline UX

- Preflight: **`nimonNetworkOnlineProvider == false`** → snackbar only (no login sheet).
- Post-request: mono social/follow **`catch`** branches prefer **`offlineUserMessageIfRecognized`** before generic errors.

## Wired Flows

- **Publish**: `ProtectedActionType.publishStory` → `_preflightCreatorPublish` (M13B) → disk/API path unchanged.
- **Resume draft** from Add tab: **not** gated (local continuation); **new story** buttons gated.

## Error Mapping

- Mono bookmark/react/follow: **`offlineUserMessageIfRecognized`** in **`catch`**.
- **`StoryDraftValidationFailedException`** / M13B **`validation_failed`** unchanged.

## Tests Added

| File | Notes |
|------|--------|
| `test/core/validation/protected_action_m13c_test.dart` | Message keys, guest flows, offline mapping, widget tests for guard |
| `test/core/validation/validation_foundation_test.dart` | Extended with guest **save** / **publishStory** |

## Commands Run

```text
dart format test/features/profile/add_to_collection_sheet_test.dart test/features/profile/edit_profile_screen_test.dart
flutter analyze test/features/profile/add_to_collection_sheet_test.dart test/features/profile/edit_profile_screen_test.dart test/support/auth_session_test_overrides.dart
flutter test test/features/profile/add_to_collection_sheet_test.dart test/features/profile/edit_profile_screen_test.dart
flutter test test/core/validation
flutter test test/features/mono
flutter test test/features/create
flutter test
```

Last full run: **`484` tests passed** (~3m).

Backend: none (no `pnpm jest` / `nest build`).

## Manual Verification

1. **Guest**: Mono Save / React / Follow → bottom sheet with correct copy + Sign in.
2. **Guest**: Add tab “Create new story” → login sheet; **Continue** draft still works without auth.
3. **Guest**: Publish from drawer → login before validation sheet.
4. **Authenticated + offline override** (`nimonNetworkOnlinePod` false in dev): protected action → offline snack only.

## Remaining Risks

- **Reachability:** interface-level connectivity does not guarantee HTTP success; transport mapping remains for late failures.
- Some API surfaces may still show non-localized errors outside the guarded mono/follow paths.

## Recommended Next Step

See **M13D** for live wiring details and optional reachability follow-ups.

---

### M13D follow-up

Live **`connectivity_plus`** wiring and tests: **[M13D_CONNECTIVITY_LIVE_WIRING_REPORT.md](M13D_CONNECTIVITY_LIVE_WIRING_REPORT.md)**.

### M13E follow-up

Form-level validation UX is documented in **[M13E_FORM_FIELD_VALIDATION_INTEGRATION_REPORT.md](M13E_FORM_FIELD_VALIDATION_INTEGRATION_REPORT.md)** (does not change protected-action decisions).

### M13H follow-up

Protected prompt body, CTAs, and offline snackbar copy resolve through **AppLocalizations** where the widget tree supplies context; decisions unchanged. See **[M13H_VALIDATION_LOCALIZATION_REPORT.md](M13H_VALIDATION_LOCALIZATION_REPORT.md)**.
