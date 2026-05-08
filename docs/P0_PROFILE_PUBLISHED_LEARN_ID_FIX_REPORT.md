# P0 Profile Published Learn Id Fix Report

**Date:** 2026-05-03  
**Scope:** Profile → Published → Learn uses **`GET /v1/mono/<PublishedMonoUuid>`** and published **`content.learn`** via existing catalog providers. No backend, migrations, cover, or listening changes.

**Reference:** [M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md](M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md)

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/mono/mono_feed_models.dart` | `kProfilePublishedMonoFeedItemIdPrefix`; optional **`catalogMonoId`**; **`monoIdForLearnRoutes`** getter. |
| `lib/features/profile/data/published_mono_reader_mapper.dart` | Sets **`catalogMonoId`** to raw published id; documents **`kProfilePublishedMonoIdPrefix`** as alias of shared prefix. |
| `lib/features/mono/data/mono_feed_item_mapper.dart` | **`monoFeedItemMergePublishedDetail`** preserves **`catalogMonoId`**. |
| `lib/features/mono/mono_screen.dart` | **`_openLearn`** pushes **`/learn/${item.monoIdForLearnRoutes}`** (one-line). |
| `lib/features/learn/learn_catalog_content_gate.dart` | **`normalizeCatalogMonoIdForUuidCheck`**; **`catalogMonoIdLooksLikeUuid`** strips profile prefix before UUID regex. |
| `test/features/learn/learn_catalog_content_gate_test.dart` | **New** — prefix strip, UUID detection, **`learnDemoMocksAllowed`** for prefixed id. |
| `test/features/profile/published_mono_reader_learn_route_id_test.dart` | **New** — mapper exposes raw learn id via **`catalogMonoId`** / getter. |

---

## Root Cause

Profile reader builds **`MonoFeedItem.id`** as **`profile-<PublishedMonoUuid>`** so unsave / menu logic can distinguish rows. **`MonoScreen._openLearn`** used **`item.id`** in **`/learn/${item.id}`**, so Learn watched **`catalogPublishedMonoDetailProvider('profile-…')`** → invalid **`GET /v1/mono/:id`**. In debug, **`learnDemoMocksAllowed`** treated the prefixed string as non-UUID → **mock learn lists**.

---

## ID Routing Fix

- **`catalogMonoId`** on **`MonoFeedItem`** holds the **raw PublishedMono id** for Profile-published rows only.
- **`monoIdForLearnRoutes`** returns **`catalogMonoId`** when set, otherwise strips **`kProfilePublishedMonoFeedItemIdPrefix`** from **`id`**, else **`id`** (Mono Home).
- **`_openLearn`** uses **`monoIdForLearnRoutes`** so the shell route and all **`/learn/:id/...`** children resolve the same catalog UUID.

---

## Profile Menu / Unsave Safety

- **`MonoFeedItem.id`** remains **`profile-<uuid>`** for items from **`monoFeedItemFromPublishedMonoDetail`** — reader **`onUnsavedMonoFeedItemId`** and **`MonoReaderMenuOrigin.profileUploaded`** behavior unchanged.
- **`monoFeedItemMergePublishedDetail`** copies **`catalogMonoId`** from the catalog **`base`** item so detail hydration does not drop the raw id when Profile rows are merged later (defensive).

---

## Mock Fallback Guard

- **`catalogMonoIdLooksLikeUuid`** now runs UUID detection on **`normalizeCatalogMonoIdForUuidCheck(contentId)`**, so **`profile-<uuid>`** is treated as a catalog id for mock gating.
- **`learnDemoMocksAllowed('profile-<uuid>')`** is **false** in debug (and always false in release), matching real Learn hydration expectations.

---

## Tests Added

| File | Coverage |
|------|----------|
| `test/features/learn/learn_catalog_content_gate_test.dart` | Prefix normalization; UUID match; **`learnDemoMocksAllowed`** for prefixed catalog UUID. |
| `test/features/profile/published_mono_reader_learn_route_id_test.dart` | **`monoFeedItemFromPublishedMonoDetail`**: **`id`** prefixed, **`catalogMonoId`** and **`monoIdForLearnRoutes`** raw UUID. |

---

## Flutter Analyze Result

```bash
flutter analyze lib/features/mono/mono_feed_models.dart \
  lib/features/mono/data/mono_feed_item_mapper.dart \
  lib/features/profile/data/published_mono_reader_mapper.dart \
  lib/features/learn/learn_catalog_content_gate.dart \
  test/features/learn/learn_catalog_content_gate_test.dart \
  test/features/profile/published_mono_reader_learn_route_id_test.dart
```

**Result:** No issues found.

Including **`mono_screen.dart`** in analyze still reports long-standing infos/warnings in that file (unchanged by this one-line edit).

---

## Flutter Test Result

```bash
flutter test test/features/learn
flutter test
```

**Result:** All tests passed (**199** in the full-suite run used for this report).

---

## Remaining Risks

- Any **other** code path that builds **`/learn/${...}`** from a **`MonoFeedItem.id`** without **`monoIdForLearnRoutes`** could reintroduce the bug (grep should stay clean).
- **`monoIdForLearnRoutes`** fallback strip assumes the only learn-problematic prefix is **`kProfilePublishedMonoFeedItemIdPrefix`**.

---

## Recommended Next Step

- **M4b3e / product:** Optional **`catalogPublishedMonoDetailProvider`** invalidation on pull-to-refresh after publish (see M4 closeout notes).
- **P1 (separate task):** Cover image **https** / upload; Listening transcript from **`content.core.sentences`** per [M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md](M4_REMAINING_PROFILE_LISTENING_COVER_AUDIT.md).

---

## Output checklist

| Question | Answer |
|----------|--------|
| Profile Learn uses raw published mono id? | **Yes** — via **`catalogMonoId`** + **`monoIdForLearnRoutes`** and **`/learn/${item.monoIdForLearnRoutes}`**. |
| Debug mock fallback prevented? | **Yes** for **`profile-<uuid>`** — UUID check normalizes prefix; test asserts **`learnDemoMocksAllowed`** is false. |
| Profile reader / menu behavior preserved? | **Yes** — **`id`** still prefixed for Profile-sourced **`MonoFeedItem`**. |
| `test/features/learn` passed? | **Yes** |
| Full `flutter test` passed? | **Yes** (199 tests) |
| Next fix recommendation | **Cover URL / upload** and/or **Listening transcript** from audit doc. |
