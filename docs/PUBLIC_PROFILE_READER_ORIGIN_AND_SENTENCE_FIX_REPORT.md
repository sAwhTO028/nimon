# Public Profile Reader Origin And Sentence Fix Report

## Root Cause

1. **Owner menu / dock:** `PublicProfileScreen` pushed `/mono-reader` with `MonoReaderMenuOrigin.profileUploaded` and a **single** `MonoFeedItem`. `MonoScreen` defaulted the story-options dock to profile-owner behavior (`MonoReaderDock` menu + `_openReaderDockStoryOptionsPanel`).

2. **Vertical feed:** Only one item was passed, so the reader `PageView` could not scroll to the next creator story.

3. **Sentence vs description:** Catalog summaries (`monoFeedItemFromMonoFeedSummary`) copied `description` into `bodyText`. Reader horizontal “Storytelling” path fell back to plain `effectiveBodyText` before `GET /v1/mono/:id` ran. **`_ensureDetailLoaded` only ran for main Mono feed** (`_useRemoteForYouFeed` / `_useRemoteFollowingFeed`), not for `/mono-reader` with `initialItemsOverride`, so public profile opens never hydrated structured `content.core.sentences`.

## Route / Origin Fix

- New enum value: `MonoReaderMenuOrigin.publicCreatorProfile`.
- `PublicProfileScreen` now passes:
  - `'items': List<MonoFeedItem>.from(_creatorMonos)` (full loaded page)
  - `'initialIndex': i` (tapped row)
  - `'readerMenuOrigin': MonoReaderMenuOrigin.publicCreatorProfile`

## Menu Visibility Policy

- **Owner menu** (bottom-right circle on `MonoReaderDock`): only when `readerMenuOrigin` is `profileUploaded` or `profileSaved`.
- **Learner/public:** `publicCreatorProfile` → `onMenu: null`; **Add Mono +** remains full-width when the menu is hidden.

## Vertical Feed Continuity

- Reader uses the same vertical `PageView` as other immersive readers; passing the full `_creatorMonos` list restores next/previous story scrolling within the **currently loaded** creator page (same limit as `fetchCreatorMonoPage`, default 15). Further pages require **Load more** on the profile first (not auto-prefetched into the reader).

## Story Sentence Hydration Fix

- `PaginatedState` / reader: `_resolvedFeedItems` merges `initialItemsOverride` through `_hydratedRemoteItems` (same pattern as remote feed).
- `_ensureDetailLoaded` runs when `!showTopControls && initialItemsOverride != null` (plus existing feed paths). Fetch uses `item.monoIdForLearnRoutes` for `GET /v1/mono/:id`.
- `monoFeedItemFromMonoFeedSummary`: `bodyText: ''` (description stays in `storyDescription` for list/footer).
- `monoFeedItemMergePublishedDetail`: removed substituting `d.description` into `bodyText` when sentences are missing; footer remains `storyDescription`.
- `monoFeedItemFromPublishedMonoDetail`: `bodyText` no longer falls back to raw description (aligned with public reader policy).

## Tests Added

- `test/features/mono/mono_reader_public_profile_dock_test.dart` — menu hidden when `onMenu` null; shown when set.
- `mono_feed_item_mapper_test.dart` — summary `bodyText` empty; merge without sentences does not promote description into `bodyText`.

## Flutter Analyze Result

`flutter analyze` on touched lib files reported **no issues** for `mono_reader_dock.dart` after replacing deprecated `withOpacity`. Broader scans may still surface pre-existing infos elsewhere.

## Flutter Test Result

- `flutter test test/features/mono` — passed  
- `flutter test` (full suite) — **354 tests passed**

## Manual Verification Steps

1. Open a **public** creator profile (`?userId=`), tap a story: **no** bottom-right owner menu; **Add Mono +** still works.
2. Swipe vertically: move to another story in the same loaded list.
3. Swipe horizontally into reading: Japanese lines match **published sentences**, not the Story Basics blurb; blurb remains in the **footer** (`ExpandableFooterDescription` / `subtitleLine`).

## Remaining Risks

- Reader only includes monos from the **current** public-profile page until the user loads more on the profile screen.
- If `GET /v1/mono/:id` fails, the story may show **cover-only** horizontal page until content exists (by design: avoid showing description as fake “sentences”).
- `MonoReaderMenuOrigin` default for **null** extra is no longer treated as `profileUploaded` for the options panel (panel only opens when origin is explicitly owner/saved).
