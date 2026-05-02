# Docker Postgres Setup Report

**Date:** 2026-05-02  
**Scope:** Local `nimon-postgres` + `nimon-backend` Prisma checks (no `migrate deploy` executed).

## Docker Status

- **`docker --version`:** Docker **available** (e.g. Docker Desktop 29.x reported in this run).
- **`docker ps -a`:** Listed containers; **`nimon-postgres`** was **already present** (not created in this pass) and **running**, with **`nimon-redis`** also running.

## Container Status

| Check | Result |
|--------|--------|
| Name | `nimon-postgres` |
| Image | `postgres:16` (PostgreSQL 16.x in logs) |
| State | **Running** (`Up`) |
| Create / start actions | **None required** — container already existed and was up. If it had been stopped, the next step would have been `docker start nimon-postgres`. |

Recent logs indicated **ready to accept connections** after the latest start.

## Port Mapping

- **Host → container:** `0.0.0.0:5432->5432/tcp` (and IPv6 equivalent).
- **`HOST_PORT=5432`** mapped to **`CONTAINER_PORT=5432`** as required.

## Env DATABASE_URL Status

- **`DATABASE_URL`** is present in `nimon-backend/.env`.
- **Before this task:** password in the URL did **not** match the requested container password (it was a different local value).
- **After this task:** `DATABASE_URL` was updated **only** on that line to:

  `postgresql://nimon:****@localhost:5432/nimon?schema=public`

  (password masked here; full value is only in your local `.env`.)

**Credential note (existing volume):** The container’s data directory was **already initialized** (`Skipping initialization` in logs). First-time `POSTGRES_PASSWORD` from `docker run` does **not** re-apply on restart. After updating `.env` to the requested password, Prisma initially returned **`P1000` authentication failed**. To align the **running** Postgres role with the requested password **without** resetting the database, a single non-destructive SQL statement was executed inside the container: **`ALTER USER nimon WITH PASSWORD …`** (password not repeated in this doc). If you prefer not to change the role password, revert `.env` to match whatever password the volume was created with.

## Prisma Validate Result

**Passed.**

```bash
cd nimon-backend
node ./node_modules/prisma/build/index.js validate
```

Schema reported **valid**.

## Prisma Migrate Status Result

**Connection succeeded.** Prisma reported **2** migrations on disk and **1** not yet applied (see below). The CLI may exit with a **non-zero code** when migrations are pending—that reflects drift, not necessarily a failed connection.

## Migrations Pending

**Yes — one pending migration:**

- `20260502120000_story_draft_dirty_flag`

(`20260421082646_init_add_flow_v1` is already applied.)

## Prisma Studio Command

After you are satisfied with DB connectivity and credentials:

```bash
cd nimon-backend
node ./node_modules/prisma/build/index.js studio
```

## Next Command To Run

**Only after you explicitly approve applying migrations:**

```bash
cd nimon-backend
node ./node_modules/prisma/build/index.js migrate deploy
```

Until then, you can keep using **`migrate status`** and **`validate`** as read-only / safe checks.

## Risk Notes

1. **Existing Docker volume:** User/password in Postgres come from **initial** container creation, not from editing `docker run` later. Mismatches between `.env` and the role password cause **`P1000`** until aligned (see credential note above).
2. **Port conflicts:** Another process binding **5432** would prevent this mapping; this run showed mapping in place for `nimon-postgres`.
3. **Pending migration:** App/schema may assume `hasUnpublishedCoreChanges` (and related behavior) until **`migrate deploy`** (or your approved migration path) is run.
