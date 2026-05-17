# M20E — Global published edit stuck in Workspace Editing

## Root cause

Three issues combined on the Render global-test path:

1. **Silent publish skip (Flutter):** `RemoteStoryDraftRepository.saveDraft` could return the **local** draft after a successful PUT when the follow-up `POST …/publish/read-only` or `POST …/publish/full-learn` was skipped (missing `If-Match` etag) or when non-strict mode masked errors. `StoryCreatorDraftNotifier` then treated `saveStatus == saved` as success → **published/success toast** while the server still had `hasUnpublishedCoreChanges: true` → row stayed under Workspace **Editing** and was hidden from the Published tab.

2. **Cancel edit quota (backend):** `DELETE /v1/story-drafts/:id` for discard staging ran `assertCanRevealOnePublishedTabMono` before delete. That incorrectly treated “restore visibility of an **existing** published mono after cancel” like adding a **new** Published-tab slot, so cancel could fail with `quota_exceeded` even when the user was not at the limit.

3. **Cancel delete fallback (Flutter):** `discardPublishedEditStaging` used `deleteDraft`, which on HTTP failure could **delete only the local cache** and still report failure—or the inverse confusion—instead of a single remote `GET` + `DELETE` path without local fallback.

4. **Profile refresh gap:** Successful publish bumped Processing refresh only; **Published pager** was not refreshed until the user switched tabs.

## Endpoints (Flutter, `NIMON_USE_REMOTE_DRAFTS=true`)

| Action | HTTP | Repository |
|--------|------|------------|
| Save staging edits | `PUT /v1/story-drafts/:id` | `RemoteStoryDraftRepository.saveDraft` |
| Update publish (read-only) | `POST /v1/story-drafts/:id/publish/read-only` | chained after PUT when `remotePublishAfterPut: readOnly` |
| Update publish (full learn) | `POST /v1/story-drafts/:id/publish/full-learn` | chained after PUT when `remotePublishAfterPut: fullLearn` |
| Cancel editing / discard staging | `DELETE /v1/story-drafts/:id` | `RemoteStoryDraftRepository.discardPublishedEditStaging` (remote GET guard + DELETE, no local-only delete) |

All use `RemoteBackendConfig.apiBaseUrl` / `NimonApiConfig`.

## Before / after DB state (successful paths)

**After successful update publish (`POST …/publish/*`):**

- `story_drafts.hasUnpublishedCoreChanges` → `false`
- `story_drafts.publishedMonoId` → unchanged (same mono)
- `story_drafts.workspaceState` (API list) → `synced` (not `editing`)
- `published_monos` row updated in place (**no** new row)

**After successful cancel edit (`DELETE` staging draft):**

- `story_drafts` row for staging id → **removed**
- `published_monos` row → unchanged, visible again under `PUBLISHED_MONO_CATALOG_VISIBLE`

## Flutter fixes

- M20E debug logs: `[M20E edit-update]`, `[M20E edit-cancel]`, `[M20E edit-result]`, `[M20E profile-refresh]`, `[M20E update-url]`, `[M20E cancel-url]`
- Publish intent: never return local-only success without completed publish POST; assert clean server DTO (`hasUnpublishedCoreChanges == false`, `publishedMonoId` set)
- `publishReadingOnlyToDisk` / `publishFullLearnToDisk`: fail when remote draft still dirty after save
- On publish success: refresh **Workspace** + **Published** pagers
- Discard: remote GET + DELETE only; surface HTTP errors via `StoryDraftHttpResponseException`

## Backend fixes

- Remove reveal-quota check on cancel-edit staging delete (M20E)
- Non-production logs: `[M20E backend-edit-update]`, `[M20E backend-edit-cancel]`

## SQL verification (Render / Postgres)

```sql
-- Published mono count (owner)
SELECT COUNT(*) AS published_monos_total
FROM published_monos
WHERE "ownerId" = '<owner-uuid>'::uuid AND "trashedAt" IS NULL;

-- Drafts for owner (staging / dirty flags)
SELECT id, "publishState", "publishedMonoId", "hasUnpublishedCoreChanges", "updatedAt"
FROM story_drafts
WHERE "ownerId" = '<owner-uuid>'::uuid
ORDER BY "updatedAt" DESC;

-- Link published mono ↔ source draft
SELECT pm.id AS mono_id, pm.title, pm."trashedAt",
       sd.id AS draft_id, sd."hasUnpublishedCoreChanges", sd."publishState"
FROM published_monos pm
LEFT JOIN story_drafts sd ON sd."publishedMonoId" = pm.id
WHERE pm."ownerId" = '<owner-uuid>'::uuid
ORDER BY pm."updatedAt" DESC;
```

## Tests

- `test/features/create/m20e_published_edit_flow_test.dart`
- `test/features/create/discard_published_edit_staging_test.dart` (updated)
- `nimon-backend` `story-drafts.service.quota.spec.ts` (cancel allowed at visible=30)

## Phone acceptance checklist

- [ ] Run with `NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com` and `NIMON_USE_REMOTE_DRAFTS=true`
- [ ] Edit a published story → Workspace shows **Editing · Previously published**
- [ ] **Update publish** → success toast only if publish completes; item leaves Editing; appears on **Published** tab with updated content
- [ ] **Cancel editing** → staging row removed from Workspace; story visible on Published tab
- [ ] Logs show `[M20E edit-update]` / `[M20E edit-cancel]` with Render `apiBase` and `edit-result status=2xx`

## Run command

```text
flutter run --dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```
