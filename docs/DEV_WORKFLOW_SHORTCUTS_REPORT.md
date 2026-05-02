# Dev workflow shortcuts report

**Date:** 2026-05-02  
**Scope:** Developer experience for Nimon **local-first**, **remote draft**, and **strict remote** flows. **No app runtime behavior** was changed.

## Inspection summary

| Location | Finding |
|----------|---------|
| **Repo root `package.json`** | **None** — Flutter project; scripts are not centralized in npm at root. |
| **`nimon-backend/package.json`** | Had `start:dev`, `build`, `test`, etc. **No** Prisma CLI aliases before this change. |
| **`README.md`** | Already documents `flutter run` + `dart-define` variants for draft modes. |
| **`docs/DEV_RUN_COMMANDS.md`** | Already had bash-style steps for Docker, backend, Flutter, Studio. |

## Scripts added

**Yes — in `nimon-backend/package.json` only** (Node/npm; cross-platform):

| Script | Command |
|--------|---------|
| `npm run prisma:generate` | `node ./node_modules/prisma/build/index.js generate` |
| `npm run prisma:studio` | `node ./node_modules/prisma/build/index.js studio` |
| `npm run prisma:validate` | `node ./node_modules/prisma/build/index.js validate` |
| `npm run prisma:migrate:status` | `node ./node_modules/prisma/build/index.js migrate status` |

**Not added:** Root-level npm scripts wrapping `flutter run` — avoids a second package manager surface and shell/path ambiguity (Flutter on PATH differs by install).

## Flutter shortcuts

**Docs-only:** Optional **shell aliases** for `flutter run` variants are documented in **`docs/DEV_RUN_COMMANDS.md` §6** (bash/zsh + PowerShell examples). Developers copy paths into their own profile.

## Files touched

- `nimon-backend/package.json` — Prisma npm scripts  
- `docs/DEV_RUN_COMMANDS.md` — npm shortcut line + Prisma Studio via `npm run` + optional shell aliases  
- `README.md` — one line pointing to backend `start:dev` / `prisma:studio`  
- `docs/DEV_WORKFLOW_SHORTCUTS_REPORT.md` — this file  

## Command reference (quick)

| Goal | Where | Command |
|------|--------|---------|
| Backend dev server | `nimon-backend/` | `npm install` then **`npm run start:dev`** |
| Flutter local-first | repo root | **`flutter run`** |
| Flutter remote drafts | repo root | **`flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true`** |
| Flutter strict remote | repo root | **`flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true`** |
| Prisma Studio | `nimon-backend/` | **`npm run prisma:studio`** |

## Rationale

- **Backend/Prisma** commands run inside **`nimon-backend`** where `node_modules/prisma` exists — npm scripts are **low risk** and work on Windows, macOS, and Linux shells invoked by npm.  
- **Flutter** remains **explicit `flutter run`** (and optional personal aliases) so CI and docs stay aligned with Flutter tooling, not a duplicate script layer.

## Follow-ups (optional)

- Team **Makefile** or **Task** runner could wrap both backend and Flutter; not introduced here to keep the repo minimal.  
- **pnpm** users can run the same script names with `pnpm run prisma:studio` from `nimon-backend/`.
