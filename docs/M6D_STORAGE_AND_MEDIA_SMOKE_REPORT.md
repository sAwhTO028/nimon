# M6d Storage And Media Smoke Report

**Purpose:** Staging / environment **smoke verification** for **media storage** (disk or S3/R2), **Flutter media upload** (cover + audio), **publish & read paths**, and **published-edit visibility** — after **M5 closeout** ([M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md)), **simplified creator UX** ([CREATOR_AUDIO_UPLOAD_UX_SIMPLIFICATION_REPORT.md](CREATOR_AUDIO_UPLOAD_UX_SIMPLIFICATION_REPORT.md), [CREATOR_COVER_UPLOAD_UX_SIMPLIFICATION_REPORT.md](CREATOR_COVER_UPLOAD_UX_SIMPLIFICATION_REPORT.md)), **M6b** driver abstraction ([M6B_MEDIA_STORAGE_DRIVER_ABSTRACTION_REPORT.md](M6B_MEDIA_STORAGE_DRIVER_ABSTRACTION_REPORT.md)), **M6c** S3/R2 driver ([M6C_S3_R2_MEDIA_STORAGE_REPORT.md](M6C_S3_R2_MEDIA_STORAGE_REPORT.md)), and **audio MIME / creator CTA hardening** ([AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md](AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md)).  

**This document is a checklist and record only** — no application code changes and **no migrations** (per [M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md), §9).

**Instructions:** Fill **Environment**, tick **Smoke** items, note **Issues Found**, then complete **Final Verdict** and **Output Summary** after the run.

---

## Environment

| Field | Value / notes |
|-------|----------------|
| Date | **2026-05-05** — manual **local disk / dev** smoke (recorded below) |
| Backend revision / image tag | Local dev (not pinned) |
| Flutter revision / build | **Flutter Web** (local) |
| **`MEDIA_STORAGE_DRIVER`** | **`disk`** (object storage not exercised this run) |
| **`MEDIA_PUBLIC_BASE_URL`** | Aligned with local API `/uploads` reachability for this smoke. |
| **`MEDIA_UPLOAD_DIR`** (disk) | Default local disk layout (per dev `.env`). |
| **`MEDIA_BUCKET`**, **`MEDIA_REGION`**, **`MEDIA_ENDPOINT`** (object storage) | **N/A** — disk-only smoke. |
| **`NIMON_API_BASE_URL`** / Flutter API base | Local dev pairing with Flutter Web. |
| **`CORS_ORIGIN`** (API) | Sufficient for this Web smoke (cover/audio fetch). |
| Flutter web origin (for bucket/`/uploads` CORS if cross-origin) | N/A for disk-only; cross-origin not blocking this run. |
| DB / JWT | Standard local dev |

---

## Backend Commands

Run as applicable (record pass/fail and versions):

```bash
cd nimon-backend
npm install
node ./node_modules/jest/bin/jest.js src/modules/media
node ./node_modules/@nestjs/cli/bin/nest.js build
```

Optional sanity:

```bash
node ./node_modules/prisma/build/index.js validate
```

**Record**

| Command | Result |
|---------|--------|
| `jest src/modules/media` | Pass / fail |
| `nest build` | Pass / fail |

**Recorded automation (post–[AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md](AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md), 2026-05-05):** `jest src/modules/media` → **36** tests passed; `nest build` → **passed**.

---

## Flutter Commands

```bash
dart format <touched paths if any>
flutter analyze
flutter test test/features/create
flutter test
```

**Record**

| Command | Result |
|---------|--------|
| `flutter test test/features/create` | Pass / fail |
| `flutter test` (full suite) | Pass / fail |

**Recorded automation (same fix batch):** `flutter test` (full suite) → **231** passed.

---

## Storage Mode

| Mode | Verification |
|------|----------------|
| **Disk (local/dev)** | `MEDIA_STORAGE_DRIVER` unset or `disk`; files under `MEDIA_UPLOAD_DIR`; static **`/uploads`** serves bytes; URLs align with `MEDIA_PUBLIC_BASE_URL`. See [M6b](M6B_MEDIA_STORAGE_DRIVER_ABSTRACTION_REPORT.md). |
| **Object storage (staging/prod)** | `MEDIA_STORAGE_DRIVER=s3` or `r2`; required env set per [M6C](M6C_S3_R2_MEDIA_STORAGE_REPORT.md); bootstrap fails fast if required vars missing. |

---

## Cover Upload Smoke

