# M7 Social And Profile Polish Plan

**Type:** Plan / audit only — **no application code changes** and **no migrations** in this document.  
**Context:** M1–M6 are complete per [M6E_RELEASE_CHECKLIST.md](M6E_RELEASE_CHECKLIST.md). Production object storage may still be pending if public release is immediate ([M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md](M6_PRODUCTION_STORAGE_CDN_RELEASE_HARDENING_PLAN.md)).

**References:** [M3_MONO_FEED_READER_CLOSEOUT_REPORT.md](M3_MONO_FEED_READER_CLOSEOUT_REPORT.md), [M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md](M5_MEDIA_UPLOAD_AND_EDIT_VISIBILITY_CLOSEOUT_REPORT.md), [M4_FULL_LEARN_CLOSEOUT_REPORT.md](M4_FULL_LEARN_CLOSEOUT_REPORT.md), `nimon-backend/prisma/schema.prisma`, `nimon-backend/src/modules/mono-feed/**`, `lib/features/mono/**`, `lib/features/profile/**`, `lib/features/auth/**`, `lib/features/learn/**`.

---

## 1. Executive Summary

**Create → publish → read → learn** is the **revenue and trust core**: auth, drafts, media, catalog feed, reader, and Learn hydration must work before investing in **social retention** mechanics.

**Saved / bookmark / react / share / profile polish** comes next because it:

- Increases **return visits** and **library value** (saved monos).
- Surfaces **lightweight engagement** (react) without full comment threads.
- Enables **distribution** (share link) once a stable public URL story exists.
- Makes **identity and discovery** credible (public profile, authored list, optional follows).

Today, **Mono UI** already exposes **React**, **Bookmark** (collections sheet), and **Share**, and **Profile** has **Workspace**, **Published**, **public profile** routes, and **mock Following** — but **persistence and APIs are largely local/mock**, and **feed counts** are **placeholders** on the server. M7 closes that gap in **thin vertical slices** (backend truth first, then optimistic Flutter).

---

## 2. Current UI Surface Audit

### Mono (`lib/features/mono/mono_screen.dart` and related)

| Control | Current behavior | Server truth? |
|--------|-------------------|---------------|
| **React** | `_reactNotifiers` map; rail toggles **local** `ValueNotifier<bool>` | **No** — no POST/DELETE |
| **Bookmark / Save** | `_bookmarkNotifiers` + `_openBookmarkCollectionSheet` — **Saved** + named **collections**, in-memory maps (`_monoSingleCollectionByItemId`, `_monoSaveFolders`) | **No** — demo/local only |
| **Share** | `_share` → **`Clipboard`** with **`item.effectiveBodyText`** + snackbar `コピーしました` | **No** — copies **body text**, not a **canonical share URL** |
| **Following / For You** | **For You** can use **remote** feed (`NIMON_USE_REMOTE_MONO_FEED`); **Following** tab is **mock** per [M3 closeout](M3_MONO_FEED_READER_CLOSEOUT_REPORT.md) | **N/A** / mock |

### Backend feed (`nimon-backend/src/modules/mono-feed`)

| Field | Current behavior |
|-------|-------------------|
| **`likesCount`** | **Hard-coded `0`** in `mapRowToSummary` |
| **`hasAudio`** | **Hard-coded `false`** (should eventually derive from `content.learn` / `storyAudio` — separate small fix; can bundle with M7 or precede it) |

### Profile (`lib/features/profile/**`)

| Area | Current behavior |
|------|------------------|
| **Profile home** | Workspace, Published, navigation drawer, notifications entry |
| **Published / Workspace** | **Remote** wired (JWT); M5 **edit visibility** refresh patterns |
| **Public profile** | `public_profile_screen.dart`, `share_profile_screen.dart`, `public_profile_data.dart` — **UI** exists; **follow** / **saved** lists need real APIs |
| **Following writers** | `FollowingRepository` returns **mock** writers only (`lib/data/following_repository.dart`) |

### Learn (`lib/features/learn/**`)

| Area | Notes |
|------|--------|
| **Routes** | `/learn/:id`, vocab/grammar/quiz/listening — **catalog** gated via `learn_catalog_content_gate` / snapshot providers ([M4 closeout](M4_FULL_LEARN_CLOSEOUT_REPORT.md)) |
| **Social** | **No** like/bookmark on Learn tiles in scope for M7a; optional later **“save mono from Learn hub”** = same bookmark API |

### Auth (`lib/features/auth/**`)

