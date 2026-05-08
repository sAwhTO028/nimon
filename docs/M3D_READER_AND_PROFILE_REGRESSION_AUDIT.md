# M3d Reader And Profile Regression Audit

**Scope:** DEBUG / AUDIT ONLY (no code changes, no migrations).  
**Context:** M3 remote Mono feed + M1 auth/guards.  
**Date:** 2026-05-03

---

## 1. Issues Reported

1. **Home Mono** — sentence lines do not show **furigana** (ruby).
2. **Home Mono** — no **translation / source meaning** for lines, even when a **Settings** control suggests explanations should appear.
3. **Profile → Workspace (Processing)** — **endless loading** when there is no data (or in some edge cases).
4. **Profile → Published** — after **adding/publishing** content, the **Published** tab does **not** list the new mono (regression vs earlier smoke).

---

## 2. Runtime Mode Assumptions

- **Remote drafts / Mono catalog:** `RemoteBackendConfig.useRemoteDrafts` gates Profile Published paging (`profilePublishedMonoPagerProvider`) vs legacy mock loose rows (`_uploadedLooseItems`).
- **Public Mono reader:** Home Mono resolves catalog entries via `GET /v1/mono/:monoId` (no JWT). Owner-scoped listing remains `GET /v1/published-monos` (JWT required via `JwtOrDevOwnerFallbackGuard`).
- **Publish pipeline:** Creator drawer calls `publishReadingOnlyToDisk()` / `publishFullLearnToDisk()` → `persistLocalNow()` → **repository `saveDraft()`**. For `RemoteStoryDraftRepository`, publish involves `PUT /v1/story-drafts/:id` with `publishState` forced to draft on PUT, then **`POST .../publish/read-only`** or **`POST .../publish/full-learn`** when the persisted domain `publishState` matches.

---

## 3. Published Tab Missing Audit

### A.1 — Is publish API returning success?

- **In code (success path):** `RemoteStoryDraftRepository.saveDraft` issues `POST /v1/story-drafts/:id/publish/read-only` (or full-learn) after a successful `PUT`, with `If-Match` and merged auth headers; `200` is treated as success and etag updated.
- **Caveats:**
  - Outer `try/catch` uses `_fallbackOrThrow`: failures may fall back to **local-only** success semantics depending on strict mode, so the UI can still report publish success while **`published_monos` was never updated**.
  - If `If-Match` / etag resolution fails and `_strict` is false, an early `return persisted` can **skip the publish POST** entirely (see `reading_only_published` branch when etag missing).

**Verdict:** Cannot assume success without runtime logs; **code allows silent skip or local-only success.**

### A.2 — Is `published_monos` row created/updated?

- **Backend:** `StoryDraftsService.publishReadOnly` creates `publishedMono` on first publish and **`publishedMono.update`** with `content` containing `core.sentences` mapped from `draft.sentences[].content` (`nimon-backend/src/modules/story-drafts/story-drafts.service.ts`).
- **Verdict:** **Row is written when publish POST succeeds** inside the transaction. If Flutter never completes that POST (or treats failure as local-only OK), **no row / stale row** — **unknown without DB inspection.**

### A.3 — Bearer token for `GET /v1/published-monos`?

- **Backend:** `PublishedMonosController` uses `@UseGuards(JwtOrDevOwnerFallbackGuard)` — **authenticated identity required** (or dev fallback per guard).
- **Flutter:** `RemotePublishedMonoRepository` calls `_mergeAuth` with `authHeaderBuilder` from `authHeaderBuilderProvider` — **Bearer is sent when builder supplies it.**

### A.4 — `profilePublishedMonoPagerProvider` after publish?

- `ProfileScreen` subscribes to `profileProcessingListRefreshProvider` and on change calls **`profilePublishedMonoPagerProvider.notifier.refresh()`** when `useRemoteDrafts` is true.
- `StoryCreatorDraftNotifier._bumpProfileProcessingListRefresh()` runs after successful **`publishReadingOnlyToDisk` / `publishFullLearnToDisk`** (when save succeeds).

**Verdict:** Refresh **is intended**, but see **§10** for race with `loadFirstPage`.

