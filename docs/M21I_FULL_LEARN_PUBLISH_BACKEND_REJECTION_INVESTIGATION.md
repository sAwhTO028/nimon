# M21I — Full Learn Publish Backend Rejection Investigation

Date: 2026-06-03  
Scope: **Investigation only** (no code changes in this document).

## Executive summary

Observed behavior (**Flutter log shows `POST /v1/story-drafts/:id/publish/full-learn`, then the “Before publishing” sheet**) is consistent with:

1. **Client preflight passing** (no blocking issues before the HTTP publish chain).
2. **Backend `publishFullLearn` rejecting** with HTTP `400` + `message: validation_failed` + structured `issues`.
3. The exact copy **“Quiz count must be between 7 and 11 (you have 13).”** matching **`messageKey: learn.count.quiz.range`** with **`min: 7`, `max: 11`, `actual: 13`** — the legacy JLPT **`QUIZ_LIMITS` / `quizLimits`** band for **N4 + `3_5`**, not HTML generator rules (AI expects 13 total; manual HTML total for N4 `3-5 mins` is **8–16**).

**Most likely origin for the POST-then-sheet case:** **deployed or running backend** (and/or **git `HEAD` committed backend**) still on legacy publish validation. **Working tree** has HTML migration in `publish-validation.ts` / `publish_validation.dart` but those files are **modified, not committed** at investigation time.

---

## A. Timeline of publish click

| Step | Where | What happens |
|------|--------|----------------|
| 1 | UI (drawer / editor) | User triggers Full Learn publish → `performCreatorDrawerPublish(..., mode: fullLearn)` (`lib/features/create/creator_drawer_publish.dart`). |
| 2 | Protected action | `ensureProtectedActionAllowed(..., publishStory)` — login/offline gate. |
| 3 | **Client preflight** | `_preflightCreatorPublish(...)` → for Full Learn: `ensurePromptSourceBackfillForPublish()` then `runFullLearnPublishPreflight(draft)` (`creator_publish_preflight.dart`). |
| 4a | Preflight **fail** | `hasBlockingIssues(pre)` → `showPublishValidationSheet(context, issues: pre.issues)` → **return false**. **No publish POST** in this branch. |
| 4b | Preflight **pass** | Continue to `publishFullLearnToDisk()`. |
| 5 | Persist + remote | `publishFullLearnToDisk()` → `_awaitPendingPersistBeforePublish()` → sets draft `publishState: fullLearnPublished` locally → `_persistPublishWithConflictRetry('publish_full_learn')` → `persistLocalNow(reason: 'publish_full_learn')` (`story_creator_provider.dart`). |
| 6 | Remote intent | `reason == 'publish_full_learn'` → `StoryDraftRemotePublishIntent.fullLearn` (`_remotePublishIntentForSaveReason`). |
| 7 | HTTP chain | `RemoteStoryDraftRepository.saveDraft`: **PUT** `/v1/story-drafts/:id` (content), optionally **POST** `/publish/read-only` if `publishedMonoId` missing, then **POST** `/v1/story-drafts/:id/publish/full-learn` (`_postPublishFullLearnHttp`, logs `[M20E update-url]` in debug). |
| 8a | HTTP **400 validation** | `_throwIfNotOk` → `tryParseValidationIssuesFromHttpBody` → `StoryDraftValidationFailedException(issues)` → rethrown from `persistLocalNow` → caught in drawer. |
| 8b | Drawer sheet (post-API) | `showPublishValidationSheet` with `validationErrFl.issues` (after `withoutLegacyFullLearnQuizRangeIssues` in **working tree** only). Title: l10n **`validationPublishSheetTitle`** → **“Before publishing”** (EN). |

**Why POST before the sheet implies backend:** Preflight runs at step 3 **before** step 7. If the user sees the full-learn POST in logs and then the sheet, step 4b occurred and step 8a is the sheet source—not step 4a.

---

## B. Client preflight result

### Entry

- `creator_drawer_publish.dart` → `_preflightCreatorPublish` (lines 50–121).
- Full Learn branch: `runFullLearnPublishPreflight(draft)` (not raw `validateStoryPublishData` in the drawer).

### Pipeline (`creator_publish_preflight.dart`)

1. `withBackfilledImportPromptSourceNote(raw)` — AI import prompt metadata backfill.
2. `storyPublishDataFromCreator(normalized)` — includes `promptSourceNote: effectiveCreatorDraftPromptSourceNote(draft)`.
3. `validateStoryPublishData(data, ValidationMode.fullLearnPublish)` in `lib/core/validation/publish_validation.dart`.
4. **Working tree only:** `_withoutLegacyFullLearnQuizRange(...)` strips `learn.count.quiz.range` from preflight issues.

