# Share URL Standardization Report

## Problem

Mono **share** links in API responses used **`http://localhost:3000/mono/<id>`** when `NIMON_PUBLIC_WEB_BASE_URL` was unset. On a physical phone (or when sharing to another person), **localhost** points at the **receiver’s device**, not the Nimon host. This is separate from **media/upload** URLs (`MEDIA_PUBLIC_BASE_URL`).

## Decision

- **Share URLs** are built only from **`NIMON_PUBLIC_WEB_BASE_URL`** (with legacy alias **`PUBLIC_WEB_BASE_URL`**), normalized: trim, strip trailing slashes, default **`http://localhost:3000`** when empty.
- **Never** use **`MEDIA_PUBLIC_BASE_URL`** for `/mono/:id` links.
- **Do not** run share URLs through the media URL canonicalizer.
- **Flutter:** Prefer **`MonoFeedItem.shareUrl`** from the API; optional client fallbacks use **`NIMON_PUBLIC_WEB_BASE_URL`** dart-define, then a **non-loopback** **`NIMON_API_BASE_URL`** — never **`localhost`** / **`127.0.0.1`** as a fallback (shows “unavailable” instead).

## Env Variables

| Variable | Purpose |
|----------|---------|
| **`NIMON_PUBLIC_WEB_BASE_URL`** | Origin for **`/mono/<id>`** share and web links (backend + documented for dev). |
| **`PUBLIC_WEB_BASE_URL`** | Optional legacy alias; secondary to `NIMON_PUBLIC_WEB_BASE_URL`. |
| **`MEDIA_PUBLIC_BASE_URL`** | **Unchanged** — uploads only; not used for share links. |

Example **LAN phone testing** (backend `.env`):

```env
NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000
MEDIA_PUBLIC_BASE_URL=http://192.168.11.5:3000/uploads
```

Example **production**:

```env
NIMON_PUBLIC_WEB_BASE_URL=https://nimon.app
```

Flutter (optional overrides):

```text
--dart-define=NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000
--dart-define=NIMON_API_BASE_URL=http://192.168.11.5:3000
```

## Backend Changes

| Item | Detail |
|------|--------|
| **`nimon-backend/src/modules/common/nimon-public-web-url.ts`** | `normalizeNimonPublicWebBaseUrl`, `monShareUrlForMonoId` (pure helpers). |
| **`PublicWebBaseUrlService` / `PublicWebBaseUrlModule`** | Nest injectable: **`baseUrl()`**, **`monoShareUrl(id)`**. |
| **`MonoFeedService`** | Feeds **`shareUrl`** via **`PublicWebBaseUrlService`**; removed inline env duplicate. |
| **`MonoSocialService`** | Bookmark list **`shareUrl`** via same service. |
| **`PublishedMonosService`** | **`shareUrl`** on owner list + **`GET /v1/published-monos/:id`** detail. |
| **`published-monos.dto.ts`** | Optional **`shareUrl`** on list item type. |

## Flutter Changes

| Item | Detail |
|------|--------|
| **`remote_backend_config.dart`** | **`RemoteBackendConfig.publicWebBaseUrl`** (`NIMON_PUBLIC_WEB_BASE_URL`, default empty). |
| **`share_mono_link.dart`** | **`resolveMonoShareUrlForItem`** (testable); **`shareMonoLink`** uses it. |
| **`published_mono_dto.dart`**, **`remote_published_mono_repository.dart`**, **`mono_feed_item_mapper.dart`** | **`shareUrl`** on profile published list → **`MonoFeedItem`**. |

## Tests Added

- **Backend:** `nimon-public-web-url.spec.ts`, `public-web-base-url.service.spec.ts`; **mono-feed** case for share host vs media base; **published-monos** expectations for **`shareUrl`**.
- **Flutter:** `test/features/mono/share_mono_link_resolve_test.dart` (backend wins, public-web fallback, LAN api fallback, no localhost fallback, **`catalogMonoId`** path).

## Commands Run

```powershell
Set-Location nimon-backend
.\node_modules\.bin\jest.cmd src/modules/mono-feed --runInBand
.\node_modules\.bin\jest.cmd src/modules/published-monos --runInBand
.\node_modules\.bin\jest.cmd --runInBand
.\node_modules\@nestjs\cli\bin\nest.js build
```

```powershell
Set-Location ..  # repo root
dart format lib/features/mono/share_mono_link.dart lib/features/create/data/remote_backend_config.dart lib/features/profile/data/published_mono_dto.dart lib/features/profile/data/remote_published_mono_repository.dart lib/features/mono/data/mono_feed_item_mapper.dart test/features/mono/share_mono_link_resolve_test.dart
flutter analyze lib/features/mono lib/features/create/data/remote_backend_config.dart lib/features/profile/data
flutter test test/features/mono
flutter test
```

## Manual Verification

1. Set **`NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000`** on the Nest host; restart.
2. **`GET /v1/mono/feed?limit=3`** — each **`shareUrl`** should be **`http://192.168.11.5:3000/mono/<uuid>`** (no **`localhost`**).
3. **`GET /v1/mono/<id>`** — same **`shareUrl`** shape.
4. **`GET /v1/published-monos`** (authenticated) — items include **`shareUrl`** with the same base.
5. Flutter: share from reader — clipboard should match backend **`shareUrl`** when using remote feed.

## Remaining Risks

- **Deep links / universal links** for **`https://nimon.app/mono/...`** still need app-side routing when a future web client exists.
- If both **`NIMON_PUBLIC_WEB_BASE_URL`** and Flutter defines are wrong, users may still copy a bad link; backend env is the primary fix.

## Production Recommendation

Set **`NIMON_PUBLIC_WEB_BASE_URL=https://nimon.app`** (or your canonical marketing domain) in production secrets. Keep **`MEDIA_PUBLIC_BASE_URL`** on your CDN/object storage origin as today. Document ops runbook so share and upload bases are not confused.
