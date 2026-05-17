# M20D — Flutter global test API switch (Render)

**Goal:** Point the Flutter app at the **Render** global test backend for phone smoke, while keeping an easy **local LAN** dev path.

**Render API:** `https://nimon-api-global-test.onrender.com`

---

## Root cause (why Publish showed no POST on Render)

Two issues showed up in the field:

1. **API base was not a single obvious compile-time default.** Earlier builds used `NIMON_API_TARGET` with a **localhost** fallback when nothing was set. That made it easy to think `NIMON_API_BASE_URL` was “the” switch while the binary still resolved to a different origin, or to run from an IDE **without** the same `--dart-define` flags as the CLI.

2. **Remote drafts are opt-in.** `story_draft_repository_provider` uses [RemoteStoryDraftRepository] only when `NIMON_USE_REMOTE_DRAFTS=true`. Otherwise the app uses [LocalStoryDraftRepository], so **Publish never performs network POSTs** regardless of API base URL. Search could still hit Render if wired separately, which matches “GET /v1/search/monos works but Publish does not.”

---

## Fixed API base (single source of truth)

| File | Role |
|------|------|
| **`lib/core/config/nimon_api_config.dart`** | **Only** `String.fromEnvironment('NIMON_API_BASE_URL', defaultValue: 'http://192.168.11.5:3000')` plus optional `NIMON_PUBLIC_WEB_BASE_URL` |
| **`lib/features/create/data/remote_backend_config.dart`** | Thin facade — `apiBaseUrl` / `publicWebBaseUrl` delegate to `NimonApiConfig` |

All repositories and providers that use **`RemoteBackendConfig.apiBaseUrl`** follow that one compile-time value. There is **no** `NIMON_API_TARGET` indirection anymore.

---

## Debug / profile startup log

On **debug** and **profile** builds only, `main()` prints (no tokens):

```text
[M20D api-base] <resolved-api-origin>
```

Use it to confirm the binary you installed actually contains the expected base URL.

---

## Command to run with Render API

**Publish smoke (network drafts + Render base):**

```text
flutter run --dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

Add feed/search flags as needed for your scenario:

```text
flutter run --dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com --dart-define=NIMON_USE_REMOTE_DRAFTS=true --dart-define=NIMON_USE_REMOTE_MONO_FEED=true
```

**LAN default (no dart-define):** API base is `http://192.168.11.5:3000` (Nest on `0.0.0.0:3000`, phone on same Wi‑Fi).

**Android emulator → host:**

```text
flutter run --dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000 --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

---

## Phone verification (Render logs)

1. Run the **Render** command above (include `NIMON_USE_REMOTE_DRAFTS=true` if you need Publish to hit the network).
2. In the device logcat / Flutter console, confirm **`[M20D api-base] https://nimon-api-global-test.onrender.com`**.
3. Tap **Publish** on a flow that uses remote drafts.
4. **Render logs must show a POST** to the draft/publish path (not only `GET /v1/search/monos`).

If search hits Render but Publish does not, re-check **`NIMON_USE_REMOTE_DRAFTS`** on the **exact** run configuration used to install the app (IDE run configs often omit CLI dart-defines).

---

## Tests

- **`test/core/config/nimon_api_config_test.dart`** — default LAN base; optional skipped test proves dart-define when run with `VERIFY_NIMON_API_DEFINE=true` and `NIMON_API_BASE_URL=...`.
- **`test/core/config/remote_backend_api_base_wiring_test.dart`** — `RemoteBackendConfig` delegates to `NimonApiConfig`.
- **`test/features/search/remote_mono_search_repository_api_host_test.dart`** — search client uses injected API origin for `/v1/search/monos`.
- **`test/features/create/remote_story_draft_repository_api_host_test.dart`** — draft client uses injected API origin for `/v1/story-drafts`.

Full suite: **`flutter test`**.

---

## Notes

- **Backend / publish UI logic:** unchanged in M20D; only config, wiring visibility, tests, and docs.
- **Render cold start:** first request after idle may be slow; retry once if needed.