### Does preflight use HTML or legacy quiz tables?

| Source | Quiz count rules |
|--------|------------------|
| **Git `HEAD`** (`lib/core/validation/publish_validation.dart`) | Legacy `quizLimits` + `quizGlobalHardMax` from `learn_validators.dart` → emits **`learn.count.quiz.range`**. |
| **Working tree** (uncommitted `M` on same file) | `HtmlGeneratorLimits` + `resolveHtmlPromptModeFromSourceNote` → emits **`publish.htmlRules.quizTotalMismatch`** (and related `publish.htmlRules.*`), **no** `learn.count.quiz.range`. |

### Does client preflight pass before backend?

**When preflight passes:** `hasBlockingIssues(pre) == false` → drawer proceeds to `publishFullLearnToDisk()` and the POST chain.

**For an AI N4 `3_5` draft with 13 quizzes:**

- **Working tree preflight:** Expected **pass** (AI selected total = 13).
- **`HEAD` preflight:** Expected **block** on `learn.count.quiz.range` (7–11) **before** any POST—**inconsistent** with “POST then sheet” unless the running app binary was built from working-tree Dart while the server is still on `HEAD` backend.

Debug logging (debug builds only): `[publish_preflight] ... issueCodes=... messageKeys=...` in `creator_drawer_publish.dart` lines 87–97.

---

## C. API request sent or not

### Function that sends `POST .../publish/full-learn`

- `RemoteStoryDraftRepository._postPublishFullLearnHttp` (`lib/features/create/data/remote_story_draft_repository.dart`, ~424–485).
- Called from `saveDraft` when `remotePublishAfterPut == StoryDraftRemotePublishIntent.fullLearn` (~1020–1057).
- Triggered by `StoryCreatorDraftNotifier.persistLocalNow(reason: 'publish_full_learn')` → `publishFullLearnToDisk()`.

### Controller route (backend)

- `POST /v1/story-drafts/:draftId/publish/full-learn`
- `StoryDraftsController.publishFullLearn` → `StoryDraftsService.publishFullLearn` (`nimon-backend/src/modules/story-drafts/story-drafts.controller.ts` lines 112–124).

### Error mapping (client)

- `RemoteStoryDraftRepository._throwIfNotOk`: on status **400**, parses body via `tryParseValidationIssuesFromHttpBody` (`lib/core/validation/validation_issue_from_json.dart`).
- Requires root `message == 'validation_failed'` and `issues: [...]`.
- Throws `StoryDraftValidationFailedException(issues)` (`story_draft_remote_publish_errors.dart`).
- `persistLocalNow` rethrows; `performCreatorDrawerPublish` catches and opens the sheet.

### Sheet after POST: client or backend issues?

| Sheet trigger | `issues` source | When |
|---------------|-----------------|------|
| Preflight (lines 106–110) | `pre.issues` from `runFullLearnPublishPreflight` | **Before** POST |
| Post-publish (lines 259–266) | `validationErrFl.issues` from HTTP **400** parse | **After** POST |

**POST then sheet → backend issues** (parsed JSON), displayed through the same `showPublishValidationSheet` + `validationIssueDisplayMessageLocalized`.

**Working tree note:** Post-API sheet applies `withoutLegacyFullLearnQuizRangeIssues(...)` so legacy quiz range issues from the server would be **hidden** in the UI even if the server still sends them. If the user still sees the 7–11 string, either that filter is **not** in the running build, or the investigation snapshot differs from the device build.

---

## D. Backend validation function used

### Handler

`StoryDraftsService.publishFullLearn` (`nimon-backend/src/modules/story-drafts/story-drafts.service.ts`, ~1166):

```typescript
const learnCheck = validateStoryPublishInput(
  storyPublishInputFromDraftRow(draft),
  ValidationMode.FullLearnPublish,
);
assertNoBlockingValidationIssues(learnCheck);
```

- `assertNoBlockingValidationIssues` → `throwValidationFailed` → Nest `BadRequestException` with `{ message: 'validation_failed', issues }` (`validation-exception.ts`).

### Validation module

- **File:** `nimon-backend/src/common/validation/publish-validation.ts`
- **Function:** `validateStoryPublishInput` (export name; mirrors Flutter `validateStoryPublishData`).
- **Draft mapping:** `storyPublishInputFromDraftRow` includes `promptSourceNote` from DB draft row.

### HTML vs legacy on backend

