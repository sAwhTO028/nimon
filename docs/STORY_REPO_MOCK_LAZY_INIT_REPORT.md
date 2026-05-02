# StoryRepoMock Lazy Init Report

**Purpose:** Document explicit lazy memoization for mock story / episode / one-shot catalogs in `StoryRepoMock`, aligned with `docs/STORY_REPO_LIVE_DEPENDENCY_MAP.md` (live Mono/Profile do not call `StoryRepo` today).

---

## Files Changed

| File | Change |
|------|--------|
| `lib/data/story_repo_mock.dart` | Replaced library-level `late final` list fields with nullable memo variables plus private getters (`_stories`, `_episodes`, `_oneShots`) using `??=` on first read. Consolidated imports (`story_repo`, `story`, `oneshot`, `filter_state`, `section_key`, `episode_mock_data`). |

**Not changed:** `lib/data/story_repo.dart`, `lib/data/repo_singleton.dart`, `lib/data/episode_mock_data.dart`, `MonoScreen`, `ProfileScreen`, routing.

---

## Previous Behavior

- Three library-level **`late final`** lists each ran their initializer on **first read** of that variable (standard Dart semantics for `late final` with an initializer).
- **`StoryRepoMock()`** did not access those lists; **`repo_singleton.dart`** only constructs the mock.
- Different API methods touched different catalogs first (e.g. `listStories` → `_stories` only; `fetchQuickOneShots` → `_oneShots` only; `getEpisodesByStory` / `addEpisode` → `_episodes`, which depends on `_stories` inside `_genEpisodes`).
- Importing `story_repo_mock.dart` did **not** build the lists by itself.

---

## New Behavior

- **`_storiesMemo` / `_episodesMemo` / `_oneShotsMemo`** hold caches; getters assign with **`??=`** on first access.
- **Same generation functions** (`_genStories`, `_genEpisodes`, `_genOneShots`), **same list instances** for mutations (**`addEpisode`** still appends to the memoized `_episodes` list).
- **`StoryRepo` public API** unchanged: method signatures, return types, delays, and filtering logic are preserved.

---

## Why This Improves Startup

- For the **current app**, cold start **already avoided** building mock catalogs until the **first `StoryRepo` method call** (previous `late final` was lazy per field).
- This refactor **documents and encodes** that contract explicitly, reducing the chance a future change accidentally triggers generation during library load or construction.
- **Heavy work** (notably episode bodies using **`episode_mock_data.dart`**) still runs only when **`_episodes`** is first populated—same trigger points as before.

---

## Compatibility Notes

- **No** changes to **`StoryRepo`** or **`StoryRepoMock` method signatures**.
- **Identical** observable behavior for callers that use the same method sequences as before (including **`addEpisode`** after partial initialization).
- Archived legacy UI under `archive/` is excluded from analysis but would behave the same if re-linked.

---

## Flutter Analyze Result

| Metric | Result |
|--------|--------|
| **Command** | `flutter analyze` |
| **Error-severity issues** | **0** |
| **Total issues** | **225** (warnings + infos; project baseline; not a cleanup pass) |

---

## Flutter Test Result

| Metric | Result |
|--------|--------|
| **Command** | `flutter test` |
| **Outcome** | **All tests passed** (**36** tests) |

---

## Risk Notes

- Semantics are intended to match **`late final`** lazy initialization; if any external code relied on **identity** of unmemoized vs memoized lists across isolates, there is none in-repo—**same single instance per getter** after first use.
- Duplicate-import **warnings** in this file were removed incidentally; overall analyzer issue count may shift slightly.

---

## Recommended Next Step

- When **`StoryRepo`** gains a real backend implementation, consider **splitting** mock generation behind an interface or **feature flags** so tests can inject smaller fixtures without touching **`episode_mock_data.dart`**.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Files changed** | `lib/data/story_repo_mock.dart`, `docs/STORY_REPO_MOCK_LAZY_INIT_REPORT.md` |
| **Public API changed?** | **No** (`StoryRepo` unchanged; `StoryRepoMock` method signatures unchanged). |
| **`flutter analyze` 0 errors?** | **Yes** |
| **`flutter test` passed?** | **Yes** (36/36) |
| **Risks** | Low: refactor is memoization-only with preserved generators and mutability. |
