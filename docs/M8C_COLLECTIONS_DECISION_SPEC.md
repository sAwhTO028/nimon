# M8c Collections Decision Spec

## 1. Executive Summary

Nimon’s learner **Saved** experience is **production-backed** as a **single flat list**: `MonoBookmark` enforces one row per `(userId, publishedMonoId)`, and **`GET /v1/me/bookmarks`** returns a cursor-paged stream. **M8b** completed followers parity; **collections/folders** remain the main open **product fork** for bookmarks.

This document compares options, **recommends keeping Saved-only for V1**, and spells out what changes if the product later chooses **named collections**. **No code or migrations** are performed in this step.

Sources reviewed: `docs/M8_DISCOVERY_AND_POLISH_PLAN.md`, `docs/M7_SOCIAL_PROFILE_POLISH_CLOSEOUT_REPORT.md`, `docs/M7C_PROFILE_SAVED_LIST_REPORT.md`, `nimon-backend/prisma/schema.prisma` (`MonoBookmark`), and spot checks of `lib/features/profile/profile_screen.dart` and `lib/features/mono/mono_screen.dart` (demo folder UI vs flat remote Saved).

---

## 2. Current Saved Behavior

### Backend

- **Model:** `MonoBookmark` (`mono_bookmarks`): `userId`, `publishedMonoId`, `createdAt`; **`@@unique([userId, publishedMonoId])`** — exactly **one** saved row per user per published mono.
- **APIs (M7a/M7c):**
  - `POST/DELETE /v1/mono/:monoId/bookmark` (JWT, catalog-visible rules)
  - `GET /v1/me/bookmarks?cursor=&limit=` (JWT)
- **Feed/detail:** `isBookmarkedByMe` for signed-in users (optional JWT on public surfaces).

### Flutter (remote mode)

- **Profile → Saved tab:** `profileSavedMonoPagerProvider` + `RemoteMonoSocialRepository.fetchBookmarkedPage()`.
- **States:** auth gate, loading, error, empty (“No saved stories yet.”), row opens reader; **Unsave** removes bookmark and list row; **`profileSavedListRefreshProvider`** refreshes when Mono toggles bookmark.
- **Mono:** optimistic bookmark; snackbar **“Sign in to save stories.”** for guests.

### Legacy / demo surfaces

- **`mono_screen.dart`** still seeds **demo “collections”** (`_MonoSaveFolder` — e.g. Favorites, Read later) for **UX exploration**; that is **not** persisted as separate backend collections — the real bookmark is still **flat**.
- **`profile_screen.dart`** retains **mock folder structures** when remote drafts/list paths are off; remote Saved path is **flat** per M7c.

---

## 3. Product Options

### A. Saved-only flat list

- **What:** One **Saved** library; bookmark = add/remove from that list; sort by `createdAt` (or product-chosen sort later).
- **Pros:** Matches current schema and APIs; smallest eng surface; clear mental model; fast to polish copy and empty states.
- **Cons:** Power users cannot group reading lists; marketing cannot claim “folders” without caveat.

### B. Collections / folders

- **What:** User-created **containers**; each bookmark **membership** in at most one folder or a **default** “Saved” bucket (product must decide **1:N vs N:M**).
- **Pros:** Organized reading; aligns with exploratory UI already sketched in Mono demo sheets.
- **Cons:** **New tables + migrations**; CRUD + move/rename/delete; conflict resolution with flat `MonoBookmark` semantics; larger Flutter scope (picker sheets, profile tab layout).

### C. Tags / labels

- **What:** Multiple labels per saved mono (many-to-many), filter by tag.
- **Pros:** Flexible; no strict hierarchy.
- **Cons:** **More complex** than folders for average learners; filter UI and backend queries heavier than V1 needs; overlaps with search/discovery later.

### D. Later smart collections

- **What:** Rule-based lists (“Unread”, “JLPT N3”, “From creators I follow”) generated from metadata.
- **Pros:** Delightful when done well.
- **Cons:** Requires **rules engine + indexing + product definition**; should not precede a stable manual Saved baseline.

---

## 4. Recommended V1 Decision

**Recommendation: Option A — Saved-only (flat list) for V1 ship.**

