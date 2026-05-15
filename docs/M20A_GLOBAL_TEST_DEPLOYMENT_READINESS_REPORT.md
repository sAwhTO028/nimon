# M20A — Global test server deployment readiness audit

**Scope:** Readiness for a **free global test / beta-style** deployment (not production).  
**Target:** Render Web Service (API) + Supabase Postgres; Flutter uses `--dart-define=NIMON_API_BASE_URL=…` to the Render public URL.  
**Out of scope for this doc:** Actual deploy, `render.yaml` in-repo (proposal only below), product feature changes, secrets.

---

## 1. Executive summary

| Area | Status |
|------|--------|
| Backend package / paths | **Ready** — `pnpm`, root `nimon-backend/`, `nest build` → `dist/src/main.js` |
| Process port | **Ready** — `PORT` with fallback `3000` |
| Database | **Ready pattern** — `DATABASE_URL` + Prisma; **Supabase connection string required** |
| Prisma CLI | **Ready** — `prisma.config.ts` supplies `datasource.url` from `DATABASE_URL` |
| CORS + static `/uploads` | **Configurable** — must set **`CORS_ORIGIN`** (and uploads CORS behavior) for non-localhost clients in production mode |
| Health | **Ready** — `GET /health` |
| JWT | **Ready** — `JWT_SECRET` (≥32 chars when `NODE_ENV=production`); refresh is **opaque**, not a second JWT secret |
| Media (disk on Render) | **Blocker-class limitation** — **ephemeral filesystem**; use **S3/R2** or accept data loss on restart |

---

## 2. Why Render + Supabase for *test only*

- **Cost:** Free/low tiers fit smoke and small beta cohorts.
- **Risk:** Cold starts, sleep, bandwidth limits, and **no SLA** — inappropriate as sole production stack without upgrades and runbooks.
- **Data:** Treat DB and object storage as **disposable** or regularly backed up if you care about beta content.

---

## 3. Backend facts (audited)

### Package manager

- **pnpm** — `nimon-backend/pnpm-lock.yaml` present; use `pnpm install`, `pnpm run …`.

### Root path

- **`nimon-backend/`** (repository subfolder; not repo root).

### Build command

- **`pnpm run build`** → runs `nest build` (`package.json` `"build": "nest build"`).
- Verified alternative (per task):  
  `node node_modules/@nestjs/cli/bin/nest.js build`  
  (equivalent to Nest CLI.)

### Start command (production-style)

- **`pnpm run start:prod`** → `node dist/src/main.js`  
  Same as **`pnpm run start:local`**.

### Build output entrypoint

- **`dist/src/main.js`** (confirmed in `package.json` scripts `start:prod` / `start:local` / `start:once`).

### Prisma

| Command | Purpose |
|---------|---------|
| **`pnpm run prisma:generate`** | `prisma generate` — client after schema changes |
| **`pnpm exec prisma migrate deploy`** | Apply migrations to the target DB (CI/Render release phase) |

There is **no** `prisma:migrate:deploy` npm script today; use `pnpm exec prisma migrate deploy` (or `npx prisma migrate deploy` after install).

- **Config:** `prisma.config.ts` — `datasource.url` = `process.env.DATABASE_URL` (required for CLI).
- **Runtime:** `PrismaService` uses `process.env.DATABASE_URL` with a **dev fallback** `postgresql://nimon:nimon@localhost:5432/nimon?schema=public` if unset — **must set `DATABASE_URL` on Render** so the app does not point at a non-existent host.

### Required / important environment variables

Derived from `ConfigModule`, `main.ts`, `auth.config.ts`, media modules, `public-web-base-url.service.ts`, `prisma.config.ts`, and related code:

| Variable | Role |
|----------|------|
| `DATABASE_URL` | Postgres (Supabase); Prisma + runtime |
| `JWT_SECRET` | Access token signing; **≥32 chars** when `NODE_ENV=production` |
| `JWT_EXPIRES_IN` | Access JWT expiry (default `15m`) |
| `JWT_REFRESH_EXPIRES_IN` | Opaque refresh TTL in **seconds** (default `604800`) |
| `PORT` | Listen port (Render sets this) |
| `NODE_ENV` | `production` enables stricter JWT and uploads CORS behavior |
| `CORS_ORIGIN` | API CORS allowlist / `*` behavior (see `main.ts`) |
| `NIMON_PUBLIC_WEB_BASE_URL` | Share links `/mono/:id` (optional `PUBLIC_WEB_BASE_URL`) |
| `MEDIA_PUBLIC_BASE_URL` | Canonical base for `/uploads/...` URLs in API responses |
| `MEDIA_UPLOAD_DIR` | Directory for disk driver (default `uploads`) |
| `MEDIA_STORAGE_DRIVER` | `disk` \| `s3` \| `r2` |
| S3/R2 vars | `MEDIA_BUCKET`, `MEDIA_REGION`, `MEDIA_ACCESS_KEY_ID`, `MEDIA_SECRET_ACCESS_KEY`, optional `MEDIA_ENDPOINT`, `MEDIA_OBJECT_KEY_PREFIX`, `MEDIA_S3_FORCE_PATH_STYLE` |
| `MEDIA_COVER_MAX_BYTES`, `MEDIA_AUDIO_MAX_BYTES` | Upload limits |
| `ALLOW_DEV_OWNER_FALLBACK`, `DEV_OWNER_ID` | **Dev only** — must stay **off** / unset on shared test servers |

