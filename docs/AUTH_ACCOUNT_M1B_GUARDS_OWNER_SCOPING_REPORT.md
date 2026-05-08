# Auth Account M1b Guards Owner Scoping Report

Milestone **M1b** secures `v1/story-drafts` and `v1/published-monos` with JWT-backed identity. **Owner id** for all database operations is taken from the verified access token’s **`sub`** (loaded as `JwtValidatedUser.userId` on the request), **not** from the client body or query.

---

## Files Changed

| Area | Path | Notes |
|------|------|--------|
| Auth | `nimon-backend/src/modules/auth/jwt-or-dev-owner-fallback.guard.ts` | Verifies Bearer JWT; optional non-prod dev fallback. |
| Auth | `nimon-backend/src/modules/auth/current-user.decorator.ts` | `@CurrentUser()` → `JwtValidatedUser`. |
| Auth | `nimon-backend/src/modules/auth/dev-owner.constants.ts` | `DEFAULT_DEV_OWNER_ID` for fallback only. |
| Auth | `nimon-backend/src/modules/auth/authenticated-request.ts` | `AuthenticatedRequest` typing helper. |
| Auth | `nimon-backend/src/modules/auth/auth.module.ts` | Registers/exports `JwtOrDevOwnerFallbackGuard`. |
| Story drafts | `nimon-backend/src/modules/story-drafts/story-drafts.controller.ts` | `@UseGuards(JwtOrDevOwnerFallbackGuard)`, passes `user.userId`; **list** param order fixed for TypeScript. |
| Story drafts | `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` | All methods take explicit `ownerId: string` (from controller). `updateDraft` overwrites `basics.ownerId` from JWT path. |
| Story drafts | `nimon-backend/src/modules/story-drafts/story-drafts.module.ts` | `imports: [AuthModule]`. |
| Story drafts | `nimon-backend/src/modules/story-drafts/story-drafts.service.spec.ts` | Passes owner id into `listDrafts` / other calls. |
| Story drafts | `nimon-backend/src/modules/story-drafts/story-drafts.service.owner-scope.spec.ts` | **New** — list/get/delete scoping. |
| Published | `nimon-backend/src/modules/published-monos/published-monos.controller.ts` | Same guard + `user.userId`. |
| Published | `nimon-backend/src/modules/published-monos/published-monos.service.ts` | `listPublishedMonos(ownerId, …)`, `getPublishedMonoById(ownerId, id)`. |
| Published | `nimon-backend/src/modules/published-monos/published-monos.module.ts` | `imports: [AuthModule]`. |
| Published | `nimon-backend/src/modules/published-monos/published-monos.service.spec.ts` | **New** — list/detail scoping. |
| Env | `nimon-backend/.env.example` | `ALLOW_DEV_OWNER_FALLBACK`, `DEV_OWNER_ID` comments. |

**Not modified:** Flutter, register/login DTOs and auth controller behavior (except shared `AuthModule` exports), Prisma schema for M1b.

---

## Guard Strategy

- **`JwtOrDevOwnerFallbackGuard`** (controller-level on story-drafts and published-monos):
  - **Bearer token present:** Verify JWT with same secret as login (`resolveJwtSecret`), read **`sub`**, load `User` from Prisma, set `req.user = { userId, email }`.
  - **No token:** Only if **`NODE_ENV !== 'production'`** and **`ALLOW_DEV_OWNER_FALLBACK === 'true'`** — set `req.user` to the dev owner id (`DEV_OWNER_ID` or `DEFAULT_DEV_OWNER_ID`). Otherwise **`401 Unauthorized`**.
- **`@CurrentUser()`** returns **`JwtValidatedUser`** (`userId` comes from JWT **`sub`** after DB lookup).
- **`JwtStrategy`** (existing passport JWT path for `@UseGuards(JwtAuthGuard)`) still exposes **`userId`** — same semantic as **`sub`**.

---

## Story Draft Ownership Changes

| Route | Behavior |
|-------|----------|
| `POST /v1/story-drafts` | `createDraft(user.userId, body)` — **`basics.ownerId` from client is not trusted**; persisted owner is `user.userId`. |
| `GET /v1/story-drafts` | `listDrafts(user.userId, query)` — only that owner’s drafts. |
| `GET /v1/story-drafts/:draftId` | `where: { id, ownerId: user.userId }` — **404** if not owned. |
| `PUT /v1/story-drafts/:draftId` | Merged `basics` includes **`ownerId: user.userId`**, **`storyId: draftId`**; If-Match / version behavior preserved. |
| `DELETE /v1/story-drafts/:draftId` | `deleteMany` with `{ id, ownerId }` — **404** if no row. |
| `POST .../publish/read-only`, `.../full-learn` | Same `ownerId` scoping as other draft operations; If-Match preserved. |

