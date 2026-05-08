# M3 Mono Feed Backend Integration Plan

**Status:** Plan / audit only (no code changes in this document).  
**Parent:** [NIMON_V1_RELEASE_PRIORITY_PLAN.md](NIMON_V1_RELEASE_PRIORITY_PLAN.md) — Mono feed / reader integration is **HIGH** priority; M1 auth and M2 remote authoring smoke are **complete**, so discovery should reflect **Postgres-backed `published_monos`**, not static seeds.

**Related:** [M2_REMOTE_AUTHORING_SMOKE_REPORT.md](M2_REMOTE_AUTHORING_SMOKE_REPORT.md), [M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md](M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md), [NIMON_API_QUERY_CONTRACT.md](NIMON_API_QUERY_CONTRACT.md), [NIMON_QUERY_PERFORMANCE_GUIDE.md](NIMON_QUERY_PERFORMANCE_GUIDE.md), [NIMON_PERFORMANCE_BUDGETS.md](NIMON_PERFORMANCE_BUDGETS.md), [NIMON_CACHE_AND_REFRESH_POLICY.md](NIMON_CACHE_AND_REFRESH_POLICY.md), [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md).

---

## 1. Current Mono Feed State

- **`MonoScreen`** (`lib/features/mono/mono_screen.dart`) builds the **For You** feed from a large **static in-memory list** (`_mockItems` → `_buildV1MonoMockItems()`). **Level** filtering (`N5` … `All`) is applied client-side to that list.
- **Following** uses **`_followingMockItems`**, derived from the same mock builders (handle/writer filters), not a server graph.
- **`StoryRepo`** is a **required constructor parameter** on `MonoScreen`, but **`widget.repo` is not referenced** in `mono_screen.dart` — the Mono home path does **not** load stories from `StoryRepo` / legacy APIs today.
- **Reader path:** Each `MonoFeedItem` can carry full **`MonoContent`** (structured sentences, ruby tokens) inline because mocks embed complete reader payloads. **Saved** tab seed ids / folder maps (`_seedSavedIds`, `_seedFolderByItemId`) are **demo-only** and documented as not wired to Profile folder persistence.
- **Profile → Published** is a **separate** path: it already uses **`RemotePublishedMonoRepository`** + cursor paging for **`GET /v1/published-monos`** (owner-scoped). Mono Home does **not** reuse that list.

---

## 2. Current Published Data State

- **Database:** `PublishedMono` in Prisma maps to **`published_monos`** — core columns (`title`, `category`, `level`, `description`) plus **`content` JSON** (core snapshot, publish kind, etc.). See `nimon-backend/prisma/schema.prisma`.
- **Backend module:** `nimon-backend/src/modules/published-monos/` — **`PublishedMonosController`** registers **`GET /v1/published-monos`** and **`GET /v1/published-monos/:id`** under **`JwtOrDevOwnerFallbackGuard`**.
- **`PublishedMonosService.listPublishedMonos(ownerId, …)`** is explicitly **“Profile / my published”** — **`where: { ownerId }`**, ordered by `updatedAt` desc. Response DTO matches **`publishedMonoListItemFromRow`** (summary fields + **`contentSummary`** derived from JSON); **note:** the current list query **`select`s `content`** from Prisma for every row (mapper strips heavy fields for JSON output but **DB still reads full JSON** per row — acceptable for small lists; **public feed at scale** should **avoid selecting full `content`** for list endpoints — see §8).
- **Pagination:** List handler accepts **`limit`** only today; service returns **`nextCursor: null`** (no cursor continuation yet). Flutter **`PageRequest` / `PageResult`** path exists for Profile and maps query params when the API gains **`cursor` + `hasMore`**.
- **DTOs:** Flutter **`published_mono_dto.dart`** aligns with list/detail payloads; **`PublishedMonoListItemDto`** is the closest existing shape to **`MonoFeedSummaryDto`** from the query contract (field names differ slightly — mapping layer in M3).
- **Owner vs catalog:** **`/v1/published-monos`** is **not** a public discovery API — it returns **only the authenticated user’s** published rows (JWT `sub`). That is correct for Profile but **insufficient** for Mono Home, which must show **other users’** published work unless the product intentionally limits the feed to “my content only” (not the stated goal).

---

## 3. Product Requirement

- **Published content must appear in Mono Home** as **read-ready** after publish: users discover stories in the **same app shell** they use to create, without relying on mock ids.
- **Read path:** Feed cards show **summary** metadata only; opening a mono loads **detail** (full `content` for reader parsing / Learn gating) per [NIMON_QUERY_PERFORMANCE_GUIDE.md](NIMON_QUERY_PERFORMANCE_GUIDE.md).
- **Consistency:** Align with [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md) — **`published_monos`** is the reader-visible snapshot; drafts remain non-catalog.

