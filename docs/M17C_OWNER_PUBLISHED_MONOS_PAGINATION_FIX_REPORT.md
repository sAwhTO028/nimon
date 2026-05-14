# M17C Owner Published Monos Pagination Fix Report

## Final root cause timeline

### 1. Original bug

Owners viewing **Own Profile → Published → Monos** saw only **20** rows when **21** (or more) published monos existed. The first slice fit in one response, but there was **no reliable way to continue**: **`GET /v1/published-monos`** did not yet expose a continuation contract the app could trust, so **`loadMore`** never advanced.

### 2. M17C pagination implementation

**Backend:** **`GET /v1/published-monos`** gained **cursor** pagination (`limit`, opaque **`cursor`**, stable ordering) and response fields **`hasMore`**, **`nextCursor`**, and **`totalCount`** (first non-trash page).

**Flutter:** **`ProfilePublishedMonoPager`**, **`RemotePublishedMonoRepository.fetchPage`**, and **`PageRequest`**-driven **`loadMore`** were added.

Later, the **real UI** often showed only **10** rows: the owner list adopted **`PaginationDefaults.profilePublishedMonoPageLimit` (10)**, but **`loadMore`** still did not always run. Scroll hooks that depended on **`ScrollUpdateNotification`** and “near bottom” logic **did nothing** when the first page **did not overflow** the viewport (**`maxScrollExtent`** small or zero). Pagination needed **scroll metrics + post-frame attachment + underscroll / short-list prefetch + a bottom sentinel** so pages 2 and 3 were requested without requiring the user to hit an exact scroll threshold.

### 3. Real metadata confusion (device)

On device, logs sometimes showed **`hasMore=false`**, **`nextCursor=null`**, **`totalCount=null`** even while the Flutter parser already supported envelopes and aliases. The **runtime** root cause was an **old backend process still serving HTTP on port 3000** (the app’s API base), so the phone hit **pre-M17C behavior** while the repo already contained the new handler.

After a **clean stop of the stale process and restart** of the intended backend on that port, metadata matched the contract.

**Correct first-page log after restart:** **`items=10`**, **`hasMore=true`**, **`nextCursor` set**, **`totalCount=21`**.

### 4. Final remaining test issue (widget harness)

Owner-profile **underscroll prefetch** can **chain page 3 immediately after page 2** completes—the same pattern as a fast device. **`profile_published_monos_owner_ui_pagination_test.dart`** originally expected **exactly 20** pager items and **`httpCalls == 2`** at a fixed intermediate phase, which **raced** with chained prefetch.

**Fix in tests (not product):** wait until **`items.length >= 20`**, allow **`httpCalls >= 2`** during that window, call **`page3Gate.complete()`** only if the gate is not already completed, then assert **final** **`items.length == 21`** and **`httpCalls == 3`**.

### 5. Final expected behavior

- **Published** header shows **21** (label prefers **`totalCount`** when present).
- **First GET:** **`limit=10`** → **10** rows; **`hasMore=true`**, **`nextCursor`** set, **`totalCount=21`**.
- **Second GET:** includes **`cursor`** from page 1 → **10** more rows (**20** cumulative); **`hasMore=true`** and **`nextCursor`** until the last partial page.
- **Third GET:** includes **`cursor`** from page 2 → **1** row (**21** cumulative); **`hasMore=false`**, **`nextCursor`** null.
- **No duplicates** (pager appends with **dedupe by `id`**).
- **Public profile** code paths were **not** modified for this workstream.

### 6. Final verification

```text
flutter test test/features/profile/profile_published_monos_scroll_prefetch_test.dart
flutter test test/features/profile/profile_published_monos_owner_ui_pagination_test.dart --dart-define=NIMON_USE_REMOTE_DRAFTS=true
flutter test test/features/profile
flutter test test/features/profile/profile_published_pagination_test.dart
```

**Backend:**

```text
cd nimon-backend
node node_modules/jest/bin/jest.js src/modules/published-monos --runInBand
node node_modules/@nestjs/cli/bin/nest.js build
```

