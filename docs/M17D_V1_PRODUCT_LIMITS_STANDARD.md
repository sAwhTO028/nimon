# M17D — V1 free product quota limits (standard)

This document is the **normative V1 standard for free-tier quotas per user** (counts of persisted catalog objects). It does **not** redefine **mono content validation** (title length, `STORY_SENTENCE_LIMITS`, learn-module tables, media MIME/size, etc.) — those remain **separate product/technical limits** documented elsewhere (e.g. M13 validation docs, `story-validation.ts`, `publish-validation.ts`).

**Companion:** gap analysis and current-state inventory — [`M17D_V1_LIMITS_ALIGNMENT_AUDIT.md`](./M17D_V1_LIMITS_ALIGNMENT_AUDIT.md).

**M17D:** docs/audit only — **no backend or Flutter implementation** in this task.

---

## 1. V1 free quota philosophy

- **Free tier is quota-driven:** specific **maximum counts** apply to selected user-owned resources so V1 stays predictable for infra and product.
- **Backend is authoritative:** every quota must be **enforced on the server** before commit (no “client-only” caps).
- **No silent failure:** when a quota blocks an action, the API returns an explicit, **machine-readable** response; the app shows a **visible, localized** alert — never silent no-ops or generic failures without context.
- **No automatic deletion:** reaching a quota **does not** auto-remove older content; the user must delete or reorganize, or wait for a future **premium** tier (V2).
- **Pagination is not a quota:** public/home reading feeds and profile lists stay **uncapped totals with cursor pagination**; quotas only cap **how many rows a user may own** in the listed resource classes.
- **Premium is V2:** V1 may show **“Premium coming later”** only where a quota block naturally invites upgrade messaging — no subscription flows in V1.

---

## 2. Final V1 quota table

| Resource | Free V1 max per user | Notes |
|----------|----------------------|--------|
| **Published monos** | **30** | Count **non-trashed**, catalog-visible published monos owned by the user (exact counting rule to be finalized in M17E to match product). |
| **Saved monos** (bookmarks) | **50** | Rows in **`mono_bookmarks`** (or equivalent) for the user. |
| **Collections** | **10** | Creator collections owned by the user. |
| **Collection items** | **30** per collection | Items in **`creator_mono_collection_items`** for a given **`collectionId`**. |
| **Draft stories** | **50** | **`story_drafts`** rows owned by the user (workspace drafts). |

All numbers are **product constants** for V1 free tier; they must live in one **backend** source of truth and be **mirrored** in Flutter for **pre-check UX** only (server still decides).

---

## 3. What is not capped in V1

| Area | V1 policy |
|------|-----------|
| **Followers / following** | **No cap**; social graph grows freely. |
| **Reading / public mono feed** | **No ownership quota**; **paginate only** (`hasMore` / cursor). Same for discovery surfaces that are not “owned row counts.” |
| **Mono content** | Governed by **validation** (story/learn/media/profile text rules), **not** by this quota doc. |
| **API page sizes** | Pagination **default/max** per route remain **technical** concerns (see existing `PaginationDefaults`, service clamps); they do **not** replace **ownership quotas**. |

---

## 4. Backend enforcement points

Guards must run **before** the mutating transaction commits. Suggested **primary** hook points (exact function names may vary — M17E implements):

| Quota | Enforcement point (Nest / Prisma) |
|-------|-------------------------------------|
| **Published monos (30)** | Path that **creates** or **restores** a catalog-visible published mono for the owner (e.g. publish from draft / create published record). **Not** on list GET. |
| **Saved monos (50)** | **`mono-social`** (or equivalent) **bookmark add** / “save” mutation — before `create` on `mono_bookmarks`. |
| **Collections (10)** | **`creator-collections.service`** — **`create`** collection (before `prisma.creatorMonoCollection.create`). |
| **Collection items (30)** | **`creator-collections.service`** — **add item** / **bulk add** paths (before inserts into `creator_mono_collection_items`; enforce per **`collectionId`**). |
| **Draft stories (50)** | **`story-drafts.service`** — **create draft** (before new `story_drafts` row). |

**Cross-cutting:** centralize constants (e.g. `src/common/quotas/v1-free-quotas.ts` in M17E) to avoid drift; use **`count`** queries scoped by **`userId`** / **`ownerId`** with the same filters product uses for “what counts.”

---

## 5. Flutter UX / alert requirements

- **Intercept quota responses:** map HTTP + JSON body with **`code: "quota_exceeded"`** to a **single** user-facing alert path (dialog or banner — product choice in M17F).
- **Localized copy:** message must use **`key`** + **`limit`** + **`current`** (see §6) via **ARB / `AppLocalizations`** — no raw server English strings in UI.
- **Pre-submit UX (optional but recommended):** when **`current >= limit - buffer`** (e.g. at `limit`), disable primary CTA or show inline hint **only if** Flutter has fresh counts; **never** rely on client count alone to allow bypass.
- **No silent swallow:** repository / notifier surfaces quota errors to the presenting widget.
- **Premium placeholder:** where design calls for it, show **“Premium coming later”** (localized) as secondary text — **no** purchase flow in V1.

