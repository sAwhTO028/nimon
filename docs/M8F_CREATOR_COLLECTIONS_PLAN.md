# M8f Creator Collections Plan

**Document type:** product / architecture plan and audit only.  
**No application code changes** and **no database migrations** are performed as part of authoring this document.

**References:** `docs/M8C_COLLECTIONS_DECISION_SPEC.md`, `docs/M8_DISCOVERY_AND_POLISH_CLOSEOUT_REPORT.md`, `docs/M8_PROFILE_TRASH_UI_REAL_STATS_FIX_REPORT.md`, `lib/features/profile/profile_screen.dart`, `lib/features/profile/public_profile_screen.dart`, `nimon-backend/prisma/schema.prisma`, `nimon-backend/src/modules/published-monos/**`, `nimon-backend/src/modules/users/**`.

---

## 1. Executive Summary

**Learner Saved collections (M8c)** remain **deferred for V1**: bookmarks are a **flat list** backed by `MonoBookmark` and `GET /v1/me/bookmarks`. Named folders/tags for **learners saving stories** are still a **post-V1 fork** per `M8C_COLLECTIONS_DECISION_SPEC.md`.

**Creator public collections (M8f — new)** are a **different feature**: the **publisher** groups **their own published monos** into **curated lists** visible on **public profile** (alongside “all monos”). This is **not** the learner Saved library; it does not replace `MonoBookmark` semantics.

| Dimension | Learner Saved | Creator collections (proposed) |
|-----------|----------------|-------------------------------|
| Actor | Signed-in learner | Creator (owner of `PublishedMono`) |
| Data | `MonoBookmark` → flat saves | New tables linking owner → collections → `publishedMonoId` |
| Primary surface | Profile → Saved tab | Owner Published management + Public Profile → Collections tab |
| V1 status | Ship flat Saved | **New scope** — requires schema + APIs + Flutter |

---

## 2. Current UI Audit

### Profile Published — multi-select and bulk actions

**Location:** `_FolderGroupList` inside Profile → **Published** tab (`profile_screen.dart`).

- **Selection mode:** Row overflow / “…” opens a sheet with **Multi Select** and **Add to collection** (Add to collection shows **“Coming soon”** snackbar).
- **Bulk bar:** When `_selecting` is true on the **Monos** filter, `_buildFilterOrSelectionBar` shows **“N selected”**, **Cancel**, and a primary button:
  - **Saved section:** label **Unsave** → `onBulkUnsaveLoose`.
  - **Published section:** label **Delete** → `onBulkDeleteLoose`.
- **Published + remote drafts (`useRemoteDrafts`):** `onBulkDeleteLoose` calls `profilePublishedMonoPagerProvider.notifier.removeItemsByIds(ids)` — **client-side list removal only** in the pager state (does **not** replace server-side trash/permanent-delete flows by itself from this snippet).
- **Published + mock/local:** bulk removes loose items from `_uploadedLooseItems` in memory.

**Implication for M8f:** Product wants **no bulk Delete** on Published multi-select; that slot becomes **Add to collection** (once backend exists). Per-item **Move to Trash** / story options remain the integrity path for removal.

### Story options sheet / per-item actions

- **Remote Published:** Readers opened from Profile Published use `/mono-reader` with owner-oriented origins (see existing reader wiring).
- **Trash:** Dedicated **Trash** screen and APIs for trashed monos — orthogonal to “collections” but must stay consistent for visibility rules (§7).

### Public Profile — Monos / Collections

**Remote `userId` profile (`_useRemoteProfile`):** Success UI is a **single scrollable profile** with a **Monos** section (creator feed page), hero header, etc. There is **no** live **Collections** tab wired to backend data in this path today.

**Legacy mock profile (`legacyDemoCreatorProfileActive`, `?creator=` debug):** **NestedScrollView** with **TabBar**: **Monos** (`_PublicMonoTab`) and **Collections** (`_PublicCollectionsTab`). Collections use **`PublicProfileBundle.folders`** — **mock/demo folders**, not learner Saved and not server-backed creator collections.

### Existing mock/demo collection UI (owner Profile)