### A.5 — `ownerId` mismatch after M1?

- Remote save normalizes `creatorOwnerId` toward JWT user id (`_normalizeDevOwnerForRemoteSave`). Backend lists **`where: { ownerId: user.userId }`**.
- **Risk:** If JWT user ≠ stored draft owner after migrations / strict vs dev fallback, **empty list** — plausible.

### A.6 — Hidden by Workspace hide logic?

- `_hidePublishedItemForWorkspaceEditing`: **`isBackendPublished` rows are never hidden** (`nimon-backend`-mapped rows use `isBackendPublished: true`).
- **Loading fallback:** `_publishedLooseRowsForUi` returns **`_uploadedLooseItems` (mock)** while `pager.isInitialLoading && items.isEmpty && error == null` — can **mask** real remote results until load settles.

---

## 4. Workspace Endless Loading Audit

### B.1 — Which provider?

- **`profileWorkspaceDraftPagerProvider`** (`ProfileWorkspaceDraftPager`) backed by **`storyDraftRepositoryProvider`** → `fetchWorkspaceDraftPage` → **`GET /v1/story-drafts`** (remote) with auth.

### B.2 — Empty `PageResult` and `isLoading`?

- On success, pager sets **`isInitialLoading: false`** with **`items: result.items`** (possibly empty), **`hasMore`** from API — **empty page is not inherently stuck** if state updates run.

### B.3 — `fetchWorkspaceDraftPage` empty + `hasMore: false`?

- **Remote:** `DraftListPageDto.parseEnvelope` — **assumed** to return `items: []`, `hasMore: false` for empty account; **not re-verified in this audit** (read `DraftListPageDto` if needed).

### B.4 — Error swallowed?

- `_ProcessingDraftManagerTab`: if `items.isEmpty` and **`isInitialLoading` false**, UI shows **empty card** (“Nothing in Processing yet”) — **error state not surfaced** in the excerpted branch (spinner only when `isInitialLoading && error == null`).

### B.5 — Missing empty state?

- **Empty state exists** when `widget.items.isEmpty` and not initial-loading.

### B.6 — Critical logic bug (loading stuck)

- **`ProfileWorkspaceDraftPager.loadFirstPage`** sets `isInitialLoading: true`, then awaits fetch; **`refresh()`** increments `requestEpoch` but **does not clear `isInitialLoading`**.
- If **`refresh()` completes while an older `loadFirstPage` is in flight**, the older completion does **`if (state.requestEpoch != myEpoch) return`** **without** setting `isInitialLoading: false` → **`isInitialLoading` can remain true forever**.
- **`ProfileScreen._onTabChanged`** calls **`profileWorkspaceDraftPagerProvider.notifier.refresh()`** when switching to tab index **1** (Workspace) — **high-probability race** with `initState`’s `loadFirstPage()`.

**Verdict:** **Endless spinner** is consistent with **epoch / `isInitialLoading` leak**, not only with “no data”.

---

## 5. Furigana Missing Audit

### C.1 — `published_monos.content` stores furigana?

- Publish copies **`s.content` from each sentence row into `core.sentences[]`** — **whatever the draft JSON contains** (including any ruby/token fields) is **stored**.

### C.2 — `GET /v1/mono/:id` returns those fields?

- `MonoFeedService.getPublicMonoById` returns `publishedMonoDetailFromRow` which includes **`content: m.content`** (full JSON).

### C.3 — Parser?

- **`buildMonoContentFromPublishedCore`** (`published_mono_detail_parser.dart`) builds each `MonoSentenceLine` with **`tokens: const []`** and only **`plainText`** from `japaneseText` — **no token / ruby parsing**.

### C.4 — `MonoFeedItem` / `MonoContent`?

- Mapper path uses the same content builder; **no tokens** in `MonoContent` for remote-hydrated published core.

### C.5 — `MonoScreen` widget?

- With **empty `tokens`**, `MonoContent` render path uses **plain text** (per model comments) — **no ruby layout**.

**Verdict:** **Primary cause is client-side:** parser discards structure; even a correct backend payload would not show furigana.

