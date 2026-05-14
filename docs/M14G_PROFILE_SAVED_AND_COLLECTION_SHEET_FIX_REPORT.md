# M14G Profile Saved and Collection Sheet Fix Report

## Problem

1. **Saved tab:** Remote saved list used **`Card` + `ListTile`**, which read as large card blocks instead of the compact **mono row** style used on the Published tab.
2. **Collection sheets:** “N selected” used **`Colors.black.withOpacity`** on a dark sheet surface, so the label looked black / unreadable in dark mode.
3. **Keyboard:** Add / move / new collection flows used a standard modal body without **`viewInsets`** padding and without a **scrollable** shell, so on phones the sheet could sit behind the keyboard when naming a collection.

## Scope

- **Saved tab UI only** (no bookmark API or pager logic changes).
- **Add to collection** bottom sheet (`add_to_collection_sheet.dart`) and **rename/new collection name** sheet (`_showCollectionNameBottomSheet` / `_CollectionNameSheet` in `profile_screen.dart`).
- **Published multi-select bar** (`$count selected`) colors updated to theme tokens for dark readability (same user-visible string as collection flows).
- New shared layout widget for collection modals.
- **No** backend, validation, protected-action guard, or product rule changes.

## Saved Tab List Normalization

- Extracted **`ProfileSavedRemoteTab`** to `lib/features/profile/presentation/profile_saved_remote_tab.dart` (same behavior as before: guest / loading / error / empty / list).
- List body: **`ListView.separated`** + **`MonoStoryListRow`** (thumbnail, title, description, optional publish badge) + trailing **`bookmark_remove`** `IconButton`, matching the compact pattern used for loose monos in `_FolderGroupList`.
- **Keys** for tests: `kProfileSavedCompactRowKey`, `kProfileSavedUnsaveButtonKey` (prefix + mono id).

## Collection Sheet Dark Text Fix

- **`add_to_collection_sheet.dart`:** “N selected” now uses **`Theme.of(context).colorScheme.onSurfaceVariant`** and **`collectionSheetSelectedCountTextKey`** (`ValueKey('collectionSheetSelectedCountText')`).
- Headline and list tiles use **`onSurface` / `onSurfaceVariant`** instead of default / black-only styles.
- **`_buildFilterOrSelectionBar`** (Published loose multi-select): bar fill/border and **`$count selected`** use **`ColorScheme`** (`surfaceContainerHighest`, `outlineVariant`, `onSurfaceVariant`) instead of `Colors.grey.shade100` and default text color.

## Keyboard-Safe Bottom Sheets

- Added **`ProfileCollectionBottomSheetFrame`** (`lib/features/profile/presentation/widgets/profile_collection_bottom_sheet_frame.dart`):
  - Modal callers use **`isScrollControlled: true`**, **`useSafeArea: true`**, **`backgroundColor: Colors.transparent`**, **`showDragHandle: false`**.
  - Frame: **`AnimatedPadding`** (`viewInsets.bottom`), **`SafeArea(top: false)`**, bottom **`Align`**, **`ConstrainedBox`** (**`maxHeight` ~0.88** of screen only), **`Material`** surface + top radius 24, **`SingleChildScrollView`** with **`onDrag`** keyboard dismiss, inner drag pill, horizontal padding 28.
- **`showAddToCollectionSheet`** wraps **`_AddToCollectionSheetBody`** in the frame; inner duplicate bottom padding removed.
- **`_showCollectionNameBottomSheet`** wraps **`_CollectionNameSheet`** in the same frame; removed duplicate **`AnimatedPadding`** from `_CollectionNameSheet` (frame owns keyboard lift).

## Shared Helpers

- **`ProfileCollectionBottomSheetFrame`** — single place for collection modal chrome + keyboard behavior.

## Tests Added

- `test/features/profile/profile_saved_tab_compact_list_test.dart` — compact rows, no `Card`, keys, bookmark icon, tap opens stub reader route.
- `test/features/profile/collection_bottom_sheet_keyboard_dark_test.dart` — dark selected-count contrast; frame + `MediaQuery.viewInsets` smoke; light overflow check.

## Commands Run

```bash
dart format lib/features/profile/presentation/profile_saved_remote_tab.dart lib/features/profile/presentation/widgets/profile_collection_bottom_sheet_frame.dart lib/features/profile/presentation/add_to_collection_sheet.dart lib/features/profile/profile_screen.dart test/features/profile/profile_saved_tab_compact_list_test.dart test/features/profile/collection_bottom_sheet_keyboard_dark_test.dart

flutter analyze lib/features/profile/presentation/profile_saved_remote_tab.dart lib/features/profile/presentation/widgets/profile_collection_bottom_sheet_frame.dart lib/features/profile/presentation/add_to_collection_sheet.dart

flutter test test/features/profile/profile_saved_tab_compact_list_test.dart test/features/profile/collection_bottom_sheet_keyboard_dark_test.dart test/features/profile/add_to_collection_sheet_test.dart
flutter test test/features/profile
```

## Manual Verification

**Dark:** Profile → Saved: compact rows, readable unsave icon. Published → multi-select bar readable. Add / move / new collection: open sheet, focus name field — sheet scrolls / lifts; Cancel + Create visible.

**Light:** Same flows; no layout regression.

## Remaining Risks

- Very small devices with **both** long collection list and keyboard may still need scrolling inside the capped sheet; `SingleChildScrollView` is the safety valve.
- Full-repo `flutter analyze` on `profile_screen.dart` still reports historical warnings unrelated to M14G.
