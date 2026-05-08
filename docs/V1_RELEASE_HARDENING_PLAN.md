# V1 Release Hardening Plan

## 1. Executive Summary

This plan defines the **release hardening** workstream immediately following the close of **M1–M8** (see `docs/M8_DISCOVERY_AND_POLISH_CLOSEOUT_REPORT.md`). It is an **operator + QA checklist** and a **repeatable smoke protocol** for producing a V1 release candidate (RC) that is consistent across environments.

Guiding principles:

- **No new features**: hardening is about **verification**, **environment correctness**, and **regression prevention**.
- **No migrations are authored in this plan**; the checklist validates that existing migrations are **applied** and that environments are **in sync**.
- **Production readiness is storage-driven**: disk-only uploads are acceptable for **dev/internal**, but **object storage** is required for **real public production** (see `docs/M6E_RELEASE_CHECKLIST.md` §5–7 and `docs/M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md`).

## 2. Release Scope

### In scope (V1 ship)

Based on the M7/M8 closeouts and M5/M6 readiness docs:

- **Core create → media upload → publish → read/learn** lifecycle (M5 closeout + M6d smoke)
- **Published edit visibility** (M5) and **delete lifecycle** including **permanent delete** UX (P3)
- **Social + profile**: bookmark/react, saved list, follow/following, public creator profile, routing hygiene, followers list (M7 + M8)
- **Saved-only** decision applied (M8c + M8c1)
- **Social counts** formatting/polish (M8d)
- **Share + copy centralization** (clipboard share, `NimonAppStrings`) (M8e)

### Out of scope (explicitly deferred)

- System share sheet dependency (`share_plus`) (M8e)
- ARB / `gen-l10n` localization (M8e)
- Collections/folders implementation beyond flat Saved (M8c)
- Full legacy route removal (`?creator=`) (M8a / M8 closeout)
- Further social count placement polish on additional surfaces (M8d / M8 closeout)
- Infrastructure beyond what’s required to run production safely (rate limits, monitoring, backups) unless your org treats them as release blockers (see §11).

## 3. Environment Checklist

Complete this section **per target environment** (local dev, staging, production).

### Required environment variables (backend)

- **Database**
  - `DATABASE_URL` is correct for the environment
  - Postgres is reachable
- **Auth**
  - `JWT_SECRET` set (no dev fallback in production)
- **Media / storage**
  - `MEDIA_STORAGE_DRIVER` (`disk` for dev/internal only; `s3`/`r2` for public prod)
  - `MEDIA_PUBLIC_BASE_URL` matches the host that serves assets (no mixed-content on HTTPS web)
  - `MEDIA_UPLOAD_DIR` (disk only) or bucket credentials (S3/R2)
- **CORS**
  - `CORS_ORIGIN` matches app origin(s)
  - Static `/uploads` CORS behavior verified (see M5/M6 docs)

### Required compile-time flags (Flutter)

Use `docs/DEV_RUN_COMMANDS.md` and `README.md` as the source of truth.

- `NIMON_USE_REMOTE_DRAFTS=true` for staging/prod validation
- `NIMON_STRICT_REMOTE_DRAFTS=true` recommended for QA (surface backend failures)
- `NIMON_API_BASE_URL=...` set for non-localhost environments
- If applicable: `NIMON_DEV_OWNER_ID` matches backend `DEV_OWNER_ID` to avoid “Published looks empty” confusion (local/dev primarily)

## 4. Backend Checklist

Run from `nimon-backend/` unless noted. Record the exact outputs in the RC run notes.

### Commands

- **Install**: `npm install`
- **Prisma sanity**
  - `npm run prisma:validate`
  - `npm run prisma:generate`
  - `npm run prisma:migrate:status`
- **Tests** (targeted then full as time permits)
  - `node ./node_modules/jest/bin/jest.js src/modules/media` (see M6d recorded snapshot)
  - `npm test` (or your CI suite)
- **Build**
  - `npm run build` (or `nest build`)

### Backend acceptance checks

- **Auth required routes** reject missing/invalid JWTs appropriately
- **Catalog-visible rules** for published content behave as documented (M5/M7)
- **Followers endpoint** behavior matches M8b contract (`GET /v1/users/:id/followers`)
- **Delete lifecycle** endpoints match P1–P3 reports (trash/restore/permanent delete)

## 5. Flutter Checklist

Run from repo root.

### Automation

- `flutter pub get`
- `flutter test`
- `flutter analyze`
  - Expect non-zero exit if repo has info/warning baseline; the hardening rule is **no new error-severity issues** on the release branch.

### Build & runtime checks (per platform)

At minimum validate:

- **Flutter Web** (because CORS/mixed-content are most likely to break here)
- **One mobile target** (Android emulator/device or iOS simulator/device)

## 6. Database / Migration Checklist

This plan does **not** introduce migrations. It verifies that the target environment is consistent.

- Confirm DB connectivity with `DATABASE_URL`
- Confirm Prisma schema matches generated client (`prisma generate`)
- Confirm deployed migration state is clean (`prisma migrate status`)
- For staging/prod deployments, ensure your deploy pipeline runs `prisma migrate deploy` (or the project’s equivalent)

## 7. Media / Storage Checklist

This is the primary release gate per `docs/M6E_RELEASE_CHECKLIST.md` §5–7 and `docs/M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md`.

### Disk (dev/internal only)

- `/uploads` serves bytes
- returned URLs are rooted at `MEDIA_PUBLIC_BASE_URL`
- cover and audio upload flows work end-to-end

### Object storage (required before public production)

If V1 is public-facing:

