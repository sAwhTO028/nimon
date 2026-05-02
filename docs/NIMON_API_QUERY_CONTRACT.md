# Nimon API Query Contract

**Purpose:** Normalize **pagination**, **filters**, and **DTO shapes** across Flutter repositories and **`nimon-backend`** (NestJS today).  
**Compatibility:** Existing `StoryRepo`/`StoryRepoMock` are **legacy-shaped** (`List<T>` without cursors)—new remote APIs **must** follow this contract; Flutter facades map pages into repositories.

---

## 1. Standard Paginated Response

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false,
  "totalCount": 128
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `items` | `array` | **yes** | See summary/detail DTOs below; **never embed learn/audio/quiz detail** inside list envelopes. |
| `nextCursor` | `string \| null` | **yes** | Opaque backend token (recommended: base64 of `(updatedAt,id)` or signed cursor). **`null`** when done. |
| `hasMore` | `boolean` | **yes** | Redundant with `nextCursor !== null`; both sent for tolerant clients. |
| `totalCount` | `number` | optional | Omit on expensive counts; expose only where UX needs “N results”. |

**Non-goals:** No `page`/`offset` for publicly scaled lists unless legacy exception—prefer **cursor** for stable paging under inserts.

---

## 2. Standard Request Params (Query or JSON Body Fragment)

| Param | Type | Description |
|-------|------|-------------|
| `limit` | `number` | Page size (**max** enforced server-side—see §3). |
| `cursor` | `string?` | Opaque pagination cursor; omit on first load. |
| `sort` | `string` | Canonical sort (`recent`, `popular`, `title`, …)—document enum per endpoint. |
| `level` | `string?` | JLPT / curated level slug (e.g. `N5`). |
| `category` | `string?` | Category slug aligned with Flutter `StoryCategory`/product list. |
| `query` | `string?` | Search substring (debounced client). |
| `ownerId` | `string?` | Scoped lists (published, drafts). |
| `status` | `string?` | `draft \| processing \| published \| archived` … |
| `accessType` | `string?` | `public \| followers \| private` … |
| `updatedAfter` | `ISO8601?` | Delta sync pattern (advanced). |

Validation: Unknown params **ignored** server-side OR return `400` with schema—pick one convention per service.

---

## 3. Limits (Recommended Defaults)

| Surface | Default `limit` | Max `limit` |
|---------|-----------------|-------------|
| Mono feed first page | 15 | 30 |
| Mono feed continuation | 15 | 30 |
| Profile published / saved / workspace | 20 | 50 |
| Collections | 24 | 60 |
| Vocab / Grammar / Quiz browse | 50 | 100 |
| Search | 20 | 50 |

Hard cap **512 KB** uncompressed JSON envelope per response (see performance budgets); truncate/fail politely if breached.

---

## 4. Summary DTOs (List Rows)

Summary objects **exclude** sentences, quiz bank, transcripts, grammar trees, furigana token arrays larger than teaser.

### 4.1 `MonoFeedSummaryDto`

```json
{
  "monoId": "uuid",
  "title": "...",
  "coverUrl": "https://...",
  "level": "N5",
  "categories": ["Love"],
  "likesCount": 120,
  "writerId": "...",
  "writerHandle": "@handle",
  "publishedAt": "2026-01-01T00:00:00Z",
  "hasAudio": false
}
```

### 4.2 `ProfilePublishedSummaryDto`

```json
{
  "monoId": "uuid",
  "title": "...",
  "coverUrl": "...",
  "level": "N4",
  "status": "published",
  "updatedAt": "..."
}
```

### 4.3 `SavedMonoSummaryDto`

```json
{
  "monoId": "uuid",
  "title": "...",
  "savedAt": "...",
  "coverUrl": "..."
}
```

### 4.4 `WorkspaceDraftSummaryDto`

```json
{
  "draftId": "uuid",
  "titleDraft": "...",
  "thumbnailUrl": "...",
  "level": "N3",
  "updatedAt": "...",
  "processingState": "idle"
}
```

### 4.5 `CollectionSummaryDto`

```json
{
  "collectionId": "uuid",
  "name": "...",
  "itemCount": 12,
  "coverUrls": [],
  "updatedAt": "..."
}
```

`coverUrls` capped (e.g. **max 4** URLs or empty—no full child list).

---

## 5. Detail DTOs (Drill-In)

Fetched **after** navigation or explicit prefetch window.

### 5.1 `MonoDetailDto`
Reader shell: headline metadata + **sentence page window** refs (pagination may apply inside reader).

### 5.2 `StorySentenceDto`
Japanese line, furigana tokens/ranges, optional translation keys, linkage ids.

### 5.3 `LearnModuleDetailDto`
Hub-level payload for one content id—not same as aggregated learn for every mono in feed.

### 5.4 `VocabularyDetailDto` / `GrammarDetailDto`
Full pedagogy payloads for learner screens—**never** inlined in summaries.

### 5.5 `QuizDetailDto`
Questions + options + explainers.

### 5.6 `ListeningDetailDto`
Audio URL/metadata, waveform optional, transcripts—**defer** unless module opened.

---

## 6. Index Recommendations (Backend)

Recommended composite / single indexes (adjust per Mongo/Postgres/Prisma schema):

| Key fields | Typical use |
|------------|---------------|
| `(status, updatedAt DESC, id)` | Draft workspace / moderator queues |
| `(ownerId, status, updatedAt DESC)` | Author published drafts |
| `(level, category, publishedAt DESC)` | Mono feed facets |
| `(accessType, publishedAt DESC)` | Public vs restricted catalog |
| `storyId` / `monoId` | FK drill-down |
| `(ownerId, query)` FTS | Search (vendor-specific extension) |

**AI jobs table** separate lifecycle—indexed by `(userId, status, createdAt)`.

---

## 7. AI Endpoints Separation

Normal list/detail REST **must never** enqueue OpenAI implicitly.

| Class | Routes |
|-------|--------|
| **Catalog** | `/mono/feed`, `/profile/...`, `/drafts`, `/collections` |
| **AI Assist** | `/ai/generate-*`, `/ai/jobs/:id`, `/ai/accept-draft` |

AI responses return **draft** artifacts only (`docs/NIMON_AI_FEATURE_PLAN.md`). Publishing uses canonical content APIs.

---

## 8. Error Handling & Retry

| Status | Flutter behavior |
|--------|-------------------|
| **400 / 422** | Map to field errors; **no** infinite retry |
| **401 / 403** | Re-auth UX |
| **404** | Invalidate local row optionally |
| **429** | Respect `Retry-After`; exponential backoff (**max cap**) |
| **5xx / network fail** | 1 immediate retry IF idempotent GET; backoff for writes |

Writes: prefer **optimistic UI** only when PATCH idempotency guarantees exist.

---

## Related

- `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`
- `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`
- Remote draft / published repos in Flutter today map onto these shapes incrementally—**StoryRepo stays** until replacement.
