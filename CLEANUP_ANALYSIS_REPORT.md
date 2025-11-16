# Flutter Project Cleanup Analysis Report

## 1. Unused Files (Candidates for Delete)

### 100% Safe to Delete:
- **`lib/main_example.dart`** - Standalone example file, not imported anywhere. Used for testing CreateMonoScreen independently.
- **`lib/app/app.dart`** - Not imported. `main.dart` defines its own `NimonApp` class inline.
- **`lib/app/nav_shell.dart`** - Not imported. `main.dart` defines its own `AppShell` class inline.
- **`lib/login/login_screen.dart`** - Not used. `main.dart` imports `features/auth/login_screen.dart` instead.
- **`lib/ui/widgets/sheets/`** - Empty directory, can be removed.

### Needs Manual Review:
- None identified

---

## 2. Unused Symbols

### In `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart`:
- **`_getPromptTitle()`** (line 754) - Private method, never called
- **`_getContextText()`** (line 765) - Private method, never called  
- **`_getDuration()`** (line 776) - Private method, never called
- **`_getCategoryIcon()`** (line 787) - Private method, never called
- **`_getAssetPathForCategory()`** (line 814) - Private method, never called
- **`CreationType` enum** (line 8) - Defined here but also in `create_mono_screen.dart`. This one is marked "Legacy - kept for compatibility" but `create_mono_screen.dart` has the active one.

### In `lib/main.dart`:
- **Commented code** (line 21): `//final repo = StoryRepoMock();` - Dead comment

---

## 3. Duplicate Code

### Duplicate Enum Definitions:
- **`CreationType`** is defined in:
  1. `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart` (line 8) - marked as "Legacy"
  2. `lib/create_mono/create_mono_screen.dart` (line 6) - actively used

**Recommendation**: The one in `add_mono_bottom_sheet.dart` appears unused. The file imports it from `create_mono_screen.dart` via `header_sheet.dart`, so the local definition might be redundant.

### Duplicate Helper Methods:
- Similar helper methods exist in multiple files:
  - `_getPromptTitle()`, `_getContextText()`, `_getDuration()` in both `add_mono_bottom_sheet.dart` and `create_mono_screen.dart`
  - `_getCategoryIcon()`, `_getAssetPathForCategory()` in multiple files

**Note**: These might be intentionally duplicated for different contexts, but worth reviewing for consolidation.

---

## 4. Warnings / Potential Risky Changes

### ⚠️ Be Careful:
1. **`showAddMonoSheet()` function** (line 1099 in `add_mono_bottom_sheet.dart`) - Not currently called, but might be intended for future use or called via reflection/routes. Mark with TODO instead of deleting.

2. **`CreationType` enum duplication** - Before removing from `add_mono_bottom_sheet.dart`, verify that `header_sheet.dart` actually imports it from `create_mono_screen.dart` and doesn't rely on the local definition.

3. **Empty `sheets/` directory** - Verify it's not referenced in build scripts or documentation.

---

## 5. Safe Cleanup Opportunities

### Unused Imports:
- Need to scan each file individually (will do in next phase)

### Code Style:
- Convert `var` to `final` where appropriate
- Remove commented-out code
- Fix formatting inconsistencies

### Dead Code:
- Remove the 5 unused private methods in `add_mono_bottom_sheet.dart` (100% safe)
- Remove commented `repo` line in `main.dart`

---

## 6. Large Files (Suggestions Only)

- **`lib/ui/bottom_sheets/add_mono_bottom_sheet.dart`** (1109 lines) - Could potentially split into:
  - Main sheet widget
  - Custom prompt sheet widget  
  - State management
  - Helper methods

- **`lib/features/create/create_screen.dart`** - Check line count, might benefit from splitting

**Note**: Only suggest, do not split without explicit permission.

---

## Next Steps

1. ✅ Delete unused files (100% safe)
2. ✅ Remove unused private methods
3. ✅ Clean up commented code
4. ⚠️ Add TODOs for uncertain items
5. 🔍 Scan for unused imports file-by-file
6. 🎨 Apply safe code style improvements

