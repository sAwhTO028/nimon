# Nimon Performance Audit (render cost + interaction latency risks)

This is **analysis-only**. No code was modified as part of this report.

## A. Executive summary

Overall risk level: **Medium–High**.

The app will generally feel smooth on modern devices, but there are several **high-cost UI patterns** that can cause jank on mid-tier phones, especially during **scroll**, **drag**, and **blur-heavy overlays**:
- **Heavy blur / filter layers** (`BackdropFilter`, `ImageFiltered`, `ImageFilter.blur`) used in sheets, cards, and Hero cover treatment.
- **Large widget subtrees** in a few “mega files” (notably `mono_screen.dart`, `profile_screen.dart`, and `story_creator_sentences_screen.dart`) with many rebuild triggers.
- **OverlayEntry-based panels** that animate and handle gestures while also hosting scrollable content.
- **Custom ruby text layout** uses `TextPainter` measurement and widget spans; rendering long content can be expensive if rebuilt often.

Top concerns (practical):
- **Blur + scrolling/dragging** (sheet blur backdrops, overlay panels) is the most likely source of dropped frames.
- **Broad rebuild scope** around feed items and creator screens can amplify cost when state changes.
- **Image decoding at full resolution** and repeated filtered layers can increase memory + raster time.

## B. Highest-risk hotspots

### 1) `lib/features/mono/mono_screen.dart` — Mono feed + Hero/Read presentation
- **Widget/class/function**: `MonoScreen`, `_ReadingFeedPostState`, `_MonoCoverPage`
- **Why it may be heavy**
  - Mixed **vertical feed** + **inner horizontal PageView** per feed item.
  - Hero cover uses **`ImageFiltered(ImageFilter.blur)`**, `ClipRect`, `RepaintBoundary`, and multiple stacked layers (background image + gradients).
  - Read mode uses `SingleChildScrollView` with potentially long `NimonRubyText` content.
  - Uses `ValueListenableBuilder` and multiple `ValueNotifier`s per item (bookmark/react) which can trigger localized rebuilds; if not carefully scoped, can still be costly.
- **Severity**: **High**
- **Likely issue vs confirmed**
  - **Likely**: Blur layer raster cost during transitions/scroll.
  - **Likely**: Nested `PageView` interactions causing extra work when gesture arena resolves.

### 2) `lib/ui/reading/nimon_ruby_text.dart` — custom ruby renderer + measurement
- **Widget/class/function**: `NimonRubyText`, `measureNimonRubyText`, `_InlineRubyToken`
- **Why it may be heavy**
  - Uses `TextPainter` layout and line metrics computation in `measureNimonRubyText`.
  - Uses `WidgetSpan` + custom render object for inline ruby tokens.
  - Long documents + frequent rebuilds can be expensive; selection can also increase complexity.
- **Severity**: **High**
- **Likely issue vs confirmed**
  - **Confirmed heavy pattern**: `TextPainter.layout` and line metrics are expensive if called often.
  - **Likely**: On-screen `RichText` with many spans can be heavy if rebuilt repeatedly.

### 3) `lib/ui/bottom_sheets/episode_details_sheet.dart` — blurred draggable sheet
- **Widget/class/function**: `showEpisodeDetailsSheet`, `EpisodeDetailsSheet`
- **Why it may be heavy**
  - `showModalBottomSheet` with `BackdropFilter` blur (`sigma 12`).
  - Draggable sheet + clip + shadows; blur over a large background area can be a major raster cost.
  - Builds a sizable column with scroll content and sticky CTA.
- **Severity**: **High**

### 4) `lib/ui/bottom_sheets/mono_story_options_sheet.dart` — overlay entry panel above dock
- **Widget/class/function**: `showMonoStoryOptionsPanel`, `_DismissibleDockPanelState`
- **Why it may be heavy**
  - Uses `OverlayEntry` + full-screen `Stack` with dim layer and a draggable panel.
  - Panel uses `AnimatedOpacity` + `Transform.translate` + `ClipRRect` + shadow.
  - Own `AnimationController` and gesture handling; can run while underlying page is still mounted.
  - Must be diligently removed/disposed; otherwise can retain memory/work.
- **Severity**: **High**
- **Confirmed safe practice present**
  - `hideMonoStoryOptionsPanel()` disposes the scroll controller and removes the overlay (good).

### 5) `lib/features/widgets/real_book_3d_cover.dart` — 3D transform + shadows + blur chip
- **Widget/class/function**: `RealBook3DCover`, `_BookBody`
- **Why it may be heavy**
  - Multiple layered `BoxShadow`s, `Transform` with perspective, multiple `ClipRRect`.
  - Uses `BackdropFilter` blur for overlay title chip.
  - Expensive in lists/grids if used frequently.
