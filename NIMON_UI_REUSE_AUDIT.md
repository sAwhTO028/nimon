# Nimon UI Reuse Audit (duplicate patterns + reuse opportunities)

This is an **analysis-only** audit. No code was refactored as part of this report.

## A. Executive summary

The codebase shows a **medium-to-high level of UI duplication**, mostly in:
- **Bottom sheet shells** (drag handle + rounded top radius + safe-area padding + scrollable body)
- **Badged media cards** (cover image + top-left badge + top-right JLPT chip + bottom title band + footer)
- **List rows** (thumbnail + title/description + trailing menu)
- **Action groups** (icon + label stacks; mixed color/shadow patterns)
- **Design tokens** used inconsistently (some files use `theme.space/theme.radii/theme.type`, others hardcode pixel values/colors)

Biggest optimization opportunities:
- **Unify bottom sheet scaffolding** into a lightweight base widget (drag handle, padding, shape, scrim, scroll controller plumbing).
- **Unify “badged cover card”** patterns into one shared card with configurable badge/chip/title/footer.
- **Standardize row primitives** (thumb+text+trailing; meta pills; icon-only square buttons).
- **Centralize repeated design constants** (radii, padding, shadows, scrim opacity) to reduce drift.

## B. Reusable widget candidates

Below are concrete candidates for shared widgets (or “base” widgets) that would remove repeated structures without over-engineering.

### 1) `NimonBottomSheetScaffold` (base)
- **Duplicated locations**
  - `lib/ui/bottom_sheets/episode_bottom_sheet.dart` (M3 draggable sheet)
  - `lib/features/widgets/episode_bottom_sheet.dart` (transparent bg + BackdropFilter + draggable)
  - `lib/features/profile/profile_screen.dart` (collection name sheet via `showModalBottomSheet`)
  - `lib/features/create/create_story_basics_form.dart` (progress bottom sheet invoked from form)
  - `lib/ui/create/widgets/one_short_paper_card.dart` (uses `showModalBottomSheet`, not fully reviewed here but referenced by grep)
  - `lib/ui/create/widgets/custom_prompt_sheet.dart` (listed by glob)
  - `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart` (large multi-step content in sheet)
  - `lib/features/mono/start_mono_sheet.dart` (simple “Add MONO” sheet UI)
- **What is shared**
  - Rounded top shape (20–28 radius)
  - Drag handle (width ~40–72, height ~4–6)
  - `SafeArea` + extra bottom padding for nav/insets
  - Scrollable content (either `SingleChildScrollView` or `CustomScrollView`)
  - Scrim/barrier opacity range (0.3–0.35)
- **What varies**
  - Transparent vs surface background
  - Draggable vs fixed-height
  - Blur-on-scrim (`BackdropFilter`) vs plain scrim
  - Header row layout, actions, primary CTA row
- **Priority**: **High**

### 2) `NimonEpisodeSheet` (single canonical episode preview sheet)
- **Duplicated locations**
  - `lib/ui/bottom_sheets/episode_bottom_sheet.dart` (global, Episode→EpisodeModel conversions, M3 sheet)
  - `lib/features/widgets/episode_bottom_sheet.dart` (premium details sheet for `EpisodeMeta`, has own animation controller + divider behavior)
  - Call sites include: `lib/features/home/widgets/mono_collection_row.dart`, `lib/features/story/story_detail_screen.dart` (via grep hits)
- **What is shared**
  - Episode cover + title + metadata
  - Preview card / preview section
  - Metrics row / stats
  - Action bar (save/share/start)
  - Draggable sheet sizing with snap points
- **What varies**
  - Data model inputs (full `Episode` vs `EpisodeMeta` vs `EpisodeModel`)
  - Styling choices (transparent background + blur vs solid surface)
  - Header/preview composition and animations
- **Priority**: **High**
- **Note**: This is a “choose one canonical implementation” situation (not just extract a base).

### 3) `NimonBadgedCoverCard` (cover + badge + JLPT chip + title band + footer)
- **Duplicated locations**
  - `lib/shared/widgets/cards/episode_badged_card.dart`
  - `lib/shared/widgets/cards/oneshot_badged_card.dart`
  - `lib/shared/widgets/compact_story_card.dart` (same “cover with overlays + title band” idea)
  - `lib/features/home/widgets/mono_collection_row.dart` (`_EpisodeCard` repeats badge/chip/title band + footer)
  - `lib/widgets/story_card.dart` (same “cover + content” but less overlay-heavy)
- **What is shared**
  - Cover image with placeholder
  - Top-left type badge (icon+text)
  - Top-right JLPT chip
  - Bottom title band (often blurred/gradient)
  - Footer row with avatar + two-line meta
