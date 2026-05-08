# M6e Release Checklist

**Purpose:** Freeze **release readiness** for Nimon after **M1–M6** track work — **documentation only**. No application code changes and **no migrations** are implied by this file; operators run commands in their environment and tick boxes.

**Milestone context (current state):**

| Track | Status (product) |
|-------|------------------|
| **M1** Auth / account | Complete |
| **M2** Remote authoring | Complete |
| **M3** Mono feed + reader | Complete |
| **M4** Full Learn | Complete — see [M4_FULL_LEARN_CLOSEOUT_REPORT.md](M4_FULL_LEARN_CLOSEOUT_REPORT.md) |
| **M5** Media upload + published edit visibility | Complete — see [M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md) |
| **M6** Storage / CDN hardening | **Local disk** media smoke **passed** — see [M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md](M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md). **S3/R2** production path may still be **pending / environment-dependent** — see [M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md) §9–12. |

**Related runbooks:** [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md), [README.md](../README.md) (draft modes, `dart-define` flags).

---

## 1. Current Release Readiness Summary

- **Feature breadth:** M1–M5 capabilities (auth, remote drafts, Mono, Learn, uploads, edit visibility) are **closed out** in docs; M6 **disk** path is **smoke-verified** for dev-style environments.
- **Automation:** Backend media Jest + `nest build`, and Flutter `flutter test`, are **expected green** before tagging; record actual counts in your run notes (see [M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md](M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md) for last recorded automation snapshot).
- **Production storage:** **Disk + `/uploads` is not a production durability/scaling strategy** per [M6 plan §1](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md). Treat **S3/R2 + correct `MEDIA_PUBLIC_BASE_URL` + CORS/TLS** as a **release gate** for any **real public** deployment.
- **Use this checklist** to sign off **internal / dev / staging** vs **public production** explicitly in the **Output summary** at the bottom.

---

## 2. Required Backend Checks

Run from **`nimon-backend/`** unless noted. Record **Pass / Fail / N/A** in your own run log.

| Step | Action | Notes |
|------|--------|--------|
| **Postgres** | **Docker Postgres running** | `docker compose up -d postgres` or `docker start nimon-postgres` — [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md) §1 |
| **DB URL** | **`DATABASE_URL`** in `.env` matches the running instance | See `nimon-backend/.env.example` |
| **Migrate status** | `npm run prisma:migrate:status` (or `npx prisma migrate status`) | No new migrations required for URL-only media V1 per M6 plan; still verify **deployed** env is in sync |
| **Prisma generate** | `npm run prisma:generate` or `npx prisma generate` | Ensures client matches schema |
| **Prisma validate** | `npm run prisma:validate` (optional) | Sanity on schema |
| **Backend tests** | `npm test` or targeted `node ./node_modules/jest/bin/jest.js src/modules/media` | Media module had **36** tests at last recorded M6d run |
| **Backend build** | `npm run build` or `nest build` | Must succeed for deploy artifacts |
| **JWT env** | **`JWT_SECRET`** (and related auth vars) set for the environment | No dev-only defaults in production |
| **MEDIA env** | **`MEDIA_STORAGE_DRIVER`**, **`MEDIA_PUBLIC_BASE_URL`**, **`MEDIA_UPLOAD_DIR`** (disk) **or** bucket credentials (S3/R2) per [M6 plan §6](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md) | Misconfiguration is the #1 prod risk for broken images/audio |
| **CORS env** | **`CORS_ORIGIN`** for API; **`/uploads`** static CORS aligned for Web GET | [UPLOADS_STATIC_CORS_FIX_REPORT.md](UPLOADS_STATIC_CORS_FIX_REPORT.md), M5 closeout |
| **Dev owner parity** (local only) | If using **`DEV_OWNER_ID`**, Flutter **`NIMON_DEV_OWNER_ID`** matches | [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md) §2 — avoids “empty Published” confusion |

---

## 3. Required Flutter Checks

From **repo root** (parent of `nimon-backend/`). See [README.md](../README.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md).

| Step | Action | Notes |
|------|--------|--------|
| **Deps** | `flutter pub get` | |
| **Tests** | `flutter test` | Full suite before tag; optional `flutter test test/features/create` for faster signal |
| **Analyze** | `flutter analyze` | Expect **existing** infos/warnings on large files (§6); no **new** errors for release branch |
| **Remote drafts** | Run with `--dart-define=NIMON_USE_REMOTE_DRAFTS=true` for staging smoke | Required if validating **DB-backed** drafts |
| **Remote strict** | Add `--dart-define=NIMON_STRICT_REMOTE_DRAFTS=true` | Surfaces API failures instead of silent local fallback — recommended for **staging / QA** |
| **API base** | `--dart-define=NIMON_API_BASE_URL=...` when not `localhost:3000` | e.g. Android emulator `http://10.0.2.2:3000` |
| **Login / register smoke** | Manual: register (if enabled), login, token persistence, session refresh behavior | Align with **M1** acceptance |

---

## 4. Manual Product Smoke

Tick when verified in the **target environment** (record Web vs mobile separately if needed).

**Account & creator**

- [ ] **Register** (if product allows) / **Login**
- [ ] **Create story** (basics + at least one sentence path as product requires)
- [ ] **Save draft** (local-first and/or **remote drafts** per your matrix)

**Media**

- [ ] **Upload cover** (JPG; add PNG/WebP if in release matrix)
- [ ] **Upload audio** (mp3 / m4a / wav); **Add audio to story**; Web **MIME / 415** sanity if Web ships

**Publish**

- [ ] **Publish read-only**
- [ ] **Publish full-learn**

**Discovery & profile**

