# Nimon Add flow — Remote backend E2E smoke test (V1)

Date: 2026-04-21  
Scope: Add flow remote persistence + publish via `RemoteStoryDraftRepository` (no UI redesign).

---

## A. Test setup used

- **Backend**
  - Postgres/Redis: `docker compose up -d` (from `nimon-backend/`)
  - API: `pnpm run start` (NestJS on `http://localhost:3000`)
- **Flutter**
  - Repository-level smoke test (no UI automation): `flutter test test/remote_add_flow_smoke_test.dart`
  - Remote repo base URL used: `http://localhost:3000`

---

## B. Remote mode verification

Remote path was exercised by directly instantiating `RemoteStoryDraftRepository` and calling:
- `createNewDraft()`
- `saveDraft() / saveDraftNow()`
- `listDraftIds()`

These calls performed real HTTP operations against the running Nest backend.

---

## C. What worked

- **Create draft** (remote)
  - `POST /v1/story-drafts` returned a server `draftId` and `etag`
- **Basics save** (remote)
  - `PUT /v1/story-drafts/:draftId` succeeded with `If-Match`
- **Story sentence edit save** (remote)
  - PUT with at least one sentence succeeded
- **Processing list** (remote)
  - `GET /v1/story-drafts` returned the created draft id in `items[]`
- **Read-only publish** (remote)
  - `POST /v1/story-drafts/:draftId/publish/read-only` succeeded with `If-Match`
- **Full-learn publish** (remote)
  - After marking all module workflow statuses as `completed`, `POST /v1/story-drafts/:draftId/publish/full-learn` succeeded with `If-Match`
- **Local persistence fallback remains intact**
  - After remote operations, the draft was also written into local storage (so resume meta remains local-only)

---

## D. What failed

No failures in the repository-level smoke pass.

---

## E. Failures attribution (backend-side vs app-side)

N/A (no failures observed).

---

## F. What must be fixed next

### 1) Avoid “silent fallback” masking remote failures

The current `RemoteStoryDraftRepository` behavior intentionally falls back to local storage on network errors in several methods. This is good for offline safety, but can be misleading during remote-mode development because:
- Remote failures may appear as “success” if the local fallback path runs.

Recommended next step:
- Add an explicit **“strict remote mode”** option (dev-only) that fails loudly instead of falling back.

### 2) UI-level verification (manual)

This smoke pass validated repository + backend integration, not the full UI interaction. Next:
- Run the app in remote mode (`--dart-define=NIMON_USE_REMOTE_DRAFTS=true`) and manually click through Add flow screens.

---

## G. Final verdict

**Usable for continued development? YES** (repository ↔ backend contract and `If-Match`/`etag` flow works end-to-end in a smoke pass).

