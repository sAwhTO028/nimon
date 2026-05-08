# P0 Published Edit Visibility Smoke Report

**Purpose:** P0 smoke per [PUBLISHED_EDIT_DELETE_POLICY_PLAN.md](PUBLISHED_EDIT_DELETE_POLICY_PLAN.md) §12–§13 — confirm **M5** published edit visibility **before** Trash (soft-delete) work.  
**Scope:** This run combines **automated regression** (CI-style) with a **manual checklist** for full-stack verification. **No app code changes** and **no migrations** as part of this report.

**References:** [M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md), [M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md), [M6E_RELEASE_CHECKLIST.md](M6E_RELEASE_CHECKLIST.md), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md), [PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md](PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md).

---

## Environment

| Field | Value |
|-------|--------|
| **Report date** | 2026-05-05 |
| **Repo** | `nimon` (Flutter) + `nimon-backend` |
| **Manual smoke target** | Backend + Postgres running; Flutter with `NIMON_USE_REMOTE_DRAFTS=true`, `NIMON_STRICT_REMOTE_DRAFTS=true`, remote Mono feed ON (`NIMON_USE_REMOTE_MONO_FEED` per project docs) |
| **Agent session** | Ran **automated tests only**; **did not** run Prisma Studio, live API curls against a dev server, or manual Flutter UI in this session |

**Flutter defines (manual run):** See [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md) — e.g.:

```bash
flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true --dart-define=NIMON_USE_REMOTE_MONO_FEED=true
```

(Adjust `NIMON_API_BASE_URL` / `NIMON_DEV_OWNER_ID` per your `.env` parity.)

---

## Story Under Test

| Field | Manual run — record here |
|-------|--------------------------|
| **Draft / mono id** | _— fill after publish —_ |
| **Publish kind** | Read-only _or_ Full learn |
| **Account** | _— test user —_ |

---

## Edit Visibility Steps

| Step | Description | Result (manual) | Automated proxy |
|------|-------------|-----------------|-----------------|
| 1 | Publish read-only or full-learn | **Not executed here** | — |
| 2 | Appears Mono Home + Profile Published | **Not executed here** | Feed/list behavior covered by backend `PUBLISHED_MONO_CATALOG_VISIBLE` in Jest |
| 3 | Open creator from Published or Mono | **Not executed here** | — |
| 4 | Core edit (title / description / sentence) | **Not executed here** | — |
| 5 | Save remote draft → `hasUnpublishedCoreChanges = true` | **Not executed here** | Story-drafts service tests exist separately |
| 6–10 | Prisma + UI + 404 + republish | **Not executed here** | See **Automated regression** below |
| 11 | Optional: delete linked draft → orphan risk | **Not executed here** | Document only in [PUBLISHED_EDIT_DELETE_POLICY_PLAN.md](PUBLISHED_EDIT_DELETE_POLICY_PLAN.md) §4 |

---

## Prisma Checks

| Check | Expected | Manual result |
|-------|----------|---------------|
| `StoryDraft.hasUnpublishedCoreChanges` | `true` after dirty save | _—_ |
| `StoryDraft.publishedMonoId` | Set to published mono UUID | _—_ |
| After republish | `hasUnpublishedCoreChanges = false` | _—_ |

---

## UI Checks

| Check | Expected | Manual result |
|-------|----------|---------------|
| Mono Home after refresh | Story **hidden** while dirty | _—_ |
| Profile Published | Row **hidden** while dirty | _—_ |
| Profile Workspace | Row shows **Editing** (or equivalent) | _—_ |
| Open detail / old id | Friendly **editing** copy if 404 mapped | _—_ |

---

## Republish Checks

| Check | Expected | Manual result |
|-------|----------|---------------|
| Mono Home | Story **visible** again | _—_ |
| Profile Published | Row **visible** again | _—_ |
| Workspace | Editing state **clears** / syncs | _—_ |

### Storytelling core after republish (sentence fix — doc alignment)

Aligned with **[PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md](PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md)** (backend + regression). **Operators should confirm on a live stack** alongside visibility rows above:

| Checkpoint | Expected (after fix) |
|------------|----------------------|
| **Update Full Learn** | Refreshes **`content.core`** **and** **`content.learn`** on `PublishedMono` (Full Learn previously omitted core refresh — fixed). |
| **Update Read Only** | Refreshes **`content.core`** (unchanged product intent; shared core builder). |
| **Sentence edits** | Storytelling text changes from published-edit flow **publish** to reader-facing core. |
| **Sentence reorder** | Order in **`content.core.sentences`** matches creator Storytelling order (`DraftSentence.order` / `orderIndex`). |
| **Furigana / meanings** | Preserved inside each sentence **`content`** payload (spans + `meanings`). |

---

## Draft Delete Orphan Check

**Step 11 (optional, dev-only content):** _Not performed in this session._  
If performed manually: record whether **`PublishedMono`** reappeared in **`GET /v1/mono/feed`** after **`DELETE /v1/story-drafts/:id`** — aligns with **orphan risk** in [PUBLISHED_EDIT_DELETE_POLICY_PLAN.md](PUBLISHED_EDIT_DELETE_POLICY_PLAN.md) §4.

| Observed | Notes |
|----------|--------|
| _—_ | _—_ |

---

## Automated regression (executed)

Commands run in agent session:

```bash
cd nimon-backend
node ./node_modules/jest/bin/jest.js src/modules/mono-feed src/modules/published-monos
```

**Result:** **14 passed** (mono-feed + published-monos suites — includes `PUBLISHED_MONO_CATALOG_VISIBLE` in feed/list/detail `where` clauses per M5d).