**Not used:** `JWT_REFRESH_SECRET` (refresh is opaque + SHA-256 in DB, not a second signed JWT).  
**Aliases documented only:** `APP_PUBLIC_BASE_URL`, `UPLOAD_PUBLIC_BASE_URL` — live code uses `NIMON_PUBLIC_WEB_BASE_URL` / `PUBLIC_WEB_BASE_URL` and `MEDIA_PUBLIC_BASE_URL`.

### CORS

- **API:** `src/main.ts` — `CORS_ORIGIN` = `*` (reflect origin), exact match, or localhost-style origins via `isLocalWebDevOrigin`.
- **Static `/uploads`:** `src/common/uploads-static-cors.ts` — separate rules; in **`NODE_ENV=production`** without `CORS_ORIGIN`, non-localhost browser origins may get **no** `Access-Control-Allow-Origin` on static files.

### `PORT`

- `const port = Number(process.env.PORT ?? 3000);` — **Render-compatible**.

### Health endpoint

- **`GET /health`** → `{ "status": "ok" }` (`HealthController`, no global prefix in codebase).

### Uploads / static files

- Express **`/uploads`** serves files from `MEDIA_UPLOAD_DIR` (resolved under `cwd` unless absolute).
- **`MEDIA_PUBLIC_BASE_URL`** must be a URL clients can use to load images/audio (typically `https://<your-render-service>.onrender.com/uploads` for disk mode, or a CDN/R2 public URL).

---

## 4. Hardcoded / default local URL audit

### Backend blockers (must address for global test)

1. **`PrismaService` default `DATABASE_URL`** — if `DATABASE_URL` is missing at runtime, connection targets **localhost** Postgres. **Set `DATABASE_URL` in Render** to Supabase.
2. **Ephemeral disk on Render** — `MEDIA_STORAGE_DRIVER=disk` stores uploads on instance disk; **restarts / redeploys lose files**. For meaningful media testing use **S3-compatible** (`s3` / `r2`) or accept limitation.
3. **Production CORS for Flutter app + `/uploads`** — set **`CORS_ORIGIN`** to your Flutter **web** origin if testing web, or appropriate policy; align **`MEDIA_PUBLIC_BASE_URL`** with the public URL that serves `/uploads`.

### Flutter “blockers” (configuration, not code defects)

- **`RemoteBackendConfig.apiBaseUrl`** defaults to **`http://localhost:3000`** — release/test builds **must** pass **`--dart-define=NIMON_API_BASE_URL=https://<render-host>`** (and **`NIMON_PUBLIC_WEB_BASE_URL`** if share links must not be localhost).
- **`NIMON_USE_REMOTE_DRAFTS`**, **`NIMON_USE_REMOTE_MONO_FEED`**, etc. — feature flags already documented elsewhere; test builds need the right combination for “all remote” smoke.

### Docs-only / tests / safe local defaults

- **`DEFAULT_NIMON_PUBLIC_WEB_BASE_URL`**, **`DEFAULT_MEDIA_PUBLIC_BASE_URL`** in TypeScript — dev defaults; overridden by env in deployment.
- **`mono-feed.service.ts`** share URL fallback string `http://localhost:3000` when env-derived base is empty — **mitigated** by setting **`NIMON_PUBLIC_WEB_BASE_URL`** on the server.
- **Tests** (`*.spec.ts`, `test/**/*.dart`) — localhost / `127.0.0.1:9` — **safe to ignore** for deployment.
- **Markdown docs** — illustrative URLs — **docs-only**.

---

## 5. Suggested Render release command sequence

From repo root:

```bash
cd nimon-backend
pnpm install --frozen-lockfile
pnpm run prisma:generate
pnpm exec prisma migrate deploy
pnpm run build
node dist/src/main.js
```

Render typically splits **build** vs **start**; ensure **`DATABASE_URL`** (and other env vars) are available in **both** phases if migrations run at build time.

---

## 6. Supabase (Postgres) — minimal steps

1. Create a Supabase project → **Project Settings → Database** → copy **connection string** (URI), often with `?sslmode=require`.
2. Set **`DATABASE_URL`** on Render to that URI (pooler vs direct: follow Supabase docs for serverless vs long-lived Node; Prisma docs cover pooler parameters).
3. Run **`pnpm exec prisma migrate deploy`** against that URL before or during first deploy (same schema as repo migrations under `prisma/migrations/`).

