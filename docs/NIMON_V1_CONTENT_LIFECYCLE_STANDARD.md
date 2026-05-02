# Nimon V1 Content Lifecycle Standard

**Status:** Product + engineering standard (documentation only).  
**Related:** [NIMON_CONTENT_LIFECYCLE_AUDIT.md](NIMON_CONTENT_LIFECYCLE_AUDIT.md) (behavioral audit), [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md) (commands).

---

## Concepts

### Draft

- **Definition:** The creator’s **working copy** of a story (basics, sentences, learn modules, etc.).
- **Visibility:** **Not** a public reader surface. Readers must not consume the draft as published content.
- **Recoverability:** Must remain **recoverable** across app restarts (local prefs and/or server row, depending on mode).
- **Implementation:** Backed by **`StoryDraftRepository`** (local or remote implementation) and **`StoryCreatorDraftNotifier`** in Flutter.

### PublishedMono

- **Definition:** A **public server snapshot** of story core (and later learn metadata) stored in PostgreSQL **`published_monos`**.
- **Lifecycle:** Created or **updated in place** on publish flows; readers see this row until the creator changes or deletes published content through product-supported actions.
- **Visibility:** **Stays visible** while the creator edits the linked **`StoryDraft`**; the app must not hide real backend published rows merely because a draft is in “Editing” (see Profile Published tab rules in the audit).

### Editing published content

- **Definition:** The same **`StoryDraft`** row continues as the **working copy** after a read-only or full-learn publish.
- **`StoryDraft.hasUnpublishedCoreChanges`:** Should be **`true`** after meaningful edits that are not yet reflected in the latest published snapshot (server-side flag on **`story_drafts`** when using remote drafts + Nest **`updateDraft`** rules).
- **Update publish:** An explicit **publish / update publish** action **replaces or updates** the linked **`PublishedMono`** and sets **`hasUnpublishedCoreChanges`** back to **`false`** on success.

---

## Flutter run modes (no default code change)

Modes are selected at **compile time** via `--dart-define` (see `lib/features/create/data/remote_backend_config.dart`).  
`storyDraftRepositoryProvider` chooses **`LocalStoryDraftRepository`** vs **`RemoteStoryDraftRepository`** based on **`NIMON_USE_REMOTE_DRAFTS`**.

### Local-first (default)

| Flag | Value |
|------|--------|
| `NIMON_USE_REMOTE_DRAFTS` | **Omitted or `false`** (default) |

- **Persistence:** Draft JSON and index live in **on-device storage** (SharedPreferences via `StoryCreatorDraftStorage`).
- **Backend:** Creator edits **do not** update PostgreSQL **`story_drafts`** / **`draft_sentences`**.
- **Prisma Studio:** Opening Studio will **not** show Story Basics / Sentence edits from the app, because those edits **never hit the DB**. This is **expected**, not a broken sync.

### Remote draft mode

| Flag | Value |
|------|--------|
| `NIMON_USE_REMOTE_DRAFTS` | **`true`** |

- **Persistence:** Still **writes local first** (same local storage), then **syncs** to Nest **`/v1/story-drafts`** (PUT + publish endpoints as implemented in `RemoteStoryDraftRepository`).
- **Backend:** Successful sync updates **`story_drafts`** and related **`draft_*`** tables.
- **Prisma Studio:** After a successful save/sync, **Studio reflects** draft rows and children **consistent with the last server write**. If the API fails and the app falls back to local-only, Studio may **lag** the device.

**Optional defines:**

| Define | Purpose |
|--------|---------|
| `NIMON_API_BASE_URL` | Base URL for the API (default `http://localhost:3000`; use e.g. `http://10.0.2.2:3000` for Android emulator → host). |
| `NIMON_DEV_OWNER_ID` | UUID sent as draft owner; must match backend `DEV_OWNER_ID` when set. |

### Strict remote mode

| Flags | Values |
|--------|--------|
| `NIMON_USE_REMOTE_DRAFTS` | `true` |
| `NIMON_STRICT_REMOTE_DRAFTS` | **`true`** |

- **Behavior:** Remote failures **throw** instead of silently returning **local-only** success paths, so integration issues are visible during development.
- **Use when:** Debugging API contracts, ETags, or backend errors without masking.

---

## Which mode affects Prisma Studio?

| Studio observation | Explanation |
|--------------------|-------------|
| **No row changes** on Basics/Sentences edit | **Local-first default** — edits stay on device. |
| **`story_drafts` / `draft_sentences` change** after edit | **Remote draft mode** and successful **PUT** to the backend. |
| **`published_monos` appears/updates** | **Publish Read Only** or **Full Learn** completed on server (remote path or direct API). |

Studio always shows **Postgres truth**, not SharedPreferences.

---

## Database tables per action (server)

Assumes **Nest API** + Postgres. **Local-first Flutter** alone does **not** perform these writes.

| Action | `story_drafts` | `draft_sentences` (and other `draft_*`) | `published_monos` |
|--------|----------------|----------------------------------------|---------------------|
| Save draft content (remote PUT success) | Update (+ version); **`hasUnpublishedCoreChanges`** per server rules | Replace children for that draft | No |
| Publish Read Only (first time) | Update state, link **`publishedMonoId`**, clear dirty | Source for snapshot | **INSERT** |
| Publish Read Only (update) | Update; clear dirty | Source for snapshot | **UPDATE** (same id) |
| Publish Full Learn | Update; clear dirty | Readiness checks | **UPDATE** metadata |

Exact server logic: `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` and Prisma schema.

---

## Expected behavior by product action

### Story Basics

- **Local-first:** In-memory (Riverpod) updates; debounced or immediate save to **local storage**; **no** Postgres change.
- **Remote drafts:** Same local behavior, plus **HTTP** persist when sync succeeds; Postgres reflects saved basics fields on **`story_drafts`**.

### Story Sentences

- **Local-first:** Same as basics — **device persistence only** unless user enables remote drafts.
- **Remote drafts:** Local + **PUT** replaces **`draft_sentences`** (and related) for that draft id on success.

### Publish Read Only

- **Local-first:** Updates **local** `publishState` and persisted JSON; **does not** create **`published_monos`** on server.
- **Remote drafts:** After local publish state is set, client calls backend **publish read-only**; server **creates or updates** **`published_monos`** and clears **`hasUnpublishedCoreChanges`**.

### Edit published (working copy)

- **PublishedMono:** Remains **listed and visible** for backend-backed rows while editing (app policy).
- **Remote + server:** Edits that hit **`updateDraft`** can set **`hasUnpublishedCoreChanges = true`** until the next successful publish.

### Update publish (same story, new snapshot)

- **Server:** **`publishReadOnly`** (or full-learn path) **updates** the existing **`published_monos`** row tied to **`publishedMonoId`** and sets **`hasUnpublishedCoreChanges: false`** on the draft.

---

## Alignment with V1 wireframe

The PDF wireframe remains the **UX source of truth**. This document standardizes **where data lives** and **what developers should expect** from tooling (Prisma Studio, logs) per run mode.

---

## Open questions (documentation / future work)

1. **Full draft GET DTO** today omits **`hasUnpublishedCoreChanges`** in the declared TypeScript response type — clients that only use GET-full may need contract parity (see audit §3).
2. **Remote PUT** sends **`publishState: 'draft'`** on content saves before re-invoking publish endpoints — maintainers should treat this as an intentional sequence and keep regression coverage (see audit §8).
3. **Physical devices** need a reachable **`NIMON_API_BASE_URL`** (not always `localhost`).