---

## 6. Translation Toggle Missing Audit

### D.1–D.2 — Storage & API

- **Meaning fields** would live under each sentence’s `content` in draft → copied into `published_monos.content` (same as C.1).
- **API** returns full `content` on `GET /v1/mono/:id`.

### D.3 — Parser

- **`explanation: null`** for every line in `buildMonoContentFromPublishedCore` — **meanings not mapped** into `MonoSentenceLine.explanation`.

### D.4 — Reader UI

- **`mono_screen.dart`** sets **`const showExplanation = false`** with an explicit product comment that explanations belong elsewhere — **Settings toggle is not consulted on this screen.**

### D.5 — Settings toggle

- **`monoExplanationEnabledSettingProvider`** — UI label: **“Listening explanation sentence”** / **“Listening / Pronunciation”**, **not** Home Mono.

### D.6 — `MonoScreen` reads toggle?

- **No** — `showExplanation` is **hardcoded false** (see ~2911–2913 in `mono_screen.dart`).

### D.7 — Remote vs mock path?

- **Remote-hydrated content still uses the same parser and same `showExplanation` constant** — regression is **not** feed-mode-specific beyond parser usage.

---

## 7. Backend Payload Findings

| Area | Finding |
|------|--------|
| **Publish** | `publishReadOnly` writes `content.core.sentences[].content` from draft sentences; structure preserved as JSON. |
| **Public Mono detail** | Returns **full** `content` including `core`. |
| **Owner Published list** | **JWT-guarded**, `ownerId`-scoped. |
| **Mono feed list** | Summary items avoid heavy blob; **detail** endpoint carries full content. |

---

## 8. Flutter Parser / Mapper Findings

| File | Finding |
|------|--------|
| `published_mono_detail_parser.dart` | **`tokens: []`**, **`explanation: null`** — strips ruby and meanings. |
| `mono_feed_item_mapper.dart` | Uses published-core builder for merged detail — **inherits parser limits**. |
| `profile_published_mono_pager.dart` | Same **epoch pattern** as workspace pager for `loadFirstPage` vs `refresh` (**no `finally` clearing `isInitialLoading`**). |

---

## 9. UI Rendering Findings

| Surface | Finding |
|---------|--------|
| **Mono Home reader** | **`showExplanation` forced false** — translations/explanations never shown. |
| **Profile Published** | While remote pager initial-loading with empty items, UI can show **`_uploadedLooseItems`** mocks — misleading during load. |
| **Workspace** | Spinner when **`items.isEmpty && isInitialLoading`**; **epoch bug** can keep **`isInitialLoading` true**. |
| **Settings** | Mono explanation switch is **scoped to Listening/Pronunciation** in copy — **user expectation mismatch** for Mono. |

---

## 10. Most Likely Root Causes

| Issue | Likely root cause |
|-------|-------------------|
| **Published tab missing new mono** | (1) **Pager race:** `refresh()` / `loadFirstPage()` epoch mismatch leaves **`isInitialLoading` stuck** or stale state; (2) **remote publish not reached** (etag / strict / fallback); (3) **401 / owner scope** on `GET /v1/published-monos`; (4) **mock fallback** during loading obscuring reality. |
| **Workspace endless loading** | **`ProfileWorkspaceDraftPager`**: superseded `loadFirstPage` exits without clearing **`isInitialLoading`** after **`refresh()`** (tab switch triggers refresh). |
| **Furigana** | **`buildMonoContentFromPublishedCore`** never builds **`MonoRubyToken`** list from sentence JSON. |
| **Translation / meaning** | Parser drops meanings; **`MonoScreen` hardcodes `showExplanation = false`**; Settings toggle **not wired** to Mono reader. |

---

## 11. Recommended Fix Order

