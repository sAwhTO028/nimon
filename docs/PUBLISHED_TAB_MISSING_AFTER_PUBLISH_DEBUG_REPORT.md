# Published Tab Missing After Publish Debug Report

**Date:** 2026-05-02  
**Type:** Read-only code audit (no runtime changes, no migrations, no data deletion).

## 1. Reproduction Assumptions

- **`NIMON_USE_REMOTE_DRAFTS=true`** (remote draft repository active).
- User completes **Read Only** (or Full Learn after RO) publish from the creator flow.
- User expects the story to appear under **Profile → Published** (remote-backed list).
- Issue: row **does not appear** until some later action (e.g. app restart) or **never**.

---

## 2. Publish API Path (Flutter → Nest)

1. **`performCreatorDrawerPublish`** (`creator_drawer_publish.dart`) calls  
   **`StoryCreatorDraftNotifier.publishReadingOnlyToDisk()`** (or Full Learn variant).
2. That sets **`publishState`**, then **`persistLocalNow`** → **`StoryDraftRepository.saveDraft`**.
3. **`RemoteStoryDraftRepository.saveDraft`** (`remote_story_draft_repository.dart`):  
   - Always **`_local.saveDraft` first** (device JSON).  
   - **PUT** `/v1/story-drafts/:id` (content; publish state forced to `'draft'` in PUT payload per implementation).  
   - If local desired state is **`reading_only_published`**, follows with **POST** `/v1/story-drafts/:id/publish/read-only` with **`If-Match`** (and analogous path for full learn).
4. On success, **`publishReadingOnlyToDisk`** also calls **`_bumpProfileProcessingListRefresh()`** (via notifier callback), which **increments `profileProcessingListRefreshProvider`** (`story_creator_provider.dart`).

**Conclusion:** If remote publish **HTTP succeeds**, the backend **`publishReadOnly`** transaction should **create or update `PublishedMono`** (see §3). If those requests **fail**, Flutter may still show “published” locally depending on save path; **Studio would not** get a new mono.

---

## 3. PublishedMono Backend Creation

**`StoryDraftsService.publishReadOnly`** (`story-drafts.service.ts`):

- Loads draft + sentences; validates readiness.
- **Creates** `published_monos` if **`publishedMonoId`** missing; otherwise **updates** the same row.
- Snapshots core into **`published_monos.content`** (includes **`sourceDraftId`** in nested structure used by list mapping).
- Updates **`story_drafts`**: `publishState`, `publishedMonoId`, **`hasUnpublishedCoreChanges: false`**, version bump.

**Answer to Q1:** **Yes**, on successful **`publishReadOnly`**, **`PublishedMono`** is **created or updated** in Postgres.

---

## 4. PublishedMono List Endpoint

- **Route:** **`GET /v1/published-monos`** (`published-monos.controller.ts`).
- **Query:** optional **`limit`** only (controller); other query keys from Flutter are **ignored** by Nest (no harm expected).
- **Service:** `PublishedMonosService.listPublishedMonos` filters  
  **`where: { ownerId: getDevOwnerId() }`** — **no** extra status filter; returns **`orderBy: { updatedAt: 'desc' }`**, **`take: limit`**.

**Answer to Q3:** The list is **owner-scoped only** (dev owner from **`process.env.DEV_OWNER_ID`** or default UUID). It does **not** exclude “new” rows by status. **If the row exists** with matching **`ownerId`**, it should be returned.

**Answer to Q2:** Profile Published tab (remote mode) ultimately uses **`RemotePublishedMonoRepository.fetchPage`** → **`GET /v1/published-monos`** with query from **`PageRequest.toQueryParameters()`** (includes **`limit`**, **`sort`**; backend uses **`limit`**).

---

## 5. Flutter Published Repository

**`RemotePublishedMonoRepository.fetchPage`**:

- Parses JSON **`items`** array; maps each object with **`_listItemFromMap`** (`remote_published_mono_repository.dart`).
- Expects **`id`**, **`ownerId`**, **`title`**, etc. **`sourceDraftId`** is **optional** in JSON; backend supplies it via **`publishedMonoListItemFromRow`** reading **`content.sourceDraftId`** (`published-mono-common.ts`).