---

## 6. Error contract

When a quota blocks an action, the API returns a **structured** payload (exact HTTP status to align with existing Nimon API patterns in M17E — e.g. **422** or **403**; body shape is normative below).

**Body shape (normative):**

```json
{
  "code": "quota_exceeded",
  "key": "<specific_limit_key>",
  "limit": 30,
  "current": 30
}
```

| Field | Type | Meaning |
|-------|------|---------|
| **`code`** | string | Always **`quota_exceeded`** for this contract. |
| **`key`** | string | One of the **required quota keys** (§7). |
| **`limit`** | number | Configured max for that quota. |
| **`current`** | number | Count at time of check (usually equals **`limit`** when blocked). |

**Required values for `key`:**

| `key` | When used |
|-------|-----------|
| **`published_mono_limit_reached`** | User already at **30** published monos (per counting rules). |
| **`saved_mono_limit_reached`** | User already at **50** saved/bookmarked monos. |
| **`collection_limit_reached`** | User already at **10** collections. |
| **`collection_item_limit_reached`** | Target collection already at **30** items. |
| **`draft_story_limit_reached`** | User already at **50** draft stories. |

**Compatibility:** until M17E ships, existing endpoints may return ad-hoc errors; M17E migrates mutating paths to this contract.

---

## 7. Localization keys

Flutter should map **`key`** from §6 to ARB entries. Recommended pattern: **`quota.<key>`** mirroring the API value for traceability.

| API `key` | Suggested ARB key | Parameters |
|-----------|-------------------|------------|
| `published_mono_limit_reached` | `quota.published_mono_limit_reached` | `limit`, `current` |
| `saved_mono_limit_reached` | `quota.saved_mono_limit_reached` | `limit`, `current` |
| `collection_limit_reached` | `quota.collection_limit_reached` | `limit`, `current` |
| `collection_item_limit_reached` | `quota.collection_item_limit_reached` | `limit`, `current` |
| `draft_story_limit_reached` | `quota.draft_story_limit_reached` | `limit`, `current` |

Example English template (product tone in M17F): *“You’ve reached the free limit of {limit} published monos (you have {current}). Premium tiers will arrive later.”*

---

## 8. Premium V2 notes

- **V1:** quotas are **hard blocks** for free users; messaging may tease **premium later** — **no** payment, entitlements, or store SKUs.
- **V2:** premium may raise or remove quotas per plan; same **`quota_exceeded`** contract can carry **`plan`** / **`upgrade`** hints later — **out of scope** for M17D/M17E wording unless product adds fields in a minor revision.

---

## 9. P0 / P1 / P2 implementation plan

| Priority | Item | Owner |
|----------|------|--------|
| **P0** | Backend **enforces all five quotas** on mutating paths; returns §6 JSON; **no** silent failure. | **M17E — done** ([`M17E_BACKEND_FREE_QUOTA_GUARDS_REPORT.md`](./M17E_BACKEND_FREE_QUOTA_GUARDS_REPORT.md)) |
| **P0** | Flutter **handles `quota_exceeded`** and shows **localized** alert using §7 keys + **`limit`/`current`**. | M17F |
| **P1** | Wire **pre-check** UX (optional counts endpoint or cached counts from list `totalCount` where applicable) to reduce surprise. | M17E + M17F |
| **P1** | Contract tests: each mutation returns correct **`key`** at boundary **`limit`** and **`limit-1`** still succeeds. | M17E |
| **P2** | Admin / support tooling, analytics events on quota hits, rate limits on list endpoints (abuse). | Post-V1 |

**Milestone split (revised for quotas):**

| Milestone | Scope |
|-----------|--------|
| **M17E** | Backend **quota guards**, shared constants, **`quota_exceeded`** responses (§6), Jest coverage for each mutation boundary. |
| **M17F** | Flutter **quota alert** pipeline, **localization** (§7), repository mapping, UI placement (create/save/publish/collection flows). |
| **M17G** | **Device smoke** + release checklist: hit each quota on a dev build, verify alerts, verify no regressions on M17C pagination; automated smoke where feasible. |

**Content validation** (story title, sentences, learn tables, media) stays **out of M17E–G** unless explicitly re-scoped; track under existing validation / M13 follow-ups if needed.

---

## Related docs

- [`M17C_OWNER_PUBLISHED_MONOS_PAGINATION_FIX_REPORT.md`](./M17C_OWNER_PUBLISHED_MONOS_PAGINATION_FIX_REPORT.md) — pagination vs **stale backend** (orthogonal to quotas).
- M13 / validation standard docs — **content** limits, not **ownership** quotas.
