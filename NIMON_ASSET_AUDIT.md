# Nimon Asset / Image / Visual Media Audit

This is **analysis-only**. No code was modified as part of this report.

## A. Executive summary

Current risk level: **Medium–High** for image consistency and performance, mainly because:
- The project’s `pubspec.yaml` declares `assets/images/` as an asset directory, but the **actual assets present are very few** (mostly `assets/images/one_short/*.png` and `assets/images/mono_hero_blur_backdrop.png`).
- Multiple code paths reference **assets that do not exist** in the repo (e.g. category images under `assets/images/*.png`, and `assets/images/writer.png`).
- Many UI components use **full-size network images** (`Image.network`) without an explicit decode-size strategy (`cacheWidth/cacheHeight` / `ResizeImage`) for list rows/cards.
- There is significant use of **blur effects** (`BackdropFilter`, `ImageFiltered`) on top of images in cards/sheets, which increases render cost and compositing.

## B. Highest-risk asset/image hotspots

### 1) Mono Hero cover blur (regenerated blur from active cover)
- **File**: `lib/features/mono/mono_screen.dart`
- **Widget**: `_MonoCoverPage`
- **Why risky**
  - Uses a blurred background derived from the same cover image:
    - `ResizeImage(coverProvider, width: cw.round(), height: bh.round())`
    - `ImageFiltered(ImageFilter.blur(sigmaX: 24, sigmaY: 24))`
  - This is visually correct and more cohesive than a placeholder blur, but it is still a **heavy blur layer** with multiple stacked effects (`Opacity`, `ColorFiltered`, gradient overlay).
- **Risk type**
  - **Performance** (blur + compositing)
  - **Network image variability** (different covers → different decode sizes)

### 2) Blurred draggable sheets (full-screen BackdropFilter)
- **Files**
  - `lib/ui/bottom_sheets/episode_details_sheet.dart` (`BackdropFilter` sigma 12)
  - `lib/features/widgets/episode_bottom_sheet.dart` (`BackdropFilter` sigma 10)
- **Why risky**
  - Full-screen blur behind a sheet is expensive, especially on mid-tier devices.
  - Combines with `DraggableScrollableSheet` (continuous gesture updates).

### 3) 3D book cover widgets with blur title chips
- **File**: `lib/features/widgets/real_book_3d_cover.dart`
- **Widget**: `RealBook3DCover`
- **Why risky**
  - Multiple shadows + perspective transform + multiple clips
  - Optional `BackdropFilter` blur in the title chip
  - If used in scrolling lists, can amplify raster load.

### 4) Home/collection cards: repeated network cover usage
- **Files**
  - `lib/features/home/widgets/book_cover_card.dart` (`Image.network` for cover and circular variant)
  - `lib/features/home/widgets/mono_collection_row.dart` (episode cards load category “cover” via network mapping)
  - `lib/shared/widgets/cards/oneshot_badged_card.dart` (cover network images)
- **Why risky**
  - Many `Image.network` calls in card lists without explicit decode size.
  - Repeated overlays (badges/chips/title bars) increase compositing.

## C. Performance-heavy image usage

### 1) No explicit thumbnail strategy in most list/card images
- **Observed in**
  - `BookCoverCard` (`Image.network(story.coverUrl ?? picsum 600/900)`): no `cacheWidth/cacheHeight`
  - `OneShotBadgedCard` (`Image.network(oneShot.coverUrl!)`): no decode-size hints
  - `MonoCollectionRow._EpisodeCard` (`Image.network(cover)`): no decode-size hints
- **Risk**
  - Decodes may be larger than the on-screen size, increasing memory and decode time.

### 2) Placeholder/fallback inconsistency
- Some widgets use:
  - gray container + spinner
  - `Icon(Icons.book)`
  - `Icon(Icons.image_outlined)`
  - gradient placeholder
- **Risk**
  - Visual inconsistency and repeated code paths.
  - Harder to maintain consistent loading states.

## D. Blur/background image risks

### 1) BackdropFilter on cards and sheets
- **Files**
  - `lib/features/home/widgets/book_cover_card.dart` (blur title bar)
  - `lib/shared/widgets/cards/oneshot_badged_card.dart` (blur title band)
  - `lib/ui/bottom_sheets/episode_details_sheet.dart`
  - `lib/features/widgets/episode_bottom_sheet.dart`
  - `lib/features/widgets/real_book_3d_cover.dart` (title chip)
- **Risk**
  - Backdrop blur is one of the most expensive visual effects in Flutter; doing it in lists or draggable sheets is a common jank source.

### 2) Mono hero blur is correct-but-costly
- `_MonoCoverPage` now regenerates blur from the same cover image (good quality and cohesiveness).
- Still uses:
  - `ImageFiltered` + high sigma blur
  - additional opacity/color filtering and gradient overlays
- **Risk**
  - Potential jank on older devices and increased GPU work during transitions.

## E. Missing/broken asset risks

