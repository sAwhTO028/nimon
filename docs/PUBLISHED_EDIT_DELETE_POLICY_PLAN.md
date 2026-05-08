# Published Edit Delete Policy Plan

**Type:** Plan / audit only — **no application code changes** and **no migrations** in this document.  
**Context:** M5d/M5e already implement **edit-in-progress hiding** via `StoryDraft.hasUnpublishedCoreChanges` ([M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md), [M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md](M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md)). **Delete / unpublish / trash** behavior is **not** fully specified in product or backend.

**References:** [M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md), [M6E_RELEASE_CHECKLIST.md](M6E_RELEASE_CHECKLIST.md), `nimon-backend/prisma/schema.prisma`, `nimon-backend/src/modules/published-monos/**`, `nimon-backend/src/modules/story-drafts/**`, `nimon-backend/src/modules/mono-feed/**`, `lib/features/profile/profile_screen.dart`, `lib/features/create/creator_resume_draft.dart`, `lib/features/create/story_creator_provider.dart`, `lib/features/mono/mono_screen.dart`, `lib/ui/bottom_sheets/mono_story_options_sheet.dart`.

---

## 1. Executive Summary

**Bookmark, react, and share (M7)** assume a **stable catalog identity** for a published mono: users save and share **IDs** that should not **flip between visible, missing, and zombie states** without clear rules.

**Edit visibility** is already **defined and implemented** (hide while dirty; restore on republish). **Delete** is **not**: today, **draft deletion** can leave **`PublishedMono` rows orphaned** in the database, and **public catalog visibility** can **reappear** because M5d only hides when a **linked** draft has `hasUnpublishedCoreChanges === true` — **no linked draft** means the mono is **visible** again ([published-mono-visibility.ts](nimon-backend/src/modules/published-monos/published-mono-visibility.ts)). Mono reader **Delete** is explicitly **“Coming soon.”**

This plan **locks product intent** for **edit** (confirm M5) and **proposes V1 delete/trash** so engineering can implement **before or in parallel with M7**, without contradictions.

---

## 2. Current Edit Visibility Implementation

### M5d (backend)

- **Predicate:** `PUBLISHED_MONO_CATALOG_VISIBLE` — exclude `published_monos` where **any** linked `StoryDraft` has **`hasUnpublishedCoreChanges === true`**.
- **Surfaces:** `GET /v1/mono/feed`, `GET /v1/mono/:id`, `GET /v1/published-monos`, `GET /v1/published-monos/:id` all use the same visibility (owner detail returns **404** when hidden — conservative).
- **Republish:** `publishReadOnly` / `publishFullLearn` set **`hasUnpublishedCoreChanges: false`** → row **reappears**.
- **Does not delete** `PublishedMono` while editing.

### M5e (Flutter)

- **Refresh:** `bumpProfileCatalogSurfacesRefresh` / `profileProcessingListRefreshProvider` after resume, remote save on published drafts, and publish success — **Workspace**, **Published**, **Mono** (when mounted) refetch.
- **404 UX:** `PublishedMonoHiddenWhileEditingException` — *“This story is being edited and will return after republish.”*

---

## 3. Desired Edit Behavior Standard

| Scenario | Expected product behavior |
|----------|---------------------------|
| **Edit from Published** | Open creator on linked draft; after save with unpublished changes → **Mono Home** hides story; **Profile → Published** hides; **Workspace** shows row as **Editing** (or equivalent). |
| **Edit from Mono reader** | Same as above once user enters creator and saves dirty state (remote drafts). |
| **Save edit** | Backend sets **`hasUnpublishedCoreChanges: true`** on linked draft; M5d hides catalog; M5e refreshes lists. |
| **Workspace Editing** | Single source of truth for in-progress published edits; chips/copy already oriented to **“Editing • Previously published”** in profile workspace UI. |
| **Published hidden** | Owner list omits row (API); opening old id → **404** + friendly copy. |
| **Mono feed hidden** | Feed omits row; detail **404** + friendly copy. |
| **Republish** | Clears dirty flag → row **restores** everywhere; refresh signals already wired. |

**This standard matches current M5d/M5e implementation** — treat as **frozen** unless a deliberate product change is approved.

---

## 4. Current Delete Behavior Audit

### Mono reader (`lib/ui/bottom_sheets/mono_story_options_sheet.dart`)

