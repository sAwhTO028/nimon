# M20C — Render Web Service deployment prep (Nimon backend)

**Goal:** Exact instructions to create a **Render Web Service** for the NestJS API **manually** (no auto-deploy from this doc). **Do not commit secrets**; use placeholders below.

** Preconditions (M20B):** Supabase Postgres is migrated; Prisma generate/build succeed locally.

---

## 1. Backend root

| Item | Value |
|------|--------|
| Monorepo service root | **`nimon-backend/`** (directory at repo root: `nimon/nimon-backend`) |
| `package.json` | **Present** at `nimon-backend/package.json` |
| Render **Root Directory** | Set to **`nimon-backend`** when the Render service is attached to the **parent** git repo (`nimon`). If the Render service uses a **subtree repo** that only contains the backend, root can be `.`. |

---

## 2. Package manager

| Lockfile | `pnpm-lock.yaml` (**pnpm** is the repo’s lockfile source of truth) |
| `package-lock.json` | **Not present** — npm will resolve from `package.json` only unless you add a lockfile. |
| Local dev note | On some machines `pnpm` / `npm` may be missing from `PATH`; **Render’s Node environment provides npm**, so npm-style commands below are valid on Render. |
| Recommended install on Render (pnpm) | `corepack enable && corepack prepare pnpm@latest --activate && pnpm install --frozen-lockfile` **or** pin a pnpm version your team uses. |
| Fallback (npm only) | `npm install` (no frozen lock unless you add `package-lock.json`). |

---

## 3. Build command (Render “Build Command”)

Use the **Root Directory** = `nimon-backend` so commands do **not** need `cd nimon-backend` **when Render is already rooted there**. If Render root is repo root instead, prefix with `cd nimon-backend &&`.

**Recommended (Root Directory = `nimon-backend`, npm):**

```bash
npm install && npx prisma generate && npm run build
```

**If using pnpm (frozen lockfile):**

```bash
corepack enable && corepack prepare pnpm@latest --activate && pnpm install --frozen-lockfile && npx prisma generate && pnpm run build
```

**Notes:**

- `npm run build` runs **`nest build`** per `package.json`.
- `npx prisma generate` matches local usage; alternative: `npm run prisma:generate` (runs the same Prisma CLI path).
- Prisma reads **`DATABASE_URL`** from the environment via `prisma.config.ts` — ensure **`DATABASE_URL`** (or a build-time secret) is available in Render if you run `prisma generate` at build time. Often **`DATABASE_URL`** is already set as a Render secret for migrate/start.

---

## 4. Start command (Render “Start Command”)

**Compiled entrypoint (verified in `package.json`):** **`dist/src/main.js`**  
(not `dist/main.js`).

**Why migrate in start:** Applies pending migrations on each new deploy before the server accepts traffic.

**Important (Supabase pooler):** If runtime **`DATABASE_URL`** uses **pgbouncer / port 6543**, some migration workloads are safer against a **direct** connection. Keep a separate env var **`DIRECT_URL`** (Supabase **5432** connection string, password URL-encoded). Run migrate in a **subshell** so only the migrate step uses `DIRECT_URL`, then the app keeps the pooled `DATABASE_URL`:

**Recommended start (bash, Root Directory = `nimon-backend`):**

```bash
( export DATABASE_URL="$DIRECT_URL" && npx prisma migrate deploy ) && node dist/src/main.js
```

If Render root is the **repo root**:

```bash
cd nimon-backend && ( export DATABASE_URL="$DIRECT_URL" && npx prisma migrate deploy ) && node dist/src/main.js
```

---

## 5. `process.env.PORT`

**Supported.** `src/main.ts` uses:

`const port = Number(process.env.PORT ?? 3000);`

**Render:** Injects **`PORT`** automatically — **do not** hardcode `10000` unless you have a special port mapping. Omit a manual `PORT` env on Render so the platform value wins, **or** set `PORT` explicitly to match Render’s assigned port if you use a custom domain/port setup.

---

## 6. Required Render environment variables

Use **exact names** from backend code / Prisma config. Values are **placeholders** only.