| Source | Quiz validation |
|--------|-----------------|
| **Git `HEAD`** | Imports **`QUIZ_LIMITS`** from `learn-validation.ts`; uses `QUIZ_LIMITS[jlpt][band]`; emits **`learn.count.quiz.range`** with `min`/`max` from legacy table. |
| **Working tree** (`M` publish-validation.ts) | `quizLimit` / `selectedFullLearnLimits` from `html-generator-limits.ts`; emits **`publish.htmlRules.quizTotalMismatch`** etc.; **no** `learn.count.quiz.range` in file. |

`learn-validation.ts` **`QUIZ_LIMITS` N4 `3_5`:** `{ min: 7, max: 11, absoluteMax: 20 }` — matches observed **7 and 11**.

Legacy tables remain in repo for other validators/tests; **committed publish path** still referenced `QUIZ_LIMITS` at `HEAD`.

### Can backend still emit `learn.count.quiz.range`?

| Deployment / code state | Emits `learn.count.quiz.range` on Full Learn publish? |
|-------------------------|--------------------------------------------------------|
| **Git `HEAD` backend** | **Yes** — when `quizCount` ∉ [min, max] for JLPT×band. |
| **Working tree backend** (uncommitted) | **No** — HTML keys only. |
| **Running local Nest** | Depends which sources are built (dist/ ts-node): if not rebuilt after working-tree edit, may still run old JS. |

### Can backend return the exact English sentence?

Backend returns **structured issues** (`code`, `field`, `messageKey`, `severity`, `params`), not pre-rendered English. The app renders:

- `messageKey: learn.count.quiz.range` → `AppLocalizations.validationLearnCountQuizRange(min, max, actual)` (`lib/l10n/app_en.arb`, `localized_validation_messages.dart` case line ~215).

So the backend “returns” that sentence **indirectly** via `messageKey` + `params`, not a free-text `message` field.

**`publish.htmlRules.quizTotalMismatch`** has **no** ARB/l10n entry; UI would fall back to `validationUnknownFieldMessage` (“Please check this field.”), **not** the 7–11 quiz string. Therefore the observed English copy **identifies** `learn.count.quiz.range`, not HTML publish keys.

---

## E. Exact issue origin

| Field | Value |
|-------|--------|
| **User-visible text** | Quiz count must be between 7 and 11 (you have 13). |
| **messageKey** | `learn.count.quiz.range` |
| **code** (committed) | `learn.count.quiz.range` (same as messageKey in legacy block) |
| **field** | `learn.quiz.count` |
| **params** | `{ min: 7, max: 11, actual: 13 }` (for N4 + `3_5` + 13 quiz rows) |
| **Rule table** | `QUIZ_LIMITS` / `quizLimits` — N4 `3_5` min 7 max 11 |

### Emitter locations (committed `HEAD`)

| Layer | File | Function | Emits? |
|-------|------|----------|--------|
| Flutter (committed) | `lib/core/validation/publish_validation.dart` | `validateStoryPublishData` | **Yes** — `quizLimits[jlpt][band]`, `_block(..., 'learn.count.quiz.range', ...)` |
| Flutter (working tree) | same file | same | **No** (HTML only) |
| Backend (committed) | `nimon-backend/src/common/validation/publish-validation.ts` | `validateStoryPublishInput` | **Yes** — `QUIZ_LIMITS[jlpt][band]` |
| Backend (working tree) | same | same | **No** (HTML only) |

### Display-only (not emitters)

| File | Role |
|------|------|
| `lib/l10n/app_en.arb` | `validationLearnCountQuizRange` template |
| `lib/core/validation/validation_fallback_messages.dart` | English fallback map key `learn.count.quiz.range` |
| `lib/core/validation/localized_validation_messages.dart` | l10n switch case |

### Preflight vs backend for observed POST-then-sheet

| Path | Verdict |
|------|---------|
| **Client preflight** | Unlikely source **if** POST already logged (preflight would block earlier on `HEAD` client too). |
| **Backend response** | **Primary suspect** when POST precedes sheet and copy is 7–11. |
| **Working tree client + legacy server** | Preflight pass (HTML) + POST + server 400 `learn.count.quiz.range` → sheet; filter may hide issue in newest drawer code. |

---

## F. Whether backend deploy is stale

### How the app picks API URL