**Answer to Q4:** List DTOs include **`id`** (mono id) and **`sourceDraftId`** when present in **`content`**. Profile maps list items with **`isBackendPublished: true`** (`profile_screen.dart` **`_mapPublishedDtosToLooseItems`**).

**Non-strict mode:** On HTTP/parse failure, **`fetchPage` returns `PageResult.empty()`** without rethrowing — the Published pager can show **no items** with **no visible error** if **`strictRemoteDrafts`** is false.

---

## 6. Profile Published Pager

**`ProfilePublishedMonoPager`** (`profile_published_mono_pager.dart`):

- **`loadFirstPage`** / **`refresh`** call **`_repo.fetchPage(PageRequest(limit: profilePageLimit))`**.
- **No automatic link** to **`profileProcessingListRefreshProvider`** (that provider is **not** listened to here).

**Answer to Q5:** **After publish**, **`profileProcessingListRefreshProvider`** is bumped, but **`ProfileScreen`** only uses that listener to **`profileWorkspaceDraftPagerProvider.notifier.refresh()`** — **not** **`profilePublishedMonoPagerProvider`**.  
**`loadFirstPage`** on the Published pager runs in **`ProfileScreen.initState`** (once per widget lifetime when `useRemoteDrafts` is true). **Switching to the Published tab** does **not** call **`loadFirstPage`** or **`refresh`** on the Published pager ( **`_onTabChanged`** only refreshes **Workspace** when tab index **== 1**).

**Answer to Q9 / Q8:** **Yes — a refresh/invalidation gap is likely:** the Published mono pager is **not** refreshed when publish completes, only the **Workspace** pager is (via **`profileProcessingListRefreshProvider`**). **`storyCreatorDraftProvider`** does not touch **`profilePublishedMonoPagerProvider`**.

---

## 7. ProfileScreen Hide / Filter Logic

**`_hidePublishedItemForWorkspaceEditing`** (`profile_screen.dart`):

- If **`it.isBackendPublished`** → **never hide**.
- Hides only **non-backend** (“loose” / mock) rows when **`sourceDraftId`** is in the Workspace **Editing** id set.

**Answer to Q6 / Q7:** **Backend** published rows (**`isBackendPublished: true`**) are **not** hidden by this rule. **`sourceDraftId`** is used for **Edit** resume and duplicate-hide for **non-backend** rows only.

**Loading placeholder:** **`_publishedLooseRowsForUi`** returns **`_uploadedLooseItems`** (mock) while **`pager.isInitialLoading && pager.items.isEmpty && pager.error == null`**, which can **mask** an empty server list until loading finishes — worth noting for UX confusion, not for hiding a real backend row after load completes.

---

## 8. Refresh / Invalidation After Publish

| Signal | What refreshes |
|--------|------------------|
| **`profileProcessingListRefreshProvider`++** | **`profileWorkspaceDraftPagerProvider.refresh()`** only ( **`ProfileScreen` listener**). |
| **`StoryCreatorAddTabScreen`** | Listens to same provider → **Add tab draft summary** refresh only. |
| **Navigate to Published tab** after publish | **`openPublishedTabForRouter`** changes route query; **does not** call **`profilePublishedMonoPager.refresh()`**. |
| **Tab change to Published (index 0)** | **`_onTabChanged`** does **not** refresh Published pager (only Workspace at index **1**). |

**Answer to Q8:** **Yes — missing invalidation** of **`profilePublishedMonoPagerProvider`** after successful publish (and on focusing Published tab) is consistent with the code.

---

## 9. Most Likely Root Cause

**Primary (UI state):** **`profilePublishedMonoPagerProvider`** is **loaded once** in **`ProfileScreen.initState`** and is **not** refreshed when **`profileProcessingListRefreshProvider`** fires after publish. If the user had already opened Profile earlier (or the pager previously fetched an **empty** list), the Published list **stays stale** until **`refresh` / `loadFirstPage`** runs again (e.g. **new** **`ProfileScreen`** instance after **app restart**, or manual code path not present today).

**Secondary (environment):** **`DEV_OWNER_ID`** (backend `.env`) **must match** **`NIMON_DEV_OWNER_ID`** (Flutter `dart-define`). If they differ, **`GET /v1/published-monos`** uses backend owner **A** while drafts/monos might be stored under **B** → **empty list** regardless of refresh. **Restart alone does not fix** owner mismatch.