| Variable | Purpose / notes |
|----------|------------------|
| `DATABASE_URL` | Supabase **pooled** URL (typical **port 6543**, `?pgbouncer=true` as per Supabase). **Password must be URL-encoded** in the URI. Used by Prisma at **runtime** and by `PrismaService`. |
| `DIRECT_URL` | Supabase **direct** URL (**port 5432**, same user/host pattern). Used **only for the migrate subshell** in the start command above. |
| `JWT_SECRET` | Access JWT signing secret — **≥ 32 characters** when `NODE_ENV=production` (`auth.config.ts`). |
| `JWT_EXPIRES_IN` | e.g. `15m` |
| `JWT_REFRESH_EXPIRES_IN` | **Integer seconds** (e.g. `2592000` for ~30 days). **Not** a `30d`-style string. |
| `NODE_ENV` | `production` |
| `CORS_ORIGIN` | For global smoke: `*` is acceptable (`main.ts`). **Tighten later** to a single web/app origin. |
| `MEDIA_UPLOAD_DIR` | e.g. `uploads` — local disk folder under process cwd for `express.static` `/uploads`. |
| `MEDIA_PUBLIC_BASE_URL` | Public base for canonical media URLs, e.g. `https://<your-service>.onrender.com/uploads` (**no trailing slash** after normalization in code paths — trailing slashes are stripped in normalizers; still use canonical shape). |
| `NIMON_PUBLIC_WEB_BASE_URL` | Public origin for web/share routes (e.g. `https://<your-service>.onrender.com`). Optional alias: `PUBLIC_WEB_BASE_URL` is read in some services. |

**Requested but not consumed by current JWT code:** `JWT_REFRESH_SECRET` — refresh tokens are **opaque** in this codebase; you may still set this in Render for **future parity** or tooling, but Nest does not read it today.

**S3/R2 (omit for disk-only smoke):** `MEDIA_STORAGE_DRIVER`, `MEDIA_BUCKET`, `MEDIA_REGION`, `MEDIA_ACCESS_KEY_ID`, `MEDIA_SECRET_ACCESS_KEY`, `MEDIA_ENDPOINT`, etc. — see `nimon-backend/.env.example`.

**Never on shared hosts:** `ALLOW_DEV_OWNER_FALLBACK`, careless `DEV_OWNER_ID` — keep dev fallbacks disabled.

---

## 7. CORS

- **API CORS:** `CORS_ORIGIN` in `src/main.ts` (`*` reflects Origin; single origin exact match; localhost dev origins allowed via helper).
- **Static `/uploads` CORS:** `src/common/uploads-static-cors.ts` — separate from Nest `enableCors`; with `NODE_ENV=production`, ensure `CORS_ORIGIN` is set appropriately for browser clients loading media.

---

## 8. Static `/uploads`

- Served from **`MEDIA_UPLOAD_DIR`** (resolved under `cwd` unless absolute) via `express.static` in `src/main.ts`.
- **Limitation (Render free / ephemeral disk):** Files are **not durable** across redeploys/restarts. **OK for temporary smoke** only. **M20E** (or later) should move to **Supabase Storage / R2 / S3** for persistent media.

---

## 9. Render UI setup steps (manual)

1. **New → Web Service** → connect the Git repo.
2. Set **Root Directory** to **`nimon-backend`** (if deploying from the monorepo).
3. **Runtime:** Node (LTS aligned with `package.json` engines if you add engines; otherwise Render default LTS).
4. **Build Command:** section 3.
5. **Start Command:** section 4.
6. **Environment → Environment Variables:** add all variables from section 6 (paste secrets in the UI only; never commit).
7. **Health check path (optional):** `GET /health` returns `{ "status": "ok" }` (no `/v1` prefix).
8. **Deploy** once configuration is saved.

---

## 10. Prisma migration behavior

- **`prisma migrate deploy`** is **non-interactive** and applies pending migrations from `prisma/migrations/`.
- **Subshell + `DIRECT_URL`** avoids running migrations solely through a **transaction-pooled** URL when that is problematic.
- After migrate, **`node dist/src/main.js`** runs with the outer shell’s **`DATABASE_URL`** (pooled) for normal app traffic.

---

## 11. Health / API smoke checklist (post-deploy)

- [ ] `GET https://<service>.onrender.com/health` → `200`, body contains `"status":"ok"`.
- [ ] `GET https://<service>.onrender.com/v1/...` (a known public route) responds without 5xx.
- [ ] Register/login smoke (if enabled) against production `JWT_SECRET`.
- [ ] Upload a small cover image; `GET` the returned `/uploads/...` URL from a phone off-LAN (validates `MEDIA_PUBLIC_BASE_URL` + CORS).

---

## 12. Rollback / delete

- **Rollback deploy:** Render dashboard → **Manual Deploy** → select a previous **successful** deploy.
- **Delete service:** Render → service → **Settings** → delete (irreversible; rotate DB credentials if you suspect exposure).

---

## 13. Next step

**You** create the Render Web Service manually using this doc, then point Flutter (`NIMON_API_BASE_URL`, etc.) in a **later** step (not part of M20C).

---

## 14. Blockers

**None identified** for Render prep from the current repo layout: **`dist/src/main.js`**, **`PORT`**, scripts, and env names match the implementation.