---

## 4. API Design

**Recommended primary route (wireframe + query contract alignment):**

- **`GET /v1/mono/feed`** — public or optionally authenticated catalog.

**Alternate name** (if routing prefers resource grouping):

- **`GET /v1/catalog/monos`** — behavior identical; pick **one** canonical path and document redirects if both exist temporarily.

**Standard envelope:** [NIMON_API_QUERY_CONTRACT.md](NIMON_API_QUERY_CONTRACT.md) §1 — `{ items, nextCursor, hasMore, totalCount? }`.

**Query parameters (contract §2):**

| Param | Purpose |
|-------|---------|
| **`limit`** | Page size — default **15**, max **30** ([NIMON_PERFORMANCE_BUDGETS.md](NIMON_PERFORMANCE_BUDGETS.md)). |
| **`cursor`** | Opaque token for stable paging (e.g. encode `(updatedAt, id)`). |
| **`sort`** | Start with **`recent`** (`updatedAt` or `createdAt` desc — product choice); **`popular`** deferred until counts exist. |
| **`level`** | JLPT slug (`N5` …) or `All` omission. |
| **`category`** | Slug aligned with creator **`StoryCategory`**. |
| **`query`** | Substring search on title/description (optional V1.1; debounced client). |

**Summary DTO:** **`MonoFeedSummaryDto`** (contract §4.1) — **`monoId`, `title`, `coverUrl`, `level`, `categories`, `likesCount`, `writerId`, `writerHandle`, `publishedAt`, `hasAudio`**. Map from DB via **`UserProfile`** (`handle`, `displayName`) and **`published_monos`** columns / JSON teasers. **Do not** embed sentences, learn payloads, or full `content` in list items.

**Detail endpoints (reader):**

- **`GET /v1/mono/:monoId`** or **`GET /v1/catalog/monos/:monoId`** returning **`MonoDetailDto`** / existing **`PublishedMonoDetailDto`**-compatible payload with **full `content` JSON** for `published_mono_detail_parser` / reader shell.
- **Critical:** Today **`GET /v1/published-monos/:id`** is **owner-scoped**. Any user opening another author’s mono from the **public feed** needs a **reader-authorized** GET (public mono by id) — either new route or relaxed guard with **visibility rules** (see §9).

**Tabs (future):**

- **For You:** default feed query above; later **personalized** ranking when optional JWT is present.
- **Following:** **out of scope for M3 data** unless follow graph ships — keep **mock subset** or empty state with honest UX until follow APIs exist ([NIMON_V1_RELEASE_PRIORITY_PLAN.md](NIMON_V1_RELEASE_PRIORITY_PLAN.md)).

---

## 5. Backend Implementation Plan

- **New module:** e.g. **`MonoFeedModule`** (or **`CatalogModule`**) with **`MonoFeedController`** + **`MonoFeedService`** — keeps **`PublishedMonosModule`** focused on **owner** CRUD/list for Profile.
- **Query:** `prisma.publishedMono.findMany` with **`where`** appropriate for **public catalog** (see §9 — today schema has **no `accessType` / `visibility`** column; V1 may define **“all rows in `published_monos` are public catalog”** until a migration adds flags).
- **Exclude drafts:** Drafts live in **`story_drafts`**; **`published_monos`** rows are already publish snapshots — no extra draft filter unless soft-delete / unpublish is modeled later.
- **Public visibility:** Document explicit rule (e.g. “every published mono is discoverable”) or add **`visibility: 'public'`** in JSON until schema migration — product/legal gate.
- **Auth optional:** **`GET /v1/mono/feed`** can be **anonymous** for read-only catalog; pass **optional JWT** for future **personalized** sort / geo. Do **not** reuse **`JwtOrDevOwnerFallbackGuard`** as the only guard if that would imply owner impersonation in prod ([M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md](M2_REMOTE_AUTHORING_RELEASE_MODE_PLAN.md)).
- **Pagination:** Cursor-based **`updatedAt` + `id`** ordering; return **`hasMore`** + **`nextCursor`**; avoid OFFSET for large tables ([NIMON_API_QUERY_CONTRACT.md](NIMON_API_QUERY_CONTRACT.md)).
- **List projection:** **`select`** columns needed for summary + **minimal JSON** (e.g. parse `content.core` only if stored nested) — **avoid `select: { content: true }` for full blob** on list if payloads grow ([NIMON_QUERY_PERFORMANCE_GUIDE.md](NIMON_QUERY_PERFORMANCE_GUIDE.md) §3.1).
- **Indexes:** Contract §6 suggests **`(level, category, publishedAt desc)`** — add when filters are live; **`(ownerId, updatedAt)`** already exists on `published_monos`.
- **Tests:** Nest unit tests for service (filter combinations, cursor stability, empty page); e2e optional; guard tests for **public vs authenticated** behavior.