- Published/Saved tabbed folder UI uses **`_StoryFolder`**, `_ProfileFolderFilter` (Monos vs Collections), **CollectionListRow**, folder detail **`_FolderDetailScreen`**.
- When **remote Saved** is on, Saved tab swaps to **`_ProfileSavedRemoteTab`** (flat list); mock folders are bypassed for Saved.
- Demo bookmark folders in Mono (`mono_screen.dart`) remain **UX exploration**, not creator collections.

---

## 3. Product Decision

1. **Remove bulk Delete** from Profile **Published** multi-select toolbar (replace with **Add to collection** once APIs exist; until then **disabled / “Coming soon”** or hidden — see M8f1 prompt §10).
2. **Keep per-item delete path:** **Move to Trash** / story options / Trash screen / permanent delete policy unchanged in intent.
3. **Multi-select primary action (Published):** **Add selected published monos to a creator collection** (create collection + pick collection + bulk add).
4. **Public profile:**
   - **Monos tab:** **All** creator published content (existing feed/list semantics; pagination as today).
   - **Collections tab:** Lists **creator-defined collections**; each opens detail listing member monos (public visibility rules TBD).
5. **Saved tab bulk Unsave** for learners may remain **unless product wants parity review** — out of scope for “creator collections” except to avoid naming collisions in UI copy (“Collections” on learner vs creator surfaces).

---

## 4. Data Model Proposal

New tables (names illustrative — align with Prisma naming on implementation):

### `CreatorMonoCollection` (or `PublisherCollection`)

| Field | Notes |
|-------|--------|
| `id` | UUID PK |
| `ownerId` | FK → `User.id` (creator) |
| `title` | Display name |
| `description` | Optional |
| `coverImageUrl` | Optional |
| `visibility` | `public` / `private` (product: private = owner-only manage, hidden from public profile?) |
| `sortOrder` | Optional manual ordering among collections |
| `createdAt` / `updatedAt` | Standard |

### `CreatorMonoCollectionItem`

| Field | Notes |
|-------|--------|
| `collectionId` | FK → collection |
| `publishedMonoId` | FK → `PublishedMono.id` |
| `sortOrder` | Optional order within collection |
| `createdAt` | |
| **Unique** | `@@unique([collectionId, publishedMonoId])` |

**Rules:**

- **Ownership:** `PublishedMono.ownerId` must equal `CreatorMonoCollection.ownerId` for inserts.
- **Trash / catalog visibility:** If `PublishedMono.trashedAt != null` or mono is permanently deleted, **do not show** that mono in **public** collection listings; owner UI may show **ghost/disabled** row or omit — product choice.
- **Collection survives trash:** Removing a mono from catalog via trash **does not** need to delete the collection row; **membership** either hides the mono publicly or is removed on cascade policy (recommend: **keep membership row** optional; simpler public query = join where `trashedAt IS NULL`).

**Migration:** **Yes** — new tables and FKs when this feature ships (explicitly **not** run as part of this document).

---

## 5. Backend API Proposal

### Owner (JWT) — `/v1/me/creator-collections`

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/v1/me/creator-collections` | List my collections (cursor optional). |
| POST | `/v1/me/creator-collections` | Create collection. |
| PATCH | `/v1/me/creator-collections/:id` | Update metadata. |
| DELETE | `/v1/me/creator-collections/:id` | Delete collection (+ cascade items). |
| POST | `/v1/me/creator-collections/:id/items` | Add one `publishedMonoId`. |
| DELETE | `/v1/me/creator-collections/:id/items/:publishedMonoId` | Remove membership. |
| POST | `/v1/me/creator-collections/:id/items/bulk` | Body: `{ publishedMonoIds: string[] }` — bulk add with ownership checks. |

### Public (optional JWT for personalization only)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/v1/users/:userId/creator-collections` | Public-visible collections for creator. |
| GET | `/v1/users/:userId/creator-collections/:id/monos` | Paginated monos in collection (respect trash/hidden). |

**Published monos module:** New Nest module or extend `users` / `published-monos` with collection services; enforce **owner** on mutations and **catalog visibility** on reads.

---

## 6. Flutter UX Proposal

### Owner — Profile → Published

- **Multi-select bar:** **“N selected”** / **Cancel** / **Add to collection** (remove **Delete** from Published).
- **Sheet:** List collections + **Create new** + confirm add for selected mono IDs (calls bulk API).
- **Per row:** **Move to Trash** / edit flows unchanged where applicable.