1. **P0 — Pagers:** Clear **`isInitialLoading`** in `finally` or on epoch supersede; align **`refresh()`** with **`loadFirstPage()`** semantics (same pattern as **`loadMore`’s `finally`** in `profilePublishedMonoPager`).
2. **P0 — Publish visibility:** Confirm **`POST publish/read-only`** runs and surfaces failures when strict/local fallback differs; verify **`profileProcessingListRefresh`** ordering vs **`ProfileScreen`** init loads.
3. **P0 — Auth:** Verify **`GET /v1/published-monos`** returns rows for signed-in user (owner alignment).
4. **P1 — Parser:** Map sentence `content` JSON into **`tokens`** / **`explanation`** (field names must match draft schema).
5. **P1 — Mono UI:** Replace **`const showExplanation = false`** with a **real provider** (existing or new toggle), and align Settings copy vs behavior.

---

## 12. Exact Cursor Prompt For P0 Fixes

```
Fix Profile pager stuck loading and Published list refresh regressions (no migrations).

1) In ProfileWorkspaceDraftPager and ProfilePublishedMonoPager: ensure no code path leaves isInitialLoading true after a superseded request (loadFirstPage interrupted by refresh/tab listener). Mirror the fix pattern already used for loadMore finally blocks — clear loading flags safely when requestEpoch != myEpoch only after resetting isInitialLoading in a controlled way, or use finally on each async method.

2) ProfileScreen: audit initState ordering vs profileProcessingListRefreshProvider — avoid double-fetch races that leave Published pager wedged; optionally defer published loadFirstPage until after first frame or coalesce refresh.

3) RemoteStoryDraftRepository.saveDraft: trace publishReadOnly path — ensure POST publish/read-only is actually invoked after publishReadingOnlyToDisk; log or surface failure when strict=false would skip publish.

4) Verify RemotePublishedMonoRepository fetch uses auth headers and document owner mismatch if GET returns empty.

Files: lib/features/profile/presentation/providers/profile_workspace_draft_pager.dart, profile_published_mono_pager.dart, lib/features/profile/profile_screen.dart, lib/features/create/data/remote_story_draft_repository.dart.

Run flutter analyze and relevant tests.
```

---

## 13. Exact Cursor Prompt For Furigana / Translation Fixes

```
Restore furigana and line meanings on Home Mono for remote-published content.

1) published_mono_detail_parser.dart: extend buildMonoContentFromPublishedCore to parse sentence content maps into MonoSentenceLine.tokens (MonoRubyToken) using the same JSON shape as story draft sentences (furigana/ruby fields as stored server-side). Populate MonoSentenceLine.explanation / MonoExplanationLine from sourceMeaning / englishMeaning (exact keys per draft DTO).

2) mono_feed_item_mapper.dart: ensure merged remote detail uses enriched parser output.

3) mono_screen.dart: remove const showExplanation = false; wire showExplanationLines from monoExplanationEnabledSettingProvider (or add mono_reader_* toggle) and pass through _ReadingFeedPost.

4) Settings: update strings if Mono reader is included.

Match existing typography for ruby text. flutter analyze + widget tests if present.

Files: lib/features/profile/data/published_mono_detail_parser.dart, lib/features/mono/data/mono_feed_item_mapper.dart, lib/features/mono/mono_screen.dart, lib/features/settings/settings_screen.dart (copy only if needed).
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| **`published_monos` row created?** | **Unknown** without DB/runtime — **yes** when backend `publishReadOnly` transaction completes; **may be no** if Flutter skips POST or fails open to local-only. |
| **Profile Published missing likely cause** | **Pager epoch / `isInitialLoading` stuck**, **publish POST not reached**, **401/owner scope**, or **mock rows during loading**. |
| **Workspace loading likely cause** | **`loadFirstPage` vs `refresh()` epoch race** leaving **`isInitialLoading` true** (tab 1 calls refresh in `_onTabChanged`). |
| **Furigana missing likely cause** | **Parser sets `tokens: []`**; UI only renders ruby when tokens exist. |
| **Translation missing likely cause** | **Parser `explanation: null`** + **`MonoScreen` `showExplanation` hardcoded false** + Settings toggle **not wired** to Mono. |
| **P0 fix recommendation** | **Pager loading-flag / epoch fix** + verify **remote publish + auth** on Published fetch. |
| **P1 fix recommendation** | **Parse ruby/meaning from sentence JSON** + **wire explanation visibility** to Mono reader (and clarify Settings). |
