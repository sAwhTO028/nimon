# M3b Mono Feed Flutter Foundation Report

**Date:** 2026-05-03  
**Scope:** Flutter data layer for public Mono catalog (`GET /v1/mono/feed`, `GET /v1/mono/:monoId`). **MonoScreen not wired** — mock UI unchanged per M3b.

---

## Files Changed

| Path | Purpose |
|------|---------|
| `lib/features/mono/data/mono_feed_summary_dto.dart` | `MonoFeedSummaryDto` + `fromJson` (defaults + `categories` fallback from `category`). |
| `lib/features/mono/data/mono_feed_repository.dart` | Abstract `MonoFeedRepository`. |
| `lib/features/mono/data/remote_mono_feed_repository.dart` | `RemoteMonoFeedRepository` — HTTP + optional auth merge. |
| `lib/features/mono/data/mono_feed_providers.dart` | `remoteMonoFeedRepositoryProvider`, `monoFeedPagerProvider`, `MonoFeedPager`. |
| `lib/features/create/data/remote_backend_config.dart` | `NIMON_USE_REMOTE_MONO_FEED` → `useRemoteMonoFeed` (default **false**). |
| `lib/core/pagination/pagination_defaults.dart` | `monoFeedPageLimit` (**15**, aligned with M3a backend default). |
| `test/features/mono/mono_feed_summary_dto_test.dart` | DTO tests. |
| `test/features/mono/remote_mono_feed_repository_test.dart` | Repository URL / mapping / detail / optional auth tests. |
| `test/features/mono/mono_feed_pager_test.dart` | Pager load / refresh / loadMore tests. |

---

## DTOs Added

- **`MonoFeedSummaryDto`** — fields: `monoId`, `title`, `coverUrl`, `level`, `category`, `categories`, `description`, `writerId`, `writerHandle`, `writerDisplayName`, `publishedAt`, `updatedAt`, `likesCount` (default **0**), `hasAudio` (default **false**), `publishKind`, `accessType` (default **`public`** when missing).

---

## Repository Added

- **`MonoFeedRepository`** — `fetchFeedPage(PageRequest, {level, category})` → `PageResult<MonoFeedSummaryDto>`; `fetchMonoDetail(monoId)` → **`PublishedMonoDetailDto`** (same shape as Profile owner detail / public M3a detail).
- **`RemoteMonoFeedRepository`** — `GET /v1/mono/feed` with `PageRequest.toQueryParameters()` after normalizing **`sort: recent`** and clamping **`limit`** to **1–30**. **`GET /v1/mono/:id`** for detail. **No required Authorization**; optional **`authHeaderBuilder`** merges Bearer when tokens exist (future personalization).

---

## Pager Added

- **`monoFeedPagerProvider`** / **`MonoFeedPager`** — `loadFirstPage`, `refresh`, `loadMore`; **`requestEpoch`** stale guards on first page + refresh; **`canLoadMore`** guards duplicate **`loadMore`** (matches [NIMON_REPOSITORY_PAGINATION_PATTERN.md](NIMON_REPOSITORY_PAGINATION_PATTERN.md) style).
- **`setFilters({level, category})`** — optional facet state for later **`MonoScreen`** wiring (M3c).

---

## Remote Feed Flag

- **`RemoteBackendConfig.useRemoteMonoFeed`** from **`--dart-define=NIMON_USE_REMOTE_MONO_FEED`** — default **`false`**. Not consumed by UI yet (M3c).

---

## Detail Fetch

- **`fetchMonoDetail`** calls **`GET /v1/mono/:monoId`** and maps to **`PublishedMonoDetailDto`** (same manual mapping as `RemotePublishedMonoRepository.get` for parser compatibility).

---

## Tests Added

| File | Coverage |
|------|----------|
| `test/features/mono/mono_feed_summary_dto_test.dart` | Full JSON row, defaults, `categories` fallback. |
| `test/features/mono/remote_mono_feed_repository_test.dart` | Query params, envelope → `PageResult`, detail path, optional auth. |
| `test/features/mono/mono_feed_pager_test.dart` | loadFirst, refresh, loadMore append, loadMore no-op when `!hasMore`. |

---

## Flutter Analyze Result

Command: `flutter analyze lib/features/mono/data lib/core/pagination/pagination_defaults.dart lib/features/create/data/remote_backend_config.dart test/features/mono`  
**Result:** **No issues found.**

---

## Flutter Test Result

| Scope | Result |
|-------|--------|
| `flutter test test/features/mono/` | **All passed** (**11** tests) |
| `flutter test` (full suite) | **All passed** (**113** tests) |

---

## Risks

| Risk | Mitigation |
|------|------------|
| **`PageRequest.sort`** vs backend **`recent`** | Repository forces **`sort: recent`** for mono feed calls. |
| **Duplicate epoch tests** | Profile pager has stale tests; Mono pager follows same epoch pattern — optional deeper async duplicate-load test in M3c. |

---

## Recommended Next Step

**M3c:** When **`RemoteBackendConfig.useRemoteMonoFeed`** is true, wire **`MonoScreen`** For You source to **`monoFeedPagerProvider`** (keep mock path when false); map **`MonoFeedSummaryDto`** → **`MonoFeedItem`** or parallel list model.

---

## Output Summary

| Question | Answer |
|----------|--------|
| DTO added? | **Yes** — `MonoFeedSummaryDto` |
| Remote repository added? | **Yes** — `RemoteMonoFeedRepository` |
| Pager added? | **Yes** — `MonoFeedPager` + `monoFeedPagerProvider` |
| Remote feed flag added? | **Yes** — `NIMON_USE_REMOTE_MONO_FEED` / `useRemoteMonoFeed` |
| MonoScreen untouched? | **Yes** |
| Tests passed? | **Yes** — mono **11**, full suite **113** |
| `flutter test` passed? | **Yes** |
| Next step M3c or fixes? | **M3c** — wire Mono Home to pager when flag on |
