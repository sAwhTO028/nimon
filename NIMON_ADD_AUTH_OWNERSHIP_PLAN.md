# Nimon — Add flow ownership & auth model (pre–backend)

Design and architecture analysis only. **No implementation, login UI, or backend wiring** in this document.

**Code anchors today (for alignment):**

- Aggregate: `CreatorStoryV1` in `lib/features/create/story_v1_model.dart` — `basics.storyId` is the **local draft id** (UUID); `basics.creatorOwnerId` exists but is typically empty until a dev stub fills it.
- Lifecycle: `StoryPublishState` (`draft` | `readingOnlyPublished` | `fullLearnPublished`).
- Persistence: `StoryCreatorDraftStorage` + `StoryCreatorDraftResumeStorage` (`SharedPreferences`, device-local).
- Publish (today): `publishReadingOnlyToDisk` / `publishFullLearnToDisk` in `lib/features/create/story_creator_provider.dart` — updates publish state and **persists locally** (`creator_drawer_publish.dart`).

---

## A. Owner model

### Draft owner

- **Definition:** The authenticated **user** who created the draft (`ownerId` / `userId`). Every draft row must be attributable to exactly one owner.
- **V1 rule:** Only that owner may **read (via API), edit, publish, or delete** the draft.
- **Today:** Ownership is **implicitly the device** (single-tenant demo). The schema already has `StoryBasics.creatorOwnerId` — treat it as the **future canonical owner field** once auth exists.

### Mono owner (published content from Add flow)

- **Definition:** The **creator user** who published the story as a Mono (or Mono-equivalent content unit). The published record is **server-owned** with `ownerId` = creator.
- **Relationship to draft:** At first successful publish, the backend should store **`draftId` → `publishedMonoId`** (or reuse draft id only if product chooses 1:1 forever — see section G). The **mono’s `ownerId` must match** the draft’s owner at publish time.
- **Read path:** Other users see only what **`visibility`** allows (V1: public published only for non-owners).

### Collection owner

Distinguish two concepts that both appear in product language:

| Concept | Owner | Contents |
|--------|--------|----------|
| **Creator collection** (e.g. “my series”, curated list of my monos) | Same **creator `userId`** | References **`publishedMonoId`** (and optionally order) |
| **Reader saved folder / bookmark collection** (Profile → Saved) | The **reader `userId`** | References **other users’ public** `publishedMonoId`s (and local-only state pre-sync) |

- **V1 rule:** A collection row is owned by the user who created the collection. It does **not** transfer ownership of the underlying monos.

### Saved item owner

- **Definition:** A **save/bookmark** is owned by the **reader** who saved it (`userId` = saver), not by the mono’s creator.
- **V1 rule:** Saves are private to the saver (unless product later adds “public lists”). They reference `publishedMonoId` + optional `collectionId` (folder).

---

## B. Required IDs / fields

Minimal **V1** set (simple, backend-friendly). Names can map 1:1 to JSON columns.

### Identity & ownership (always on server-bound entities)

| Field | Used on | Purpose |
|-------|---------|---------|
| `userId` | Auth session / JWT subject | Stable account id |
| `ownerId` | Draft, Mono, Creator collection | Same as `userId` for creator-owned resources |
| `createdAt` / `updatedAt` | All mutable resources | Audit + sync |

### Add-flow content

| Field | Where | Purpose |
|-------|--------|---------|
| `draftId` | Client + server (after sync) | Stable id for `CreatorStoryV1` (`basics.storyId` today). **Do not rotate** on publish. |
| `publishState` | Draft / published snapshot | Mirrors `StoryPublishState`: `draft` \| `reading_only_published` \| `full_learn_published` |
| `publishedMonoId` | After publish | **Server-issued** public content id (recommended). Avoid reusing `draftId` as the public id unless product explicitly wants one id everywhere. |
| `publishedRevision` | Optional | If you allow edit-after-publish later |
| `visibility` | Published mono | V1: `public` \| `unlisted` (optional) \| `private` (creator-only preview — only if needed) |
| `learnBundleVersion` | Published mono | Which learn layers ship (`reading_only` vs `full_learn`) — aligns with publish modes |

### Collections

| Field | Purpose |
|-------|---------|
| `collectionId` | Server id for a user’s folder/list |
| `ownerId` | Must equal collection creator |
| `itemIds[]` or join table | Ordered list of `publishedMonoId` |

### Saves

| Field | Purpose |
|-------|---------|
| `saveId` | Optional; or composite `(userId, publishedMonoId)` |
| `userId` | Saver |
| `publishedMonoId` | Target |
| `collectionId` | Optional folder |

### Must always carry `ownerId` / `userId`

- **Draft payload (sync):** `draftId`, `ownerId` (= creator), `publishState`, full `CreatorStoryV1` blob or normalized tables.
- **Published mono:** `publishedMonoId`, `ownerId`, `visibility`, `publishState` / learn tier, timestamps, content hashes optional.
- **Creator collection:** `collectionId`, `ownerId`.
- **Save:** `userId` (saver), `publishedMonoId`.

### Local-only fields (may stay device-only until sync)

- `CreatorDraftResumeMeta` (last active module, UI resume) — can remain local or be synced as convenience.
- Ephemeral UI: scroll positions, transient validation — local only.

---

## C. V1 permission rules