- **What varies**
  - Radii (12 vs 20), aspect ratios, overlay style (blur vs gradient vs translucent)
  - Footer content (likes sometimes, sometimes not)
  - Tap target (InkWell border radius)
- **Priority**: **High**
- **Practical reuse**: a single base with “slots” for badge/chip/title/footer avoids forcing identical designs.

### 4) `NimonThumbWithBadge` (thumbnail + JLPT badge)
- **Duplicated locations**
  - `lib/features/profile/public_profile_widgets.dart` (`PublicStoryThumb`)
  - `lib/features/profile/mono_story_list_row.dart` (uses `PublicStoryThumb`)
  - Similar thumbnail-with-badge patterns appear inside cards (episode/oneshot) and could share image/placeholder logic.
- **What is shared**
  - `ClipRRect` + `Image.network` with fallback placeholder
  - Small corner badge pill
  - Consistent sizing parameters
- **What varies**
  - Badge location (top-left), badge style (dark pill)
  - Placeholder icon choice
- **Priority**: **Medium**

### 5) `NimonListRowScaffold` (thumb + title/desc + trailing)
- **Duplicated locations**
  - `lib/features/profile/mono_story_list_row.dart` (`MonoStoryListRow`)
  - `lib/features/profile/public_profile_widgets.dart` (`CollectionListRow` / `PublicCollectionListRow`)
  - Similar “row skeleton” patterns exist in profile and other lists (not exhaustively enumerated).
- **What is shared**
  - Left media thumb, `Expanded` middle column, optional trailing `IconButton`
  - Title style (bold, 2 lines), description style (muted, 1–2 lines)
  - Compact trailing menu constraints (36×36) and density
- **What varies**
  - Thumb geometry (square vs wide stacked)
  - Secondary line (count label vs description vs subtitle)
- **Priority**: **High**

### 6) `NimonMetadataPills` / “meta row” consolidation
- **Duplicated locations**
  - `lib/ui/widgets/nimon_metadata_row.dart` already provides a tokenized meta row (pill + text parts).
  - Multiple other screens implement their own pills/chips (e.g., card overlays, filter chips).
- **What is shared**
  - Small pill container + consistent text style
  - Wrap spacing/runSpacing patterns
- **What varies**
  - Colors by context, whether the value is a pill vs plain text
- **Priority**: **Medium**
- **Note**: Prefer *adopting* `NimonMetadataRow` as the default, not creating yet another.

### 7) `NimonIconButtonSquare` / `NimonFabMini` primitives
- **Duplicated locations**
  - `lib/ui/widgets/episode_action_bar.dart` (48×48 icon-only OutlinedButton)
  - Multiple bottom sheets and rows use icon-only actions with ad-hoc sizing.
- **What is shared**
  - Fixed size button, icon size ~20–22, rounded radius ~14
  - Disabled/loading state patterns
- **What varies**
  - Filled vs outlined vs tonal
  - Border opacity and background
- **Priority**: **Medium**

### 8) “Paper card” family consolidation
- **Duplicated locations**
  - `lib/ui/widgets/paper_sheet_widget.dart`
  - `lib/ui/widgets/paper_sheet_widget_compact.dart`
  - `lib/ui/create/widgets/one_short_paper_card.dart` (related; referenced by imports in add-mono sheet)
- **What is shared**
  - Same conceptual component: title, level, thumb, context, duration, selected state
  - Same border/boxShadow logic with small parameter changes
- **What varies**
  - Size calculations (fixed vs responsive clamp)
  - Typography sizes and padding
- **Priority**: **High**
- **Recommendation**: Make one `PaperSheetCard` with a `density` enum (`regular/compact`) and shared internal pieces.

## C. Duplicate bottom sheet patterns

