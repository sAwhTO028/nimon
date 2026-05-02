# Published tab pipeline — diagnostic note (analysis only)

This document traces where backend `PublishedMono` list data can be lost on the way to the Flutter **Published** tab. It is derived from **static review** of the repo. **Run values** (counts, HTTP status, `dart-define` at runtime) must be confirmed in the app or build logs; those are **not** guessed here.

---

## A. File / function map (pipeline order)

| Step | File | Function / location |
|------|------|----------------------|
| 1. Compile-time config | `lib/features/create/data/remote_backend_config.dart` | `RemoteBackendConfig` |
| 2. Profile route / initial tab | `lib/main.dart` | `GoRoute` `path: '/more'`, `pageBuilder` |
| 3. Profile screen init + state | `lib/features/profile/profile_screen.dart` | `_ProfileScreenState.initState`, `build` |
| 4. Remote load (Published) | `lib/features/profile/profile_screen.dart` | `_loadPublishedFromBackendIfEnabled` |
| 5. HTTP + parse | `lib/features/profile/data/remote_published_mono_repository.dart` | `RemotePublishedMonoRepository.list` |
| 6. DTO | `lib/features/profile/data/published_mono_dto.dart` | `PublishedMonoListItemDto` |
| 7. In-memory list | `lib/features/profile/profile_screen.dart` | `setState` → `_uploadedLooseItems` (and `_uploadedFolders` cleared) |
| 8. Filter | `lib/features/profile/profile_screen.dart` | `_hidePublishedItemForWorkspaceEditing`, `filteredLoose` in `build` |
| 9. List UI | `lib/features/profile/profile_screen.dart` | `_FolderGroupList` + `_FolderGroupListState` (filter chip Monos/Collections) |
| 10. Row | `lib/features/profile/mono_story_list_row.dart` | `MonoStoryListRow` |

**Debug already present:** `_debugLogPublishedLoad` in `profile_screen.dart`; `debugPrint` in `RemotePublishedMonoRepository.list` (e.g. JSON vs parsed DTO count) in **debug** profile only for some lines — confirm `kDebugMode` / console visibility.

---

## 1. App launch config (compile-time `dart-define`)

| Question | Code fact | “Observed” (you must run build / log) |
|----------|-----------|----------------------------------------|
| Is `NIMON_USE_REMOTE_DRAFTS` true at **runtime**? | `static const bool useRemoteDrafts = bool.fromEnvironment('NIMON_USE_REMOTE_DRAFTS', defaultValue: **false**);` | Rebuild with `--dart-define=...` and/or log `RemoteBackendConfig.useRemoteDrafts` in `_debugLogPublishedLoad`. |
| `NIMON_API_BASE_URL`? | `String.fromEnvironment('NIMON_API_BASE_URL', defaultValue: 'http://localhost:3000')` | Log `base=...` from existing `_debugLogPublishedLoad` line. |
| Strict remote? | `NIMON_STRICT_REMOTE_DRAFTS` default **false** | Same — `bool.fromEnvironment`. |

**Break risk:** If the browser is used to `GET http://localhost:3000/v1/...` **without** matching what Flutter was built with, the app may still have **`useRemoteDrafts == false`**. In that case `_loadPublishedFromBackendIfEnabled` **returns before any HTTP** to `/v1/published-monos` and `_uploadedLooseItems` stays on **initial mock** (`_uploadedLooseMock`), not the API.

**First candidate breakpoint (config):** Step 4: early `if (!RemoteBackendConfig.useRemoteDrafts) return;` in `_loadPublishedFromBackendIfEnabled` — **line ~502** area in current tree.

---

## 2. Profile tab selection

| Question | Code fact |
|----------|-----------|
| Which index is **Published**? | `PageView` / `_ProfileIconTabs`: **index 0 = Published** (label `"Published"`), 1 = Workspace, 2 = Saved. |
| `tab=uploaded`? | In `lib/main.dart`, `q['tab'] == 'uploaded'` → `initialTab = 0` passed as `ProfileScreen.initialTabIndex`. |
| `initialTab` null? | `initialTab` can stay `null` (e.g. `/more` with no `tab=`), then `widget.initialTabIndex ?? 0` in `initState` → **0 = Published** still. |
| “Does the UI enter Published tab builder?” | The **first** `PageView` child is the Published tab content (IIFE that builds `filteredLoose` + `_FolderGroupList`). The visible page depends on `_pageController` / `initialTab` — if user is on another tab, **the widget tree for Published still exists** off-screen; it should still get `setState` updates. |