| Area | Notes |
|------|--------|
| **JWT** | Bearer for owner + upload + published lists |
| **Guest** | Guest flows exist; **bookmark/react** should be **auth-gated** or **degraded** (see §7) |

---

## 3. Product Behavior Standard

### Bookmark / save mono

- **Authenticated user** can **save** a published mono to a **default Saved list** and optionally **named collections** (V1: single “Saved” + folders if product keeps current sheet UX).
- **Idempotent:** repeat POST no-ops or returns existing row.
- **Unsave:** DELETE removes membership (and from collections if modeled as join rows).

### Like / react

- **V1:** single **binary “react”** (heart) per user per mono — maps cleanly to **`likesCount`** and **`myReacted`**.
- **Future:** reaction types (👍❤️) → `reactionType` enum + aggregation.

### Share / copy link

- **Primary:** **Copy canonical URL** to clipboard (title + URL optional).
- **Not** default to copying **full story body** (current Mono `_share` behavior is wrong for product).

### Saved list

- **Profile** (or Mono tab) shows **saved monos** (paged), same cards as feed summary where possible.

### Public profile

- **Handle**, **display name**, **avatar**, **bio** from `UserProfile` (already in schema).
- **Published monos** list for that user **if** product exposes creator catalog (may reuse public endpoints or owner-scoped public view).

### Follow / unfollow (if in scope)

- **Optional M7e:** **follow** creator → **Following** feed filters `GET /v1/mono/feed?following=1` or dedicated endpoint returning monos by followed `writerId`s.
- **Unfollow:** DELETE edge.

**Out of scope for M7 (defer):** comments, DMs, notifications content from reactions, moderation dashboards.

---

## 4. Backend Data Model Proposal

**New tables** (names illustrative — align with Prisma naming conventions):

### `mono_bookmarks` (or `saved_monos`)

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID PK | |
| `userId` | UUID FK → `users.id` | CASCADE delete |
| `publishedMonoId` | UUID FK → `published_monos.id` | CASCADE delete |
| `createdAt` | DateTime | |

- **`@@unique([userId, publishedMonoId])`** — one saved row per user per mono (collection membership can be a **second** table if needed).
- **`@@index([userId, createdAt])`** — list “my bookmarks”.
- **`@@index([publishedMonoId])`** — optional aggregate counts.

### `mono_collections` + `mono_collection_items` (optional V1.1)

If product keeps **named folders**: collection belongs to `userId`; join table `(collectionId, publishedMonoId)` with unique pair. **M7a** can ship **Saved only** (single implicit collection) and add folders later.

### `mono_reactions`

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID PK | |
| `userId` | UUID FK | |
| `publishedMonoId` | UUID FK | |
| `createdAt` | DateTime | |
| `kind` | String or enum | V1: `'heart'` only |

- **`@@unique([userId, publishedMonoId])`** — one reaction per user per mono for V1.
- **`@@index([publishedMonoId])`** — `COUNT(*)` for `likesCount` (or maintain counter cache later).

### `mono_share_events` (optional)

Analytics-only: `id`, `userId` nullable (anonymous share), `publishedMonoId`, `channel` (`copy_link` | `system_share`), `createdAt`. **Not required** for MVP product behavior.

### `user_follows` (optional / M7e)

| Column | Type | Notes |
|--------|------|--------|
| `followerId` | UUID FK | |
| `followingId` | UUID FK | must ≠ `followerId` |
| `createdAt` | DateTime | |

- **`@@unique([followerId, followingId])`**
- **`@@index([followerId])`**, **`@@index([followingId])`**

**Uniqueness / integrity:** enforce mono exists and is **catalog-visible** (same `PUBLISHED_MONO_CATALOG_VISIBLE` predicate as feed) on write.

---

## 5. API Design

All **mutations** require **`JwtAuthGuard`** unless explicitly public. Use **idempotent** semantics where noted.

| Method | Path | Body | Behavior |
|--------|------|------|----------|
| **POST** | `/v1/mono/:monoId/bookmark` | optional `{ collectionId? }` | Create bookmark; 404 if mono invisible; 401 if anonymous |
| **DELETE** | `/v1/mono/:monoId/bookmark` | | Remove bookmark |
| **GET** | `/v1/me/bookmarks` | query: `cursor`, `limit` | Paged list of summary DTOs (reuse feed item shape or subset) |
| **POST** | `/v1/mono/:monoId/react` | optional `{ kind?: 'heart' }` | Upsert reaction |
| **DELETE** | `/v1/mono/:monoId/react` | | Remove reaction |
| **POST** | `/v1/users/:userId/follow` | | **M7e** — optional |
| **DELETE** | `/v1/users/:userId/follow` | | **M7e** |