**Rationale:**

1. **Schema and APIs already match** flat Saved; M7c closed the Profile Saved tab on that contract.
2. **M8 plan** explicitly sequenced **collections as a decision milestone**, not a V1 blocker, after routing and followers parity.
3. **Mono demo folders** can stay as **non-persistent UX experiments** until product commits to B; avoiding half-implemented “folders that don’t sync” reduces user distrust.
4. **Tags (C)** and **smart collections (D)** are better **post-V1** once usage data and discovery roadmap exist.

**If product insists on folders before V1:** treat as **scope expansion** — use §6 and §8 as the implementation contract and accept migration + timeline hit.

---

## 5. If Saved-only

Define polish **without** schema changes:

| Area | Guidance |
|------|-----------|
| **Clearer copy** | Use one verb family: **Save / Saved** in Mono; **Saved** tab title; empty state explains **“Save from Mono”** (already close to M7c). Avoid calling the tab “Collections” unless you ship folders. |
| **Unsave behavior** | Keep **idempotent** `DELETE` bookmark; optimistic removal from list; refresh signal from Mono (existing). Optional: confirm dialog only if accidental taps become a support theme. |
| **Saved count (optional)** | Profile header or tab badge: **count from pager `totalCount`** only if backend adds it — *not required for V1 polish*; can defer to avoid API change. |
| **Mono sheet vs single tap** | Today bookmark toggles from feed; demo **save sheet** with folders is **misleading** if folders are not real — consider simplifying sheet to **Save / Remove** only when product freezes Saved-only. |
| **Schema** | **None.** |

---

## 6. If Collections

### Backend models (conceptual)

- **`MonoCollection`:** `id`, `userId`, `name`, `sortOrder` or `createdAt`, optional `colorKey`.
- **`MonoCollectionItem`:** unique `(collectionId, publishedMonoId)` **or** nullable `collectionId` on an extended bookmark row — **do not** break `MonoBookmark` uniqueness without a migration strategy (e.g. keep `MonoBookmark` as source of truth and add **optional** `collectionId` FK, or move to membership-only table and drop direct mono link — product choice).

### APIs (sketch)

- `GET/POST/PATCH/DELETE /v1/me/collections`
- `POST /v1/me/collections/:id/items` (add mono to collection)
- `DELETE /v1/me/collections/:id/items/:monoId`
- `GET /v1/me/bookmarks` — extend with `?collectionId=` **or** separate `GET /v1/me/collections/:id/bookmarks`
- **Visibility:** all **owner-only** (JWT); no public collection URLs until defined.

### Flutter UX

- **Mono:** save sheet → **Save** (default) + **Add to collection** + manage collections.
- **Profile Saved:** segmented control or nested nav: **All saved** vs per-folder; create/rename/delete folder; drag-sort (optional, later).
- **Reader:** Unsave vs **Remove from this collection** if N:M membership.

### Migration needs

- **Yes** — new tables and/or columns; backfill: all existing `MonoBookmark` → **default collection** or **null collection = All**.

### Risks

- **Data model creep:** N:M tags vs 1-folder-per-item confusion.
- **Sync:** offline or failed moves leaving inconsistent UI.
- **Performance:** listing all bookmarks per folder with large libraries.

---

## 7. UX Copy

Suggested **Saved-only** strings (align across Mono + Profile):

| Context | Copy (EN) |
|---------|-----------|
| Guest gate (Profile) | Title: **Sign in to see saved stories.** Body: **Save stories from Mono to find them here.** |
| Empty (Profile) | **No saved stories yet.** / **Save stories from Mono to build your reading list.** |
| Mono — save success | (Optional subtle) **Saved.** or rely on icon state only. |
| Mono — remove | **Removed from Saved.** or **Unsaved.** |
| Mono — guest | **Sign in to save stories.** (existing) |
| Button / a11y | **Save story**, **Remove from Saved**, **Saved** (toggle state) |
| **Avoid until folders ship** | “Add to collection”, “Move to folder”, “Collections” as tab name |

If **collections** ship later:

- **Add to collection**, **Create collection**, **Rename collection**, **Delete collection** (with destructive warning), **Remove from this list** (when multi-membership).

