# M13D Connectivity Live Wiring Report

## Problem

`nimonNetworkOnlinePod` defaulted to **online** and was only updated by tests or manual overrides. Protected-action offline preflight could not reflect real device connectivity before network calls.

## Dependency

- **`connectivity_plus`** **`^7.1.1`** added to `pubspec.yaml` (not previously present).

## Connectivity Bridge

- **`lib/core/networking/connectivity_status.dart`**
  - **`NimonConnectivityStatus`** (`online` | `offline`).
  - **`nimonConnectivityStatusFromResults`**: `ConnectivityResult.none` only (or empty list defensively) ⇒ offline; any other result ⇒ online.
  - **`nimonConnectivityStatusProvider`**: `StreamProvider` wrapping **`Connectivity.checkConnectivity()`** (initial yield) then **`onConnectivityChanged`**.
  - **`syncNimonNetworkOnlinePodFromStatus`**: maps status → **`nimonNetworkOnlinePod`** using a generic **`read`** (`ref.read` / `container.read`).
  - **`protected_action.dart`** does **not** import `connectivity_plus`; only this networking module does.

## nimonNetworkOnlinePod Wiring

- **`lib/main.dart`** — **`_NimonAppState.build`**: **`ref.listen`** on **`nimonConnectivityStatusProvider`**; on **`AsyncData`**, call **`syncNimonNetworkOnlinePodFromStatus(ref.read, status)`**.
- **`nimonNetworkOnlinePod`** remains the mutable source; **`nimonNetworkOnlineProvider`** unchanged.
- Initial **`checkConnectivity`** runs inside the stream provider before **`yield`** from the async generator, so the first **`AsyncData`** updates the pod shortly after startup (after **`AsyncLoading`**).

## Offline UX

- **`checkProtectedAction`** order unchanged: **network** → **login** → allowed. Guest **and** offline ⇒ **`networkRequired`** only (no login sheet + offline snack together).
- **`ensureProtectedActionAllowed`** unchanged; reads **`nimonNetworkOnlineProvider`** fed by live connectivity.

## Transport Error Mapping

- **`lib/core/networking/network_error_mapping.dart`** unchanged — still used when a guarded action proceeds but the transport fails later.

## Tests Added

| File | Coverage |
|------|-----------|
| `test/core/networking/connectivity_status_test.dart` | Mapping (`none` vs wifi/mobile/ethernet/vpn/bluetooth/other/satellite, empty list, mixed); pod override; **`syncNimonNetworkOnlinePodFromStatus`**; stream override + listen mirrors root sync; guest offline ⇒ **`networkRequired`** |

## Commands Run

```text
flutter pub get
dart format lib/core/networking/connectivity_status.dart lib/main.dart lib/core/validation/nimon_network_online_provider.dart test/core/networking/connectivity_status_test.dart
dart analyze lib/core/networking/connectivity_status.dart lib/main.dart lib/core/validation/nimon_network_online_provider.dart test/core/networking/connectivity_status_test.dart
flutter test test/core/validation
flutter test test/core/networking
flutter test test/features/mono
flutter test test/features/create
flutter test
```

Last full run: **498** tests passed (~3.5m).

## Manual Verification

1. On device/emulator, toggle airplane mode: protected actions (react/follow/save/etc.) should show the central offline snack before hitting repositories when authenticated.
2. Restore network: same actions should proceed (subject to auth), without stale “offline” if the stream updates.

## Remaining Risks

- **`connectivity_plus`** reports **radio/interface** status, not guaranteed end-to-end reachability; transport error mapping remains necessary.
- **Known plugin caveats** (e.g. some Wi‑Fi toggles on simulators) per upstream docs.

## Recommended Next Step

Optional: lightweight **reachability ping** or **failed-request backoff** for stronger “real offline” detection without relying on raw exception strings.

## Follow-up: M13E

Connectivity-driven offline checks remain orthogonal to field validators; see `docs/M13E_FORM_FIELD_VALIDATION_INTEGRATION_REPORT.md`.