(With **`pnpm`** on **`PATH`**: **`pnpm jest src/modules/published-monos --runInBand`** and **`pnpm nest build`**. A full **`pnpm jest --runInBand`** run is recommended before release.)

---

## Operational note

If phone logs show **`hasMore=false`** / **`nextCursor=null`** / missing **`totalCount`** again for an account that should paginate, **first** check for a **stale backend process still bound to the API port (commonly 3000)** and confirm **M17C runtime logs** and response shape after a clean restart **before** changing Flutter parsing or UI.

---

## Problem

Owners with **more than 20** published monos only saw **20** rows on **Profile → Published → Monos**. The Flutter pager already used `PaginationDefaults.profilePageLimit` (20) and `PageRequest` / `fetchPage`, but **`GET /v1/published-monos` always returned `nextCursor: null`** with no `hasMore`, so **`loadMore` never had a cursor** and page 2 never loaded. Public profile monos used **`/v1/mono/feed`** with a real cursor contract and was unaffected (M17A audit).

## Scope

- **Backend:** `GET /v1/published-monos` list only (owner-scoped, including `trashed=true` path on the same handler).
- **Flutter:** `RemotePublishedMonoRepository.fetchPage`, `ProfilePublishedMonoPager`, and tests under `test/features/profile/profile_published_pagination_test.dart`.
- **Explicitly not changed:** public profile UI/nested layout, public profile monos notifier, M17B identity layout, auth, validation, create shell, arbitrary limit-only “fixes”.

## Root Cause

1. **Backend** returned a full slice up to `take` with **no continuation token** and **no `hasMore`**.
2. **Flutter** `RemotePublishedMonoRepository` and pager were already cursor-ready; **`hasMore` defaulted to false** when absent, so the UI never requested the next page.

## Backend Contract

**Request**

`GET /v1/published-monos?limit=<n>&cursor=<opaque>&sort=<optional>&trashed=<optional>`

- **`limit`:** optional; default **20**; clamped **1–50**.
- **`cursor`:** optional; opaque **base64url JSON** `{ "u": "<ISO8601 updatedAt>", "i": "<publishedMono id>" }` — **same shape as** `MonoFeedService` / public feed cursors for consistency.
- **`sort`:** optional; allowed values: **empty**, `latest`, `recent` (all map to **`updatedAt` desc, `id` desc**). Other values → **400 `unsupported_sort`**.
- **`trashed`:** unchanged (`true` / `1` / `yes` → trash list).

**Response**

```json
{
  "items": [ /* PublishedMonoListItemDto[] */ ],
  "nextCursor": "<string> | null",
  "hasMore": true,
  "totalCount": 21
}
```

- **`hasMore`:** `true` when another page exists (implementation uses **`limit + 1`** fetch, same pattern as mono feed).
- **`nextCursor`:** last row of the returned page (when `hasMore` is true).
- **`totalCount`:** optional; set on the **first** page of the **non-trash** list only (`!trashed && !cursor`), for owner header `20+` / exact count UX. Omitted on continuation pages and on trash-only lists.

**Ordering:** `[{ updatedAt: 'desc' }, { id: 'desc' }]` — stable and aligned with existing public feed ordering.

**Visibility:** unchanged `PUBLISHED_MONO_CATALOG_VISIBLE` for active list; trashed list still `trashedAt != null` only.

## Flutter Integration

- **`PaginationDefaults.profilePublishedMonoPageLimit` (10)** for **`ProfilePublishedMonoPager`** only (Saved / followers still use **`profilePageLimit`**).
- **`fetchPage`** unchanged in signature; query already includes `cursor` + `limit` + `sort` via `PageRequest.toQueryParameters()`.
- **`ProfilePublishedMonoPager.loadMore`:** appends rows **deduped by `id`**; on **`loadMore` failure**, existing **`items` / `nextCursor` / `hasMore`** are left intact and **`error`** is set (retry after **pull-to-refresh** clears state via `refresh()`).