---

## Published Mono Ownership Changes

- **`GET /v1/published-monos`:** `listPublishedMonos(user.userId, limit)` — “my published” for the authenticated user.
- **`GET /v1/published-monos/:id`:** `getPublishedMonoById(user.userId, id)` — **404** if the mono is not owned by the caller.

These routes are **owner/profile** APIs, not a public catalog. A future **public** reader or catalog can be a **separate** path (out of M1b).

---

## DEV_OWNER_ID / Fallback Policy

| Environment | Unauthenticated request |
|-------------|-------------------------|
| **`NODE_ENV === 'production'`** | **401** always (no dev fallback). |
| **Non-production** + **`ALLOW_DEV_OWNER_FALLBACK !== 'true'`** | **401**. |
| **Non-production** + **`ALLOW_DEV_OWNER_FALLBACK=true`** | Treated as **`DEV_OWNER_ID`** or code default `DEFAULT_DEV_OWNER_ID`. |

**Production never** uses unauthenticated `DEV_OWNER_ID` as the effective user. **Do not** set `ALLOW_DEV_OWNER_FALLBACK` in production.

---

## Public vs Owner Published Endpoint Notes

- Current **`/v1/published-monos`** and **`/v1/published-monos/:id`** are **authenticated** and **owner-scoped** (match Profile “my published”).
- If a **public** read-only catalog or share link is required, add **dedicated** routes (e.g. no owner in path, or optional auth) in a later milestone to avoid conflating “any user’s public content” with “my library.”

---

## Tests Added Or Updated

| Test file | Coverage |
|-----------|----------|
| `story-drafts.service.spec.ts` | Updated for explicit `ownerId` argument to service methods. |
| `story-drafts.service.owner-scope.spec.ts` | `listDrafts` `where.ownerId`, `getDraftById` / `deleteDraft` not found for wrong owner. |
| `published-monos.service.spec.ts` | `findMany` / `findFirst` scoped by `ownerId`; not found for missing row. |
| `auth.service.spec.ts` | Unchanged contract; re-run to ensure M1a auth still green. |

**Deferred:** HTTP e2e asserting **401** without `Authorization` (guard behavior is standard Nest + unit tests cover service scoping). Add `*.e2e-spec.ts` when the project adds a stable e2e harness for protected routes.

---

## Prisma Generate Result

```
✔ Generated Prisma Client (v7.7.0) …
```

Command: `node ./node_modules/prisma/build/index.js generate` (from `nimon-backend`).

---

## Auth Test Result

```
Test Suites: 1 passed, 1 total
Tests:       7 passed, 7 total
```

Command: `node ./node_modules/jest/bin/jest.js src/modules/auth/auth.service.spec.ts`

---

## Story Draft Test Result

```
Test Suites: 1 passed, 1 total
Tests:       10 passed, 10 total
```

Command: `node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts`

**Owner-scope suite:**

```
Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
```

Command: `node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.owner-scope.spec.ts`

**Published monos service:**

```
Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
```

Command: `node ./node_modules/jest/bin/jest.js src/modules/published-monos/published-monos.service.spec.ts`

---

## Backend Build Result

```
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Exit code: 0** (after fixing `listDrafts` parameter order: required `@CurrentUser()` before optional `@Query` parameters for TypeScript).

---

## Risks

- **Local clients without JWT** (e.g. raw `curl` or pre-M1c Flutter) receive **401** unless **`ALLOW_DEV_OWNER_FALLBACK=true`** in non-production.
- **Published list/detail** are no longer anonymous; any integration that assumed open access must send **Bearer** token or use the dev fallback in local only.

---

## Recommended Next Step

- **M1c (per M1 plan):** Flutter (or other clients) — store access token, send **`Authorization: Bearer`**, align **`NIMON_DEV_OWNER_ID`** / backend **`DEV_OWNER_ID`** only for explicit dev fallback — or proceed with profile/account UI as prioritized in `AUTH_ACCOUNT_IDENTITY_M1_PLAN.md`.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **story-drafts guarded?** | **Yes** — `JwtOrDevOwnerFallbackGuard` on controller. |
| **published-monos guarded?** | **Yes** — same. |
| **ownerId from JWT sub?** | **Yes** — verified **`sub`** → Prisma `User` → **`user.userId`** passed to services. |
| **DEV_OWNER_ID production fallback removed/disabled?** | **Yes** — production requires Bearer JWT; dev owner only when non-production **and** `ALLOW_DEV_OWNER_FALLBACK=true`. |
| **tests passed?** | **Yes** — auth, story-drafts, owner-scope, published-monos specs as listed above. |
| **backend build passed?** | **Yes**. |
| **next step M1c or fixes?** | **M1c** — wire clients to JWT; optional follow-up: e2e tests for 401 without auth. |
