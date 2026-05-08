# M2 Remote Authoring Smoke Report

**Report date:** 2026-05-03  
**Type:** Release QA verification (per [M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md](M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md)).  
**Scope:** Follow [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md) — Postgres → Nest → Flutter (remote + strict) → auth → draft → publish → Studio → Profile → logout/restart.

**Manual smoke confirmation:** Manual smoke was confirmed by developer after running Postgres + Nest backend + Flutter remote strict mode.

---

## Environment

| Item | Value / notes |
|------|------------------|
| Repo / workspace | `nimon` (clone path as used locally) |
| OS | Windows (per dev machine) |
| Postgres | **Verified** — running for manual smoke per [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md). |
| Backend | **Verified** — Nest dev server used for smoke (see Commands Used). |
| Flutter target | Remote draft + strict mode; `NIMON_API_BASE_URL` set appropriately for device/emulator. |
| Prisma / DB | **Verified** — Prisma Studio used to confirm **`story_drafts`** and **`published_monos`** rows after draft save and publish. |
| Auth baseline | M1 auth complete per plan; M1d identity surfaces documented in [AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md](AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md). |

---

## Commands Used

**Postgres (from `nimon-backend/`):**

```bash
docker compose up -d postgres
# or: docker start nimon-postgres
```

**Backend:**

```bash
cd nimon-backend
npm install
npm run start:dev
```

**Optional — migration status only (no apply):**

```bash
cd nimon-backend
npm run prisma:migrate:status
```

**Flutter — remote drafts + strict + API URL (adjust URL for target):**

```bash
cd ..   # repo root
flutter pub get
flutter run \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true \
  --dart-define=NIMON_API_BASE_URL=http://localhost:3000
```

For **Android emulator** talking to host Nest:

```bash
flutter run \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true \
  --dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000
```

**Prisma Studio (verify DB rows):**

```bash
cd nimon-backend
npm run prisma:studio
```

**Owner alignment:** If Published tab appears empty after publish, confirm Flutter `NIMON_DEV_OWNER_ID` matches backend `DEV_OWNER_ID` when using dev owner overrides ([DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md)).

---

## Register / Login Result

| Step | Expected | Result (manual) |
|------|----------|-------------------|
| Register new account | Success, navigates or allows login | **Pass** |
| Land on `/mono` after login | Route as designed | **Pass** |

---

## Account Identity Result

| Step | Expected | Result (manual) |
|------|----------|-------------------|
| Profile drawer or Settings shows signed-in identity | Email / handle / id per M1d | **Pass** |
| Matches registered user | Consistent with JWT user | **Pass** |

---

## Draft Save Result

| Step | Expected | Result (manual) |
|------|----------|-------------------|
| Create story basics | UI completes | **Pass** |
| Add story sentences | UI completes | **Pass** |
| Save remote draft | Success; strict mode surfaces errors if API fails | **Pass** |

---

## Publish Result

| Step | Expected | Result (manual) |
|------|----------|-------------------|
| Publish read-only | Completes without error | **Pass** |

---

## Prisma Studio Observations

| Check | Expected | Result (manual) |
|-------|----------|-------------------|
| After draft save | Row(s) in **`story_drafts`** (and related **`draft_sentences`** if applicable) | **Pass** |
| After publish | Row(s) in **`published_monos`** | **Pass** |

*Optional:* Record example row id / `updatedAt` timestamps after QA run (no secrets).

---

## Profile Published Result

| Step | Expected | Result (manual) |
|------|----------|-------------------|
| Profile → **Published** tab | Lists published content for authenticated user | **Pass** |

---

## Logout / Restart Result

| Step | Expected | Result (manual) |
|------|----------|-------------------|
| Logout | Session cleared; login required | **Pass** |
| Restart app | Cold start | **Pass** |
| Login again | Same account | **Pass** |
| Data continuity | Same user’s drafts/published state as before restart | **Pass** |

---

## Issues Found

| ID | Severity | Description |
|----|----------|-------------|
| — | — | **None** — manual smoke completed with no blocking defects recorded. |

---

## Final Verdict

**Verdict:** **Pass** — M2 remote authoring smoke passed on local developer stack.

---

## Recommended Next Step

1. Proceed with remaining **M2 remote authoring release-mode** items in [M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md](M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md) (shipping configuration, guards, and any documented gaps).  
2. Run the same smoke on a **staging** or **release-shaped** environment (TLS, real API URL, production env flags) before external beta or store submission.  
3. Track defects from broader QA and re-smoke after fixes.

---

## Output summary

| Question | Answer |
|----------|--------|
| Smoke passed? | **Yes** |
| Register/login passed? | **Yes** |
| Remote draft save passed? | **Yes** |
| Publish passed? | **Yes** |
| Profile Published passed? | **Yes** |
| Logout/restart passed? | **Yes** |
| Issues found? | **None** |
| Next milestone recommendation | Close remaining M2 plan items; repeat smoke on staging/release-shaped stack before wider rollout |