**Tertiary:** Silent failure in **`fetchPage`** when **`strictRemoteDrafts`** is false → empty **`PageResult`** without surfacing error.

---

## 10. Recommended Fix (for a future implementation pass)

1. **After successful remote publish**, call **`ref.read(profilePublishedMonoPagerProvider.notifier).refresh()`** (or **`loadFirstPage`**) alongside the existing processing refresh — e.g. from the same place that bumps **`profileProcessingListRefreshProvider`**, or inside the **`profileProcessingListRefreshProvider`** listener (also refresh Published pager when `useRemoteDrafts`).
2. Optionally **refresh Published pager** when the user **lands on the Published tab** (index **0**) or when **`ProfileScreen`** becomes visible again after publish navigation.
3. **Verify** **`DEV_OWNER_ID`** and **`NIMON_DEV_OWNER_ID`** alignment in dev docs / run scripts.
4. In debug, enable **`NIMON_STRICT_REMOTE_DRAFTS=true`** to surface **`fetchPage`** failures instead of silent empty lists.

---

## 11. Exact Cursor Prompt For Fix

> Fix Profile Published tab not updating after remote publish without app restart. In `ProfileScreen` / providers: when `profileProcessingListRefreshProvider` increments (or immediately after successful `publishReadingOnlyToDisk` / `publishFullLearnToDisk` when `RemoteBackendConfig.useRemoteDrafts` is true), also call `profilePublishedMonoPagerProvider.notifier.refresh()` (or `loadFirstPage`). Optionally refresh when switching to Published tab (PageView index 0). Add a widget test or integration test: publish then assert published pager items include the new mono id. Do not change backend contracts. Document `DEV_OWNER_ID` vs `NIMON_DEV_OWNER_ID` in README if missing.

---

## Appendix — Direct Answers

| # | Question | Answer |
|---|----------|--------|
| 1 | PublishedMono created on backend when publish succeeds? | **Yes** via **`publishReadOnly`** / **`publishFullLearn`** transactions. |
| 2 | Which endpoint does Profile Published call? | **`GET /v1/published-monos`** via **`RemotePublishedMonoRepository.fetchPage`**. |
| 3 | List filter exclude new row? | **Only by `ownerId`** — must match **`getDevOwnerId()`**. No status filter. |
| 4 | List DTO include `sourceDraftId` / `id`? | **`id`** always; **`sourceDraftId`** from **`content.sourceDraftId`** in mapper. |
| 5 | Pager `loadFirstPage`/`refresh` after publish? | **Not automatically** — **gap**. |
| 6 | Hide/filter hide backend rows? | **No** for **`isBackendPublished`**. |
| 7 | Backend row `isBackendPublished` / `sourceDraftId`? | UI sets **`isBackendPublished: true`** for API-mapped rows; **`sourceDraftId`** from API when present. |
| 8 | Cache/provider invalidation missing? | **Yes** for **Published** pager vs **Workspace** refresh. |
| 9 | Restart makes it appear → what refresh missing? | **Published pager reload** (**`refresh`/`loadFirstPage`**) when Profile remounts or state resets — consistent with **stale pager** theory. |
| 10 | Restart does not help → what issue? | **Owner mismatch**, **publish never hit backend**, or **silent `fetchPage` error** (non-strict). |

---

### Output summary (executive)

| Item | Finding |
|------|---------|
| **PublishedMono created by backend?** | **Yes**, on successful Nest publish endpoints. |
| **Published list endpoint for Profile?** | **`GET /v1/published-monos`**. |
| **Profile pager refresh after publish?** | **No** — only **Workspace** pager listens to **`profileProcessingListRefreshProvider`**. |
| **Hide/filter hiding real rows?** | **Unlikely** — backend rows are **not** hidden by Editing logic. |
| **Most likely root cause** | **Stale `profilePublishedMonoPagerProvider`** + **no refresh** on publish; secondarily **owner id mismatch** or **silent fetch errors**. |
| **Recommended fix** | **Refresh Published pager** when processing refresh fires or after successful publish; align **dev owner** ids; use **strict remote** when debugging. |