- **Severity**: **Medium–High** (depends on how often it appears in scrolling surfaces)

### 6) `lib/features/create/story_creator_sentences_screen.dart` — creator mega-screen + many sheets
- **Widget/class/function**: `StoryCreatorSentencesScreen` (and related sheet builders)
- **Why it may be heavy**
  - Many `showModalBottomSheet` flows (some draggable) and large lists/forms.
  - Multiple providers watched; can cause rebuilds across a large subtree.
  - Rich editing UIs frequently rebuild during typing/dragging.
- **Severity**: **High**

### 7) `lib/features/profile/profile_screen.dart` — large tabbed screen with lots of UI
- **Widget/class/function**: `ProfileScreen` and internal sections (processing/published/saved)
- **Why it may be heavy**
  - Very large widget tree; lots of `InkWell`, `DecoratedBox`, cards/rows, and state.
  - Multiple dialogs/sheets; likely many rebuild triggers via state + animation tickers.
- **Severity**: **Medium–High**

## C. Rebuild risk list

### Broad rebuild scopes (likely)
- **`lib/features/mono/mono_screen.dart`**
  - Feed item UI is complex; avoid rebuilding cover blur stack when only a small notifier changes (bookmark/react).
  - Nested `PageView.builder` inside each post: `onPageChanged` uses `setState`, which rebuilds the entire post subtree.
- **`lib/features/profile/profile_screen.dart`**
  - Large file suggests large build method(s); if using `setState` frequently, scope may be too broad.
- **`lib/features/create/story_creator_sentences_screen.dart`**
  - Provider-driven tabs + editor modules; `ref.watch` changes can cause large areas to rebuild.

### Builder patterns that can still be heavy
- `AnimatedBuilder` is used in multiple places. It’s good when localized, but if the builder returns a large subtree, it can still be expensive.
- Many files use `MediaQuery.of(context)`/`LayoutBuilder` repeatedly; not a problem by itself, but can correlate with large build methods.

### Missing-const / object churn (likely)
- Many widgets create new `BoxDecoration`, `TextStyle.copyWith`, `EdgeInsets`, `BorderRadius` inline in `build`.
  - Usually fine, but in **large lists** or **high-frequency rebuild zones** it adds churn.

## D. Scroll/gesture risk list

### Nested scrolls / gesture arenas
- **Mono**: vertical feed + inner horizontal `PageView` per item (`lib/features/mono/mono_screen.dart`).
  - Risk: gesture competition (horizontal vs vertical) can feel “sticky” and can also trigger extra layout work.
- **DraggableScrollableSheet** in multiple sheets (`episode_bottom_sheet.dart`, `episode_details_sheet.dart`, creator sheets).
  - Risk: drag updates + rebuilds + blur can cause jank.
- **Overlay dock panel**: `mono_story_options_sheet.dart`
  - Risk: simultaneous scroll controller + drag-to-dismiss + animated opacity.

### Animated widgets during scroll
- Any `AnimatedOpacity` + `Transform` over scroll content can amplify raster cost (overlay panel).

## E. Image/media risk list

### Large network images decoded at full size (likely)
- Many `Image.network` and `NetworkImage` usages are present across home/cards/sheets.
- Some widgets use `filterQuality: FilterQuality.high` (good for quality, but potentially more costly).

### Blur generation / filters
- **BackdropFilter** is used in:
  - `lib/ui/bottom_sheets/episode_details_sheet.dart` (sigma 12 over full screen)
  - `lib/features/widgets/real_book_3d_cover.dart` (title chip)
  - `lib/shared/widgets/cards/oneshot_badged_card.dart` (blur title band)
  - `lib/features/widgets/episode_bottom_sheet.dart` (blur scrim wrapper)
- **ImageFiltered** / cover blur in Mono hero (`lib/features/mono/mono_screen.dart`)
  - The hero cover blur is now derived from the same cover image and uses `ResizeImage` (good), but it’s still a filter layer.

### Repeated image decode / resizing
- If the same image is shown in multiple places (card + sheet + hero), consider a unified thumbnail strategy (analysis-only recommendation).

## F. Overlay/bottom sheet risk list

### Heavy blurred sheets
- `episode_details_sheet.dart`: `BackdropFilter` + `DraggableScrollableSheet` + `ClipRRect` + shadows.
- `features/widgets/episode_bottom_sheet.dart`: transparent background + `BackdropFilter` + custom sheet.

