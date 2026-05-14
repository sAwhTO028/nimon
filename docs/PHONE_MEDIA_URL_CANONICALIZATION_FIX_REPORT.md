# Phone Media URL Canonicalization Fix Report

## Problem

Physical phones could not load covers (and some avatars) for older published monos because stored URLs used **`http://localhost:3000/uploads/...`** or **`http://127.0.0.1:3000/uploads/...`**. On a handset, **localhost is the phone**, not the development PC. API responses echoed those strings unchanged.

## Confirmed Root Cause

See [PHONE_OLD_MONO_IMAGE_ROOT_CAUSE_DIAGNOSIS.md](./PHONE_OLD_MONO_IMAGE_ROOT_CAUSE_DIAGNOSIS.md): **`published_monos.content.core.coverImageUrl`** (and profile media fields) retained whatever **`MEDIA_PUBLIC_BASE_URL`** was at upload/publish time.

## Fix Strategy

1. **Pure helper** `canonicalizeMediaUrl(url, mediaPublicBaseUrl)` plus **`clonePublishedContentWithCanonicalMedia`** for nested JSON.
2. **`MediaUrlCanonicalizerService`** reads **`MEDIA_PUBLIC_BASE_URL`** via **`ConfigService`** (same source as disk uploads).
3. **Response-only**: map read paths so outgoing DTOs never mutate ORM rows in memory used for writes.
4. **Optional offline repair**: `scripts/repair-localhost-media-urls.ts` updates stored rows (dry-run default).

Non-goals respected:

- No rewriting of external CDN URLs or non-`/uploads/` localhost URLs (e.g. web **`shareUrl`** / **`/mono/:id`** links unchanged).
- Upload pipeline unchanged.

## Backend Helper

| File | Role |
|------|------|
| `nimon-backend/src/modules/media/media-url-canonicalizer.ts` | `canonicalizeMediaUrl`, `clonePublishedContentWithCanonicalMedia`, `normalizeMediaPublicBaseUrl` |
| `nimon-backend/src/modules/media/media-url-canonicalizer.service.ts` | Nest wrapper: **`mediaPublicBaseUrl()`**, **`url()`** |
| `nimon-backend/src/modules/media/media-url-canonicalizer.module.ts` | Exported **`MediaUrlCanonicalizerModule`** |

Loopback hosts **`localhost`**, **`127.0.0.1`**, **`::1`** (including bracketed IPv6 host parsing quirks) + relative **`/uploads/...`** paths are rewritten to the configured uploads base. **`http(s)`** to other hosts are unchanged.

## DTO Fields Updated

| Area | Fields canonicalized |
|------|----------------------|
| Mono feed (`MonoFeedService`) | `coverUrl`, `writerAvatarUrl` |
| Public mono detail (`MonoFeedService.getPublicMonoById`) | Top-level `coverImageUrl`, **`content.core.coverImageUrl`**, **`learn.audio.storyAudio.sourceUrl`** (cloned JSON), `writerAvatarUrl` |
| Published monos (owner list/detail) | Via **`publishedMonoListItemFromRow`**, **`publishedMonoDetailFromRow`**, **`attachWriterProfile*`**: `coverImageUrl`, `writerAvatarUrl`, nested content as above |
| Creator collections | Collection **`coverImageUrl`** in **`toDto`**; derived mono covers; mono list items + writer avatar |
| Mono bookmarks list (`MonoSocialService`) | Summary **`coverUrl`** |
| User profile (`AuthService` GET/PATCH profile, **`UsersService`** public profile) | **`avatarUrl`**, **`coverImageUrl`** |
| Follow lists (`UserFollowService`) | **`avatarUrl`** on following/followers rows |

## Optional Repair Script

| File | Behavior |
|------|----------|
| `nimon-backend/scripts/repair-localhost-media-urls.ts` | **Dry-run by default** (logs counts). **`--write`** persists updates to **`published_monos.content`**, **`user_profiles`** (`avatarUrl`, `coverImageUrl`), **`creator_mono_collections.coverImageUrl`**. Uses Prisma + **`@prisma/adapter-pg`** like the app. |

Run (from `nimon-backend`):

```powershell
pnpm exec ts-node --transpileOnly scripts/repair-localhost-media-urls.ts
pnpm exec ts-node --transpileOnly scripts/repair-localhost-media-urls.ts --write
```

If `pnpm`/`npm` are unavailable, use `node_modules\.bin\ts-node.cmd` analogously.

## Tests Added

- **`media-url-canonicalizer.spec.ts`**: URL matrix (null, relative `/uploads`, localhost, 127.0.0.1, IPv6, LAN unchanged, CDN unchanged, query string, malformed).
- **`mono-feed.service.spec.ts`**: Feed rewrites loopback cover + writer avatar when base is LAN.
- **`published-monos.service.spec.ts`**: List row **`coverImageUrl`** + **`writerAvatarUrl`** canonicalization.

Existing suites updated for **`MediaUrlCanonicalizerService`** injection and PATCH profile expectation (`127.0.0.1` uploads URL normalized to default **`localhost`** uploads base in tests).

## Commands Run

```powershell
Set-Location nimon-backend
.\node_modules\.bin\prisma.cmd generate
.\node_modules\.bin\jest.cmd src/modules/media --runInBand
.\node_modules\.bin\jest.cmd src/modules/mono-feed src/modules/published-monos --runInBand
.\node_modules\.bin\jest.cmd --runInBand
.\node_modules\@nestjs\cli\bin\nest.js build
```

## Manual Verification

After **`MEDIA_PUBLIC_BASE_URL=http://192.168.11.5:3000/uploads`** and backend restart:

1. **`GET http://127.0.0.1:3000/v1/mono/feed?limit=5`** — previously **`localhost`** **`coverUrl`** values should appear as **`http://192.168.11.5:3000/uploads/...`**.
2. **`GET /v1/mono/:id`** — **`coverImageUrl`** and nested **`content.core.coverImageUrl`** match.
3. Flutter (example defines from `lib/features/create/data/remote_backend_config.dart`):

```powershell
flutter run `
  --dart-define=NIMON_API_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true `
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

Confirm old and new mono covers and profile avatars where stored under **`/uploads/`**.

## Summary Checklist

| Check | Result |
|--------|--------|
| Old localhost **`/uploads`** URLs canonicalized in API responses | Yes |
| New LAN **`192.168.*`** URLs unchanged | Yes |
| External **`https://`** URLs unchanged | Yes |
| Feed / detail / profile / follow / bookmarks paths covered | Yes |
| Unit tests | 179 passed (`nimon-backend`) |
| **`nest build`** | Success |

Phone smoke: confirm on device after restart (not executed in this environment).

## Remaining Risks

- **`MEDIA_PUBLIC_BASE_URL`** must match the host the phone can reach; Wi‑Fi IP changes require updating env or DNS.
- **`shareUrl`** / non-upload localhost links are intentionally **not** rewritten (web navigation, not media).
- Repair script mutates production JSON; use dry-run first.

## Recommended Next Step

Deploy with a stable uploads base (LAN hostname or tunnel) and run the repair script **`--write`** once per environment if you want DB rows aligned with responses (optional; response canonicalization alone fixes the phone reader).