## Count Consistency

- **`publishedCountLabelForOwnerHeader`** already prefers **`totalCount`** when present, else **`n+`** when **`hasMore`**, else exact **`n`** after all pages are loaded.
- **Public profile** code paths were not modified.

## Tests Added

**Backend (`published-monos.service.spec.ts`)**

- First page: 21 rows mocked → **20 items**, **`hasMore`**, **`nextCursor`**, **`totalCount`**.
- **M17C-2:** **`limit=10`**, 21 rows → **three pages** (`10+10+1`), **`hasMore`** / **`nextCursor`** per stage, **`totalCount`** only on first page.
- Second page via cursor → remaining rows, **`hasMore` false**, no duplicate ids across pages.
- **`totalCount`**: `count` invoked only once (first page).
- **Invalid cursor** → `BadRequestException`; **unsupported `sort`** → `BadRequestException`.
- No-cursor call uses **`take: 21`** (limit 20 + probe row).
- Existing tests updated for **`count`**, **`hasMore`**, **`orderBy`**, and **`take`**.

**Flutter (`profile_published_pagination_test.dart`)**

- HTTP mock: three pages **`limit: 10`** for **21** items (`10 + 10 + 1`).
- Pager end-to-end with same mock (three `fetchPage` calls).
- **`loadMore` dedupes** duplicate ids.
- **`loadMore` failure** preserves first page + cursor.
- **Concurrent `loadMore`** while in flight does not spawn extra fetches.

**Flutter (`profile_published_monos_scroll_prefetch_test.dart`)**

- `profilePublishedMonosShouldPrefetchNextPage` — zero extent, near bottom, short-scroll + `hasMore`, long-scroll guard, horizontal axis.

**Flutter (`profile_published_monos_owner_ui_pagination_test.dart`)**

- Runs with **`--dart-define=NIMON_USE_REMOTE_DRAFTS=true`** (skipped in default `flutter test` without the define): asserts **3** HTTP calls and **21** pager rows via real **`ProfileScreen`** wiring.

## Commands run