- **Delete** action shows **SnackBar: “Delete - Coming soon”** — **no API call**, no local state change for catalog.

### Profile → Workspace (`lib/features/profile/profile_screen.dart`)

- **Processing sheet** includes **Delete** → `storyDraftRepositoryProvider.deleteDraft(item.id)` then `syncIfDraftWasRemovedExternally`, `profileWorkspaceDraftPagerProvider.removeDraftById`.
- **Local-first row delete** (`_delete`): dialog **“Delete local draft?”** / **“Delete from this device”** → same repository **`deleteDraft`** + local pager removal.

### Backend (`DELETE /v1/story-drafts/:draftId`)

- **`StoryDraftsService.deleteDraft`:** `prisma.storyDraft.deleteMany({ where: { id, ownerId } })` — **hard delete** of the **draft row** only ([story-drafts.service.ts](nimon-backend/src/modules/story-drafts/story-drafts.service.ts)).
- **No** `DELETE` on **`published-monos`** controller ([published-monos.controller.ts](nimon-backend/src/modules/published-monos/published-monos.controller.ts) — **GET only**).

### PublishedMono orphan edge case

- If the deleted draft was the **only** link carrying `publishedMonoId`, the **`PublishedMono` row remains** in the DB.
- **M5d visibility:** with **no** linked draft having `hasUnpublishedCoreChanges`, the mono can become **catalog-visible again** — potentially **stale** relative to user expectation (“I deleted my story”).
- **Risk:** **high** for product trust; must be resolved by **delete policy** (below).

### List refresh

- Workspace path removes draft from **pager** client-side; **Published / Mono** may **not** automatically refetch on draft-only delete unless another signal fires — **verify** during P0 smoke.

---

## 5. Delete Policy Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Permanent delete immediately** | `DELETE` removes `PublishedMono` + draft + dependents in one transaction | Simple mental model; catalog immediately clean | **Irreversible**; accidental taps painful; legal/audit gaps |
| **B. Soft delete / Trash** | Flag **`trashedAt`** (or `deletedAt`) on `PublishedMono` (and/or draft); hide from all public/owner lists except Trash | **Recoverable**; matches user expectations for “delete” in consumer apps | Requires **restore**, TTL or **permanent delete** later; more queries |
| **C. Unpublish only, keep draft** | Remove from catalog but keep draft as workspace-only “unpublished” | Preserves editor content | **Naming** confusing vs “delete”; still need catalog tombstone |
| **D. Archive** | Visible to owner only under “Archived”; not in main feed | Good for creators who want history | Heavier UX; overlaps with Trash unless differentiated |

---

## 6. Recommended V1 Policy

1. **User-facing primary action:** **“Move to Trash”** (not “Delete forever” on first tap).
2. **Effect:** **`PublishedMono` immediately hidden** from **Mono feed**, **Profile Published**, **public detail**; **not** shown in default Workspace as active publishing — optional **Trash** section lists trashed monos + linked draft summary.
3. **Draft:** Keep **recoverable** — either **soft-delete both** with restore pairing, or **unlink + retain draft** under Trash metadata (implementation detail in §7).
4. **Permanent delete:** Only inside **Trash** with **second confirmation** (“Permanently delete — cannot be undone”).
5. **Edit-while-published (M5)** remains unchanged: **dirty draft** hides catalog **without** requiring Trash (orthogonal concern).

---

## 7. Backend State Model

### Option 1 — **Timestamps on `PublishedMono` (recommended minimal)**

- Add **`trashedAt DateTime?`** on **`PublishedMono`**.
- **Catalog visibility** becomes: `PUBLISHED_MONO_CATALOG_VISIBLE` **AND** `trashedAt == null`.
- **Restore:** `trashedAt = null` (and re-check M5 dirty rules).
- **Permanent delete:** hard `delete` `PublishedMono` (and policy for linked `StoryDraft` — cascade or explicit delete in transaction).

**Draft handling:** On “move to trash,” either:

- **(1a)** Set `trashedAt` on mono only; keep draft linked → Workspace shows Trash entry via **`GET /v1/story-drafts?includeTrashed=`** or separate **`GET /v1/trash`**, **or**
- **(1b)** Also set a **`trashedAt`** or **`workspaceHidden`** on draft — **second column** on `StoryDraft`.

**Migration:** **Yes** — Prisma migration adding nullable `trashedAt` (and optional draft flag).