---

## 6. Flutter Implementation Plan

- **`MonoFeedRepository`** (abstract + **`RemoteMonoFeedRepository`**) — **`fetchPage(PageRequest)`** → **`PageResult<MonoFeedSummary>`** (new thin model or reuse fields mapped to existing **`MonoFeedItem`** with nullable **`content`** until detail load).
- **Reuse** **`PageRequest` / `PageResult`** (`lib/core/pagination/`) and the same **in-flight / stale-completion** patterns as Profile published ([NIMON_REPOSITORY_PAGINATION_PATTERN.md](NIMON_REPOSITORY_PAGINATION_PATTERN.md) if present).
- **Riverpod:** dedicated **`monoFeedPagerProvider`** (or similar) — **not** the same notifier as Profile Published to avoid invalidation coupling ([NIMON_CACHE_AND_REFRESH_POLICY.md](NIMON_CACHE_AND_REFRESH_POLICY.md) §8 publish → refresh **first page** of Mono feed only).
- **`MonoScreen` wiring:** Replace **`_mockItems`** / **`_forYouFilteredItems`** source when **remote feed flag is on**; keep **mock fallback** when flag off for offline UI / design work.
- **Compile-time flag:** e.g. **`NIMON_USE_REMOTE_MONO_FEED`** (mirrors remote drafts pattern in **`remote_backend_config.dart`**) — document alongside M2 defines in release notes.
- **Strict behavior:** If **`NIMON_STRICT_REMOTE_DRAFTS`** applies globally to remote repositories, align Mono feed errors with **strict 401** bridge ([AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md](AUTH_ACCOUNT_M1D_IMPLEMENTATION_REPORT.md)) — or scope strict flag to “remote authoring” only to avoid blocking guests browsing catalog (product decision).
- **Reader detail:** On row tap, **`GET` detail** by **`monoId`** (new public reader endpoint); map to **`MonoFeedItem`** / **`MonoContent`** via existing **`published_mono_detail_parser`** paths used from Profile.

**Files likely to touch (implementation phase):**

- `lib/features/mono/mono_screen.dart` — data source + paging UI (`loadMore`, refresh).
- **New:** `lib/features/mono/data/mono_feed_repository.dart` (or under `lib/features/mono/data/`).
- **New:** providers under `lib/features/mono/` or `lib/core/providers/`.
- `lib/features/create/data/remote_backend_config.dart` — feed flag(s).
- `lib/main.dart` — optional provider overrides / repo injection.
- Reuse **`published_mono_detail_parser.dart`** / reader navigation patterns from Profile where possible.

---

## 7. Reader / Detail Readiness

- **Feed list:** Bind cards to **summary only** — **no** sentence arrays, **no** full furigana token lists ([NIMON_QUERY_PERFORMANCE_GUIDE.md](NIMON_QUERY_PERFORMANCE_GUIDE.md)).
- **Detail fetch:** After navigation, load **`content`** JSON from **detail endpoint**; parse into **`MonoContent`** for **`NimonRubyText` / sentence blocks** — same canonical shape as Profile-published open.
- **Japanese / furigana / meaning:** Handled in existing reader pipeline from **`content.core`** pages — **regression-test** one published mono from feed → reader parity with Profile → Published.
- **Learn button gating:** **`PublishedMonoAccess`** / **`displayPublishKind`** (`read_only` vs `full_learn`) must flow from summary or detail so **`_openLearn`** behavior matches Profile (`lib/features/profile/data/published_mono_display_contract.dart`).
- **Guest vs signed-in:** Catalog read may be **guest-accessible**; Learn modules may still require auth — unchanged product rules, but **call out** in QA.

---

## 8. Performance / Cache Policy

- **Page size:** Default **15**, max **30** ([NIMON_PERFORMANCE_BUDGETS.md](NIMON_PERFORMANCE_BUDGETS.md)).
- **No learn payload in feed** — Learn loads only after navigation ([NIMON_QUERY_PERFORMANCE_GUIDE.md](NIMON_QUERY_PERFORMANCE_GUIDE.md) §3.2–3.3).
- **Pull-to-refresh:** Bypass TTL; **SWR** — show cached rows while refreshing ([NIMON_CACHE_AND_REFRESH_POLICY.md](NIMON_CACHE_AND_REFRESH_POLICY.md) §4–5).
- **Load more:** Append next cursor page; **in-flight guard** per cursor key.
- **Optimistic counters:** **`likesCount`** may be **0** until reactions ship — **patch row** later per cache matrix §7.
- **Stale-while-revalidate:** Feed TTL **30–120 s** guideline ([NIMON_CACHE_AND_REFRESH_POLICY.md](NIMON_CACHE_AND_REFRESH_POLICY.md) §3); **invalidate subset** on publish (§8).
- **Envelope size:** Stay under **512 KB** per response ([NIMON_PERFORMANCE_BUDGETS.md](NIMON_PERFORMANCE_BUDGETS.md)).