- `NimonApiConfig.apiBaseUrl` — `--dart-define=NIMON_API_BASE_URL=...` (`lib/core/config/nimon_api_config.dart`).
- **Default (no dart-define):** `http://192.168.11.5:3000` (LAN dev).
- **Documented Render test:** `https://nimon-api-global-test.onrender.com` (`remote_backend_config.dart`, `docs/M20G_RELEASE_APK_GLOBAL_API_VERIFY_REPORT.md`).
- Remote drafts: `NIMON_USE_REMOTE_DRAFTS=true` (default **false**).
- Startup log: `[M20G release-config] apiBase=… remoteDrafts=…` (`lib/main.dart`).

There is **no** in-app backend build SHA / version endpoint found in this investigation. Deploy freshness must be inferred from **git state**, **Render deploy history**, and **behavior** (issue keys in 400 body).

### Git state at investigation

```
## feature/nimon-v1...origin/feature/nimon-v1
 M lib/core/validation/publish_validation.dart
 M lib/features/create/creator_drawer_publish.dart
 M nimon-backend/src/common/validation/publish-validation.ts
```

- **Latest commit on branch:** `b13ad67 fixed_stale_conflict` (publish-validation files last touched in history by `1026e01 detail-fix-code-clean-backend` — **before** HTML migration in working tree).
- **`git show HEAD`:** both Flutter and backend publish validators still contain **`learn.count.quiz.range`** / **`QUIZ_LIMITS`**.
- **Working tree:** HTML migration present locally, **not committed**.

### Is local backend latest but Render old?

**Plausible and consistent with evidence:**

- Local **working tree** backend: HTML rules, would **not** emit 7–11 for 13 quizzes in AI mode.
- **Committed / Render-built from `HEAD`:** legacy `QUIZ_LIMITS` → **would** reject 13 quizzes for N4 `3_5` with `learn.count.quiz.range` (7–11).
- **Phase 5** (M21E): “Wire backend validation to the same values” — parity claimed in M21F for **code**, but **deploy** to Render is a separate step; M20G documents Render URL and APK dart-defines, not automatic redeploy after Phase 5.

### Cannot prove from repo alone

- Whether `nimon-api-global-test.onrender.com` currently runs `HEAD` or a local build.
- Whether the device uses Render vs `192.168.11.5:3000` without logcat `[M20G release-config]` / `[M20E update-url]` host.

**Verification steps (manual):**

1. Logcat: `[M20G release-config] apiBase=...`
2. Capture **400 response body** for failed full-learn publish; inspect `issues[].messageKey`.
3. Compare Render deploy timestamp / commit SHA to branch `HEAD` vs working tree HTML migration.

---

## G. Recommended fix options (do not implement here)

1. **Commit and deploy HTML publish validation** (Flutter + backend) together so `validateStoryPublishInput` / `validateStoryPublishData` match `HtmlGeneratorLimits` and readiness/import (close Phase 5 deploy gap).

2. **Redeploy Render** (`nimon-api-global-test.onrender.com` or whichever URL the APK uses) after backend merge; confirm 400 no longer contains `learn.count.quiz.range` for AI N4 `3_5` / 13 quizzes.

3. **Align prompt mode on server draft row:** Ensure `draft.promptSourceNote` (or equivalent) is persisted on PUT before publish so backend resolves **AI** not default manual; legacy 7–11 is JLPT-band, not prompt-mode, but manual/HTML mismatch was a separate historical bug class.

4. **Temporary client-only mitigation (already in working tree, uncommitted):** `withoutLegacyFullLearnQuizRangeIssues` — hides legacy issues in the sheet but **does not** make publish succeed if the server still returns 400.

5. **Add l10n/fallbacks for `publish.htmlRules.*`** so future HTML mismatches show readable copy (and debug `messageKey` lines distinguish from legacy).

6. **Operational:** Log parsed `issues[].code` / `messageKey` on 400 in debug (drawer already logs preflight keys; extend to API catch).

---

## Appendix — Quick reference map

```
performCreatorDrawerPublish (fullLearn)
  ├─ _preflightCreatorPublish
  │    └─ runFullLearnPublishPreflight
  │         └─ validateStoryPublishData (publish_validation.dart)
  └─ publishFullLearnToDisk
       └─ persistLocalNow('publish_full_learn')
            └─ RemoteStoryDraftRepository.saveDraft(fullLearn)
                 ├─ PUT /v1/story-drafts/:id
                 ├─ [optional] POST .../publish/read-only
                 └─ POST .../publish/full-learn
                      └─ StoryDraftsService.publishFullLearn
                           └─ validateStoryPublishInput → assertNoBlockingValidationIssues
                                └─ 400 validation_failed → StoryDraftValidationFailedException
                                     └─ showPublishValidationSheet ("Before publishing")
```

---

*End of M21I investigation report.*
