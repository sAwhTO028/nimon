# Nimon Flutter UI stability audit

**Scope:** Client-side Flutter only (no backend). Focus on lifecycle, list identity, reorder/refresh timing, and **Chrome/web vs mobile** differences.  
**Known symptom:** Assertion `_elements.contains(element) is not true` during card/list reorder or refresh (web-heavy).

---

## Executive summary

Several surfaces combine **scrollables**, **post-frame callbacks**, **GlobalKeys**, and **ReorderableListView** without always guaranteeing that **element references** used after layout still belong to the **current** `Element` tree. On **web**, frame scheduling, pointer/gesture routing, and layout timing differ from mobile, so the same code paths can hit Flutter’s stricter checks (`_elements.contains(element)`) when `ensureVisible`, reorder proxies, or scroll positions briefly reference **detached** or **stale** elements.

---

## A. High-risk files

| Priority | File | Why |
|----------|------|-----|
| **P0** | `lib/features/profile/profile_screen.dart` | `_ProcessingDraftManagerTabState`: **GlobalKey** map + **`Scrollable.ensureVisible`** in post-frame after list/split changes; keys not pruned; `didUpdateWidget` only keys off `items.length` + `highlightDraftId`, not reorder/publish **section moves**. |
| **P0** | `lib/features/create/story_creator_sentences_screen.dart` | Large **`ReorderableListView.builder`**; `_sentenceReorderKey` falls back to **`ValueKey` embedding `index`** for plaintext drift → key churn on reorder/sync with web drag timing. |
| **P1** | `lib/features/mono/mono_screen.dart` | Vertical feed **`PageView.builder`** with **`ValueKey(..., ${data.length})`** → whole pager identity resets when length changes; many **`addPostFrameCallback`** paths (`jumpToPage`, precache, tab switches). |
| **P1** | `lib/features/home/widgets/trending_for_you.dart` | **`dispose()` + recreate `PageController` inside `build()`** when viewport fraction changes; post-frame re-attaches listener — race with layout and web resize. |
| **P2** | `lib/features/create/story_creator_grammar_editor_screen.dart` | `ReorderableListView` with **`ValueKey(e.id)`** — generally sound; still reorder + provider refresh surface. |
| **P2** | `lib/features/create/story_creator_vocab_kanji_editor_screen.dart` | Same pattern as grammar. |
| **P2** | `lib/features/create/story_creator_quiz_editor_screen.dart` | `ReorderableListView.builder` — verify keys on every item (spot-check: similar to grammar). |
| **P2** | `lib/features/writer/writer_screen.dart` | Reorderable with explicit key comment — lower risk but same class of bugs if keys ever regress. |

---

## B. Lifecycle-risk files

| File | Pattern |
|------|---------|
| `profile_screen.dart` | Post-frame **`ensureVisible`** after async list updates; **GlobalKey** `currentContext` may not be under the same `Scrollable` attachment on web for one frame. |
| `mono_screen.dart` | High density of **`WidgetsBinding.instance.addPostFrameCallback`** + **`setState`** + **`jumpToPage`** / scroll clients. |
| `story_creator_sentences_screen.dart` | Many post-frame callbacks; reorder mutates `TextEditingController` then **`applySentences`** + **`setState`** — tight timing with `ReorderableListView` proxy decorator. |
| `creator_route_sync.dart` / `creator_drawer_publish.dart` / `creator_learn_mode_sync.dart` | Post-frame navigation/sync (recently hardened with `GoRouter` capture); still worth listing under “route transition + list refresh” interaction tests. |
| `public_profile_screen.dart` | Multiple `addPostFrameCallback` usages. |
| `learn_hub_screen.dart` | Post-frame callback. |
| `reader/episode_reader_screen.dart` | Post-frame callbacks. |

---

## C. List identity / key risks

### 1. Unstable or index-only keys