```bash
cd <repo-root>
flutter test test/auth/remote_published_mono_repository_auth_test.dart \
  test/features/mono/remote_mono_feed_repository_test.dart \
  test/features/profile/published_mono_catalog_visibility_exception_test.dart
```

**Result:** **9 passed** — owner `GET /v1/published-monos/:id` **404** → `PublishedMonoHiddenWhileEditingException`; public `GET /v1/mono/:id` **404** → same; user message helpers.

### Story drafts + mono-feed (sentence / core publish regression)

Recorded in **[PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md](PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md)** — validates published **core** storytelling after Full Learn publish, reorder persistence, and related mapper/wire coverage.

```bash
cd nimon-backend
node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts
node ./node_modules/jest/bin/jest.js src/modules/mono-feed
node ./node_modules/@nestjs/cli/bin/nest.js build
```

```bash
cd <repo-root>
flutter test
```

| Suite / gate | Result (recorded with fix doc) |
|--------------|--------------------------------|
| **`story-drafts.service.spec`** | **17 passed** |
| **`mono-feed`** | **11 passed** |
| **NestJS build** | **Passed** |
| **`flutter test` (full)** | **283 passed** |

**Product confirmations (engineering regression, not substitute for manual UI):**

- **Update Full Learn** now refreshes **`content.core`** and **`content.learn`**.
- **Storytelling** sentence **edits** publish correctly via core refresh.
- **Storytelling** sentence **reorder** publishes correctly (ordered core sentences).
- **Furigana** / **meanings** preserved in published sentence payloads.
- **Read Only** and **Full Learn** updates **both refresh core**.

---

## Issues Found

| ID | Severity | Description |
|----|----------|-------------|
| — | — | **No blocking defects** observed in **automated** runs (visibility + targeted client suites + story-drafts core publish regression noted above). |
| **M-1** | Info | **Manual steps 1–11** not executed in this session — **full P0 sign-off** still requires operator run with live stack. |
| **M-2** | Info | **Prior gap (fixed):** Full Learn republish did not refresh **`content.core`**, so reader Storytelling could stay stale while learn updated — see [PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md](PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md). **Manual** reader check after republish still recommended. |

---

## Final Verdict

| Criterion | Status |
|-----------|--------|
| **M5d visibility logic** | **Pass** (automated Jest — feed + published queries include catalog visibility). |
| **M5e client 404 mapping + copy helpers** | **Pass** (targeted Flutter tests). |
| **Published core storytelling on republish** | **Pass** (automated) per [PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md](PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md): Full Learn + Read Only refresh **`content.core`**; sentence edit/reorder + furigana/meanings covered in **story-drafts** Jest + **Flutter** suite (**283**); backend **build** passed. **Manual** reader confirmation still part of full P0. |
| **End-to-end manual smoke (steps 1–11)** | **Not run** in this session — **Incomplete** until operator completes tables above. |

**Summary:** Automated regression supports M5 published-edit hiding behavior **and** published **core** refresh after the sentence reorder / Full Learn fix; **full product smoke** remains **pending** on a live **Postgres + Nest + Flutter (remote strict + remote mono feed)** environment.

---

## Recommended Next Step

1. **Operator:** Execute **§ Story Under Test** through **§ Republish Checks** manually; fill tables; include **§ Storytelling core after republish** (sentence edit, reorder, furigana/meaning) on the live stack; run **optional** draft-delete orphan on **throwaway** data only.  
2. **Engineering:** Proceed with **P1 Trash** backend ([PUBLISHED_EDIT_DELETE_POLICY_PLAN.md](PUBLISHED_EDIT_DELETE_POLICY_PLAN.md) §14) after manual P0 is **green** or accept documented risk.  
3. **If manual run finds a bug:** File issue; **do not** change code in the smoke task unless explicitly approved.

---

## Output summary

| Question | Answer |
|----------|--------|
| **Edit hides from Mono Home?** | **Expected yes** per M5d; **not manually verified** here — Jest covers visibility predicate on feed query. |
| **Edit hides from Profile Published?** | **Expected yes**; **not manually verified** here — Jest covers published-monos list/detail `where`. |
| **Workspace shows Editing?** | **Not manually verified** here (Flutter UI). |
| **Prisma dirty flag correct?** | **Not manually verified** here (requires Studio / SQL). |
| **Republish restores?** | **Expected yes** per M5 docs; **not manually verified** here — covered indirectly by existing publish flows in backend tests (separate suites). |
| **Full Learn refreshes `content.core` + `content.learn`?** | **Yes** per implementation + **story-drafts** Jest (**17**); details in [PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md](PUBLISHED_SENTENCE_REORDER_PUBLISH_FIX_REPORT.md). |
| **Storytelling sentence edit / reorder publish?** | **Expected yes**; **automated** coverage in story-drafts + Flutter create/wire tests; **manual** reader check still open. |
| **Furigana / meanings preserved on publish?** | **Expected yes** per fix report + tests; **manual** spot-check recommended. |
| **Backend tests (story-drafts / mono-feed)?** | **17** / **11** passed (as recorded with fix doc). |
| **Backend build / Flutter full test?** | **Build passed**; **Flutter 283** passed (as recorded with fix doc). |
| **Draft delete orphan reproduced?** | **Not tested** (step 11 skipped). |
| **Final verdict** | **Partial:** **automated regression Pass** (visibility + **core republish**); **manual P0 Incomplete** until operator fills this doc. |
| **Next step** | **Manual run** of steps 1–10 (+ optional 11) **and** storytelling core checks on dev stack; then **P1 Trash** implementation. |