Simple **two-role** model: **Owner** vs **Everyone else**. No RBAC matrix.

1. **Owner (creator)**  
   - Create, read, update, delete **own drafts**.  
   - Publish / unpublish (if product allows) **own** content.  
   - Manage **own** creator collections.  

2. **Non-owner**  
   - May **read** published monos only if `visibility` allows (V1 default: **`public`**).  
   - May **save** public monos to **own** saved list (subject to product).  
   - **Must not** list, open, or mutate **another user’s drafts** or **processing queue** via API.  
   - **Must not** see another user’s non-public drafts or private processing state.

3. **Processing**  
   - In V1, treat **Processing** as **creator-private pipeline state** tied to `ownerId` + `draftId`. Public feed never exposes “processing” for other users’ content.

4. **Learn modules**  
   - Editing: owner only (part of draft).  
   - Consumption after publish: gated by published tier (`reading_only` vs `full_learn`) + visibility.

---

## D. Local-first flow

### What exists locally before backend

- Full **`CreatorStoryV1`** graph: Story basics, sentences, vocab/kanji, grammar, quiz, audio metadata, module workflow statuses (`SharedPreferences` via `StoryCreatorDraftStorage`).
- **Publish state** transitions written locally (`StoryPublishState`).
- **Processing tab** lists drafts/published items from **local** storage (current app behavior).
- **Mono feed / Saved / folders** in parts of the app may still be **mock or in-memory** — treat as **UI demo** until wired to server.

### What becomes server-owned after publish

- A **published mono record** (`publishedMonoId`, `ownerId`, `visibility`, content snapshot or references).
- **Public read model** for feed (subset of fields).
- Optional: **media URLs** (covers, audio) after upload — replace local paths.

### What stays local-only (V1)

- **Unsynced drafts** if user is offline or not logged in yet (queue for upload after auth).
- **Sensitive local paths** (`StoryAudioAsset.localPath`, etc.) — never trusted on server; re-upload or issue signed URLs.
- **Pure UI state** (drawer highlight, last tab).

---

## E. Dev auth stub plan

Goal: one place that defines **“current user”** so `creatorOwnerId` and future API headers stay consistent.

**Recommended stub (development only):**

1. **`CurrentUserProvider` (Riverpod)**  
   - Returns `{ userId: string, displayName?: string }`.  
   - V1 dev default: **fixed UUID** in `const` or `--dart-define` / `.env` (not committed if secrets ever appear).

2. **Wire into draft creation**  
   - On `CreatorStoryV1.empty()` / `startNewLocalDraft()`, set `basics.creatorOwnerId` = `currentUser.userId`.  
   - On load from disk, if `creatorOwnerId` is empty, **backfill** from current stub once (migration-friendly).

3. **Guardrails**  
   - In debug, assert `creatorOwnerId` is non-empty when saving.  
   - Optional: prefix local storage keys with `userId` when multi-user testing on one device (later).

4. **No login UI** — stub only; swap implementation when real auth lands.

---

## F. Future auth compatibility

- **JWT / session `sub`** maps to **`userId`** everywhere in this doc.
- **Server validates `ownerId`** on every mutating route; never trust client-only ownership.
- **Id mapping:**  
  - Keep **`draftId`** stable for client sync.  
  - Issue **`publishedMonoId`** at publish time; store mapping server-side.  
- **Migrating local drafts:** On first login, **upload** drafts with empty `creatorOwnerId` resolved to logged-in `userId`; server rejects conflicts if draft id already exists for another user (rare — use namespace or new id).

---

## G. Recommended next schema / model steps

1. **Freeze vocabulary:** Use `userId` / `ownerId` / `draftId` / `publishedMonoId` / `collectionId` as above.  
2. **Populate `creatorOwnerId`** via dev stub → then real auth.  
3. **Add `publishedMonoId` concept** even if still stored locally first — avoids coupling public id to draft UUID forever.  
4. **Define `visibility` default** for published monos: `public` for V1 demo.  
5. **API sketch (for later):**  
   - `POST /drafts` / `PUT /drafts/{draftId}` — body includes full payload + `ownerId` from token.  
   - `POST /drafts/{draftId}/publish` — returns `{ publishedMonoId, publishState }`.  
   - `GET /monos/{publishedMonoId}` — public read.  
   - `GET /me/processing` — drafts + processing for **owner only**.  
6. **Collections & saves:** separate small tables; never embed another user’s draft ids in public responses.

---

## Direct answers (summary)

| Question | V1 answer |
|----------|-----------|
| Who owns a draft? | The creator **`userId`** stored as `ownerId` / `StoryBasics.creatorOwnerId`. |
| Who can edit a draft? | **Owner only.** |
| Who can publish? | **Owner only** (when validation passes). |
| Who owns a published mono? | Same **creator `userId`**; server record has `ownerId`. |
| Who owns collections from this content? | **Creator collection** → creator. **Saved folder** → reader. |
| What must carry `userId`/`ownerId`? | Draft sync, published mono, creator collections; saves carry **saver** `userId`. |
| What stays local-only before publish? | Full draft blob, resume meta, local file paths, UI state. |
| V1 permission assumptions? | Owner-all for create/edit/publish/delete; non-owner **read public only**; no access to others’ drafts/processing. |

This model stays **intentionally small**: one owner per resource, no RBAC layers, and a clean path to JWT-backed APIs later.