**Primary verification:** see **[§6 Final verification](#6-final-verification)** in the timeline above (`flutter test` targets, **`published-monos`** Jest, **`nest build`**).

**Additional commands used during development:**

```text
dart format lib/features/profile/presentation/providers/profile_published_mono_pager.dart \
  lib/features/profile/data/remote_published_mono_repository.dart \
  test/features/profile/profile_published_pagination_test.dart

flutter analyze lib/features/profile/presentation/providers/profile_published_mono_pager.dart \
  lib/features/profile/data/remote_published_mono_repository.dart

flutter test test/features/profile/profile_published_pagination_test.dart \
  test/features/profile/public_profile_identity_visibility_test.dart \
  test/features/profile/public_profile_monos_pagination_test.dart

flutter test
```

**Backend (full Jest suite — optional beyond §6):**

```text
cd nimon-backend
node node_modules/jest/bin/jest.js --runInBand
```

**Backend (equivalent with `pnpm` when available):**

```text
cd nimon-backend
pnpm jest src/modules/published-monos --runInBand
pnpm jest --runInBand
pnpm nest build
```

## M17C-2 Real UI Follow-up

### Problem (phone)

Own Profile → Published → Monos still capped at the **first page** in real builds even when the backend returned **`hasMore` + `nextCursor`**: the list’s **`NotificationListener` only handled `ScrollUpdateNotification`**, and returned early when **`maxScrollExtent <= 0`**. When the first page does **not** overflow the viewport (common on tall phones with 10–20 rows), the user never scrolls, so **`loadMore()` was never called**.

### Scope

- **Flutter:** `_FolderGroupList` Published Monos scroll hook, dedicated page size **`PaginationDefaults.profilePublishedMonoPageLimit` (10)** for **`ProfilePublishedMonoPager`**, debug logging on first load + `fetchPage` (debug builds).
- **Backend:** Jest coverage for **`limit=10`** with **21** rows → three pages.
- **Tests:** scroll-prefetch predicate unit tests; optional widget test when **`NIMON_USE_REMOTE_DRAFTS=true`** (see below).

### Root cause

Undersized scroll extent (`maxScrollExtent == 0`) ⇒ no “near bottom” scroll updates ⇒ **no automatic pagination** despite `hasMore: true`.

### Fix

1. **`profile_published_monos_scroll_prefetch.dart`:** `profilePublishedMonosShouldPrefetchNextPage` — near bottom, **`maxScrollExtent <= 0`**, and (when **`hasMoreFromApi`**) **short scroll range** at top (`maxScrollExtent < viewport * 2.2`, `pixels <= 8`) so page 3 loads without user drag.
2. **`_FolderGroupList`:** `NotificationListener<Notification>` for **`ScrollUpdateNotification`** + **`ScrollMetricsNotification`**; **`ScrollController`** + post-frame **`didUpdateWidget`** hook; passes **`hasMore`** from **`onPublishedLoosePagerHasMore`**.
3. **Page size:** **`PaginationDefaults.profilePublishedMonoPageLimit = 10`** for **`ProfilePublishedMonoPager`** only.

### Phone verification (manual)

1. Run app **debug** on device; open Own Profile → Published → Monos.
2. In console, confirm **`RemotePublishedMonoRepository.fetchPage: GET /v1/published-monos`** with **`limit=10`** (first and subsequent pages).
3. Confirm JSON log line includes **`hasMore`**, **`nextCursor` (set/null)**, **`totalCount`** on first page.
4. Confirm **`[Profile Published] after pager loadFirstPage`** line includes **`hasMore`**, **`nextCursor`**, **`totalCount`**.
5. If responses show **`hasMore: false`** and **`nextCursor: null`** with 21 monos, the device is likely hitting a **stale backend** on the API port — see **[Operational note](#operational-note)**; fix process / base URL before changing Flutter.

### Widget test note

`test/features/profile/profile_published_monos_owner_ui_pagination_test.dart` is **`skip: !RemoteBackendConfig.useRemoteDrafts`**. To execute it locally:

```text
flutter test test/features/profile/profile_published_monos_owner_ui_pagination_test.dart --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

### Part G checklist (M17C-2)

| Question | Answer |
|----------|--------|
| Actual phone HTTP response checked? | **Manual** (see steps above); automated test optional with `dart-define`. |
| Backend response has `hasMore` / `nextCursor`? | **Yes** when on current API (unchanged from M17C). |
| First page size is 10? | **Yes** (`profilePublishedMonoPageLimit`). |
| Actual Profile screen uses pager? | **Yes** (unchanged wiring; `RemoteBackendConfig.useRemoteDrafts`). |
| `loadMore` on real scroll / short list? | **Yes** — metrics + underscroll prefetch. |
| 21st item visible in owner profile? | **Yes** after prefetch / scroll (with updated backend). |
| No duplicates? | **Yes** (pager dedupe unchanged). |
| Public profile untouched? | **Yes**. |
| Public profile identity still passes? | **Run** `flutter test test/features/profile/public_profile_identity_visibility_test.dart` in CI. |
| Backend tests passed? | **Run** `node node_modules/jest/bin/jest.js src/modules/published-monos --runInBand`. |
| Profile tests passed? | **Run** `flutter test test/features/profile`. |

## Risks

- **Cursor / sort strictness:** invalid cursor or unsupported `sort` now returns **400** (Flutter strict mode would surface errors; normal app uses valid cursors from prior responses and default `sort`).
- **`totalCount`:** extra **`COUNT(*)`** on first page of the active list only; bounded by owner scope and index usage on `published_monos`.
- **Lexicographic `id` tie-break:** uses string **`lt`** on UUID text, consistent with existing **`mono-feed`** cursor logic.

---

## M17C-4 Metadata Contract Fix

Wire contract for **`GET /v1/published-monos?limit=10&sort=latest`** (first page, 21 matching rows): **`items.length == 10`**, **`hasMore: true`**, **`nextCursor` non-null**, **`totalCount: 21`**. Continuation pages omit **`totalCount`**; **`hasMore` / `nextCursor`** follow the **`limit + 1`** probe.

**Backend (this repo):** `PublishedMonosController.list` → `PublishedMonosService.listPublishedMonos` (`nimon-backend/src/modules/published-monos/published-monos.service.ts`) implements **`take: limit + 1`**, slices **`items`**, sets **`hasMore`**, **`nextCursor`** from the last returned row, and runs **`count`** on the owner catalog-visible filter for **`totalCount`** on the first non-trash page.

**Flutter:** `RemotePublishedMonoRepository.fetchPage` normalizes **`pagination`**, **`meta`**, and a sibling **`data`** object map (when **`items`** are already top-level), treats **`data`** as a list when **`items`** is absent, and maps snake_case aliases. **`hasMore`** accepts **`bool`**, **`num`** (e.g. **`1`**), and common string forms. **`kDebugMode`:** **`RemotePublishedMonoRepository.fetchPage: raw keys=...`**, **`[RAW JSON envelope]`**, **`[RAW body prefix]`**; post-parse line reports **`hasMore`**, **`nextCursor`**, **`totalCount`**.

Return only:

| Check | Status |
|-------|--------|
| Backend raw JSON fixed? | **Yes** in this repo (top-level envelope). If the device still sees **`items` only**, redeploy / align API base URL. |
| Parser fixed if needed? | **Yes** — **`meta`**, **`pagination`**, sibling **`data`** map, **`data[]`**, snake_case, numeric **`hasMore`**. |
| Phone first-page log has `hasMore=true`? | **Expected** when ≥11 rows match **`PUBLISHED_MONO_CATALOG_VISIBLE`** and the body carries pagination (root, **`meta`**, **`data`**, or **`pagination`**). |
| `totalCount=21`? | **Expected** on first page when the server count matches; **`totalCount`** counts the same filter as the Published list (owner, live, not trashed, catalog-visible). |
| Second page request fires? | **Expected** when **`canLoadMore`** is true (`hasMore` + cursor from parse). |
| 21 rows eventually visible? | **Expected** with existing prefetch/scroll; pager dedupes as before. |
| Profile tests passed? | **Yes** (this session: **`flutter test test/features/profile/profile_published_pagination_test.dart`**, **`flutter test test/features/profile`**). |

### Tests (M17C-4)

**Flutter — `test/features/profile/profile_published_pagination_test.dart`**

- **`M17C-4: top-level items plus sibling data map pagination`**
- **`M17C-4: meta map fills pagination when top-level omits it`**
- **`M17C-4: data array plus meta snake_case pagination`**
- **`paginated JSON envelope maps hasMore when sent as int 1`**
- **`M17C-2: backend envelope three pages via cursor (limit 10)`** (unchanged)
- **`M17C-4: loadFirstPage preserves totalCount from meta-only pagination`** (pager)

**Backend:** `published-monos.service.spec.ts` (including **`limit=10`**, 21 rows, three pages, JSON serialization of pagination keys).

### Commands (verify)

```text
cd nimon-backend
node node_modules/jest/bin/jest.js src/modules/published-monos --runInBand
node node_modules/@nestjs/cli/bin/nest.js build

flutter test test/features/profile/profile_published_pagination_test.dart
flutter test test/features/profile
```

### Phone acceptance

After first **`GET`**, debug console should show:

- **`RemotePublishedMonoRepository.fetchPage: raw keys=...`**
- **`RemotePublishedMonoRepository.fetchPage: JSON items=10 parsedDtos=10 hasMore=true nextCursor=<value> totalCount=21`**

Then page 2 **`GET`** includes **`cursor=`**; owner Published header can show **21** while only 10 rows are loaded until **`loadMore`** completes.