**Public profile**

- Either extend **`GET /v1/mono/feed?writerId=`** or add **`GET /v1/users/:id/profile`** returning **profile fields + paged published summaries** (no JWT for **public** parts; rate-limit).

**Detail**

- **`GET /v1/mono/:monoId`** (existing): extend JSON with **`likesCount`**, **`isBookmarkedByMe`**, **`myReaction`** when request carries **optional JWT** (see §6).

---

## 6. Feed DTO / Counts

### List: `MonoFeedSummaryItemDto` (extend)

| Field | Source |
|-------|--------|
| `likesCount` | `COUNT(mono_reactions)` for `publishedMonoId` (or cached column later) |
| `bookmarksCount` | Optional; omit in V1 UI if not shown — **expensive** on list if N+1; prefer **detail only** or **materialized** later |
| `isBookmarkedByMe` | Subquery/join when `Authorization` present; **false** for guests |
| `myReaction` | `null` \| `{ kind: 'heart' }` when JWT present |
| `shareUrl` | **Computed** server-side from env **`NIMON_PUBLIC_WEB_BASE_URL`** + path template **`/mono/{monoId}`** (or app scheme) — avoids client guessing |

### Detail: `PublishedMonoDetailDto` or parallel envelope

Same fields as list for consistency; **`hasAudio`** should eventually be derived from **`content`** (fix placeholder `hasAudio: false` in feed mapper).

### Contract versioning

Add fields as **optional** in OpenAPI / consumer DTOs first, then require in app once shipped.

---

## 7. Flutter State Plan

### Optimistic UI

- On **react** / **bookmark** tap: flip **local state** immediately; fire **repository** mutation.
- On **4xx/5xx / network**: **rollback** notifier + **`SnackBar`** with retry.

### Auth required

- **Signed out:** tapping bookmark/react opens **login** or shows **“Sign in to save”** (match M5 cover upload pattern).

### Guest behavior

- **Read** catalog remains public; **no** persisted social state.

### Cache invalidation

- **Riverpod** providers: `monoFeedPagerProvider` epoch bump after bookmark/react if counts or `isBookmarkedByMe` shown on cards.
- **Detail:** `catalogPublishedMonoDetailProvider` / mono detail cache **invalidate** on success.
- **Profile saved tab:** dedicated `myBookmarksProvider` refetch on return.

### Replace `ValueNotifier` maps

- Move from ad-hoc `_bookmarkNotifiers` in `MonoScreen` to **per-item provider family** or **MapNotifier** keyed by `monoId` fed by **hydration** from API.

---

## 8. Share Plan

### Now (M7d)

- **`share_plus`** or **clipboard-only**: copy **`shareUrl`** from API or build from **`dart-define=NIMON_PUBLIC_WEB_BASE_URL`** + `/mono/{id}`.
- Snackbar: **“Link copied”** (localized).

### Later

- **Platform share sheet** (`share_plus`) with subject line (title) + URL.
- **Web:** `WebShareApi` when available.

### Deep link format

- Document **`https://{app-host}/mono/{uuid}`** (or custom scheme **`nimon://mono/{uuid}`** for mobile). **Fallback:** if no public web reader, share URL can point to **marketing page** + query `?open=mono&id=` for future App Links.

---

## 9. Profile Polish Plan

| Theme | Work |
|-------|------|
| **Account identity** | Ensure **register/login** sets **handle** / **displayName**; **edit profile** screen saves to **`UserProfile`** (verify existing `me` + PATCH if any). |
| **Public profile** | Wire **published list** from backend; **follower counts** if M7e ships. |
| **Saved / bookmarked** | New **Profile → Saved** (or Mono **Saved** tab) backed by **`GET /v1/me/bookmarks`**. |
| **Authored list** | Already **Published** for owner; public view uses **writer-scoped feed** or profile endpoint. |
| **Follow / following** | Replace **`FollowingRepository` mock** with real API; **Following** feed = monos from followed users (batch query or fan-out). |

---

## 10. Tests Needed

### Backend

- **Unit:** service rules — duplicate bookmark, delete missing, react toggle, invisible mono → 404.
- **Integration:** Prisma test DB or mocked repo — `likesCount` aggregation correct with 0/N rows.
- **Auth:** 401 without JWT on mutations.

### Flutter

- **Repository** mappers for new DTO fields.
- **Widget:** auth-gated snackbar; optimistic rollback (mock client).
- **Integration:** bookmark from Mono → appears in Saved list provider.

