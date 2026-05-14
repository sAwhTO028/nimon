# NestJS `nest start --watch` on Windows — `taskkill` race

## Root cause

`npm run start:dev` runs `nest start --watch`. On each file change the Nest CLI rebuilds and tries to **terminate the previous Node child** before starting a new one. On Windows it uses **`taskkill /pid <pid> /T /F`**.

If that child process **has already exited** (crash, slow shutdown, race with the compiler, or PID reuse edge cases), `taskkill` fails with:

```text
Reason: There is no running instance of the task.
```

The Nest CLI treats a failed `taskkill` as a fatal error, so the watch loop exits with **exit code 1** even when TypeScript compilation succeeded. This is a **known class of issues** on Windows with the Nest watch runner, not an application or Prisma error.

Using **very new Node versions** (for example **Node 24.x**) can increase odd timing behavior with child processes; prefer an **LTS** release for day-to-day backend work (see below).

## Quick recovery after a stuck or half-dead watch

If the watch process dies and leaves stray `node.exe` processes:

```bat
taskkill /F /IM node.exe
```

**Warning:** This kills **all** Node processes on the machine (including other dev servers). Use Task Manager to end only the Nest process if you need a narrower kill.

Then start again with one of the workflows below.

## Recommended Node version

For NestJS and long-running CLI tooling, use a current **LTS** line:

| Recommendation | Notes |
|----------------|--------|
| **Node 22.x LTS** or **Node 20.x LTS** | Stable defaults for Nest 11 + ecosystem. |
| **Avoid Node 24.x** for primary backend dev until you explicitly need it | Newer majors can surface timing/child-process quirks before the ecosystem fully catches up. |

Pin versions with **nvm-windows**, **fnm**, or **Volta** so the repo matches CI and production.

## Safe non-watch run (no `taskkill` loop)

One compile, one process:

```bash
cd nimon-backend
npm run build
node dist/src/main.js
```

Or use the npm alias:

```bash
npm run start:once
```

**Note:** This project emits the bootstrap file at **`dist/src/main.js`** (Nest preserves `src/` under `dist/`). If `start` fails with “Cannot find module”, confirm that path exists after `npm run build`.

Use this when you only need to verify the server boots or to avoid watch entirely on Windows.

## Recommended alternative: two-terminal workflow (avoids `nest start --watch`)

This separates **TypeScript compile watch** from **running the server**, so the Nest CLI never runs its Windows `taskkill` restart path.

**Terminal 1 — incremental compile only:**

```bash
cd nimon-backend
npm run build:watch
```

**Terminal 2 — run the compiled app** (after the first successful build):

```bash
cd nimon-backend
npm run start:local
```

(`start:local` runs `node dist/src/main.js`.)

When `build:watch` emits new `dist/` output, **stop** the server in Terminal 2 (**Ctrl+C**) and run `npm run start:local` again, or use a file watcher (e.g. `nodemon` watching `dist`) if you want automatic restarts without `nest start --watch`.

First-time users should run **`npm run build`** once before **`start:local`** so `dist/` exists.

## Scripts reference (`nimon-backend/package.json`)

| Script | Purpose |
|--------|--------|
| `start:dev` | Unchanged — `nest start --watch` (may hit `taskkill` race on Windows). |
| `build:watch` | `nest build --watch` — compile only; use with two-terminal workflow. |
| `start:local` | `node dist/src/main.js` — run last build. |
| `start:once` | `npm run build && node dist/src/main.js` — build then run, no watch. |

## If problems persist

- Confirm you are in `nimon-backend` and `.env` / DB / ports are valid (`start:once` helps isolate watch vs config).
- Try Node **22** or **20** LTS.
- Report upstream to **nestjs/nest** / **@nestjs/cli** if a minimal reproduction on latest LTS still triggers `taskkill` failures after restarts.
