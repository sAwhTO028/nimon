# M17I — Saved tab pagination fix report

## Summary

Profile → **Saved** (`GET /v1/me/bookmarks`) stopped after the first **20** rows: the list showed a bottom spinner but no additional items. Pagination is restored by **deferring `loadMore` out of `ListView` build**, adding a **scroll near-end** trigger, hardening the **JSON envelope parser**, tightening **`loadMore` state** (including append **dedupe**), and returning **`totalCount`** from the backend.

## Root cause

1. **Primary (Flutter UI):** `ProfileSavedRemoteTab` called `profileSavedMonoPagerProvider.notifier.loadMore()` **directly inside `ListView.separated` `itemBuilder`** while building the footer row. That updates Riverpod / `StateNotifier` state **during layout**, which is unsafe and produced unreliable pagination (stuck spinner, no append).
2. **Secondary (parser robustness):** `RemoteMonoSocialRepository.fetchBookmarkedPage` only read top-level camelCase `hasMore` / `nextCursor` and treated non-bool `hasMore` as **false**. Any gateway-style `{ "data": { ... } }` or snake_case flags would break `hasMore` / cursor / totals.
3. **Tertiary (loadMore cleanup):** `loadMore` used `finally { if (state.requestEpoch == myEpoch) isLoadingMore = false }`, so a rare **epoch mismatch** could theoretically leave **`isLoadingMore` true**; this is corrected by **always** clearing the flag in `finally`.

## Backend response shape

`GET /v1/me/bookmarks` returns (unchanged field names; **added** `totalCount`):

```json
{
  "items": [ /* MonoBookmarksListItemDto */ ],
  "hasMore": true,
  "nextCursor": "<base64url cursor>",
  "totalCount": 35
}
```

- **`totalCount`:** count of **catalog-visible** bookmark rows for the user (`MonoBookmark` ∧ `PUBLISHED_MONO_CATALOG_VISIBLE`), same visibility filter as list rows.
- **`nextCursor` / `hasMore`:** unchanged logic (`take = limit + 1`, slice, encode last row’s `createdAt` + bookmark `id`).

**Debug logging (Nest):** `MonoSocialController` logs `[SavedTab API] ...` at **debug** level (`Logger.debug`) after each list call.

## Flutter changes

| Area | Change |
|------|--------|
| **`profile_saved_remote_tab.dart`** | Wrapped list in `NotificationListener<ScrollNotification>`; **debounced** `_scheduleSavedLoadMore()` (450 ms) from **near-end scroll**; footer calls the same scheduler (post-frame, not synchronous `loadMore`). Footer shown when `(hasMore OR isLoadingMore) AND error == null`. |
| **`profile_saved_mono_pager.dart`** | `loadMore`: append with **dedupe by `MonoFeedItem.id`**; `finally` **always** sets `isLoadingMore: false`; carries **`totalCount`**; **`refresh`** resets `hasMore` to false until the new first page returns; **`kDebugMode`** `[SavedTab]` logs. |
| **`remote_mono_social_repository.dart`** | Normalizes JSON like published-monos (`data` / `meta` / `pagination` merge); **`has_more`**, **`next_cursor`**, **`total_count`**; **`publishedMonoId`** fallback for row id; **`kDebugMode`** `[SavedTab]` logs. |

## Tests

| Suite | Notes |
|-------|--------|
| `nimon-backend` `mono-social.service.spec.ts` | **`listMyBookmarks` pagination + `totalCount`** (35 total, page 1 size 20 + cursor, page 2 size 15, `hasMore` false). |
| `flutter test` `remote_mono_social_repository_test.dart` | Wrapped **`data`** envelope + snake_case flags + **`totalCount`**. |
| `flutter test` `profile_saved_mono_pager_test.dart` | **`loadMore`** appends, passes **cursor**, clears **`isLoadingMore`**. |
| `flutter test` `test/features/profile` | Full folder was run in CI-style batch earlier; targeted saved tests re-run after fix. |
| `flutter test` `test/features/collections` | Pass (regression guard). |
| `nest build` | Pass. |

## Commands run (Part G)

- `flutter test test/features/mono/remote_mono_social_repository_test.dart test/features/profile/profile_saved_mono_pager_test.dart test/features/profile/profile_saved_tab_compact_list_test.dart`
- `flutter test test/features/collections`
- `node node_modules/jest/bin/jest.js src/modules/mono-social --runInBand`
- `node node_modules/@nestjs/cli/bin/nest.js build`

## Phone acceptance (Part I)

After a clean backend restart, with a user who has **more than 20** saved monos:

1. Open **Profile → Saved**.
2. First page shows **20** rows.
3. Scroll near the bottom → second **`GET /v1/me/bookmarks`** includes **`cursor`**.
4. Additional rows **append**; **no duplicate** `monoId` keys.
5. Bottom **spinner stops** when **`hasMore`** is false.
6. Optional: **`totalCount`** in the JSON matches the number of visible saved rows.

## Checklist (user Part I questions)

| Question | Answer |
|----------|--------|
| Root cause found? | **Yes** — `loadMore` during `itemBuilder` / layout; parser fragility; `finally` edge case. |
| Backend metadata correct? | **`hasMore` / `nextCursor`** unchanged; **`totalCount`** added. |
| Flutter parser fixed? | **Yes** — envelope merge + snake_case + `publishedMonoId`. |
| `loadMore` state fixed? | **Yes** — dedupe, unconditional `isLoadingMore` clear, `totalCount`, refresh `hasMore` reset. |
| Spinner stuck fixed? | **Yes** (deferred load + footer/`hasMore`/`isLoadingMore` rules + `finally`). |
| Second GET with cursor? | **Yes** when `nextCursor` set (repo sends `cursor` query param). |
| Items append after 20? | **Yes** when server returns page 2. |
| `hasMore: false` stops spinner? | **Yes** — footer hidden when no more and not loading. |
| Tests passed? | **Yes** for targeted suites above. |
| Docs updated? | **This file.** |