---

## 11. Risks / Scope Cuts

| Risk | Mitigation |
|------|------------|
| **Auth required** | Clear UX; no silent guest persistence |
| **Optimistic races** | Last-write-wins; refetch on screen focus |
| **Counts drift** | Server is source of truth; list may use stale counts until refresh |
| **No public web reader** | Share URL is **forward-looking**; document limitation |
| **Moderation / privacy** | Blocked users, private monos — **future**; M7 assumes **public catalog** only |
| **Performance** | Avoid `bookmarksCount` on **every** feed row in V1; use **detail** or **lazy** |

---

## 12. Recommended Implementation Split

| Phase | Deliverable |
|-------|-------------|
| **M7a** | Prisma models **`MonoBookmark`**, **`MonoReaction`**; services; **`POST/DELETE` bookmark + react**; **`GET /v1/me/bookmarks`**; extend feed/detail DTO with **`likesCount`**, **`isBookmarkedByMe`**, **`myReaction`**, **`shareUrl`**; fix **`hasAudio`** derivation (small related change) |
| **M7b** | Flutter **repositories + Riverpod**; **optimistic** react/bookmark; auth gates |
| **M7c** | **Profile Saved** screen + pager; wire **Following** data **or** stub until M7e |
| **M7d** | **Share** uses **URL** + optional **`share_plus`** |
| **M7e** | **`user_follows`** + follow API + **Following** feed (optional) |
| **M7f** | **Smoke checklist** doc + manual matrix (Web + mobile) |

---

## 13. Exact Cursor Prompt For M7a

Use when starting implementation (**backend bookmark + react only**; no Flutter in same PR if you want clean review boundaries).

```text
You are a senior NestJS + Prisma engineer on nimon-backend.

Task: Implement M7a — persisted **bookmark** and **react** (like) for **published monos**, plus **GET /v1/me/bookmarks** list. Extend public feed/detail DTOs with server-derived **likesCount**, **isBookmarkedByMe**, **myReaction**, and **shareUrl** (from env NIMON_PUBLIC_WEB_BASE_URL).

Constraints:
- Add Prisma models and a migration (user will run migrations separately if needed).
- Do NOT change PublishedMono JSON content shape for publish/read.
- Reuse PUBLISHED_MONO_CATALOG_VISIBLE — bookmark/react must 404 when mono is not catalog-visible.
- All bookmark/react mutations: JwtAuthGuard; optional JWT on GET feed/detail for “my” flags.

Goals:
1. Schema: MonoBookmark (userId, publishedMonoId, createdAt) @@unique([userId, publishedMonoId]); MonoReaction same unique for V1 single kind 'heart'.
2. Services: idempotent create/delete; list bookmarks paged (cursor by createdAt + id).
3. Controllers: POST/DELETE /v1/mono/:monoId/bookmark and /react; GET /v1/me/bookmarks.
4. MonoFeedService: likesCount = count reactions for row; isBookmarkedByMe/myReaction from optional userId; shareUrl = base + /mono/{id}.
5. Published mono detail mapper: same extensions when JWT optional.
6. Tests: Jest unit/integration for services + controller auth.

Commands: prisma migrate dev (user), jest, nest build.

Deliver: minimal diff, clear DTO fields documented in mono-feed.dto.ts.
```

---

## Output summary

| Question | Answer |
|----------|--------|
| **First M7 feature to build** | **M7a — backend `MonoBookmark` + `MonoReaction` tables, mutations, `GET /v1/me/bookmarks`, and real `likesCount` / `isBookmarkedByMe` / `myReaction` / `shareUrl` on feed + detail** |
| **Backend tables needed** | **`mono_bookmarks`** (and optional collections later); **`mono_reactions`**; optional **`mono_share_events`**, **`user_follows`** (M7e) |
| **APIs needed** | **POST/DELETE** `/v1/mono/:id/bookmark`, **POST/DELETE** `/v1/mono/:id/react`, **GET** `/v1/me/bookmarks`; optional follow + public profile extensions |
| **Flutter screens likely to change** | **`mono_screen.dart`** (rail + sheet → wired state), **profile** (Saved tab, replace mock **Following**), **share** helper; possibly **`mono_feed_summary_dto.dart`** / mappers |
| **Biggest risk** | **Feed performance** if every row joins current user + counts; mitigate with **indexed counts**, **avoid bookmarksCount on list in V1**, and **optional JWT** scope |
| **Recommended first implementation step** | Run **§13 M7a** backend slice; then **M7b** Flutter optimistic UI against real APIs |