- `MEDIA_STORAGE_DRIVER=s3|r2` configured
- upload returns `url` under the public base
- `curl -I <asset-url>` returns `200` with correct `content-type`
- bucket/CDN CORS allows Flutter Web origin for GET
- HTTPS/TLS valid; no mixed content

## 8. Manual Smoke Checklist

This is a consolidated smoke list derived from:

- `docs/M6E_RELEASE_CHECKLIST.md` §4
- `docs/M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md`
- `docs/M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md`
- `docs/P3_FLUTTER_PERMANENT_DELETE_UI_REPORT.md`
- `docs/M7_SOCIAL_PROFILE_POLISH_CLOSEOUT_REPORT.md`
- `docs/M8_DISCOVERY_AND_POLISH_CLOSEOUT_REPORT.md`

Run the smoke in **remote drafts + strict mode** on staging (and again on prod after deploy, if your process requires).

### Account & session

- [ ] Login / session restore works
- [ ] Guest gating copy is correct on social actions (save/react/follow)

### Create & media

- [ ] Create a story (basics + at least one sentence)
- [ ] Upload **cover** (JPG) and verify it displays on Web
- [ ] Upload **audio** and attach via “Add audio to story”

### Publish & read

- [ ] Publish read-only and/or full-learn as required for V1
- [ ] Story appears in Mono feed (cover visible)
- [ ] Story appears in Profile → Published
- [ ] Learn surfaces load (including Listening playback from HTTP(S) URL)

### Published edit visibility (M5)

- [ ] Edit a published item and save changes
- [ ] Verify it is hidden from Mono feed + Profile Published while editing
- [ ] Verify it appears in Workspace
- [ ] Republish restores visibility

### Social (M7/M8)

- [ ] Bookmark toggle works; Profile → Saved list updates
- [ ] React toggle works; likes count presentation remains stable (M8d)
- [ ] Follow/unfollow updates public profile follower count; Following feed/list refresh
- [ ] Followers list (`/profile/followers`) loads and paginates
- [ ] Public profile opens via `userId` route; legacy handle-only links behave per policy

### Delete lifecycle (P1–P3)

- [ ] Move a published mono to Trash
- [ ] Restore from Trash
- [ ] Permanently delete: confirm → typed `DELETE` → row removed and snackbar shown

## 9. Known Deferred Scope

- `share_plus` / system share sheet
- ARB / `gen-l10n` localization
- collections/folders implementation
- legacy route full removal
- further social count placement polish

## 10. Known Analyzer / Warning Debt

Hardening standard:

- **Do not require** `flutter analyze` exit code 0 if the repo baseline has warnings/infos.
- **Do require**: no **new** analyzer **error-severity** issues on the release branch; and no new high-signal warnings introduced by the hardening work itself.

Known patterns from prior reports:

- Large UI files may carry many **infos/warnings** (`withOpacity` deprecation, unused private helpers, etc.).
- Example: including `profile_screen.dart` in analyze paths can surface many **pre-existing** issues (see `docs/M8C1_SAVED_ONLY_POLISH_REPORT.md`).
- Repo cleanup reports document that `flutter analyze` exit code can be **1** even when error-severity is **0** (see `docs/CLEANUP_WAVE_2A_REPORT.md`).

## 11. Release Blockers

These are **blockers before public production** (aligns with `docs/M6E_RELEASE_CHECKLIST.md` §7):

1. Object storage configured (S3/R2/etc.), not disk-only, for public release
2. `MEDIA_PUBLIC_BASE_URL` + CORS verified for Web and mobile fetch origins
3. TLS valid; no mixed-content asset URLs on HTTPS web
4. Secrets are real and protected (JWT, bucket keys, DB creds)
5. DB migration state is clean in the deployed environment
6. Manual smoke (this plan §8) executed on staging with the same storage driver as prod

## 12. Recommended Release Candidate Steps

Repeat these steps for each RC tag (RC1, RC2, …).

1. **Pick environment matrix**
   - Local dev (disk) for quick regression
   - Staging (remote drafts + strict; object storage if prod will use it)
2. **Backend**
   - Install → prisma validate/generate/migrate status → tests → build
3. **Flutter**
   - pub get → analyze → full test suite
4. **Manual smoke** on staging (Web + one mobile)
5. **Record evidence**
   - exact commands, versions, and key outputs
   - URLs used for API + asset base
6. **Decide go/no-go** based on blockers (§11)

## 13. Exact Cursor Prompt For V1 Smoke Report

Copy/paste this prompt into Cursor to generate a run-specific smoke report after executing §12 in your environment:

```text
Create docs/V1_SMOKE_REPORT_<YYYY-MM-DD>_<env>.md.

Context:
- This is a V1 release hardening smoke run.
- Do not modify app or backend code.
- Do not run migrations beyond checking status (no new migrations).
- Use docs/V1_RELEASE_HARDENING_PLAN.md as the checklist source.

Inputs to read:
- docs/V1_RELEASE_HARDENING_PLAN.md
- docs/M6E_RELEASE_CHECKLIST.md
- docs/M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md

Environment (fill in):
- env name: <local|staging|prod>
- platform(s): <web|android|ios>
- backend base url: <...>
- media public base url: <...>
- MEDIA_STORAGE_DRIVER: <disk|s3|r2>
- flutter dart-defines used: <...>

Include sections:
# V1 Smoke Report (<date> <env>)
## Environment
## Automation Results
- backend tests/build
- flutter analyze summary
- flutter test summary
## Manual Smoke Results
## Issues Found (with severity)
## Release Blockers
## Final Verdict
## Recommended Next Step
```

