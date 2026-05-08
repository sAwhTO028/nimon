# Description Display UI Fix Report

## Files Changed

- `lib/features/mono/mono_feed_models.dart` — Added `storyDescription` for Story Basics copy (separate from reading `bodyText` / structured content).
- `lib/features/mono/data/mono_feed_item_mapper.dart` — Maps summary and merged detail `description` into `storyDescription`; reading body still uses `plainBodyFromPublishedCore` when present.
- `lib/features/mono/mono_screen.dart` — Footer meta subtitle uses `storyDescription` instead of Japanese content-type labels; Learn navigation passes basics-first description string.
- `lib/features/learn/learn_hub_screen.dart` — Section title **Description**; block omitted when there is nothing to show.
- `lib/features/profile/data/published_mono_reader_mapper.dart` — Profile/detail mapper sets `storyDescription` from published detail `description`.
- `lib/features/profile/profile_screen.dart` — Folder-row `MonoFeedItem` sets `storyDescription` from list item description.
- `test/features/mono/mono_feed_item_mapper_test.dart` — Coverage for `storyDescription` mapping and merge behavior.
- `test/features/learn/learn_hub_screen_test.dart` — Widget tests for heading and visibility rules.

## Root Cause

1. **Mono Home footer:** `_PostFooterMeta` displayed `_contentTypeLabel(contentType)` (e.g. `読解 · 記事`), which looked like a category, not the publisher’s Story Basics description.
2. **Learn hub:** `_openLearn` passed the first paragraph of `effectiveBodyText` (joined sentence body when hydrated), so “What’s inside” showed reading copy instead of Story Basics description.
3. **Data model:** `bodyText` / `effectiveBodyText` intentionally favor structured sentence content for reading; there was no dedicated field for Story Basics description after detail merge, so UI could not reliably show publish metadata separately from body text.

## Mono Home Description Behavior

- The third line under creator + title shows **only** trimmed `MonoFeedItem.storyDescription` when non-empty (up to two lines, ellipsis).
- If Story Basics description is empty, **that line is hidden** (no substitute from content type).
- Title and uploader row are unchanged.

## Learn Detail Description Behavior

- Section title is **Description** (replacing “What’s inside”).
- Body text prefers **`storyDescription`** (Story Basics). If that is empty, **fallback** uses the same rule as before: first paragraph of `effectiveBodyText` (reading plain text), so legacy flows still show something when the API leaves basics blank.
- When the resolved description string is empty, the **entire** Description section (title + card) is **hidden** (no em dash placeholder).
- **See more / See less** in `_InsideCard` is unchanged for non-empty text.

## Data Mapping

- **Feed summary (`MonoFeedSummaryDto.description`):** `monoFeedItemFromMonoFeedSummary` sets `storyDescription` from the API description field (same source as before for initial `bodyText`).
- **Detail hydration (`PublishedMonoDetailDto.description`):** `monoFeedItemMergePublishedDetail` sets `storyDescription` from detail when non-empty; otherwise keeps the summary value. Reading `bodyText` still prefers `plainBodyFromPublishedCore` when the core has sentences.
- **Profile published reader:** `monoFeedItemFromPublishedMonoDetail` sets `storyDescription` from detail `description`.
- No backend changes; if a feed summary omits description entirely, the subtitle stays empty until detail load fills `storyDescription` (when the detail payload includes `description`).

## Tests Added

- Mapper tests for `storyDescription` on summary mapping; preservation when merged with sentence core; retention of summary basics when detail `description` is empty.
- `LearnHubScreen` widget tests: visible **Description** heading and body copy; section hidden when `description` is null/empty.

## Flutter Analyze Result

Command:

`flutter analyze lib/features/mono/mono_feed_models.dart lib/features/mono/data/mono_feed_item_mapper.dart`

Result: **No issues found.**

Broader analyze on very large files (`mono_screen.dart`, `profile_screen.dart`) still reports **pre-existing** infos/warnings (e.g. deprecated `withOpacity`, unused fields). No new analyzer errors were introduced for the paths above.

## Flutter Test Result

- `flutter test test/features/mono` — **passed**
- `flutter test test/features/learn/learn_hub_screen_test.dart` — **passed**
- `flutter test` (full suite) — **All tests passed** (235 tests at time of run).

## Remaining Risks

- **Summary without description:** Until detail hydration runs, `storyDescription` may be empty and the Mono footer line stays hidden even if `bodyText` temporarily mirrors an older summary-only behavior for reading.
- **Fallback to reading text:** If Story Basics is empty but sentences exist, Learn hub still shows the first paragraph of reading plain text so the section is not permanently blank; product may later tighten this to “always hide” or a dedicated copy string.