Aligned with [CREATOR_COVER_UPLOAD_UX_SIMPLIFICATION_REPORT.md](CREATOR_COVER_UPLOAD_UX_SIMPLIFICATION_REPORT.md) and [M5 closeout](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md) cover checks.

- [x] Signed in; **Story basics** shows **Choose cover image** / supported formats (short UX).
- [x] Upload **JPG** (including `image`/`jpg` / octet-stream edge cases if testing web).
- [ ] Upload **PNG** / **WebP** as needed for your matrix — *not required for this run; JPG path verified on Web.*
- [x] After success: UI shows **Saved online** (or equivalent remote state); draft persists **`coverImageUrl`** as **`http(s)`**.
- [ ] Failure path: **Local preview only** + short error (not exercised this run).
- [ ] Signed out: upload disabled / **Sign in to upload cover images.** — *not exercised this run.*

**Result:** **Pass** — Cover image **uploads and displays correctly in Flutter Web**; remote URL behavior consistent with local disk + `/uploads`.

---

## Audio Upload Smoke

Aligned with [CREATOR_AUDIO_UPLOAD_UX_SIMPLIFICATION_REPORT.md](CREATOR_AUDIO_UPLOAD_UX_SIMPLIFICATION_REPORT.md), M5 listening/upload wiring, and **[AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md](AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md)** (audio **415** fix + creator CTA).

### Backend MIME behavior (smoke awareness)

- **`POST /v1/media/upload/audio`** accepts **practical Flutter Web / browser MIME variants** (e.g. `audio/mp3`, `audio/x-wav`, `audio/vnd.wave`, `audio/m4a`, canonical WAV/MPEG/M4A aliases) via **`resolveAudioMime`** — see fix report.
- **`application/octet-stream`** (or empty Content-Type) **with a valid audio filename** is accepted when extension is **`.mp3`**, **`.m4a`**, or **`.wav`** (inferred MIME).
- **Unsupported types** (e.g. **`application/octet-stream` + `.pdf`**) remain **rejected** (**415**).
- Automated regression: backend **`jest src/modules/media`** — **36** passed (includes octet-stream audio + rejection cases).

### Creator sheet CTA (Flutter)

- After upload success, primary action is **Add audio to story** (not auto-close; user confirms attach to draft). Helper copy references upload-then-add flow — see fix report.

### Checklist

- [x] Signed in; **Listening / Audio** — primary flow **Choose audio file** → upload completes (**Upload complete**) → **Add audio to story** (then **Replace audio** / **Remove audio** as needed).
- [x] **Flutter Web** (if in scope): upload succeeds even when the browser sends **`application/octet-stream`** or non-canonical audio MIME — no **415** for valid `.mp3` / `.m4a` / `.wav`.
- [x] Supported types: **mp3 / m4a / wav** — *at least one happy path verified.*
- [ ] Attempt **unsupported** file (e.g. `.pdf`) — *not exercised this run (automated coverage still in `jest src/modules/media`).*
- [x] Draft **`storyAudio.sourceUrl`** is **`http(s)`** after **Add audio to story** for remote-safe save.
- [ ] Advanced URL / local-only paths still behave if exercised (non-primary; not exercised this run).

**Result:** **Pass** — Audio **upload succeeds**; **“Add audio to story”** applies audio to the draft as expected. **Audio MIME / 415** behavior **verified** for the Web upload path (no spurious 415 on valid audio).

---

## Publish Smoke

From [M6 plan §9](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md) and [M5 closeout](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md).

- [x] **Publish** reading-only and/or **full learn** (per product path).
- [x] **Mono feed** — story appears with **cover** (summary fields).
- [x] **Profile → Published** — row + cover thumbnail loads.
- [x] **Learn → Listening** — audio **plays** from returned **https** URL (or dev **http** if local).
- [x] **Learn → Listening** — story **sentences**, **furigana**, and **translation** (when enabled) — **verified**.
- [x] **Mono Home** + **Learn detail** — **Story Basics description** display — **verified**.
- [x] **Mono footer** — long description **See more / See less** — **verified**.

**Result:** **Pass** — **Publish / read / listen** path green on local disk; reader/Learn presentation matches expectations above.

---

## Published Edit Visibility Smoke

From [M5 closeout § Published Edit Visibility](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md).

- [x] Open creator from **Published** / reader flow; **save** draft so **`hasUnpublishedCoreChanges`** is set server-side.
- [x] **Mono feed**: row **hidden** (after refresh).
- [x] **Profile → Published**: row **hidden**.
- [x] **Workspace**: draft shows **Editing** (or equivalent).
- [x] **Republish**: row **reappears** in feed and Published lists.