**Break risk (tab):** If the user expects a different URL (e.g. `tab=published` string) and it is not mapped in `main.dart` **only** `uploaded` / `workspace` / `saved` are read — that does **not** switch tab away from 0 by default, but a wrong bookmark could set only Saved/Workspace if query matches.

**Observed tab index:** Use existing log fields `currentTabIndex`, `initialTabIndex`, `routeTab` in `_debugLogPublishedLoad` when reproducing.

---

## 3. Published load trigger

| Question | Answer from code |
|----------|------------------|
| Where is load called? | `_ProfileScreenState.initState` → `unawaited(_loadPublishedFromBackendIfEnabled());` |
| On switch to Published tab? | **No** separate refresh when changing tabs. Load runs **once** (plus processing refresh only reloads **Workspace** drafts via `profileProcessingListRefreshProvider` → `_loadLocalCreatorDraftIntoProcessing`, **not** the published list). |
| Stale / cached mock? | `initState` first assigns `_uploadedLooseItems = List.from(_uploadedLooseMock)`, then async load may replace. |
| Blocked? | `if (!mounted) return;` after `await repo.list(...)` — if the route is disposed before the future completes, **no `setState`** and list stays mock. |
| `FutureBuilder`? | **Not** used for this list. |

**First candidate breakpoint (trigger):** Remote enabled but **load never applied** (dispose / `mounted`), or **remote never enabled** so data never replaced.

---

## 4. Repository call

| Question | Code fact |
|----------|-----------|
| Is `list` called? | Only if `useRemoteDrafts` is true (see §1). |
| URL | `_u('/v1/published-monos?limit=80')` = `apiBaseUrl` (trimmed) + that path. |
| HTTP 200? | `_throwIfNotOk` on non-2xx throws. |
| On exception | `catch` → if `!strictRemoteDrafts`, return **`PublishedMonoListResponseDto(items: [])`**. If **strict**, rethrow (caller does not `try/catch` → async error, **no** `setState` with API rows). |
| Raw count | Log in repo: `JSON items=… parsedDtos=…` (kDebugMode path). |

**First candidate breakpoint (HTTP):** Any failure (CORS, wrong port, connection refused, TLS) → **empty** `items` in non-strict, or unhandled in strict. Browser success **does not** prove Flutter from the same machine uses the same origin / same flags.

---

## 5. DTO parsing

| Question | Code fact |
|----------|-----------|
| Shape `{ "items": [...], "nextCursor": null }`? | `m['items'] as List?` — if key missing, list is []. |
| Item not a `Map`? | `if (x is! Map) continue;` — that element is **skipped**, DTO count can be &lt; JSON array length. |
| Nullable `publishKind`, `coverImageUrl`, `targetDurationLabel`? | `_optStr` returns null for missing/empty; DTOs still **constructed** — they do **not** by themselves remove items. |
| Empty `id`? | `id: _optStr(it['id']) ?? ''` — row can map with `id==''` (degenerate). |

**First candidate breakpoint (parse):** Mismatch of JSON to Map types or `items` not a List → empty or partial list; use repo `JSON items=… parsedDtos=…` to compare.

---

## 6. Mapping to `_OneShortItem`

| Field | Code |
|------|------|
| Count | One `_OneShortItem` per `resp.items` entry. |
| `id` | `m.id` (PublishedMono id) |
| `sourceDraftId` | from DTO |
| `isBackendPublished` | **`true`** for these rows (see §7) |
| title / description / level / category / duration / cover / badge | From DTO in `_loadPublishedFromBackendIfEnabled` body |

**First candidate breakpoint (mapping):** `resp.items.length == 0` — no mapping; root is §4/§5, not this loop.

---

## 7. Filtering (Workspace “Editing”)

| Question | Code fact (current) |
|----------|----------------------|
| `editingIds` | `draftId` of `_processingItems` with `workspaceState == _WorkspaceState.editing` |
| Hide? | `_hidePublishedItemForWorkspaceEditing`: if `it.isBackendPublished` → **`return false`** (do **not** hide) |
| `sourceDraftId` alone | Does **not** hide backend rows in current code |

**If a build without `isBackendPublished` exemption is still in use** (or `isBackendPublished` accidentally false for API rows), then **every** row with `sourceDraftId ∈ editingIds` is hidden — a plausible **all-hidden** list.

**Observed:** Compare `loose=`, `shown=`, and `editingIds=` in `_debugLogPublishedLoad` after the fix; use `hideReason[...]` logs in kDebugMode when old rule would apply.

---

## 8. Rendering