### Bottom sheets (identified by file)
- `lib/ui/bottom_sheets/episode_bottom_sheet.dart`
- `lib/features/widgets/episode_bottom_sheet.dart`
- `lib/ui/bottom_sheets/episode_details_sheet.dart`
- `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart`
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart` *(dock-anchored overlay panel; “sheet-like” but not `showModalBottomSheet`)*
- `lib/features/see_more/widgets/filter_bottom_sheet.dart`
- `lib/features/learn/vocab_kanji_detail_sheet.dart`
- `lib/features/mono/start_mono_sheet.dart`
- `lib/ui/create/widgets/custom_prompt_sheet.dart`
- `lib/create_mono/widgets/header_sheet.dart`

### Grouping by structure

#### Group 1 — “DraggableScrollableSheet + slivers + M3 shape”
- `lib/ui/bottom_sheets/episode_bottom_sheet.dart`
- `lib/ui/bottom_sheets/episode_details_sheet.dart`
- **Could become**: `NimonDraggableSheetScaffold` (min/initial/max, snap, common shape, safe area, optional constrained width for tablet)

#### Group 2 — “Transparent background + blur scrim + internal draggable”
- `lib/features/widgets/episode_bottom_sheet.dart`
- **Could become**: an optional wrapper for Group 1 (scrim/backdrop config), or migrate to the global M3 sheet for consistency.

#### Group 3 — “Standard fixed bottom sheet container (handle + header + scroll + CTA)”
- `lib/features/see_more/widgets/filter_bottom_sheet.dart` (handle bar + header row + scroll + apply CTA)
- Likely also: `lib/features/learn/vocab_kanji_detail_sheet.dart`, `lib/ui/create/widgets/custom_prompt_sheet.dart` (not fully read here)
- **Could become**: `NimonSheetSectionedContent` (handle, header slot, body slot, footer CTA slot)

#### Group 4 — “Overlay panel anchored to persistent UI (dock)”
- `lib/ui/bottom_sheets/mono_story_options_sheet.dart`
  - Unique behavior: overlay entry, dismiss drag logic, dock-safe dimming.
- **Should stay separate** from modal sheets, but can still reuse:
  - drag-dismiss controller
  - panel container styling (radius/border/shadow)
  - list row items inside the panel

## D. Duplicate card/list item patterns

### 1) Mono item rows / story rows
- **`MonoStoryListRow`**: `lib/features/profile/mono_story_list_row.dart`
  - Good candidate to be the canonical “row” primitive (already fairly clean).
- Similar “thumb + title + subtitle/desc” appears in:
  - `CollectionListRow` / `PublicCollectionListRow`: `lib/features/profile/public_profile_widgets.dart`

### 2) Collection rows/cards
- `CollectionListRow` and stacked thumb plate: `lib/features/profile/public_profile_widgets.dart`
  - Reusable stacked-thumb is a nice distinct pattern; consider exporting `_StackedCollectionThumb` as a shared widget if used elsewhere.
- `CommunityCollectionCard`: `lib/features/home/widgets/community_collection_card.dart` (found by glob; not read in detail) likely overlaps with collection presentation.

### 3) Processing rows/cards
- `lib/features/profile/profile_screen.dart` contains processing-related cards/rows (e.g. `_ProcessingDraftCard` references found by grep).
- Risk: these are often “similar UI, different state machine”. Reuse should focus on row shells + action buttons/chips, not logic.

### 4) Episode/OneShot/Story cover cards
Clear duplication of “cover + overlays + footer” across:
- `lib/shared/widgets/cards/episode_badged_card.dart`
- `lib/shared/widgets/cards/oneshot_badged_card.dart`
- `lib/features/home/widgets/mono_collection_row.dart` (`_EpisodeCard`)
- `lib/shared/widgets/compact_story_card.dart`
- `lib/widgets/story_card.dart` (more classic Material card)

Recommendation: unify the “cover overlay layer” primitives (badge chip/title band) first, then migrate cards gradually.

## E. Design token / styling duplication

### 1) Tokens used inconsistently
- `lib/ui/widgets/nimon_metadata_row.dart` uses `theme.space`, `theme.radii`, `theme.type` (from `nimon_tokens` / `nimon_typography`).
- Many other widgets hardcode:
  - radii: `12`, `14`, `16`, `20`, `24`, `28`
  - padding: `12`, `16`, `20`, `24`
  - icon sizes: `14`, `16`, `20`, `22`
  - shadows: `withOpacity(0.05–0.14)` + blur radius `4–18`

### 2) Repeated colors
Examples found in sampled files:
- Blue selection border: `Color(0xFF3B82F6)` in paper sheet widgets.
- Repeated grayscale text colors: `0xFF111111`, `0xFF444444`, `0xFF666666`, `0xFF777777`.
- Scrim/barrier: `Colors.black.withOpacity(0.22–0.35)` across sheets/overlays.

### 3) Repeated chip styles
- JLPT chips appear in:
  - `CompactStoryCard` (`_buildJLPTChip`)
  - `EpisodeBadgedCard` (`_buildJLPTChip`)
  - `OneShotBadgedCard` (`_buildJLPTChip`)
  - `MonoCollectionRow._EpisodeCard` (`_buildJLPTChip`)
  - `PublicStoryThumb` (badge pill)
- These should share one base “badge” component and a palette mapping.

### 4) Repeated handle bars
- `FilterBottomSheet` uses a 40×4 handle.
- Episode sheets use drag handle or a custom pull handle.
- Standardize a `NimonSheetHandle()` widget.

## F. Refactor risk notes

### 1) Similar appearance, different behavior
- Episode bottom sheets: one uses full `Episode` blocks + conversions; another uses `EpisodeMeta` + animated divider behavior.
  - **Risk**: consolidating prematurely could break navigation, sharing, or reader entry.
  - **Mitigation**: standardize the *shell* first, then unify content + model mapping.

### 2) Overlay vs modal sheets
- `mono_story_options_sheet.dart` is overlay-entry driven and dock-aware; it is not a normal modal sheet.
  - **Risk**: forcing it into modal conventions could break dock UX/back behavior.
  - **Mitigation**: reuse only internal components (panel container + list row items + handle), keep overlay mechanics separate.

### 3) Hardcoded sizes in cards/rows
- Many cards encode flex ratios (`flex: 71/29`, etc.) and precise paddings.
  - **Risk**: extracting a shared widget may subtly shift layout across screens.
  - **Mitigation**: create a shared base that preserves the defaults exactly; migrate file-by-file.

### 4) Duplicate file paths / potential duplication
- The repo appears to contain both `lib/features/...` and `lib\\features\\...` variants in search results (Windows path duplication).
  - **Risk**: accidental duplicate copies can cause drift and inconsistent fixes.
  - **Mitigation**: verify whether these are truly duplicated files or just path normalization artifacts in tooling before refactoring.

## G. Recommended refactor order

### Phase 1 (safe + high value)
- Create a **bottom sheet scaffold** and migrate the simplest sheets first (Filter sheet, collection name sheet).
- Consolidate **paper sheet widgets** (`PaperSheetWidget` + `PaperSheetWidgetCompact`) into one component with density variants.
- Extract **JLPT chip + type badge** primitives used by cards.

### Phase 2 (medium risk)
- Unify **badged cover card** variants (Episode/OneShot/CompactStory/MonoCollectionRow cards) under one base.
- Unify **list row scaffolds** (thumb + title/desc + trailing menu).
- Standardize **icon-only square buttons** and CTA row layouts (like `EpisodeActionBar`).

### Phase 3 (higher risk / broader consolidation)
- Choose a single canonical **Episode bottom sheet** and deprecate the duplicate implementation.
- Normalize styling/token usage across older widgets to the design system (`theme.space`, `theme.radii`, `theme.type`).
- Consolidate profile “processing/published/saved” list blocks into reusable section components where logic allows.

## H. File impact list

Files most likely to be touched first (high duplication leverage):
- `lib/ui/bottom_sheets/episode_bottom_sheet.dart`
- `lib/features/widgets/episode_bottom_sheet.dart`
- `lib/ui/widgets/paper_sheet_widget.dart`
- `lib/ui/widgets/paper_sheet_widget_compact.dart`
- `lib/shared/widgets/cards/episode_badged_card.dart`
- `lib/shared/widgets/cards/oneshot_badged_card.dart`
- `lib/features/home/widgets/mono_collection_row.dart`
- `lib/shared/widgets/compact_story_card.dart`
- `lib/features/see_more/widgets/filter_bottom_sheet.dart`
- `lib/features/profile/public_profile_widgets.dart`
- `lib/features/profile/mono_story_list_row.dart`

## I would refactor these first

1. **Unify Episode bottom sheet implementations** (pick canonical; share the shell first) — `lib/ui/bottom_sheets/episode_bottom_sheet.dart` + `lib/features/widgets/episode_bottom_sheet.dart`
2. **Merge `PaperSheetWidget` + `PaperSheetWidgetCompact` into one** (density variants) — `lib/ui/widgets/paper_sheet_widget*.dart`
3. **Extract `JLPTChip` + `TypeBadge` primitives** and reuse across cards/rows — multiple card files + `PublicStoryThumb`
4. **Create a base `NimonBottomSheetScaffold`** and migrate `FilterBottomSheet` to it — `lib/features/see_more/widgets/filter_bottom_sheet.dart`
5. **Create `NimonBadgedCoverCard` base** and migrate `EpisodeBadgedCard` and `OneShotBadgedCard` first — `lib/shared/widgets/cards/*`
6. **Standardize “cover title band overlay”** (gradient/blur band) — `CompactStoryCard`, `OneShotBadgedCard`, `MonoCollectionRow._EpisodeCard`
7. **Create `NimonListRowScaffold` base** and migrate `MonoStoryListRow` + `CollectionListRow` to share shells — `lib/features/profile/*`
8. **Standardize icon-only action buttons** (48×48 square, radius 14) — start from `EpisodeActionBar`
9. **Standardize sheet handle bars** (width/height/radius/opacity) — Filter sheet + other sheets
10. **Tokenize repeated radii/padding/shadows** in high-traffic widgets (cards + sheets) to reduce drift (incremental adoption of `nimon_tokens`)