---

## 8. Data Model Proposal

**Only if choosing collections (Option B).**

### `MonoCollection`

- `id` (uuid, PK)
- `userId` (FK → `User`, cascade)
- `name` (string, reasonable max length)
- `createdAt`, `updatedAt`
- `@@index([userId, createdAt])`

### `MonoCollectionItem`

**Option 1 (recommended with current `MonoBookmark`):** add nullable `collectionId` on `MonoBookmark` (FK → `MonoCollection`, `onDelete: SetNull` or restrict delete if non-empty).

- Relaxes interpretation: bookmark row = “saved”; collection = optional grouping.
- **Migration:** add column; default `null` = “All saved” or assign to a system **“Inbox”** collection.

**Option 2:** separate join table `MonoCollectionPublishedMono` with unique `(userId, publishedMonoId, collectionId)` for **N:M** — more flexible, more queries.

Names are indicative; final names should match Prisma/naming conventions in-repo.

---

## 9. Tests Needed

### If Saved-only polish

- **Flutter:** copy/a11y snapshot or golden (optional); ensure no user-facing “collection” string in remote-only paths if product adopts §7.
- **Backend:** none required for copy-only.

### If collections

- **Backend:** service tests for CRUD, membership uniqueness, cascade when mono/user deleted, list filters.
- **Flutter:** repository tests per endpoint; pager per collection; widget tests for save sheet and profile folder list.

---

## 10. Implementation Split

| Slice | Scope |
|-------|--------|
| **M8c-doc (this file)** | Decision + acceptance criteria only. |
| **M8c1 Saved-only polish** | Copy pass; optionally simplify Mono save sheet to remove fake folders from **production** builds or gate behind `kDebugMode`. |
| **M8d Collections backend** | Prisma + migrations + APIs (only if product selects B). |
| **M8e Collections Flutter** | Profile + Mono wiring (only after M8d). |

---

## 11. Exact Cursor Prompt For Chosen Next Step

**Use this if the team accepts §4 (Saved-only V1):**

```text
Implement M8c1: Saved-only polish (no Prisma migrations, no collections APIs).

Context:
- Bookmarks are flat MonoBookmark + GET /v1/me/bookmarks.
- mono_screen.dart has demo folder UI (_MonoSaveFolder) that is not backend-backed.
- Profile Saved tab is remote-backed when RemoteBackendConfig.useRemoteDrafts is true.

Tasks:
1) Align user-facing English copy with docs/M8C_COLLECTIONS_DECISION_SPEC.md §7 (Save/Saved/Remove from Saved; avoid "collection" in production paths unless gated as demo).
2) Ensure production/remote flows do not imply folders exist: simplify or gate the Mono save sheet so learners only get Save/Remove when not in debug demo mode (product-approved behavior).
3) Light UX polish on Profile Saved empty/auth states if needed.
4) dart format, flutter analyze on touched paths, flutter test test/features/profile and test/features/mono as relevant.

Do not add new bookmark tables or migrations.
```

**Use this only if product selects collections (Option B):**

```text
Implement collections backend MVP per docs/M8C_COLLECTIONS_DECISION_SPEC.md §6 and §8.

Add Prisma models (MonoCollection + membership strategy), migration, NestJS module for CRUD + list bookmarks by collection, Jest tests, and a short implementation report. Do not implement Flutter in this task unless asked.
```

---

### Output summary

| Question | Answer |
|----------|--------|
| **Recommended decision** | **Saved-only (flat)** for V1; defer folders/tags/smart lists. |
| **Migration needed?** | **No** for Saved-only polish; **Yes** if collections (Option B). |
| **Backend changes needed?** | **None** for Saved-only; **New module + migration** for collections. |
| **Flutter changes needed?** | **Copy + optional simplification** of Mono save UX for Saved-only; **major** Profile/Mono work for collections. |
| **Biggest risk** | Shipping **folder UI** without **folder persistence** confuses users — align demo vs production. |
| **First implementation step** | **Product sign-off** on §4; then run **M8c1** prompt (Saved-only polish) or **collections backend** prompt if overriding. |
