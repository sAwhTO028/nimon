# Auth Account M1a jsonwebtoken Type Fix Report

**Date:** 2026-05-03  
**Problem:** `nest build` failed with **Cannot find module 'jsonwebtoken'** after `auth.module.ts` used `import type { SignOptions } from 'jsonwebtoken'` for `expiresIn` typing only. The project does **not** list `jsonwebtoken` as a direct dependency, so the compiler could not resolve that import.  
**Constraint:** Do **not** add `jsonwebtoken` as a direct dependency; keep `AuthModule` runtime behavior the same (same `secret` and `signOptions.expiresIn` from env).

---

## Change Summary

- **Removed** the `jsonwebtoken` type-only import.
- **Used** `JwtModuleOptions` from **`@nestjs/jwt`** (already a dependency) as the `useFactory` return type.
- **Set** `signOptions.expiresIn` to `resolveAccessExpiresIn(config) as never` so the object literal is assignable to `JwtModuleOptions['signOptions']` without pulling in `jsonwebtoken` in app source. **Runtime value is unchanged** (still the string from `JWT_EXPIRES_IN` / default `15m` in `auth.config.ts`).

---

## File Changed

| File | Change |
|------|--------|
| `nimon-backend/src/modules/auth/auth.module.ts` | Drop `jsonwebtoken` import; use `JwtModuleOptions` + `as never` on `expiresIn`; import `type JwtModuleOptions` from `@nestjs/jwt` |

---

## Commands Run (verification)

```text
node ./node_modules/@nestjs/cli/bin/nest.js build
node ./node_modules/jest/bin/jest.js src/modules/auth/auth.service.spec.ts
```

| Command | Result |
|---------|--------|
| **nest build** | **Passed** (exit 0) |
| **jest** `auth.service.spec.ts` | **Passed** — 7 tests |

---

## Risks

- **`as never` on `expiresIn`:** Disables excess compile-time checking on that one property. Runtime still comes from **`resolveAccessExpiresIn`**; invalid env values remain a **runtime** concern (same as before). If stricter typing is needed later, add a small parser that returns a value already typed as `jwt.SignOptions['expiresIn']` **without** adding `jsonwebtoken` to `package.json` (e.g. re-exported type-only path from a dev-only types stub — only if the team wants to avoid `never`).

---

## Recommended Next Step

- **M1b** (JWT guards + `ownerId` from `sub` on story-drafts / published-monos) when you are ready — not part of this fix.

---

### Output summary

| Question | Answer |
|----------|--------|
| **File changed** | **`nimon-backend/src/modules/auth/auth.module.ts`** |
| **jsonwebtoken import removed?** | **Yes** |
| **Backend build passed?** | **Yes** |
| **Auth tests passed?** | **Yes** (7/7) |
| **Ready for M1b?** | **Yes** from a **build + M1a auth test** perspective; M1b remains a **separate** implement-on-purpose step |
