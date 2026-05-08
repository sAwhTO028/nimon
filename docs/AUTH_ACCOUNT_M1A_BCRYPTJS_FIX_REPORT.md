# Auth Account M1a BcryptJS Fix Report

**Date:** 2026-05-03  
**Goal:** Replace native **`bcrypt`** with pure-JS **`bcryptjs`** so M1a auth works on **Windows** without native `bcrypt_lib.node` bindings.  
**Scope:** `nimon-backend` only. **Not** M1b, **not** story-drafts / published-monos guards, **not** Flutter.

---

## Root Cause

The **`bcrypt`** package ships **native bindings** (C++). On some Windows setups, install or runtime fails with **missing `bcrypt_lib.node`**, so Jest and the app cannot load the module. **`bcryptjs`** implements the same **bcrypt** algorithm in JavaScript (no native addon), at the cost of **lower throughput** (acceptable for password hashing on auth endpoints).

---

## Files Changed

| File | Change |
|------|--------|
| `nimon-backend/package.json` | `bcrypt` / `@types/bcrypt` → **`bcryptjs`** + **`@types/bcryptjs`** |
| `nimon-backend/src/modules/auth/auth.service.ts` | Import `bcryptjs`; **`hashSync` / `compareSync`** (same cost factor and verification semantics as async `hash` / `compare`) |
| `nimon-backend/src/modules/auth/auth.service.spec.ts` | Import `bcryptjs`; tests use **`hashSync`** for fixture hashes |
| `nimon-backend/src/modules/auth/auth.module.ts` | Cast **`expiresIn`** to **`SignOptions['expiresIn']`** to satisfy `@nestjs/jwt` v11 typings (build fix; unrelated to bcrypt behavior) |

---

## Dependency Changes

| Removed | Added |
|---------|--------|
| `bcrypt` | `bcryptjs@^2.4.3` |
| `@types/bcrypt` (dev) | `@types/bcryptjs@^2.4.6` (dev) |

**API note:** `AuthService` now uses **`bcrypt.hashSync` / `bcrypt.compareSync`** with the same **`BCRYPT_COST` (12)** as before. Hashes remain **$2a$**-compatible; existing rows hashed with native `bcrypt` remain verifiable with `bcryptjs`.

---

## Import Changes

- **From:** `import * as bcrypt from 'bcrypt';`  
- **To:** `import * as bcrypt from 'bcryptjs';`

No public HTTP or token contract changes.

---

## Auth Test Result

**Command:** `node ./node_modules/jest/bin/jest.js src/modules/auth/auth.service.spec.ts`

**In this agent environment:** **Not verifiable to green** until **`pnpm install` / `npm install`** is run (no `pnpm`/`npm` on `PATH` here). After install, `bcryptjs` resolves and the suite should run.

**Expected after install:** All `AuthService` unit tests should pass; assertions still expect **`$2a$` / `$2b$` / `$2y$`**-style hashes.

---

## Backend Build Result

**Command:** `node ./node_modules/@nestjs/cli/bin/nest.js build`

**In this agent environment:** Fails without **`node_modules/bcryptjs`** (install not run). A **typing** issue on `JwtModule.registerAsync` **`expiresIn`** was also fixed via **`jsonwebtoken`’s `SignOptions['expiresIn']`** so **`nest build`** can succeed once dependencies are installed.

**After `pnpm install`:** Re-run **`nest build`** locally.

---

## Risks

1. **CPU:** `bcryptjs` is slower than native `bcrypt` for the same cost factor; mitigated by low QPS on register/login.  
2. **Sync calls:** `hashSync` / `compareSync` block the event loop briefly; acceptable for single password ops per request. If load grows, move to **async** `bcryptjs` APIs with `util.promisify` or a worker pool.  
3. **Install not run in agent:** You must run **`pnpm install`** (or **`npm install`**) to refresh the lockfile and `node_modules`.

---

## Recommended Next Step

1. In **`nimon-backend/`:** **`pnpm install`** (preferred) or **`npm install`**.  
2. Run:  
   `node ./node_modules/prisma/build/index.js generate`  
   `node ./node_modules/jest/bin/jest.js src/modules/auth/auth.service.spec.ts`  
   `node ./node_modules/@nestjs/cli/bin/nest.js build`  
3. If all green, M1a auth is verified on your machine; then proceed to **M1b** when ready (guards + owner scoping — separate task).

---

### Output summary

| Question | Answer |
|----------|--------|
| **bcrypt removed?** | **Yes** (from `package.json`) |
| **bcryptjs added?** | **Yes** + **`@types/bcryptjs`** (dev) |
| **Auth tests passed?** | **Run locally after install** — not confirmed in the agent shell (no package manager) |
| **Backend build passed?** | **Run locally after install** — `auth.module` typing fix included for post-install build |
| **Ready for M1b?** | **After** you confirm **Jest + `nest build`** pass on your system with the new lockfile; not blocked by bcrypt native binding anymore |
