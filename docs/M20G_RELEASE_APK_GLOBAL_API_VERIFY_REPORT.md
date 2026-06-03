# M20G — Release APK global Render API access

## Problem

- Phone **browser** could open `https://nimon-api-global-test.onrender.com/v1/search/monos?limit=1`.
- **Release APK** failed with:
  - `ClientException` / `SocketException: Failed host lookup: 'nimon-api-global-test.onrender.com'`
  - `OS Error: No address associated with hostname`
- `flutter run` with `--dart-define` worked; **release APK** did not.

## Root cause

`android.permission.INTERNET` was declared only in **debug** and **profile** manifest overlays, not in `android/app/src/main/AndroidManifest.xml`. Release builds merge the main manifest only for that permission, so the installed release APK had **no network permission** and DNS/TCP failed before any HTTP request.

## Fix

Added to **main** manifest (outside `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Debug/profile manifests keep their existing INTERNET entries (harmless duplicate on dev builds).

## API base (unchanged)

Compile-time defines at build time:

```text
NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com
NIMON_USE_REMOTE_DRAFTS=true
NIMON_USE_REMOTE_MONO_FEED=true
```

Default when unset remains LAN dev (`http://192.168.11.5:3000`) via `NimonApiConfig` — release QA must pass the Render dart-defines on `flutter build apk`.

## Release diagnostics

On every app start, `main()` logs (no tokens):

```text
[M20G release-config] apiBase=… remoteDrafts=… remoteMonoFeed=…
```

Visible in Android logcat for release APK verification.

## Verification

```bash
flutter test

flutter build apk --release --target-platform android-arm64 \
  --dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true
```

Install the APK, confirm logcat shows Render `apiBase` and flags `true`, then exercise search / remote drafts (same Wi‑Fi or cellular as browser test).

## Phone acceptance checklist

- [ ] Fresh install of **release** APK built with Render dart-defines above
- [ ] Logcat: `M20G release-config` → `apiBase=https://nimon-api-global-test.onrender.com`
- [ ] Mono search / feed loads (no host lookup error)
- [ ] Login / remote drafts work on same network as browser API test
- [ ] Browser still opens search URL (sanity)

## Files touched

- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart` — M20G startup config log

Backend unchanged.