### Public — Profile (`/profile/public?userId=`)

- **Monos tab:** Full published list (existing direction).
- **Collections tab:** Grid/list of creator collections → tap → **collection detail** (paged monos). Empty: **“No collections yet.”**

### Naming / copy

- Avoid reusing **“Saved collections”** language for creator bundles; use **“Collections”** in creator context only or qualify **“Creator collections”** in settings/help if needed.

---

## 7. Trash / Delete Interaction

- **Trash (`trashedAt` set):** Mono **hidden from public** feeds and **public collection mono lists**; membership row can remain for restore semantics.
- **Restore:** If mono returns to catalog and still referenced in collection, it **reappears** in public collection list when consistent with publish state.
- **Permanent delete:** Removing `PublishedMono` should **cascade delete** `CreatorMonoCollectionItem` rows (FK `onDelete: Cascade` recommended).

---

## 8. Tests Needed

**Backend**

- Ownership: cannot add another user’s mono to collection.
- Unique constraint on `(collectionId, publishedMonoId)`.
- Public list excludes trashed monos.
- Bulk add partial failures / idempotency.

**Flutter**

- Published multi-select: no bulk delete button; Add to collection wiring (mocked repo).
- Public profile: Collections tab lists API-driven data; navigation to detail.
- Regression: Trash and reader flows unchanged for per-item actions.

---

## 9. Implementation Split

| Slice | Scope |
|-------|--------|
| **M8f1** | Published tab: remove bulk **Delete** from multi-select; **Add to collection** placeholder/disabled until API ready; no regression on per-item trash. |
| **M8f2** | Prisma migration + Nest module + owner + public APIs + service tests. |
| **M8f3** | Flutter: owner collection CRUD + bulk add from Published selection. |
| **M8f4** | Flutter: Public Profile Collections tab + detail route. |
| **M8f5** | End-to-end smoke + copy review + analytics hooks if any. |

---

## 10. Exact Cursor Prompt For M8f1

Use verbatim or adapt:

> **Task (M8f1 — UI-only, safe):** Update Profile **Published** tab multi-select behavior in `lib/features/profile/profile_screen.dart` (and any helper widgets such as `_FolderGroupList`).
>
> **Goals:**
> 1. **Remove** the bulk **Delete** action from the Published-tab selection bar (`isSavedSection == false`). Do **not** remove bulk **Unsave** for the Saved tab.
> 2. Replace with **“Add to collection”** as the primary action for Published multi-select. Until backend APIs exist, implement one of: **disabled button** with tooltip/snackbar **“Coming soon”**, or **single snackbar** on tap — product-neutral placeholder.
> 3. **Do not** change per-item **Move to Trash**, story options trash flows, or `onBulkDeleteLoose` behavior for **mock/local** paths except where it duplicates the removed Published bulk delete UX (remove user-visible Delete only).
> 4. Keep **Cancel** and selection checkbox behavior.
> 5. Add/update widget tests if present for selection bar labels.
>
> **Out of scope:** Backend, Prisma, new routes, wiring real collection APIs.
>
> **Verify:** `flutter analyze` on touched files; `flutter test` for profile tests.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Learner Saved collections affected?** | **No** for V1 product stance — Saved stays **flat** per M8c. Creator collections are **additive**. Optional copy clarity so “Collections” on **public profile** means **creator** bundles, not learner Saved. |
| **Creator collections recommended?** | **Yes** as the path to **public curator groups** without changing `MonoBookmark` semantics. |
| **Migration needed?** | **Yes** when M8f2 ships — new tables/FKs; **not** part of this doc’s execution. |
| **First code step** | **M8f1:** Remove Published bulk **Delete** from multi-select; **Add to collection** placeholder (§10). |
| **Backend APIs needed** | §5 owner + public endpoints; Nest service validating **owner** and **trashed** rules. |
| **Flutter screens likely to change** | `profile_screen.dart` (`_FolderGroupList`, selection bar), `public_profile_screen.dart` (Collections tab + data), new collection picker sheet, optional `public_folder_detail_screen` reuse vs new route. |
| **Biggest risk** | **Terminology collision** (“collections” = learner demo folders vs creator bundles vs Saved); mitigate with **schema names** and **UI copy**. Second: **stale membership** when monos are trashed — define **query filters** early. |