### 1) Category assets referenced but not present
- **File**: `lib/core/story_categories.dart`
- **Code**:
  - `getCategoryImagePath(...)` → returns `assets/images/<category>.png`
  - `getEpisodeThumbnailPath(...)` → returns `assets/images/<category>_<episode>.png`
- **Repo reality**
  - Present assets are only:
    - `assets/images/one_short/{love,comedy,horror,art,history}.png`
    - `assets/images/mono_hero_blur_backdrop.png`
  - There are **no** `assets/images/love.png`, `assets/images/comedy.png`, etc.
- **Risk**
  - Runtime missing asset exceptions if used.

### 2) `assets/images/writer.png` referenced but not present
- **Files**
  - `lib/core/story_categories.dart` returns `assets/images/writer.png` as placeholder
  - `lib/features/home/widgets/mono_collection_row.dart` `_IntroCard` uses `Image.asset('assets/images/writer.png')`
- **Repo reality**
  - No `assets/images/writer.png` is present.
- **Risk**
  - Immediate missing-asset crash when `_IntroCard` renders, or when placeholder path is used.

### 3) `.jpg` references in OneShort paper card mapping
- **File**: `lib/ui/create/widgets/one_short_paper_card.dart`
- **Code**: `assetForCategory(...)` returns `assets/images/one_short/<cat>.jpg`
- **Repo reality**
  - Only `.png` assets exist under `assets/images/one_short/`.
- **Risk**
  - Missing asset error when rendering that card.

## F. Standardization opportunities

### 1) Define a single image loader wrapper
Candidate: `NimonNetworkImage` (analysis suggestion)
- Shared behaviors:
  - consistent placeholder
  - consistent error fallback
  - optional decode sizing (`cacheWidth/cacheHeight`)
  - `gaplessPlayback: true` where helpful

### 2) Standardize category/cover asset mapping
- Current mapping is split:
  - `StoryCategories` suggests `assets/images/<category>.png` but those assets don’t exist.
  - OneShort uses `assets/images/one_short/...` but mixes `.jpg` and `.png`.
- Suggestion:
  - One canonical mapping file for story categories and their assets, aligned with real assets.

### 3) Standardize blur usage patterns
- Prefer:
  - image-derived blur layers (`ImageFiltered` on an image) for hero backgrounds
  - avoid `BackdropFilter` in scrolling lists where possible
- If blur is required:
  - keep blur areas small (title chips only)
  - keep sigma modest and consistent

### 4) Thumbnail strategy for list rows/cards
- For fixed-size cards (e.g. 120×180), standardize a `cacheWidth/cacheHeight` strategy.

## G. Recommended cleanup order (analysis-only)

1. **Fix missing/broken asset references**
   - `assets/images/writer.png`
   - `.jpg` vs `.png` mismatches in one-short category assets
   - category asset path assumptions in `StoryCategories`
2. **Introduce a thumbnail decode strategy** for all high-frequency list/card images.
3. **Unify placeholders** (one consistent skeleton/placeholder style).
4. **Audit and reduce BackdropFilter usage** where it appears in list items or draggable sheets.
5. **Consolidate category cover sources** (asset vs network) for Mono vs Collection vs Story consistency.

## H. Top 10 asset/image fixes I would do first

1. **Add or correct `assets/images/writer.png` usage** (currently referenced in multiple places but missing).
2. **Fix OneShort paper card asset paths** (`.jpg` → `.png` or add missing jpgs).
3. **Align `StoryCategories.getCategoryImagePath` with real assets** (or add the missing category PNGs).
4. **Add decode sizing (`cacheWidth/cacheHeight`) to all card/list `Image.network` usages**.
5. **Standardize placeholders and error builders** across all image widgets.
6. **Reduce BackdropFilter usage in scrolling surfaces** (title bars/chips) where it’s purely decorative.
7. **Ensure consistent category thumbnail strategy** between collections, mono, and story UI.
8. **Audit duplicate network “cover URLs” vs local asset covers** to avoid fetching when assets are available.
9. **Review `mono_hero_blur_backdrop.png` usage** (currently present but not referenced in code paths found—confirm it’s needed).
10. **Create a single “image style system”** (radii, shadows, overlay gradients) to reduce drift and ensure consistent quality.

## I. File impact list

Most relevant files for asset/media cleanup:
- `pubspec.yaml` (asset declarations)
- `lib/features/mono/mono_screen.dart` (hero blur, cover rendering)
- `lib/ui/bottom_sheets/episode_details_sheet.dart` (blurred sheet)
- `lib/features/widgets/episode_bottom_sheet.dart` (blurred sheet)
- `lib/features/widgets/real_book_3d_cover.dart` (3D cover + blur chip)
- `lib/features/home/widgets/book_cover_card.dart` (network covers + BackdropFilter title bar)
- `lib/shared/widgets/cards/oneshot_badged_card.dart` (network covers + blur band)
- `lib/features/home/widgets/mono_collection_row.dart` (references missing asset `writer.png`, network category covers)
- `lib/core/story_categories.dart` (category asset path assumptions + missing writer.png)
- `lib/ui/create/widgets/one_short_paper_card.dart` (incorrect `.jpg` asset mapping)

