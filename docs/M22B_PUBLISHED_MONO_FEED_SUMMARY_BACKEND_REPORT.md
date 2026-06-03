# M22B — Published Mono Feed Summary Backend Report

Date: 2026-06-03  
Phase: Optimize `GET /v1/mono/feed` list query (no `content` JSONB select).

## Summary

Denormalized feed summary fields were added to `published_monos`, backfilled from existing `content` JSONB, wired into publish write paths, and used by `MonoFeedService.listFeed`. **`GET /v1/mono/:id` is unchanged** (still selects full `content`).

## Files modified

| File | Change |
|------|--------|
| `nimon-backend/prisma/schema.prisma` | Added 7 denormalized columns on `PublishedMono` |
| `nimon-backend/prisma/migrations/20260603120000_m22b_published_mono_feed_summary/migration.sql` | Add columns + SQL backfill |
| `nimon-backend/src/modules/published-monos/published-mono-feed-summary.ts` | **New** — extract summary from content/draft |
| `nimon-backend/src/modules/published-monos/published-mono-feed-summary.spec.ts` | **New** — unit tests |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.ts` | List select uses denormalized columns; removed `content` select + `extractContentMeta` |
| `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts` | Comment update |
| `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts` | Tests for select shape + denormalized fields |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` | Publish RO/FL writes summary columns with `content` |

## Denormalized columns added

| Column | Type | Notes |
|--------|------|--------|
| `coverImageUrl` | `String?` | From `content.core.coverImageUrl` |
| `publishKind` | `String?` | e.g. `read_only_v1`, `full_learn_v1` |
| `hasAudio` | `Boolean` default `false` | `learn.audio.storyAudio.sourceUrl` present |
| `sentenceCount` | `Int?` | `core.sentences` length |
| `vocabCount` | `Int?` | `learn.vocabularyKanji.entries` length |
| `grammarCount` | `Int?` | `learn.grammar.entries` length |
| `quizCount` | `Int?` | `learn.quiz.entries` length |

`content` JSONB **not removed**.

## Migration

- Path: `prisma/migrations/20260603120000_m22b_published_mono_feed_summary/migration.sql`
- Adds columns and **UPDATE** backfill using PostgreSQL JSONB paths (`#>>`, `jsonb_array_length`).

Run locally: `npx prisma migrate deploy` (or `prisma migrate dev`) then `npx prisma generate`.

## Publish path updated

`StoryDraftsService.buildPublishedMonoContentAndSummary()` sets denormalized fields whenever `published_monos.content` is written:

- `publishReadOnly` → `read_only_v1` update
- `publishFullLearn` → `full_learn_v1` update

## Feed query

- `MONO_FEED_LIST_PUBLISHED_MONO_SELECT` exported — **no `content: true`**
- `mapRowToSummary` reads `coverImageUrl`, `publishKind`, `hasAudio` from columns
- Response DTO unchanged (`MonoFeedSummaryItemDto`)

## Indexes

- Existing `@@index([contentLocale, learningLanguage, updatedAt])` retained (per M22A audit).
- **Not added:** global `(updatedAt desc, id desc)` index — feed already filters locale + visibility; recommend monitoring before a partial/catalog index in a later phase.

## Tests run

```bash
cd nimon-backend
npx prisma generate
npm test -- --testPathPattern="mono-feed|published-mono-feed-summary|story-drafts.service.spec"
```

*(Agent environment had no `npm` on PATH; run locally to confirm.)*

## Detail endpoint

`MonoFeedService.getPublicMonoById` — **unchanged**: still `select: { content: true, ... }`.

## Remaining risks

1. **Legacy rows** with empty/minimal `content` until next publish may have null counts until backfill migration runs.
2. **Manual DB edits** to `content` without republish won't refresh denormalized columns (same as any denormalized pattern).
3. **First publish create** (`publishedMono.create` with stub content) is immediately followed by update with full summary — create row may briefly lack summary until update in same transaction (only create path).
4. **Counts not exposed** in feed API yet — stored for future use / ops; DTO unchanged.
5. **Flutter** still lazy-loads detail — out of scope for M22B.

## Flutter / validation

- No Flutter changes (per scope).
- No publish validation rule changes.
- No import rule changes.

---

*End of M22B backend report.*