| Location | Issue |
|----------|--------|
| `profile_screen.dart` — collection detail `ListView.builder` (~2126) | **No `Key`** on rows; identity is implicit **index**. Reorder/filter/refresh with same length can mis-associate state. |
| `trending_for_you.dart` — `PageView.builder` | Items have **no `ValueKey(story.id)`**; only index-based children. |
| `mono_screen.dart` — vertical `PageView` | Key includes **`data.length`**; **not** stable per item id — full subtree reset when count changes. |

### 2. Keys that intentionally change on reorder (higher churn on web)

| Location | Issue |
|----------|--------|
| `story_creator_sentences_screen.dart` — `_sentenceReorderKey` | When line ≠ `sentences[index].japaneseText`, key is **`plain:$index:hash:$line`**. On reorder, **indices change** → keys for multiple rows flip in one frame → `ReorderableListView` may tear down proxies while pointer is still tracked — classic web stress. |

### 3. GlobalKey accumulation / movement

| Location | Issue |
|----------|--------|
| `profile_screen.dart` — `_cardKeys.putIfAbsent(id, GlobalKey.new)` | Keys are **never removed** when drafts disappear (minor leak). **Critical:** `ensureVisible(_keyFor(id).currentContext)` after `items` / **section** reshuffle: context must still be a **descendant of the active `Scrollable`** for that `ListView`. If the row moved between `Column` sections or the scroll extent changed, **one frame** can expose a context not yet in the scrollable’s element list → **`_elements.contains(element)`**. |

### 4. Reasonably stable

| Location | Note |
|----------|------|
| Grammar / vocab / quiz reorderables | **`ValueKey(e.id)`** on pattern/entry rows — good for identity. |
| `writer_screen.dart` | Documents **`key` required** for reorderable tiles. |

---

## D. Reorder / refresh timing risks

1. **Profile Processing refresh** (`ref.listen` → `_loadLocalCreatorDraftIntoProcessing` → `setState` on parent) while `_ProcessingDraftManagerTab` holds **`ScrollController`** + **GlobalKeys** + scheduled **`ensureVisible`**: parent rebuild can replace list children **between** post-frame registration and execution.

2. **`didUpdateWidget`** in `_ProcessingDraftManagerTab` only schedules scroll when **`highlightDraftId`** changes or **`items.length`** changes — **not** when the same draft **moves section** (e.g. draft → Read Only) with **unchanged total count** or when **sort order** changes. Highlight scroll can be **stale** or **double-fired** relative to actual DOM/layout on web.

3. **`ReorderableListView`** + **`proxyDecorator`** (`story_creator_sentences_screen.dart`): animated proxy during drag; if underlying **list length** or **keys** change mid-drag (provider refresh), framework can assert.

4. **Mono** tab / level changes: **`jumpToPage(0)`** in post-frame + **`setState`** updating index — if `PageView` key forces rebuild in same gesture window, scroll position and **child elements** can disagree briefly on web.

5. **TrendingForYou**: recreating **`PageController` in `build`** disposes old scrollable while widget tree still references it until end of frame — high **web-only** sensitivity.

---

## E. Web-only timing-sensitive risks

| Mechanism | Why web is worse |
|-----------|------------------|
| **`addPostFrameCallback`** | More async layout; DOM sync can defer attachment one frame vs mobile Skia pipeline. |
| **`ReorderableListView` / drag proxies** | Pointer capture and hit-testing differ; teardown of drag child vs list child ordering. |
| **`Scrollable.ensureVisible`** | Requires element in **scrollable’s** element list; web layout + shrink-wrapped `ListView` in profile can attach later. |
| **`PageView` + changing `Key`** | Full discard of children; mobile often “gets away with it”; web hits stricter invariants under load. |
| **Resize / orientation** | `TrendingForYou` recreates `PageController` on dimension changes — continuous web resize amplifies races. |

---

## F. Top 10 UI stability fixes to do next (prioritized)

1. **Profile Processing — `ensureVisible` safety:** Before `Scrollable.ensureVisible`, assert/find the **`Scrollable`** from `context` (or use `Scrollable.maybeOf` + null guard) and skip if the context is not **attached** / not under the list’s scrollable; optionally defer with **two** micro-tasks on web only (`SchedulerBinding.scheduleFrameCallback` + post-frame) if needed — **minimal**, not a redesign.