### Option 2 — **PublishState / workspaceState only**

- Overload **`PublishState`** or add **`workspaceState`** enum — **risky** overlap with existing **`draft` / `reading_only_published` / `full_learn_published`** and M5 dirty flag; easy to confuse **“editing”** vs **“trashed”**.

### Option 3 — **New status enum on `PublishedMono`**

- e.g. `catalogStatus: active | hidden_editing | trashed` — **clearer** than timestamps but **more** migration + backfill logic.

**Recommendation:** **Option 1** — **`trashedAt` on `PublishedMono`** first; extend with **`StoryDraft.trashedAt`** only if workspace queries need it without joining mono.

---

## 8. API Design

| Method | Path | Purpose |
|--------|------|---------|
| **POST** | `/v1/published-monos/:id/trash` | Soft-delete: set `trashedAt = now()`; idempotent |
| **POST** | `/v1/published-monos/:id/restore` | Clear `trashedAt`; 404 if not owner / not trashed |
| **DELETE** | `/v1/published-monos/:id/permanent` | Hard delete (optional **P4**); body or query **confirm** token; transaction with draft policy |
| **GET** | `/v1/me/trash` or query `?trashed=1` on published list | List trashed monos for owner |

**Draft-only `DELETE /v1/story-drafts/:id`:** Should be **disallowed** or **auto-trash mono** when draft is the **primary** link to a published mono — **policy decision** to avoid orphan monos (§4).

---

## 9. Query Visibility Rules

| API | Rule |
|-----|------|
| **`GET /v1/mono/feed`** | `PUBLISHED_MONO_CATALOG_VISIBLE` **∧** **`trashedAt == null`** |
| **`GET /v1/mono/:id`** | Same; **404** if trashed or hidden-by-edit |
| **`GET /v1/published-monos`** | Owner **active** list: **`trashedAt == null`** + M5 visibility |
| **`GET /v1/published-monos/:id`** | Same as today + trashed check |
| **`GET /v1/story-drafts` (workspace)** | **Exclude** trashed-linked drafts from default pager **or** show under **Trash** tab only |
| **Trash list** | **`trashedAt != null`** + owner |

**404 messaging:** Distinguish **hidden while editing** vs **trashed** vs **permanently gone** (optional refinement for Flutter copy).

---

## 10. Flutter UX Plan

| Topic | Plan |
|-------|------|
| **Delete confirmation** | First step: **“Move to Trash?”** + consequence line (“Hidden from your profile and Mono.”). |
| **Permanent delete** | Trash screen: **“Permanently delete?”** + second confirmation. |
| **Undo / Restore** | **Restore** button on Trash row; optional **Snackbar “Moved to Trash”** with **Undo** calling restore API. |
| **Workspace** | **Trash** section or tab; do not mix with **Editing** without clear labels. |
| **Profile Published** | Refetch after trash/restore (`bumpProfileCatalogSurfacesRefresh`). |
| **Mono feed** | Refetch / cache clear (same patterns as M5e). |
| **404 copy** | Extend beyond M5e: **trashed** vs **editing** vs **gone** if backend exposes **error code** (optional). |

**Mono options sheet:** Replace **“Coming soon”** with **Move to Trash** when wired.

---

## 11. Tests Needed

### Backend

- Trash → excluded from feed + published list; included in trash list.
- Restore → visible again (respect M5 dirty after restore if draft edited).
- Permanent delete → 404 on all routes.
- **Regression:** M5d dirty hiding still works when `trashedAt` null.
- **Draft delete:** Either **cascades to trash** or **rejects** if would orphan mono — spec tests per chosen rule.

### Flutter

- Repository mapping + error codes.
- Widget: confirmation flows; refresh provider fired after trash.
- Integration: trash from Profile → disappears from Published + Mono.

---

## 12. Recommended Implementation Split

| Phase | Scope |
|-------|--------|
| **P0** | **Manual + automated smoke:** confirm M5 edit hide/restore end-to-end ([M6E](M6E_RELEASE_CHECKLIST.md) matrix); document **draft-delete orphan** behavior as **known gap** until P1. |
| **P1** | Backend **`trashedAt`**, trash/restore endpoints, visibility in feed + published + public detail; **draft delete policy** (reject or auto-trash). |
| **P2** | Flutter **Move to Trash** + **restore** + refresh wiring; replace Mono sheet placeholder. |
| **P3** | **Trash screen** + permanent delete second gate. |
| **P4** | **Permanent delete** hardening, retention TTL, audit log (optional). |

