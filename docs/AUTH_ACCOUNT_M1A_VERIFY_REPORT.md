# Auth Account M1a Verify Report

**Date:** 2026-05-03  
**Scope:** Verify M1a backend auth after dependency install + generate + auth tests + Nest build (`docs/AUTH_ACCOUNT_M1A_BACKEND_REPORT.md`).  
**Constraints honored:** No M1b / no guards on story-drafts or published-monos / no Flutter changes / source edits only for install/build/test fixes (none required).

---

## Install Result

| Attempt | Result |
|---------|--------|
| **`pnpm install`** | **Not executed** — `pnpm` not found on `PATH` in the verification shell |
| **`npm install`** | **Not executed** — `npm` not found on `PATH` in the verification shell |

**Effect:** New dependencies declared in `nimon-backend/package.json` (`@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt`, type packages) are **not** present in `node_modules` in a way the compiler and Jest can resolve, so **Jest** and **`nest build`** fail until a successful install runs on a machine where **Node.js** (and `npm` or `pnpm`) is available.

**What you should run locally (in `nimon-backend/`):**

```bash
pnpm install
# or, if pnpm is not installed:
npm install
```

---

## Prisma Generate Result

**Command:** `node ./node_modules/prisma/build/index.js generate`  
**Exit code:** **0**  
**Result:** **Success** — Prisma Client v7.7.0 generated (schema includes `User.passwordHash`, `UserProfile`, `RefreshToken`).

---

## Auth Test Result

**Command:** `node ./node_modules/jest/bin/jest.js src/modules/auth/auth.service.spec.ts`  
**Exit code:** **1**  
**Result:** **Failed to run test suite** — `Cannot find module 'bcrypt'` (imported from `auth.service.spec.ts` for real bcrypt hash checks). This is **consistent with missing / incomplete post–`package.json` install** for the new auth stack.

**After a successful `pnpm install` / `npm install`, re-run the same Jest command** — the auth unit tests are expected to pass.

---

## Backend Build Result

**Command:** `node ./node_modules/@nestjs/cli/bin/nest.js build`  
**Exit code:** **1**  
**Result:** **TypeScript resolution errors (7):** cannot find modules `@nestjs/jwt`, `@nestjs/passport`, `bcrypt`, `passport-jwt` — same root cause as above (dependencies not installed in this environment).

**After install:** **`nest build`** should succeed if versions resolve cleanly.

---

## Fixes Applied

**None** to application source. Failures are **environment / dependency installation**, not logic bugs in `src/modules/auth/**`.

---

## Remaining Risks

1. **Local PATH:** Verification must be repeated on a developer machine or CI image with **Node + npm/pnpm** so `package.json` dependencies are actually installed.
2. **native `bcrypt`:** On Windows, `bcrypt` sometimes needs build tools; if install fails, document/use `windows-build-tools` or prebuilt binaries — outside this report until it occurs.
3. **pnpm layout:** This repo uses a **pnpm** store under `node_modules/.pnpm`; ensure installs use **pnpm** consistently if that is team policy (`pnpm-lock.yaml` present).

---

## Recommended Next Step

1. From **`nimon-backend/`**, run **`pnpm install`** (preferred) or **`npm install`**.  
2. Re-run (in order): **`prisma generate`** → **`jest src/modules/auth/auth.service.spec.ts`** → **`nest build`**.  
3. If all green, proceed to **M1b** (JWT guards + owner scoping on drafts/published routes per plan).  
4. If install fails, fix the **toolchain / registry / network** issue first — **no M1b** until M1a verifies.

---

### Output summary

| Question | Answer |
|----------|--------|
| **Install passed?** | **No** — neither `pnpm` nor `npm` was available on `PATH`; install was **not** run |
| **Package manager used?** | **None** (blocked) — prefer **`pnpm install`** when `pnpm` is installed |
| **Prisma generate passed?** | **Yes** (exit **0**) |
| **Auth tests passed?** | **No** — Jest exit **1** (`bcrypt` module not found) |
| **Backend build passed?** | **No** — Nest build exit **1** (missing JWT/passport/bcrypt packages) |
| **Any fixes applied?** | **No source fixes** — blocked on installing dependencies |
| **Ready for M1b?** | **Not yet** — run a successful package install and confirm **Jest + `nest build`** pass locally or in CI first |