2. **Profile Processing — GlobalKey hygiene:** Prune `_cardKeys` for ids no longer in `widget.items` in `didUpdateWidget` to avoid stale `currentContext` and memory creep.

3. **Profile Processing — `didUpdateWidget` triggers:** Also schedule `_scrollToHighlightIfNeeded` when **sorted order** or **section membership** of the highlighted id changes (not only `length`).

4. **Story sentences reorder keys:** Prefer **stable sentence `id`** keys for every row that maps to `StorySentenceItem`; avoid **`index` in `ValueKey`** for the common case — reduces reorder churn on web.

5. **Mono vertical `PageView`:** Replace key that bakes in **`data.length`** with a key that reflects **feed identity** (e.g. segment + filter) without destroying all pages on append, **or** use **`AutomaticKeepAliveClientMixin`** + stable per-item keys inside pages — pick smallest change that stops full pager reset on length tick.

6. **Collection `ListView.builder`:** Add **`ValueKey(it.id)`** (or `KeyedSubtree`) on each row for stable identity during mock edits / future reorder.

7. **Trending `PageView`:** Add per-story **`ValueKey(story.id)`**; **stop disposing/recreating `PageController` in `build`** — update viewport fraction via separate effect (`didChangeDependencies` / layout callback) without disposing mid-build.

8. **Reorderable modules (grammar/vocab/quiz):** Audit that **every** code path that mutates list length uses **`await`** + **`mounted`** before `setState` after async sheet closes (pattern already important in profile sheets).

9. **Central lint / pattern doc (optional):** “No `ensureVisible` without scrollable attachment check; no post-frame `context` after `go`/`pop`” — align with `GoRouter`-capture pattern already used in publish flow.

10. **Regression tests:** Widget tests on web target (if CI supports) for: Processing highlight after `setState`; sentence reorder one step; mono tab switch with non-empty feed.

---

## Closing answers (required)

### 1. Which issue is **most likely** causing `_elements.contains(element) is not true`?

**Primary hypothesis:** **`Scrollable.ensureVisible`** in **`profile_screen.dart`** (`_ProcessingDraftManagerTabState._scrollToHighlightIfNeeded`) using a **`GlobalKey`’s `currentContext`** in a **post-frame callback** immediately after **Processing list refresh / re-sort / section change** (draft vs Read Only vs Full Learn). On web, the keyed subtree may not yet be registered under the parent **`ListView`’s `Scrollable`** in the same frame, so `ensureVisible` walks a **`BuildContext`** whose `Element` is **not** in the scrollable’s internal element set → assertion.

**Secondary hypothesis:** **`ReorderableListView`** on **story sentences** with **index-based fallback keys** during drag end + provider refresh on **web** pointer timing.

### 2. Which files should be fixed first?

1. `lib/features/profile/profile_screen.dart` — Processing tab: **`ensureVisible` + GlobalKey + post-frame + refresh interaction**.  
2. `lib/features/create/story_creator_sentences_screen.dart` — **Reorder keys** and reorder vs `setState` timing.  
3. `lib/features/home/widgets/trending_for_you.dart` — **`PageController` lifecycle in `build`**.  
4. `lib/features/mono/mono_screen.dart` — **`PageView` key strategy** + post-frame `jumpToPage` interactions.

### 3. One focused bug vs broader stabilization?

- **If production hits are only Processing + web:** treat as **one focused bug** (ensureVisible + key lifecycle + refresh ordering) plus a **small** sentence-reorder key follow-up if reorder reproduces.  
- **If multiple surfaces show `_elements.contains`:** use this audit as a **short stabilization pass** (items 1–7 above) under one theme: **“no stale `Element`/`Scrollable` references across async + post-frame + list mutation.”**

---

*Audit based on static review of the repo’s Dart sources (April 2026). No runtime profiling was performed.*
