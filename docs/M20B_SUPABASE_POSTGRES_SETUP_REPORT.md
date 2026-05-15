# M20B — Supabase Postgres setup (Step 3)

**Purpose:** Wire a **local-only** Supabase-backed env file after **DB password rotation**, run Prisma against that database, and confirm migrations without seeding.

**Security:** A previous database password was exposed in chat and is treated as **compromised**. It must **not** be reused. Only the **new rotated** password belongs in local files (`nimon-backend/.env` and/or `nimon-backend/.env.global-test.local`). **No secrets appear in this document.**

---

## 1. Password rotation

- **Operator action:** Rotate the Supabase database password in the Supabase dashboard and URL-encode any reserved characters in the connection string (e.g. `@` → `%40`, `#` → `%23`).
- **Local files:** Put the new encoded credentials only in **gitignored** files (see below). This step does **not** commit secrets.

---

## 2. Gitignore protection

`nimon-backend/.gitignore` includes:

- `.env`
- `.env.local`
- `.env*.local` (covers patterns such as `.env.something.local`)
- `.env.global-test.local` (explicit entry)

These paths are **not** tracked by git when configured correctly.

---

## 3. Local env file: `.env.global-test.local`

**Path:** `nimon-backend/.env.global-test.local` (**gitignored** — never commit).

**Contents (shape only):**

| Variable | Notes |
|----------|--------|
| `DATABASE_URL` | Supabase **pooler** session mode — host `…pooler.supabase.com`, port **`6543`**, database `postgres`, `?pgbouncer=true` as per Supabase/Prisma guidance. |
| `DIRECT_URL` | Same pooler host, port **`5432`** (direct / non-pooled) — used for Prisma **`migrate deploy`** in this step to avoid pgbouncer migration issues. |
| `JWT_SECRET` | Random string **≥ 32 characters** (required when `NODE_ENV=production`). |
| `JWT_REFRESH_SECRET` | Stored for local parity with requested template; **Nest auth does not consume this name** today (refresh tokens are opaque). |
| `JWT_EXPIRES_IN` | e.g. `15m` |
| `JWT_REFRESH_EXPIRES_IN` | Backend expects **seconds** (integer), e.g. **`2592000`** for ~30 days — **not** the string `30d`. |
| `PORT` | `3000` for local runs |
| `NODE_ENV` | `production` for this local test profile (stricter JWT + CORS behavior vs dev) |
| `MEDIA_UPLOAD_DIR` | `uploads` |
| `MEDIA_PUBLIC_BASE_URL` | `http://localhost:3000/uploads` (temporary local test) |
| `NIMON_PUBLIC_WEB_BASE_URL` | `http://localhost:3000` |
| `CORS_ORIGIN` | `*` (permitted for this smoke profile only) |

**How Step 3 was populated (automation-safe):**

- `DATABASE_URL` and `DIRECT_URL` were copied from the operator’s existing **`nimon-backend/.env`** (which must already contain the **rotated** encoded URLs).
- `JWT_SECRET`, `JWT_REFRESH_SECRET`, and the fixed test keys above were generated or set in **`.env.global-test.local` only**.

If `.env` still contained the old password, **update `.env` first**, then regenerate `.env.global-test.local`.

---

## 4. Loading env for Prisma (no secret output)

Prisma reads `DATABASE_URL` from the environment via `prisma.config.ts`. The repo already depends on **`dotenv`**; **`dotenv-cli` was not added** to avoid lockfile/package-manager drift in this environment.

**Approach used:** PowerShell parses `.env.global-test.local` and sets **process** environment variables before spawning `node`, so Prisma inherits them (and default `dotenv` loading will not override already-set variables).

**Optional (single file, no extra package):** from repo root, with path adjusted:

```powershell
$env:DOTENV_CONFIG_PATH = "C:\path\to\nimon-backend\.env.global-test.local"
cd nimon-backend
node -r dotenv/config .\node_modules\prisma\build\index.js generate
```

**If `dotenv-cli` is installed locally**, the requested style works:

```bash
npx dotenv -e .env.global-test.local -- npx prisma generate
npx dotenv -e .env.global-test.local -- npx prisma migrate deploy
```

**Migrate deploy note:** Prisma migrations were applied with **`DATABASE_URL` temporarily set to `DIRECT_URL`** (port **5432**) for the CLI process, because **`6543` + `pgbouncer=true`** is not appropriate for all migration workloads.

---

## 5. Commands run (Step 3)

From `nimon-backend` (env loaded as above; secrets not logged):

1. **`prisma generate`** — **succeeded** (Prisma Client generated).
2. **`prisma migrate deploy`** (using direct pooler URL for the CLI session) — **succeeded**; **13** migrations applied on a fresh database in this run.
3. **`node node_modules/@nestjs/cli/bin/nest.js build`** — **succeeded**.

---

## 6. Supabase tables verification (no seed)

After migrations, a **read-only** query against `information_schema.tables` was executed (no application seed):

- **`public_base_table_count=17`** base tables in schema `public`.

This confirms the migration chain created the expected relational footprint; it does **not** assert application seed data.

---

## 7. Blockers

- **None** for this workspace run: generate, migrate deploy, and Nest build completed successfully.
- **Environment note:** If `pnpm` / `npm` are not on `PATH`, use the same `node …\prisma\build\index.js` and `node …\@nestjs\cli\bin\nest.js` invocations as above.

---

## 8. Next step

**M20C — Render deploy:** configure Render service env vars (including **rotated** `DATABASE_URL` / pooler settings, `JWT_SECRET`, `CORS_ORIGIN`, `MEDIA_PUBLIC_BASE_URL`, etc.), build/start commands per `docs/M20A_GLOBAL_TEST_DEPLOYMENT_READINESS_REPORT.md`, and avoid ephemeral-disk surprises for uploads.

---

## 9. Checklist return (Step 3)

| Item | Result |
|------|--------|
| Password rotated? | **Operator responsibility** — assumed done in Supabase; local files must use **new** URL-encoded password only. |
| Env file protected? | **Yes** — patterns in `.gitignore`; `.env.global-test.local` gitignored. |
| `DATABASE_URL` encoded? | **Operator responsibility** — use URL encoding for special characters in the password segment. |
| `prisma generate` passed? | **Yes** |
| `prisma migrate deploy` passed? | **Yes** |
| Supabase tables verified? | **Yes** — **17** `public` base tables (no seed). |
| Backend build passed? | **Yes** |
| Docs updated? | **Yes** — this file. |
| Blockers? | **None** observed for generate / migrate / build in this run. |