---

## 13. Exact Cursor Prompt For P0 Edit Visibility Smoke

```text
You are a QA-minded Flutter + NestJS engineer on Nimon.

Task: P0 — Verify existing M5 published edit visibility (no feature code changes unless a blocking bug is found and explicitly approved).

Read: docs/M5D_BACKEND_PUBLISHED_EDIT_VISIBILITY_REPORT.md, docs/M5E_FLUTTER_PUBLISHED_EDIT_VISIBILITY_REPORT.md, docs/M6E_RELEASE_CHECKLIST.md.

Steps:
1. Run backend + Flutter with remote drafts and remote mono feed flags per docs/DEV_RUN_COMMANDS.md.
2. Publish a story (read-only or full-learn); confirm it appears on Mono Home and Profile Published.
3. Open creator from Published or Workspace; make a core edit; save so hasUnpublishedCoreChanges becomes true on the server.
4. Confirm: Mono Home no longer shows the story; Profile Published list no longer shows it; Workspace shows Editing.
5. Confirm: GET /v1/mono/:id and GET /v1/published-monos/:id return 404 with catalog-hidden behavior; Flutter shows friendly “editing” copy if opening detail.
6. Republish; confirm story reappears on Mono + Published.
7. Optional: From Workspace, trigger deleteDraft on a published-linked draft; observe whether PublishedMono reappears in feed (document as orphan risk per PUBLISHED_EDIT_DELETE_POLICY_PLAN.md §4).

Deliver: short markdown test note under docs/ or a comment in the team channel — pass/fail per step, environment, and any anomaly.
```

---

## 14. Exact Cursor Prompt For P1 Backend Trash

```text
You are a senior NestJS + Prisma engineer on nimon-backend.

Task: P1 — Published mono soft-delete (Trash) per docs/PUBLISHED_EDIT_DELETE_POLICY_PLAN.md §6–9.

Constraints:
- Add Prisma field trashedAt (DateTime?) on PublishedMono; user runs migrations.
- Extend PUBLISHED_MONO_CATALOG_VISIBLE usage: all catalog queries also require trashedAt == null.
- Do NOT remove M5d dirty-draft hiding; compose predicates (trashed OR dirty-hidden).
- JwtAuthGuard (or existing owner guard) on mutations.

Goals:
1. POST /v1/published-monos/:id/trash — set trashedAt = now(); idempotent; 404 if not owner or unknown id.
2. POST /v1/published-monos/:id/restore — clear trashedAt when trashed; 400 if not trashed.
3. GET /v1/published-monos?trashed=true (or separate /v1/me/trash) — list trashed rows for owner (paged).
4. StoryDraft delete policy: choose one — (A) DELETE draft forbidden when linked PublishedMono exists and not trashed, or (B) deleting draft auto-calls trash on linked mono in same transaction. Document in controller.
5. Tests: published-monos + mono-feed services for visibility; trash/restore flows.

Commands: prisma migrate, jest, nest build.

Deliver: minimal API surface; DTO notes for Flutter.
```

---

## Output summary

| Question | Answer |
|----------|--------|
| **Edit visibility already implemented?** | **Yes** — M5d + M5e match the **Desired Edit Behavior Standard** (§3). |
| **Edit visibility smoke still needed?** | **Recommended P0** — regression smoke before M7 and before trash work; **§13** prompt. |
| **Current delete behavior** | Mono **Delete: Coming soon**; Workspace **Delete** calls **`DELETE /v1/story-drafts/:id`** (hard delete draft only); **no** published-mono DELETE; **orphan `PublishedMono` can reappear** in catalog (§4). |
| **Recommended delete policy** | **Soft delete / Trash** on **`PublishedMono`** (`trashedAt`); **hide immediately** from Mono + Published; **restore** + **permanent delete** from Trash with confirmation (§6). |
| **Migration needed?** | **Yes** when implementing P1 — at minimum **`trashedAt`** on **`PublishedMono`**; optional draft-side flag if queries require it (§7). |
| **First implementation step** | **P0 smoke** (§12–§13) to baseline M5; then **P1 backend trash** (§14) before relying on **M7** social IDs. |
