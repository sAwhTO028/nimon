# Dev shortcut scripts (Windows)

**Date:** 2026-05-02  
**Location:** `scripts/*.bat` at the repo root (`C:\Users\owner\Desktop\SAW_PROJ\nimon`).

These batch files **`cd /d`** to fixed paths, **`echo`** what they do, run one command, then **`pause`** so the window stays open after the process exits (success or failure).

## Prerequisites

- **Node / npm** on `PATH` (for backend and Prisma scripts).
- **Flutter** on `PATH` (for `flutter_*.bat`).
- **PostgreSQL** reachable when using Prisma Studio or remote Flutter mode with a local API (see [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md)).

## Scripts

| File | Purpose |
|------|---------|
| `scripts/start_backend.bat` | **`npm run start:dev`** in `nimon-backend` (Nest watch). |
| `scripts/prisma_studio.bat` | **`npm run prisma:studio`** in `nimon-backend`. |
| `scripts/flutter_local.bat` | **`flutter run`** at repo root (local-first drafts). |
| `scripts/flutter_remote.bat` | **`flutter run`** with **`NIMON_USE_REMOTE_DRAFTS=true`**. |
| `scripts/flutter_remote_strict.bat` | Remote drafts + **`NIMON_STRICT_REMOTE_DRAFTS=true`**. |

## How to use

1. Double-click a `.bat` in Explorer, **or**
2. From **cmd.exe**:  
   `C:\Users\owner\Desktop\SAW_PROJ\nimon\scripts\start_backend.bat`

If your clone lives somewhere else, **edit the `cd /d` path** inside each script or duplicate the folder with updated paths.

## Typical flow

1. Start Docker Postgres (if used): see [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md).
2. **`start_backend.bat`** in one window.
3. **`flutter_remote.bat`** or **`flutter_remote_strict.bat`** in another (or **`flutter_local.bat`** for offline drafts).
4. **`prisma_studio.bat`** when you need to inspect the database (requires **`DATABASE_URL`** in `nimon-backend/.env`).

## Related docs

- [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md) — manual commands and owner-id notes.
- [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md) — local vs remote draft behavior.
