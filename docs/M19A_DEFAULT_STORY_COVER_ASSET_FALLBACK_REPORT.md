# M19A — Default story cover asset fallback

## Summary

Published monos and other story rows now use a single bundled PNG when there is no usable uploaded cover URL or when a network cover fails to load.

## Asset

- **File:** `assets/images/nimon_default_story_cover_v1.png`
- **Dart constant:** `nimonDefaultStoryCoverAsset` in `lib/ui/nimon_default_cover_asset.dart`
- **Registration:** `pubspec.yaml` already includes `assets/images/` as a directory; no duplicate entry was added.

## Fallback rules

1. If `coverImageUrl` is **null**, **empty**, or **whitespace-only** (after trim), show `Image.asset(nimonDefaultStoryCoverAsset)`.
2. If a **non-empty** URL is used with `Image.network`, **`errorBuilder`** replaces the failed load with the same default asset.
3. **Mono reader hero** (`_MonoCoverPage`): missing URL uses the default asset for both blurred background and foreground; network failure uses the default asset for foreground and background image layers (replacing the previous solid-color / category-based art fallback).

## Shared widget

- **`lib/ui/nimon_story_cover_image.dart`** — `NimonStoryCoverImage` (fixed `width` / `height`, optional `borderRadius`, `fit`, etc.) to avoid layout shift and keep clipping consistent with existing cards.

## Affected UI surfaces

| Surface | Mechanism |
|--------|-----------|
| Mono feed reader cover page | `_MonoCoverPage` in `mono_screen.dart` |
| Learn hub cover strip | `LearnHubScreen` + route extra `coverFallbackAsset` now defaults to the same asset when absent |
| Mono story options sheet thumb | `_CoverThumb` |
| Profile Published / Saved / stacked folder thumb | `PublicStoryThumb`, `_StoryCoverThumb` |
| Public profile & collection mono rows | `MonoStoryListRow` → `PublicStoryThumb` |
| Mono search results | `MonoStoryListRow` |
| Profile trash rows | `NimonStoryCoverImage` inline |
| Episode bottom sheet row cover | `_buildCoverImage` |

**Intentionally unchanged:** profile **banner** `_CoverImage` (writer profile header, not story art), collection **folder** stacked thumb placeholder (not mono story cover), create/upload flows, backend, and pagination.

## Tests

| Location | What is covered |
|----------|-----------------|
| `test/ui/nimon_story_cover_image_test.dart` | null / empty / whitespace → asset; valid URL → `NetworkImage`; failing URL → asset after async; `MonoStoryListRow` null thumb; `hasUsableCoverUrl` |
| `test/features/search/mono_search_screen_test.dart` | Search list with `coverImageUrl: null` shows default asset in the tree |

## Phone acceptance checklist

- [ ] Mono feed: item with no server cover shows default art on the cover page (not a random category tile).
- [ ] Mono feed: broken cover URL still shows default art after load failure.
- [ ] Profile → Published: rows without cover show default thumb.
- [ ] Profile → Saved: same.
- [ ] Search: results with null cover show default thumb.
- [ ] Trash: trashed rows with null/broken cover show default thumb.
- [ ] Reader options sheet: thumb matches feed default when cover missing.
- [ ] Open Learn from mono: hub header shows default when no cover URL.

## Commands run (during implementation)

- `dart format` on touched Dart files
- `flutter test test/ui`
- `flutter test test/features/mono`
- `flutter test test/features/profile`
- `flutter test test/features/search`
- `flutter test`