### OverlayEntry panels
- `mono_story_options_sheet.dart`
  - Must be carefully removed; it already disposes controller and removes entry, but still a hotspot due to gesture + animation + shadow/clip.

### Eager build of heavy content
- Some sheets build full content trees immediately on open; if they include preview sections, long text, or multiple cards, opening can hitch.

## G. Lightweight optimization candidates (recommendations only)

### Easiest safe wins (low risk)
- **Localize rebuilds**:
  - Ensure `AnimatedBuilder`/`ValueListenableBuilder` wraps only the minimal widgets (e.g., a single icon), not large stacks.
- **Reduce clip/shadow churn in scrolling lists**:
  - Avoid unnecessary `ClipRRect` in list items when `Card` already clips.
  - Consolidate multiple shadows into one where visually acceptable.
- **Prefer resized decodes** for thumbnails:
  - Use `ResizeImage`/`cacheWidth`/`cacheHeight` for list/grid thumbnails (where not already used).

### Medium-risk wins
- **Blur containment**:
  - Constrain blurred regions (smaller BackdropFilter area) or make blur conditional based on performance mode/device class.
- **Sheet content laziness**:
  - Build “below-the-fold” sheet sections lazily (slivers), especially for long preview text.

### Higher-risk / architectural wins
- **Mono feed rendering strategy**:
  - Reduce per-item compositing layers (blur, gradients) or pre-render cover backgrounds.
  - Consider isolating hero cover blur into a cached layer if it’s repeatedly rebuilt.
- **Unify episode bottom sheet implementation**:
  - Two implementations exist; standardize to one optimized version to avoid drift and duplicated heavy work.

## H. Recommended optimization order

### Phase 1: safest / fastest wins
- Tighten rebuild scopes in hotspots (`mono_screen.dart`, creator screens) with small builder boundaries.
- Add/respect image decode sizing for list thumbnails and sheet cover images.
- Audit list items for unnecessary `ClipRRect` + shadows in repeated rows/cards.

### Phase 2: medium-risk cleanup
- Reduce blur usage area/sigma in the heaviest sheets (episode details) and cards with BackdropFilter bands.
- Convert heavy sheet bodies to sliver-based lazy build where appropriate.
- Standardize action bars and repeated button components to reduce layout complexity.

### Phase 3: deeper architecture fixes
- Revisit Mono feed structure to minimize layered compositing per item.
- Consolidate episode sheet(s) and optimize once.
- Consider caching/precomputing expensive derived layout for ruby text when feasible.

## I. File impact list (inspect first when optimizing)

High leverage / high risk:
- `lib/features/mono/mono_screen.dart`
- `lib/ui/reading/nimon_ruby_text.dart`
- `lib/ui/bottom_sheets/episode_details_sheet.dart`
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart`
- `lib/features/create/story_creator_sentences_screen.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/widgets/real_book_3d_cover.dart`
- `lib/shared/widgets/cards/oneshot_badged_card.dart`
- `lib/features/widgets/episode_bottom_sheet.dart`
- `lib/ui/bottom_sheets/episode_bottom_sheet.dart`

## J. Top 10 fixes I would do first (ordered)

1. **Constrain/remove full-screen `BackdropFilter` where possible** (start with `episode_details_sheet.dart`) — biggest raster win.
2. **Ensure all list/grid thumbnails use resized decodes** (`cacheWidth/cacheHeight` or `ResizeImage`) — reduces memory + decode time.
3. **Audit Mono hero cover blur layers** (`mono_screen.dart`) to ensure minimal repaint and avoid rebuilding blur stack on small state changes.
4. **Localize rebuilds for feed-item actions** (bookmark/react) to the smallest widgets (no large subtree rebuild).
5. **Reduce clip+shadow overuse in scrolling cards** (especially cover cards and 3D covers) — compositing win.
6. **Make heavy bottom sheet content lazy** (slivers / deferred build) for long sections — improves open/drag smoothness.
7. **Consolidate duplicate episode bottom sheets** into a single optimized implementation — removes drift and duplicated heavy work.
8. **Optimize overlay panel animations** (`mono_story_options_sheet.dart`) by minimizing animated area and avoiding expensive effects during drag.
9. **Review ruby text rebuild frequency** (`nimon_ruby_text.dart` usage sites) — avoid rebuilding spans on unrelated state changes.
10. **Add performance guardrails** (device class / “reduced effects” mode) for blur-heavy UI — ensures acceptable mid-tier performance without changing layout.