**Result:** **Pass** — **Published edit visibility** works: editing **hides** from **Mono feed** and **Profile → Published**, item **appears in Workspace**, **republish restores** public visibility.

---

## S3/R2 Verification

Applies when **`MEDIA_STORAGE_DRIVER`** is **`s3`** or **`r2`** ([M6C](M6C_S3_R2_MEDIA_STORAGE_REPORT.md)).

- [ ] API starts without env validation errors (all required keys present) — *N/A (disk-only).*
- [ ] Upload returns **`url`** whose host matches **`MEDIA_PUBLIC_BASE_URL`** (+ encoded key segments) — *N/A (disk-only).*
- [ ] **`curl -I`** or browser **GET** on a sample uploaded object returns **200** and sensible **`content-type`** (see [M6 plan §10](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md)) — *N/A (disk-only).*
- [ ] **Bucket / CDN CORS** allows Flutter **web** origin for **GET** if assets are cross-origin — *N/A (disk-only).*
- [ ] **TLS** valid on API and asset URL in production-like env — *N/A (disk-only).*

**R2-specific (if used)**

- [ ] **`MEDIA_REGION=auto`** (or documented value) + **`MEDIA_ENDPOINT`** set per account endpoint — *N/A.*
- [ ] **`forcePathStyle`** behavior matches provider (see M6C; optional **`MEDIA_S3_FORCE_PATH_STYLE`**) — *N/A.*

**Result:** **N/A (disk-only smoke)** — **S3/R2 not exercised**; repeat this section against **staging object storage** before production promotion.

---

## Issues Found

| ID | Area | Severity | Description | Tracker |
|----|------|----------|-------------|---------|
| — | — | — | **No issues** recorded for this manual local disk/dev smoke. | — |

---

## Final Verdict

| Criterion | Status |
|-----------|--------|
| Ready for next release milestone / prod cut | **Partial** — **Pass for local disk/dev**; **object storage path not validated** this run. |
| Blockers | **None** for disk-backed local/Web smoke covered above. |

**Summary (2–4 sentences):** Manual smoke on **local disk** + **Flutter Web** **passed** for **cover upload**, **audio upload** (including **MIME / 415** expectations on Web), **Add audio to story**, **publish / read / listen** (including **Listening** with **furigana** and **translation** when enabled), **published edit visibility**, **Story Basics description** on **Mono Home** and **Learn detail**, and **Mono footer See more / See less**. **S3/R2** was **not** run (**N/A**). **Next:** run the **S3/R2** checklist on a **staging** bucket (or equivalent) before treating storage as production-ready.

---

## Recommended Next Step

Per [M6 plan §12](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md): **M6e** — freeze release checklist, tag, monitor production; optional **M6f** presigned uploads if API CPU/memory or large-file behavior requires offloading.

If **S3/R2** was **not** exercised in this smoke, complete env verification from [M6C Manual Configuration Steps](M6C_S3_R2_MEDIA_STORAGE_REPORT.md) before promoting staging.

After **[AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md](AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md)**, prioritize **manual Flutter Web** audio upload on staging (octet-stream cases) if web is in the release matrix; otherwise proceed with **M6e** once this smoke sheet is green.

---

## Output Summary

| Question | Record after smoke |
|----------|-------------------|
| **local disk smoke passed?** | **Yes** |
| **cover upload passed?** | **Yes** |
| **audio upload passed?** | **Yes** |
| **audio MIME / 415 behavior verified (web octet-stream OK)?** | **Yes** |
| **creator “Add audio to story” flow verified?** | **Yes** |
| **publish/read/listen passed?** | **Yes** |
| **edit visibility passed?** | **Yes** |
| **description display verified (Mono Home + Learn detail)?** | **Yes** |
| **Mono footer See more / See less verified?** | **Yes** |
| **S3/R2 verified?** | **N/A (disk-only smoke)** |
| **next milestone recommendation** | **M6e** release checklist when ready; **before prod**: complete **M6d S3/R2** (and **M6c** env) smoke on **staging** object storage — disk-only green is **not** sufficient alone for R2/S3 production confidence. |
| **automated regression noted** | Backend **`jest src/modules/media`**: **36** passed; **`nest build`**: passed; **`flutter test`**: **231** passed (see [AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md](AUDIO_UPLOAD_415_AND_CTA_FIX_REPORT.md)) |
