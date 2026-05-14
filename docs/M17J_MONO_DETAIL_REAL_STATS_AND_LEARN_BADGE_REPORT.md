# M17J — Mono detail real stats + Learn badge label polish

## Summary

Profile mono story options (Published + Saved) now show **likes**, **read time / duration**, and **category** from server-backed fields on `MonoFeedItem`, with **no fabricated defaults** (no fake `1` likes, no `2m` from body text, no `Article`/`Story` from content type alone).

Learn hub detail stat card **Download / Use offline** is replaced with **Manual / Creator-made** (localized EN/JA/MY), with a non-download icon.

## Part A — Real data (Flutter)

### Shared UI

- `lib/ui/bottom_sheets/mono_story_options_sheet.dart` — metrics row uses:
  - `monoDetailSheetLikesValue(item)` — `item.likesCount` (formatted), default **0**
  - `monoDetailSheetReadTimeValue(item)` — `item.readDurationLabel` or `—`
  - `monoDetailSheetCategoryValue(item)` — `item.catalogCategory` or `—`

### Mapping helpers

- `lib/features/mono/mono_feed_item_detail_metrics.dart` — single source for sheet labels.

### `MonoFeedItem` fields

- `lib/features/mono/mono_feed_models.dart`
  - `readDurationLabel` — server `targetDurationLabel` (or equivalent)
  - `catalogCategory` — first of `categories` / `category` / `genre` when present

### Feed / published list

- `lib/features/mono/data/mono_feed_item_mapper.dart` — maps `targetDurationLabel`, `category`/`categories` from feed + published list DTOs.

### Published tab (owner reader)

- `lib/features/profile/data/published_mono_reader_mapper.dart` — uses `PublishedMonoDetailDto.targetDurationLabel`, `category`/`categories`, `likesCount`; `contentType` set to **article** for reader (was `story`, which produced misleading “Story” category in the sheet).

### Published GET detail (Flutter parse)

- `lib/features/profile/data/remote_published_mono_repository.dart` — `get()` now parses `likesCount`, `isBookmarkedByMe`, `myReaction` (aligned with feed detail).

### Saved tab (bookmarks)

- `lib/features/mono/data/remote_mono_social_repository.dart` — bookmark list items set `catalogCategory`, `readDurationLabel` from JSON (`targetDurationLabel` when present).

## Part B — Backend

### Published mono detail `GET /v1/published-monos/:id`

- `PublishedMonoDetailDto` extended with `likesCount`, `isBookmarkedByMe`, `myReaction`.
- `getPublishedMonoById` loads reaction count, bookmark count, and current user reaction (same pattern as public mono detail).

### Bookmarks list

- Bookmark list items now include `targetDurationLabel` (from `content.core.targetDurationBandKey` via shared `durationLabelFromKey`), so Saved tab can show real duration without client guessing.

### Field inventory

| Concern | Primary fields |
| --- | --- |
| Likes / react count | `likesCount` (detail + list where exposed); reaction detail via `myReaction` unchanged |
| Duration / read time | `targetDurationLabel` (DTO); client maps to `readDurationLabel` |
| Category | `category`, `categories[]`, or `genre` when present → `catalogCategory` |

**Gaps:** If a list endpoint omits category/duration, the sheet shows `—` for that metric (no fake inference).

## Part C — Learn hub badge

- `lib/features/learn/learn_hub_screen.dart` — third info row: **Manual** / **Creator-made**, `Icons.edit_note_outlined`.
- ARB keys: `learnPackageManualBadge`, `learnPackageCreatorMadeBadge` (EN/JA/MY).

## Part D — Localization

- EN/JA/MY ARB + generated `AppLocalizations` getters for the two badge strings.

## Part E — Tests

- `test/features/mono/mono_feed_item_detail_metrics_test.dart` — likes / duration / category / absence of fake defaults when real data differs.
- `test/features/mono/remote_mono_social_repository_test.dart` — bookmark JSON maps `category` + `targetDurationLabel`.
- `test/features/learn/learn_hub_screen_test.dart` — Manual / Creator-made; no Download / Use offline.
- `test/features/learn/learn_dark_surface_smoke_test.dart` — `AppLocalizations` delegates (required after hub l10n).

### Backend

- `published-monos.service.spec.ts` — `getPublishedMonoById` expects social fields on detail DTO.

## Commands run (agent)

- `dart format` on touched Dart files
- `flutter test` on: `mono_feed_item_detail_metrics_test`, `remote_mono_social_repository_test` (M17J bookmark mapping), `learn_dark_surface_smoke_test`, `learn_hub_screen_test` (all passed after fixes below)
- Recommended full suite: `flutter test test/features/profile test/features/mono test/features/learn` then `flutter test`
- Backend (when changing published detail / bookmarks): `jest` on `published-monos` and `mono-social`, `nest build`

### Test fixes (M17J follow-up)

- `mono_feed_item_detail_metrics_test`: `const MonoFeedItem` cannot use `'x' * 5000` in a const constructor; empty `bodyText` suffices for the “no duration label → em dash” case.
- `remote_mono_social_repository_test`: mock `http.Response` body must be Latin1-safe; use ASCII `5-7 min` instead of Unicode en-dash in the JSON string.

## M17H checklist (Part H)

| Question | Answer |
| --- | --- |
| Published detail likes real? | Yes — from `likesCount` on mapped `MonoFeedItem` (detail GET + mapper). |
| Published detail duration real? | Yes — `targetDurationLabel` → `readDurationLabel`, else `—`. |
| Published detail category real? | Yes — `category`/`categories`/`genre` → `catalogCategory`, else `—`. |
| Saved detail likes real? | Yes — `likesCount` from bookmark API. |
| Saved detail duration real? | Yes — `targetDurationLabel` on bookmark list (backend) → `readDurationLabel`, else `—`. |
| Saved detail category real? | Yes — from bookmark item category fields. |
| Fake/static values removed? | Yes — no `2m` from body, no type-derived Story/Article label. |
| Learn card Manual / Creator-made? | Yes. |
| Backend touched? | Yes — published detail social fields; bookmark `targetDurationLabel`. |
| Flutter tests passed? | As run in agent session (see Commands). |
| Docs updated? | This file. |