| Question | Code fact |
|----------|-----------|
| Final list | `filteredLoose` in first `PageView` child, passed to `_FolderGroupList(looseItems: filteredLoose, ...)` |
| Monos vs Collections | `_FolderGroupListState` default `_filter = _ProfileFolderFilter.monos` — **loose** rows in **Monos** view. In **Collections** view, the **ListView** shows **folders** only, not `looseItems` — with `_uploadedFolders` cleared after remote load, **Collections** can look **empty** while `looseItems` is non-empty. |
| Empty state | If `looseCount == 0` in Monos, list is filter bar only + no body rows. |
| Override by mock? | After successful `setState`, `_uploadedLooseItems` **is** the `items` list from API, `_uploadedFolders` **is** []. **No** separate shadow variable. |

**First candidate breakpoint (UI):** User is on **Collections** chip with no folders, not **Monos**.

---

## 9. Profile state ownership

| Question | Code fact |
|----------|-----------|
| Old mocks? | Initial: `_uploadedLooseItems = _uploadedLooseMock`. Replaced in `setState` when remote path runs successfully. |
| “Saved to unused variable”? | **No** — a single `late` `_uploadedLooseItems` is what `build` reads. |
| `_uploadedOneShorts`? | **No** such name; loose list is `_uploadedLooseItems`. |

---

## C. “Observed” counts at each step (how to fill)

Run the app with the **same** `--dart-define` you intend for production, open Profile → Published (index 0), and capture:

1. **Console:** `[Profile Published] ... useRemote= ...` lines (stage: skip vs before vs after).  
2. **Console:** `RemotePublishedMonoRepository.list: ... JSON items= N parsedDtos= M`  
3. `raw=`, `mapped=`, `loose=`, `shown=`, `editingIds` from the after-map line.

| Step | Metric | Meaning if wrong |
|------|--------|------------------|
| 1 | `useRemote=false` | No HTTP; mocks remain (or you only see one mock loose + folders from initial mock) |
| 4 | N/A after skip | `RemotePublishedMonoRepository.list` never invocated |
| 4 | `list error` in log | Thrown; empty DTOs if non-strict |
| 4–5 | `JSON items=5` `parsedDtos=0` | Skipped elements or parse bug |
| 4 | `loose=0` after setState + `mapped=0` | Empty `resp` |
| 7 | `shown=0` and `loose>0` | Filter bug (or pre-fix editing filter) |
| 8 | On **Collections** | Folders only — empty is expected if folders cleared |

**First step where data “disappears”** = first row in this table that fails the expected value.

---

## D. Root cause (cannot be finalized without B)

**From code structure alone, the most common break before any UI** is:

1. **`RemoteBackendConfig.useRemoteDrafts` is false** at compile time → no published HTTP and mock-only state for loose items (or user confusion vs browser).

2. **`RemotePublishedMonoRepository.list` throws** (network / CORS / 4xx/5xx) → in **non-strict** mode, **empty** list applied → empty Published loose list.

3. **(Historical)** **Filter** without `isBackendPublished` skip → all rows hidden when `sourceDraftId` matches an “Editing” draft.

4. **UX:** **Collections** filter selected with **no folders** after remote (folders cleared) → screen looks empty of “cards” that live only in **Monos**.

A definitive **single** root cause requires the **B** line logs from one failing run.

---

## E. Minimal fix plan (do not apply here — plan only)

1. Confirm `useRemote` and `base` in logs match the working browser base URL.  
2. If HTTP fails, fix **origin** (CORS, `NIMON_API_BASE_URL`, or run Chrome with the same host as the server).  
3. If `useRemote` is false, add/verify `--dart-define` in the run configuration used for manual testing.  
4. If `loose>0` but `shown=0`, inspect filter (and `isBackendPublished` on every API row).  
5. If data exists only in Monos, ensure UI is on **Monos** not **Collections**.  
6. If `!mounted` cancels, defer load or re-fetch when Profile remounts.

---

## F. Files likely to change (when fixing)

- `lib/features/create/data/remote_backend_config.dart` — only if you document / template `dart-define`.  
- `lib/features/profile/profile_screen.dart` — load gating, filter, or tab refresh.  
- `lib/features/profile/data/remote_published_mono_repository.dart` — error handling, logging, URL.  
- Build/run scripts / IDE run config (Flutter) — to pass `dart-define`.

---

## G. What should not be changed (without a new spec)

- Reader / `MonoScreen` detail / `GET .../:id` behavior (out of “Published **list**” scope).  
- GoRouter shell layout beyond the `/more` `tab` query.  
- Backend DTO contract unless a separate API task.  
- Large rewrites of `_FolderGroupList` layout.

---

*End of note. This file is a diagnostic aid; it does not implement code.*
