# Nimon Add flow — Final E2E verification report (remote + strict)

Date: 2026-04-22  
Scope: Verification only (no UI redesign, no refactors). Focused on Add-flow completeness/stability after adding **remote draft deletion**.

## A) What passed (actually executed)

### Backend + DB services (local)

- **Postgres + Redis**: started via `nimon-backend/docker-compose.yml` (`docker compose up -d`)
- **Backend API**: confirmed reachable on `http://localhost:3000`

### Backend API lifecycle (HTTP E2E, executed against the running backend)

All of the following were executed via real HTTP calls:

- **1. Create draft**
  - `POST /v1/story-drafts` → 200 with `draftId` + `etag`
- **2. Save basics**
  - `PUT /v1/story-drafts/:draftId` with `If-Match` → 200, `etag` increments
- **3. Edit storytelling**
  - Updated `sentences[]` in the same PUT payload → 200
- **4. Edit learn modules**
  - Updated `moduleWorkflowStatuses` (mark completed) → 200
- **5. Processing list loads correctly**
  - `GET /v1/story-drafts` → 200, `items[]` contained the draft id
- **6. Rename from Processing**
  - `PUT /v1/story-drafts/:draftId` changing `basics.title` → 200, title changed
- **8. Continue draft**
  - `GET /v1/story-drafts/:draftId` → 200 after create/save
- **9. Read Only publish**
  - `POST /v1/story-drafts/:draftId/publish/read-only` with `If-Match` → 200, `publishState=reading_only_published`
- **10. Full Learn publish**
  - `POST /v1/story-drafts/:draftId/publish/full-learn` with `If-Match` → 200, `publishState=full_learn_published`
- **7. Delete from Processing**
  - `DELETE /v1/story-drafts/:draftId` → **204 No Content**
  - After delete, `GET /v1/story-drafts/:draftId` → **404** with consistent error envelope
  - After delete, `GET /v1/story-drafts` no longer contained the deleted id

### Flutter repository-level integration (executed)

These were executed via `flutter test` with a running backend:

- `test/remote_add_flow_smoke_test.dart`
  - Create → save → list → RO publish → FL publish (etag enforced)
  - **Result:** PASS

Strict/non-strict honesty for delete was executed via `flutter test` against an intentionally wrong base URL:

- `test/remote_delete_honesty_test.dart`
  - **Strict mode (`--dart-define=NIMON_STRICT_REMOTE_DRAFTS=true`)**
    - remote delete fails → throws
    - local draft + resume meta remain intact (no faked success)
  - **Non-strict mode (strict OFF)**
    - remote delete fails → falls back to local cleanup (draft removed + resume meta cleared)
  - **Result:** PASS (in both strict ON and strict OFF runs)

## B) What failed

- No failures observed in the executed API E2E pass or Flutter repository smoke tests.

## C) Is delete now fully correct?

**Yes, for the intended semantics:**

- **Backend:** delete is supported at `DELETE /v1/story-drafts/:draftId`, scoped to dev owner, returns **204**, and uses the standard API error envelope on failures.
- **Flutter remote repo:**
  - If remote succeeds → clears local cached draft + resume meta (via local repo) + clears stored etag
  - If remote fails and **strict mode ON** → throws; no local cleanup; no faked success
  - If remote fails and **strict mode OFF** → performs local cleanup fallback (explicitly non-strict behavior)

## D) Is the Add flow “done enough” to move on?

**YES (done enough)** for moving to the next major phase, with the caveat that the pass here is:

- **API + repository integration verified**
- **UI click-through not automated/executed in this pass**

## E) Remaining Add-flow-only technical debt (practical)

- **UI-level verification still manual**: This pass did not run an emulator/device UI click-through. The repository and backend contracts look stable, but UI regressions are still possible.
- **Non-strict mode can mask backend outages** (by design): acceptable for resilience, but developers should keep **strict remote** enabled during backend contract work.

## F) Single recommended next major phase

**Add-flow UI end-to-end stabilization + regression harness**, focused on:

- manual checklist run on at least one Android emulator + one desktop target
- expand repository-level tests only when a UI issue is found (don’t preemptively refactor)

