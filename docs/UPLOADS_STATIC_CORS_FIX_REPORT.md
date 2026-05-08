# Uploads Static CORS Fix Report

## Root Cause

`NestFactory`’s `enableCors()` applies to the Nest HTTP pipeline, but uploaded files are served with **`express.static()`** mounted in `main.ts` **before** the rest of the stack. Static responses therefore did not reliably receive **`Access-Control-Allow-Origin`** and related headers. Flutter web’s `Image.network` and Chrome’s cross-origin image fetch then failed with CORS errors even though `POST /v1/media/upload/cover` returned **201** and a valid URL.

Additionally, some browsers treat cross-origin media with default **Cross-Origin-Resource-Policy** behavior; setting **`Cross-Origin-Resource-Policy: cross-origin`** makes the resource loadable in cross-origin contexts that enforce CORP.

## Files Changed

| File | Change |
|------|--------|
| `nimon-backend/src/common/uploads-static-cors.ts` | New: `isLocalWebDevOrigin` (moved from `main.ts`), `resolveUploadsAccessControlAllowOrigin`, `applyUploadsStaticCors`. |
| `nimon-backend/src/main.ts` | Import helpers; wrap `/uploads` with middleware that applies static CORS headers and short-circuits **OPTIONS** with **204**; extend API `cors` `origin` to honor **`CORS_ORIGIN`** (`*` or exact origin) without breaking existing localhost behavior. |
| `nimon-backend/src/common/uploads-static-cors.spec.ts` | Unit tests for origin resolution and localhost helper. |
| `nimon-backend/.env.example` | Document **`CORS_ORIGIN`**. |

## Static Header Policy

For every response under **`/uploads`** (including **`GET` / `HEAD` / `OPTIONS`**):

- **`Access-Control-Allow-Origin`**: from **`CORS_ORIGIN`** if set (`*` or a single origin URL); otherwise reflect allowed localhost-style **`Origin`**, or **`*`** in non-**`production`** when no allowed **`Origin`**; in **`production`** with no **`CORS_ORIGIN`**, omit when **`Origin`** is not a permitted localhost URL (returns **`null`** — configure **`CORS_ORIGIN`** in prod).
- **`Cross-Origin-Resource-Policy: cross-origin`**
- **`Access-Control-Allow-Methods`**: `GET, HEAD, OPTIONS`
- **`Access-Control-Allow-Headers`**: `Accept, Range, Content-Type, If-None-Match`
- **`Access-Control-Max-Age`**: `86400`
- **`Vary: Origin`** when the allow value is not `*`

## Tests Added

- **`uploads-static-cors.spec.ts`**: **`resolveUploadsAccessControlAllowOrigin`** with **`CORS_ORIGIN`**, **`NODE_ENV`**, and **`Origin`** combinations; **`isLocalWebDevOrigin`** smoke checks.

## Backend Test Result

Commands:

```bash
node ./node_modules/jest/bin/jest.js src/modules/media
node ./node_modules/jest/bin/jest.js src/common/uploads-static-cors.spec.ts
```

**Results:** `src/modules/media` — **2** suites, **17** tests passed. `src/common/uploads-static-cors.spec.ts` — **1** suite, **7** tests passed.

## Backend Build Result

Command:

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** Succeeded (exit code **0**).

## Manual Verification Steps

1. Start the API with default dev env (no **`CORS_ORIGIN`** or **`CORS_ORIGIN=*`** as needed).
2. Upload a cover via **`POST /v1/media/upload/cover`** with a Bearer JWT; note **`url`** (path under **`/uploads/...`**).
3. In Chrome DevTools, open the Flutter web app on **`http://localhost:<port>`** (or your dev origin).
4. Request **`GET`** the returned image URL (full URL to the API host). Confirm response headers include **`Access-Control-Allow-Origin`** (reflected localhost or **`*`**) and **`Cross-Origin-Resource-Policy: cross-origin`**.
5. Confirm **`OPTIONS`** on the same URL returns **204** with the same CORS-related headers.
6. Confirm **`POST /v1/media/upload/cover`** still returns **201** and API preflight for **`/v1/...`** still succeeds.

## Remaining Risks

- **Production** must set **`CORS_ORIGIN`** to the real web app origin if users are not on localhost; otherwise **`Access-Control-Allow-Origin`** may be omitted for strict cross-origin **`Origin`** values.
- Header policy trusts **`CORS_ORIGIN`** for static files when set (single origin or **`*`**); misconfiguration could expose **`Access-Control-Allow-Origin`** too broadly — treat like any CORS env.

---

## Output Summary

| Check | Result |
|-------|--------|
| `/uploads` CORS fixed? | Yes — middleware sets ACAO, CORP, and preflight on `/uploads` |
| Upload endpoint still works? | Yes — unchanged handler; API CORS extended only for **`CORS_ORIGIN`** |
| Image GET has CORS headers? | Yes — applied on every `/uploads` response |
| `jest src/modules/media` passed? | Yes — **17** tests |
| `jest uploads-static-cors.spec.ts` passed? | Yes — **7** tests |
| Backend build passed? | Yes |