---

## 7. Flutter — API base URL switch

Example (replace host):

```text
flutter run --dart-define=NIMON_API_BASE_URL=https://nimon-api-xxxx.onrender.com
```

Optional for correct share / deep links when not relying on API-returned `shareUrl`:

```text
--dart-define=NIMON_PUBLIC_WEB_BASE_URL=https://nimon-api-xxxx.onrender.com
```

Use **`flutter test`** after changing compile-time defaults only if you alter Dart code; defines are build-time.

---

## 8. Media upload limitation (global test)

| Topic | Detail |
|-------|--------|
| **Disk on Render** | Uploads stored under **`MEDIA_UPLOAD_DIR`** are on **ephemeral** instance storage unless you attach persistent disk (paid) — **not recommended** for free test. |
| **Canonical URLs** | **`MEDIA_PUBLIC_BASE_URL`** must match what phones can reach (your Render URL + `/uploads` for disk mode, or public CDN/R2 URL for object storage). |
| **Better test setup** | **`MEDIA_STORAGE_DRIVER=r2`** or **`s3`** + matching env vars so media survives deploys. |

---

## 9. Smoke checklist (post-deploy, no code changes)

- [ ] `GET https://<host>/health` → `200`, JSON `status: "ok"`.
- [ ] `DATABASE_URL` set; app logs show expected DB host (see Prisma log line), no `P1001` to localhost.
- [ ] Register / login from a **physical phone** on cellular (not Wi‑Fi tied to dev LAN).
- [ ] Create draft / publish path (as applicable) with **cover upload** — image loads on device.
- [ ] Mono feed / profile / search hits same API base (no accidental `localhost` in client defines).
- [ ] **`JWT_SECRET`** is long random in production mode; **`ALLOW_DEV_OWNER_FALLBACK`** unset/false.

---

## 10. Rollback

1. **Render:** redeploy previous **successful** deploy or disable service.
2. **Database:** restore Supabase backup snapshot if migrations or bad data must be reverted (take a snapshot **before** first mass test if data matters).
3. **Flutter:** revert build defines / CI channel to previous API URL.

---

## 11. `render.yaml` (proposal only — not added to repo)

Reason: single service + env-driven config is enough for first deploy; confirm **build/start** and **migrate** placement with your team.

```yaml
services:
  - type: web
    name: nimon-backend
    rootDir: nimon-backend
    runtime: node
    buildCommand: pnpm install --frozen-lockfile && pnpm run prisma:generate && pnpm exec prisma migrate deploy && pnpm run build
    startCommand: node dist/src/main.js
    envVars:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        sync: false
      - key: JWT_SECRET
        sync: false
      - key: CORS_ORIGIN
        sync: false
      - key: MEDIA_PUBLIC_BASE_URL
        sync: false
      - key: NIMON_PUBLIC_WEB_BASE_URL
        sync: false
```

Tune **`buildCommand`** if migrations should run in a one-off job instead of every build.

---

## 12. Verification commands (executed for this audit)

From `nimon-backend`:

```bash
node node_modules/@nestjs/cli/bin/nest.js build
node node_modules/jest/bin/jest.js --runInBand
```

*(Record actual exit codes in your CI; this audit assumes they pass on a clean checkout with dev deps installed.)*

Flutter: **`flutter test`** recommended whenever Dart compile-time API config or networking contracts change; **not required** for backend-only doc updates.

---

## 13. Files touched by M20A

- `nimon-backend/.env.example` — expanded to list **real** env vars used by code (no secrets).
- `docs/M20A_GLOBAL_TEST_DEPLOYMENT_READINESS_REPORT.md` — this document.

---

## 14. Return summary (task checklist)

| Item | Result |
|------|--------|
| Backend deploy readiness | **Conditionally ready** — needs **`DATABASE_URL`**, strong **`JWT_SECRET`**, **`CORS_ORIGIN`** / public URL alignment, and a **media persistence strategy** for real uploads |
| Blockers | **Ephemeral disk** for default **`MEDIA_STORAGE_DRIVER=disk`** on Render; **production CORS** for non-local clients; **must set env** to avoid Prisma localhost fallback |
| Required env vars | See **§3** and **`.env.example`** |
| Build / start | **`pnpm run build`** → **`node dist/src/main.js`** |
| Prisma migrate | **`pnpm exec prisma migrate deploy`** (after `pnpm run prisma:generate` in CI) |
| Hardcoded locals found? | **Yes** — dev defaults and test fixtures; **operational mitigation** = env on server + dart-defines on clients |
| Media limitation documented? | **Yes** — §8 |
| Docs updated? | **Yes** — this file + `.env.example` |