- [ ] **Mono feed** — item appears with **cover** and **Story Basics** description where applicable
- [ ] **Mono footer** — long description **See more / See less** if shipping that UX
- [ ] **Profile → Published** — row + thumbnail

**Edit visibility (M5)**

- [ ] **Workspace** — editing state visible when draft has unpublished changes
- [ ] **Republish** after edits — row **reappears** in Mono + Published; **hide** behavior while editing confirmed

**Learn (M4)**

- [ ] **Learn hub** — modules available per **full learn** publish
- [ ] **Vocabulary / Grammar / Quiz** — hydrated from published snapshot (no demo leakage on real UUIDs)
- [ ] **Listening** — audio plays from **http(s)** URL; **transcript** / **furigana** / **translation** when enabled in product

---

## 5. Storage / Media Release Gate

| Rule | Detail |
|------|--------|
| **Disk local** | **OK for dev / internal** only when **`MEDIA_STORAGE_DRIVER`** is unset or **`disk`**; files under **`MEDIA_UPLOAD_DIR`**; **`/uploads`** serves bytes; URLs match **`MEDIA_PUBLIC_BASE_URL`**. Confirmed in [M6D](M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md) for local disk smoke. |
| **S3/R2 before real production** | **Required** for durability, scaling, and bandwidth expectations per [M6 plan §1](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md). Run **M6d S3/R2** checklist rows in [M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md](M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md) on **staging** before prod cut. |
| **`CORS_ORIGIN`** | API + (if cross-origin assets) **bucket/CDN CORS** for Flutter **Web** **GET** (and **PUT** if presigned later). |
| **`MEDIA_PUBLIC_BASE_URL`** | Must be the **canonical public HTTPS** (or dev **http**) base for returned **`url`** — **no mixed content** on prod Web. |
| **Bucket URL test** | `curl -I` or browser GET on a sample uploaded object → **200**, sensible **`content-type`**, TLS valid in prod — [M6 plan §10](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md). |

---

## 6. Known Non-blocking Warnings

Documented product / tooling gaps — **not** automatic ship-stoppers if accepted by owners:

- **Flutter analyze:** Large legacy files (e.g. `mono_screen.dart`) may report **many infos/warnings** (`withOpacity`, unnecessary `const`, unused fields). Track cleanup separately.
- **Upload UX:** **No upload percent progress** in current `MediaUploadRepository` path — [M6 plan §8](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md), [M5C](M5C_FLUTTER_MEDIA_UPLOAD_INTEGRATION_REPORT.md).
- **Audio metadata:** **`durationSeconds`** may be **null** — server probe not guaranteed; [M5B](M5B_BACKEND_MEDIA_UPLOAD_REPORT.md).
- **S3/R2:** If smoke was **disk-only**, **object storage + CORS + public URL** behavior is **unverified** for that tag — see §5.
- **Transcript model:** “No transcript model” called out as longer-term risk in [M6 plan §11](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md) — out of core storage checklist scope.

---

## 7. Blockers Before Public Release

Treat as **must-fix** before a **real public** production launch (adjust if product scope differs):

1. **Production object storage** configured (**S3** or **R2** or equivalent), not sole reliance on API **disk**.
2. **`MEDIA_PUBLIC_BASE_URL`**, **`CORS_ORIGIN`**, and **bucket/CDN CORS** verified for **Flutter Web** and **mobile** fetch origins.
3. **TLS** valid on API and asset URLs; **no mixed-content** `http` assets on `https` app.
4. **Secrets:** **`JWT_SECRET`**, **`MEDIA_*` keys**, DB credentials — no dev defaults in prod.
5. **Database:** **`prisma migrate deploy`** (or equivalent) applied in prod; **`migrate status`** clean for the environment.
6. **Smoke:** §4 manual matrix executed on **staging** with **same** storage driver as prod.
7. **Optional hardening:** Rate limits, monitoring, backup policy for bucket — outside this checklist but expected for serious prod.

---

## 8. Recommended Next Milestone

Choose based on **whether production launch is immediate**:

| If… | Then… |
|-----|--------|
| **Production launch is immediate** | Prioritize **M6f / production storage deployment** — implement and smoke **S3/R2** (and CDN/public URL) per [M6C_S3_R2_MEDIA_STORAGE_REPORT.md](M6C_S3_R2_MEDIA_STORAGE_REPORT.md) + [M6D](M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md) object-storage rows; optional **presigned uploads** later if API offload is needed ([M6 plan §12 **M6f**](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md)). |
| **Production can wait; product depth next** | **M7 — Account / profile polish** — saved collections, bookmark/react/share consistency, notifications UX, public profile polish — *label is suggestive; split into PR-sized epics.* |

**Default recommendation:** If the next step is **public users on real infra**, do **S3/R2 staging + prod** first. If the next step is **internal beta on disk-only VPS**, document the **durability risk** explicitly and still run §2–4 checks.

---

## Output summary

| Question | Record when checklist is run |
|----------|------------------------------|
| **Release checklist created?** | **Yes** — this document (`docs/M6E_RELEASE_CHECKLIST.md`). |
| **Local / dev release ready?** | **Yes** *if* §2–4 pass on **disk** dev env and owners accept disk limitations — consistent with [M6D](M6D_STORAGE_AND_MEDIA_SMOKE_REPORT.md) local smoke. |
| **Production release ready?** | **Not without** §5 **S3/R2** (or equivalent) + §7 blockers cleared — **disk-only is not production-ready** per M6 plan. |
| **Blockers** | See **§7**; primary external gap is **object storage + env/CORS/TLS** if only disk was smoke-tested. |
| **Recommended next milestone** | **Immediate prod:** **M6f S3/R2 production deployment** + staging smoke. **Otherwise:** **M7** profile/social polish — or parallelize storage + polish with separate owners. |