---

## 9. Risks

| Risk | Notes |
|------|--------|
| **Public vs owner-scoped confusion** | **`/v1/published-monos`** is **my content**; **`/v1/mono/feed`** must be **catalog**. Different guards and DTOs to avoid leaking private drafts. |
| **Existing `/v1/published-monos` owner-only** | Profile stays owner-scoped; **do not** “widen” it for discovery — add **separate** feed + **public detail** read. |
| **Mock replacement** | Removing mocks without a flag breaks **design / offline** demos — keep **`NIMON_USE_REMOTE_MONO_FEED=false`** path until stable. |
| **Content JSON shape** | **`content`** blobs vary by publish kind; parser must tolerate **partial** pages — golden tests on real API payloads. |
| **Auth optional for catalog** | Product must decide: **anonymous browse** vs **login-required feed** — affects guards, SEO, and strict-mode UX. |
| **Current list reads full `content` in SQL** | Owner list is small today; **feed** must use **slimmer projection** to avoid table scans shipping huge JSON. |
| **Writer display** | **`UserProfile.handle`** may be null — fall back to **`displayName`** / anonymized **`writerId`** slice for cards. |

---

## 10. Recommended M3 Implementation Milestones

| Milestone | Scope |
|-----------|--------|
| **M3a** | Backend **`GET /v1/mono/feed`** (+ summary projection, cursor, filters baseline), **`GET /v1/mono/:id`** or public **`published_mono` by id** for reader — **unit tests**. |
| **M3b** | Flutter **`MonoFeedRepository`** + pager provider + **`PageRequest`** tests / mapper tests. |
| **M3c** | **`MonoScreen`** For You wired to remote pager; **mock fallback** behind flag; **loadMore** + pull-to-refresh. |
| **M3d** | Reader detail from feed **parity** with Profile (Learn gating, structured content). |
| **M3e** | **`docs/M3_MONO_FEED_SMOKE_REPORT.md`** (or extend QA checklist) — Postgres seed → publish → appears on Mono Home → open reader. |

---

## 11. Exact Cursor Prompt For M3a

Use when moving from **plan** to **backend code** (feed endpoint only):

```text
Implement M3a: public Mono catalog feed API in nimon-backend only.

Goal:
- Add GET /v1/mono/feed with cursor pagination (limit default 15, max 30), sort=recent,
  optional level and category query params matching docs/NIMON_API_QUERY_CONTRACT.md.
- Response shape: { items, nextCursor, hasMore } with items matching MonoFeedSummaryDto
  field semantics (map from published_monos + user_profiles for writerHandle).
- Query published_monos only (published snapshots). Do not expose story_drafts.
- List endpoint must NOT select full content JSON blobs — summary fields + teaser only;
  add GET /v1/mono/:monoId (or GET /v1/catalog/monos/:monoId) for full PublishedMono-style
  detail for readers (public read by id), separate from owner-scoped GET /v1/published-monos/:id.
- Use a guard appropriate for public read (no JwtOrDevOwnerFallback for anonymous catalog);
  optional JWT may be accepted later for personalization — stub optional auth if easy.
- Add PublishedMonosService-style mappers in a new MonoFeedModule (or CatalogModule).
- Unit tests for MonoFeedService: paging, filters, empty result, cursor continuation.

Constraints:
- Do not change Flutter in this task.
- Do not run prisma migrations unless a new index is strictly required — if schema change
  is needed, document in PR and defer migration to a separate review.
- Do not modify story-drafts module behavior.

Verify: npm test (Nest); manual curl against local Postgres with at least one published_monos row.
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Recommended feed endpoint** | **`GET /v1/mono/feed`** (alternate: **`GET /v1/catalog/monos`**) |
| **Backend module to add** | **`MonoFeedModule`** (or **`CatalogModule`**) with **`MonoFeedService` + `MonoFeedController`** — keep **`PublishedMonosModule`** owner-focused |
| **Owner-only vs public** | **`/v1/published-monos`** remains **owner-scoped** (Profile); **new `/v1/mono/feed` + public detail by id** serve **catalog + readers** |
| **Flutter files likely to change** | **`mono_screen.dart`**, **new `mono_feed_repository` + providers**, **`remote_backend_config.dart`**, possibly **`main.dart`** |
| **Biggest risk** | **Public reader detail** + **catalog list** require **new routes/guards** — reusing owner-only **`GET /v1/published-monos/:id`** cannot serve **other users’** monos from the feed |
| **First implementation step** | **M3a:** ship **`GET /v1/mono/feed`** + **public detail GET** with tests and slim SQL projections |
