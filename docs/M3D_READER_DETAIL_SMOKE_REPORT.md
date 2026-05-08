# M3d Reader Detail Smoke Report

**Report date:** 2026-05-03  
**Type:** Release QA — reader content parity (per [M3D_READER_DETAIL_VERIFICATION_PLAN.md](M3D_READER_DETAIL_VERIFICATION_PLAN.md) **§2 Expected Reader Parity**).  
**Scope:** Same published mono from **Profile → Published** (owner `GET /v1/published-monos/:id` → `/mono-reader`) vs **Mono Home → For You** (public `GET /v1/mono/feed` + `GET /v1/mono/:id` hydration → in-shell `MonoScreen`).

**Execution note:** This file is a **structured smoke record**. **Interactive device verification** of the two reader paths was **not performed in the authoring environment**; result cells are **Pending** until a developer completes the manual flow in **§3** of the plan and updates this document.

---

## Environment

| Item | Value (fill in when run) |
|------|----------------------------|
| Backend base URL | *e.g. `http://localhost:3000` or `http://10.0.2.2:3000` (Android emulator → host)* |
| Postgres | Running |
| Nest | Running (`npm run start:dev` from `nimon-backend/`) |
| Flutter `dart-define` | See below |

**Flutter defines (required for this smoke):**

| Define | Value |
|--------|--------|
| `NIMON_USE_REMOTE_DRAFTS` | `true` |
| `NIMON_STRICT_REMOTE_DRAFTS` | `true` |
| `NIMON_USE_REMOTE_MONO_FEED` | `true` |
| `NIMON_API_BASE_URL` | *Must reach Nest from the device (e.g. `http://10.0.2.2:3000` on Android emulator)* |

Example:

```bash
flutter run \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true \
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true \
  --dart-define=NIMON_API_BASE_URL=http://localhost:3000
```

---

## Published mono under test

| Field | Value (manual) |
|-------|----------------|
| `published_monos.id` (UUID) | **Pending** |
| Publish mode tested | **Read-only** (required) / **Full learn** (optional) |

---

## Parity results (Plan §2)

| Aspect | Profile path (`/mono-reader`) | Mono For You (in-shell `MonoScreen`) | Match? |
|--------|-------------------------------|--------------------------------------|--------|
| **Title** | **Pending** | **Pending** | **Pending** |
| **Sentence / body text** (from `content.core.sentences` / parser) | **Pending** | **Pending** | **Pending** |
| **Furigana / ruby** | **Pending** (note if plain-text only) | **Pending** | **Pending** |
| **Source / English meaning** | **Pending** (or N/A) | **Pending** (or N/A) | **Pending** |
| **Level / category** | **Pending** | **Pending** | **Pending** |
| **Publish kind** (read-only vs full-learn signal) | **Pending** | **Pending** | **Pending** |
| **Learn button / `_openLearn` behavior** | **Pending** | **Pending** | **Pending** |

---

## Path-specific observations

### Profile → Published → reader

| Topic | Result |
|-------|--------|
| API | `GET /v1/published-monos/:id` (owner-scoped, JWT) |
| Route | `/mono-reader` |
| **Title** | **Pending** |
| **Body / sentences** | **Pending** |
| **Learn** (read-only / full-learn as tested) | **Pending** |

### Mono Home → For You → same mono

| Topic | Result |
|-------|--------|
| Feed | `GET /v1/mono/feed` |
| Detail hydration | `GET /v1/mono/:id` (public) |
| Shell | In-shell `MonoScreen` / `_ReadingFeedPost` (not `/mono-reader`) |
| **Title** | **Pending** |
| **Body / sentences** (after hydration) | **Pending** |
| **Learn** (read-only / full-learn as tested) | **Pending** |

### UX shell comparison

| Topic | Notes |
|-------|--------|
| `/mono-reader` vs in-shell `MonoScreen` | **Expected:** different chrome (dock, back); **judge content parity** per plan §2, not pixel parity. |
| Hydration / SnackBar | **Pending** — note any error SnackBar, delay before full text, or stuck teaser body. |

---

## Discrepancies and issues

| ID | Severity | Description |
|----|----------|-------------|
| — | — | **None recorded** — manual run not completed in this session. |

*When testing, log: text mismatches, missing sentences, Learn gating differences, hydration failures, parser omissions.*

---

## Final verdict

**Verdict:** **Pending manual smoke** — update to **Pass**, **Partial**, or **Fail** after executing [M3D_READER_DETAIL_VERIFICATION_PLAN.md](M3D_READER_DETAIL_VERIFICATION_PLAN.md) §3.

| Verdict | Meaning |
|---------|---------|
| **Pass** | Plan §2 parity holds for read-only (and full-learn if tested); no blocking discrepancies. |
| **Partial** | Minor UX/timing issues only (e.g. brief hydration delay) or one non-core field mismatch. |
| **Fail** | Title/body/Learn gating materially differs between paths, or detail fetch consistently fails on Mono path. |

---

## Recommended next fix scope (small only)

Use only if smoke finds issues — aligned with plan §6:

1. **Parser / fixtures** — one golden JSON fixture if a specific `content` shape fails to parse equally on both paths.  
2. **Hydration UX** — clearer loading or retry if **`GET /v1/mono/:id`** fails (SnackBar already present per M3c).  
3. **Learn gating** — align **`publishedAccess`** from **`monoFeedItemMergePublishedDetail`** with **`publishedAccessFromDetail`** expectations if mismatch is confirmed.  

Defer large **`mono_screen`** refactors.

---

## Output summary

| Question | Answer |
|----------|--------|
| Environment documented? | **Yes** (defines + example command; URL filled per run) |
| Profile vs Mono path summarized? | **Yes** |
| Parity vs plan §2? | **Table ready** — results **Pending** until manual run |
| Discrepancies listed? | **None** — not yet executed |
| Final verdict? | **Pending manual smoke** |
| Next action | Run manual checklist (plan §3), fill tables, set **Pass / Partial / Fail**, then apply **small** fixes from §6 only if needed |
